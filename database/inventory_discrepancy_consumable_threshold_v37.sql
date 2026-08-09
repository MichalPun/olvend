begin;

-- Ingredients and consumables are high-volume warehouse stock. Recounting the
-- warehouse for one sleeve or one package is not material enough to justify
-- the work, regardless of whether the base unit is kg or pieces.
create or replace function public.inventory_warehouse_check_threshold_v36(
  p_product_id bigint,
  p_warehouse_location_id bigint
)
returns numeric
language sql
stable
security invoker
set search_path = public
as $$
  select case
    when coalesce(product.product_category, '') in ('ingredient', 'consumable')
    then greatest(
      public.inventory_warehouse_check_package_units_v35(product.id) * 5,
      coalesce((
        select sum(balance.quantity_on_hand)
        from public.stock_location_balances balance
        where balance.stock_location_id = p_warehouse_location_id
          and balance.product_id = product.id
      ), 0) * 0.01
    )
    else public.inventory_warehouse_check_package_units_v35(product.id)
  end
  from public.products product
  where product.id = p_product_id;
$$;

-- Apply the expanded materiality rule to every unfinished automatic control.
delete from public.inventory_audit_items child
using public.inventory_audits control,
      public.inventory_audit_items parent,
      public.products product
where child.audit_id = control.id
  and control.audit_origin = 'vehicle_discrepancy_control'
  and control.status in ('draft', 'assigned')
  and parent.id = child.parent_audit_item_id
  and product.id = parent.product_id
  and (
    coalesce(product.product_category, '') = 'food_ready'
    or not public.inventory_requires_warehouse_check_v36(
      parent.product_id,
      parent.difference_quantity,
      control.stock_location_id
    )
  );

update public.inventory_audits control
set book_quantity_total = coalesce((
      select sum(item.book_quantity)
      from public.inventory_audit_items item
      where item.audit_id = control.id
    ), 0)
where control.audit_origin = 'vehicle_discrepancy_control'
  and control.status in ('draft', 'assigned');

update public.daily_instructions instruction
set is_active = false
where instruction.id in (
  select control.instruction_id
  from public.inventory_audits control
  where control.audit_origin = 'vehicle_discrepancy_control'
    and control.status in ('draft', 'assigned')
    and not exists (
      select 1 from public.inventory_audit_items item where item.audit_id = control.id
    )
);

update public.inventory_audits parent
set resolution_status = 'manager_review'
from public.inventory_audits control
where control.parent_audit_id = parent.id
  and control.audit_origin = 'vehicle_discrepancy_control'
  and control.status in ('draft', 'assigned')
  and not exists (
    select 1 from public.inventory_audit_items item where item.audit_id = control.id
  );

update public.inventory_audits control
set status = 'cancelled',
    resolution_status = 'manager_review',
    instruction_id = null,
    note = concat_ws(E'\n', nullif(control.note, ''),
      'Automaticky zruseno: nezustala zadna polozka nad relativnim prahem skladu.')
where control.audit_origin = 'vehicle_discrepancy_control'
  and control.status in ('draft', 'assigned')
  and not exists (
    select 1 from public.inventory_audit_items item where item.audit_id = control.id
  );

commit;
