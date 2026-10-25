begin;

-- Stock audits store ingredient quantities in their product base unit. For kg/l
-- products, package.units_per_package is historical data and can be either the
-- base-unit amount (0.5, 1) or grams/millilitres (500, 1000). Convert the
-- package price to the actual stock base-unit price before valuing differences.
create or replace function public.inventory_product_unit_cost_v32(p_product_id bigint)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select case
    when product.purchase_price is null then null
    when product.usage_type = 'direct_sale'
      or product.product_category in ('beverage_ready', 'water_product', 'snack_ready', 'food_ready')
      then product.purchase_price
    when lower(coalesce(product.base_unit, '')) in ('kg', 'l')
      and coalesce(package.units_per_package, 0) > 0
      and package.units_per_package < 100
      then product.purchase_price / package.units_per_package
    when lower(coalesce(product.base_unit, '')) in ('kg', 'l')
      and coalesce(package.units_per_package, 0) >= 100
      then product.purchase_price / (package.units_per_package / 1000.0)
    when coalesce(package.units_per_package, 0) > 1
      then product.purchase_price / package.units_per_package
    else product.purchase_price
  end
  from public.products product
  left join lateral (
    select product_package.units_per_package
    from public.product_packages product_package
    where product_package.product_id = product.id
      and product_package.active = true
    order by product_package.is_default desc, product_package.id
    limit 1
  ) package on true
  where product.id = p_product_id
$$;

do $$
declare
  v_item public.inventory_audit_items%rowtype;
  v_product_id bigint;
  v_correct_cost numeric;
begin
  select item.*
    into v_item
  from public.inventory_audit_items item
  join public.products product on product.id = item.product_id
  where item.audit_id = 124
    and product.sku = '44';

  if not found then
    raise exception 'Inventory #124 item for SKU 44 was not found.';
  end if;

  if v_item.unit_cost not in (0.42, 420.00) then
    raise exception 'Inventory #124 SKU 44 has unexpected unit cost %.', v_item.unit_cost;
  end if;

  v_product_id := v_item.product_id;
  v_correct_cost := public.inventory_product_unit_cost_v32(v_product_id);
  if v_correct_cost is distinct from 420.00 then
    raise exception 'Expected corrected SKU 44 cost 420.00 CZK/kg, got %.', v_correct_cost;
  end if;

  update public.inventory_audit_items item
  set unit_cost = v_correct_cost,
      difference_value = round((item.difference_quantity * v_correct_cost)::numeric, 2)
  where item.id = v_item.id;

  update public.inventory_audits audit
  set difference_value_total = totals.difference_value_total
  from (
    select item.audit_id, coalesce(sum(item.difference_value), 0) as difference_value_total
    from public.inventory_audit_items item
    where item.audit_id = 124
    group by item.audit_id
  ) totals
  where audit.id = totals.audit_id;

  if not exists (
    select 1
    from public.inventory_audit_items item
    where item.id = v_item.id
      and item.unit_cost = 420.00
      and item.difference_quantity = 1.000
      and item.difference_value = 420.00
  ) then
    raise exception 'Inventory #124 SKU 44 did not reach the expected corrected values.';
  end if;

  if not exists (
    select 1
    from public.inventory_audits audit
    where audit.id = 124
      and audit.difference_value_total = 420.00
  ) then
    raise exception 'Inventory #124 total difference value was not corrected to 420.00 CZK.';
  end if;
end
$$;

commit;
