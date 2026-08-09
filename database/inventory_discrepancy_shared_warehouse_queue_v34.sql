begin;

create or replace function public.ensure_vehicle_discrepancy_warehouse_audit_v33(p_audit_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit public.inventory_audits%rowtype;
  v_vehicle_warehouse_id bigint;
  v_warehouse_location_id bigint;
  v_control_id bigint;
  v_item_count integer;
  v_book_total numeric(14,3);
  v_target_label text;
begin
  perform pg_advisory_xact_lock(hashtextextended('vehicle-discrepancy-control:' || p_audit_id::text, 0));

  select * into v_audit from public.inventory_audits where id = p_audit_id;
  if not found or v_audit.scope_type <> 'vehicle' or v_audit.parent_audit_id is not null then
    return jsonb_build_object('created', false, 'reason', 'not_vehicle_parent');
  end if;

  select id into v_control_id
  from public.inventory_audits
  where parent_audit_id = p_audit_id and audit_origin = 'vehicle_discrepancy_control'
  limit 1;
  if v_control_id is not null then
    return jsonb_build_object('created', false, 'reason', 'already_exists', 'audit_id', v_control_id);
  end if;

  select count(*) into v_item_count
  from public.inventory_audit_items item
  join public.products product on product.id = item.product_id
  where item.audit_id = p_audit_id
    and item.difference_quantity < -0.0001
    and coalesce(product.product_category, '') <> 'food_ready';
  if v_item_count = 0 then
    return jsonb_build_object('created', false, 'reason', 'no_warehouse_check_items');
  end if;

  select warehouse_id into v_vehicle_warehouse_id
  from public.vehicles where id = v_audit.vehicle_id;
  if v_vehicle_warehouse_id is null then
    return jsonb_build_object('created', false, 'reason', 'warehouse_missing');
  end if;

  select id, name into v_warehouse_location_id, v_target_label
  from public.stock_locations
  where location_type = 'warehouse' and warehouse_id = v_vehicle_warehouse_id and active = true
  order by id limit 1;
  if v_warehouse_location_id is null then
    return jsonb_build_object('created', false, 'reason', 'warehouse_location_missing');
  end if;

  insert into public.inventory_audits (
    audit_date, scope_type, stock_location_id, assigned_employee_id, responsible_name,
    note, status, book_quantity_total, counted_quantity_total, difference_quantity_total,
    difference_value_total, audit_origin, parent_audit_id, resolution_status
  ) values (
    current_date, 'warehouse', v_warehouse_location_id, null, 'Fronta skladu ' || v_target_label,
    'Automatická cílená kontrola rozdílů inventury vozidla #' || p_audit_id,
    'assigned', 0, 0, 0, 0, 'vehicle_discrepancy_control', p_audit_id, 'warehouse_check'
  ) returning id into v_control_id;

  insert into public.inventory_audit_items (
    audit_id, stock_location_id, product_id, book_quantity, counted_quantity,
    difference_quantity, unit_cost, difference_value, note, parent_audit_item_id
  )
  select
    v_control_id, v_warehouse_location_id, parent.product_id,
    coalesce((select sum(balance.quantity_on_hand)
      from public.stock_location_balances balance
      where balance.stock_location_id = v_warehouse_location_id
        and balance.product_id = parent.product_id), 0),
    0, 0, parent.unit_cost, 0,
    'Kontrola skladu k rozdílu vozidla #' || p_audit_id, parent.id
  from public.inventory_audit_items parent
  join public.products product on product.id = parent.product_id
  where parent.audit_id = p_audit_id
    and parent.difference_quantity < -0.0001
    and coalesce(product.product_category, '') <> 'food_ready';

  select coalesce(sum(book_quantity), 0) into v_book_total
  from public.inventory_audit_items where audit_id = v_control_id;
  update public.inventory_audits set book_quantity_total = v_book_total where id = v_control_id;
  update public.inventory_audits set resolution_status = 'warehouse_check' where id = p_audit_id;

  return jsonb_build_object(
    'created', true,
    'audit_id', v_control_id,
    'item_count', v_item_count,
    'assignment', 'warehouse_queue'
  );
end;
$$;

-- Open automatic controls become shared warehouse work. New controls exclude
-- fresh food because a later warehouse count cannot establish whether a return
-- or expiry was recorded against the wrong place. Existing rows are preserved
-- until a manager explicitly confirms their removal from an open inventory.
update public.daily_instructions instruction
set is_active = false
where instruction.id in (
  select audit.instruction_id
  from public.inventory_audits audit
  where audit.audit_origin = 'vehicle_discrepancy_control'
    and audit.status in ('draft', 'assigned')
);

update public.inventory_audits audit
set assigned_employee_id = null,
    responsible_name = 'Fronta skladu ' || coalesce(location.name, ''),
    instruction_id = null,
    status = 'assigned',
    book_quantity_total = coalesce((
      select sum(item.book_quantity)
      from public.inventory_audit_items item
      where item.audit_id = audit.id
    ), 0)
from public.stock_locations location
where location.id = audit.stock_location_id
  and audit.audit_origin = 'vehicle_discrepancy_control'
  and audit.status in ('draft', 'assigned');

commit;
