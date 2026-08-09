begin;

alter table public.inventory_audits
  add column if not exists parent_audit_id bigint references public.inventory_audits (id) on delete set null,
  add column if not exists resolution_status text not null default 'pending',
  add column if not exists resolution_protocol jsonb,
  add column if not exists resolution_sent_at timestamp with time zone,
  add column if not exists resolution_sent_to text;

alter table public.inventory_audits
  drop constraint if exists inventory_audits_resolution_status_check;

alter table public.inventory_audits
  add constraint inventory_audits_resolution_status_check
  check (resolution_status in ('pending', 'warehouse_check', 'manager_review', 'ready_to_send', 'sent', 'acknowledged'));

create unique index if not exists inventory_audits_parent_control_unique_idx
  on public.inventory_audits (parent_audit_id)
  where parent_audit_id is not null and audit_origin = 'vehicle_discrepancy_control';

alter table public.inventory_audit_items
  add column if not exists parent_audit_item_id bigint references public.inventory_audit_items (id) on delete set null,
  add column if not exists resolution_code text not null default 'pending',
  add column if not exists resolution_note text,
  add column if not exists charge_selected boolean not null default false,
  add column if not exists charge_quantity numeric(14,3) not null default 0,
  add column if not exists charge_amount numeric(14,2) not null default 0;

alter table public.inventory_audit_items
  drop constraint if exists inventory_audit_items_resolution_code_check;

alter table public.inventory_audit_items
  add constraint inventory_audit_items_resolution_code_check
  check (resolution_code in ('pending', 'no_operator', 'warehouse_error', 'transfer_error', 'accounting_correction', 'no_financial_impact', 'charge', 'investigate'));

create index if not exists inventory_audit_items_parent_idx
  on public.inventory_audit_items (parent_audit_item_id);

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
  v_warehouse_employee_id uuid;
  v_control_id bigint;
  v_instruction_id bigint;
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
  from public.inventory_audit_items
  where audit_id = p_audit_id and difference_quantity < -0.0001;
  if v_item_count = 0 then
    return jsonb_build_object('created', false, 'reason', 'no_negative_items');
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

  select id into v_warehouse_employee_id
  from public.employees
  where active = true
    and (lower(coalesce(role, '')) like '%sklad%' or lower(coalesce(email, '')) = 'lukas.urbanek@olmika.cz')
    and (warehouse_id = v_vehicle_warehouse_id or warehouse_id is null)
  order by (warehouse_id = v_vehicle_warehouse_id) desc, (lower(coalesce(email, '')) = 'lukas.urbanek@olmika.cz') desc, surname nulls last, name nulls last
  limit 1;

  insert into public.inventory_audits (
    audit_date, scope_type, stock_location_id, assigned_employee_id, responsible_name,
    note, status, book_quantity_total, counted_quantity_total, difference_quantity_total,
    difference_value_total, audit_origin, parent_audit_id, resolution_status
  ) values (
    current_date, 'warehouse', v_warehouse_location_id, v_warehouse_employee_id,
    (select trim(concat_ws(' ', name, surname)) from public.employees where id = v_warehouse_employee_id),
    'Automatická cílená kontrola rozdílů inventury vozidla #' || p_audit_id,
    case when v_warehouse_employee_id is null then 'draft' else 'assigned' end,
    0, 0, 0, 0, 'vehicle_discrepancy_control', p_audit_id, 'warehouse_check'
  ) returning id into v_control_id;

  insert into public.inventory_audit_items (
    audit_id, stock_location_id, product_id, book_quantity, counted_quantity,
    difference_quantity, unit_cost, difference_value, note, parent_audit_item_id
  )
  select
    v_control_id,
    v_warehouse_location_id,
    parent.product_id,
    coalesce((select sum(balance.quantity_on_hand)
      from public.stock_location_balances balance
      where balance.stock_location_id = v_warehouse_location_id
        and balance.product_id = parent.product_id), 0),
    0, 0, parent.unit_cost, 0,
    'Kontrola skladu k rozdílu vozidla #' || p_audit_id,
    parent.id
  from public.inventory_audit_items parent
  where parent.audit_id = p_audit_id and parent.difference_quantity < -0.0001;

  select coalesce(sum(book_quantity), 0) into v_book_total
  from public.inventory_audit_items where audit_id = v_control_id;
  update public.inventory_audits set book_quantity_total = v_book_total where id = v_control_id;

  if v_warehouse_employee_id is not null then
    insert into public.daily_instructions (
      title, message, target_type, target_employee_id, valid_from, valid_to,
      priority, requires_acknowledgement, is_active
    ) values (
      'Kontrolní inventura skladu #' || v_control_id,
      'Spočítej pouze ' || v_item_count || ' problematických položek k inventuře vozidla #' || p_audit_id || '. Otevři Mobil > Sklad > Inventura.',
      'employee', v_warehouse_employee_id, current_date, current_date + 2,
      'important', true, true
    ) returning id into v_instruction_id;
    update public.inventory_audits set instruction_id = v_instruction_id where id = v_control_id;
  end if;

  update public.inventory_audits set resolution_status = 'warehouse_check' where id = p_audit_id;
  return jsonb_build_object('created', true, 'audit_id', v_control_id, 'item_count', v_item_count);
end;
$$;

create or replace function public.trigger_vehicle_discrepancy_control_v33()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.scope_type = 'vehicle'
     and new.parent_audit_id is null
     and new.status in ('counted', 'transfer_ready', 'evaluated')
     and (old.status is distinct from new.status or old.difference_quantity_total is distinct from new.difference_quantity_total) then
    perform public.ensure_vehicle_discrepancy_warehouse_audit_v33(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_vehicle_discrepancy_control_v33 on public.inventory_audits;
create trigger trg_vehicle_discrepancy_control_v33
after update of status, difference_quantity_total on public.inventory_audits
for each row execute function public.trigger_vehicle_discrepancy_control_v33();

grant execute on function public.ensure_vehicle_discrepancy_warehouse_audit_v33(bigint) to authenticated;

do $$
declare v_row record;
begin
  for v_row in
    select a.id
    from public.inventory_audits a
    where a.scope_type = 'vehicle'
      and a.parent_audit_id is null
      and a.status in ('counted', 'transfer_ready', 'evaluated')
      and exists (select 1 from public.inventory_audit_items i where i.audit_id = a.id and i.difference_quantity < -0.0001)
      and not exists (select 1 from public.inventory_audits child where child.parent_audit_id = a.id)
    order by a.created_at desc
    limit 10
  loop
    perform public.ensure_vehicle_discrepancy_warehouse_audit_v33(v_row.id);
  end loop;
end $$;

do $$
declare
  v_audit record;
  v_employee_id uuid;
  v_instruction_id bigint;
begin
  for v_audit in
    select a.id, a.parent_audit_id, sl.warehouse_id,
           (select count(*) from public.inventory_audit_items i where i.audit_id = a.id) as item_count
    from public.inventory_audits a
    join public.stock_locations sl on sl.id = a.stock_location_id
    where a.audit_origin = 'vehicle_discrepancy_control'
      and a.assigned_employee_id is null
  loop
    select id into v_employee_id
    from public.employees
    where active = true
      and (lower(coalesce(role, '')) like '%sklad%' or lower(coalesce(email, '')) = 'lukas.urbanek@olmika.cz')
      and (warehouse_id = v_audit.warehouse_id or warehouse_id is null)
    order by (warehouse_id = v_audit.warehouse_id) desc, (lower(coalesce(email, '')) = 'lukas.urbanek@olmika.cz') desc
    limit 1;
    if v_employee_id is null then continue; end if;

    insert into public.daily_instructions (
      title, message, target_type, target_employee_id, valid_from, valid_to,
      priority, requires_acknowledgement, is_active
    ) values (
      'Kontrolní inventura skladu #' || v_audit.id,
      'Spočítej pouze ' || v_audit.item_count || ' problematických položek k inventuře vozidla #' || v_audit.parent_audit_id || '. Otevři Mobil > Sklad > Inventura.',
      'employee', v_employee_id, current_date, current_date + 2,
      'important', true, true
    ) returning id into v_instruction_id;

    update public.inventory_audits
    set assigned_employee_id = v_employee_id,
        responsible_name = (select trim(concat_ws(' ', name, surname)) from public.employees where id = v_employee_id),
        instruction_id = v_instruction_id,
        status = 'assigned'
    where id = v_audit.id;
  end loop;
end $$;

commit;
