begin;

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

create or replace function public.ensure_post_route_exception_inventory_v32(p_route_plan_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
  v_audit_id bigint;
begin
  v_result := public.ensure_post_route_exception_inventory_v31(p_route_plan_id);
  v_audit_id := nullif(v_result ->> 'audit_id', '')::bigint;

  if v_audit_id is not null then
    update public.inventory_audit_items item
    set unit_cost = public.inventory_product_unit_cost_v32(item.product_id),
        difference_value = round(
          item.difference_quantity * coalesce(public.inventory_product_unit_cost_v32(item.product_id), 0),
          2
        )
    where item.audit_id = v_audit_id;
  end if;

  return v_result;
end
$$;

create or replace function public.create_post_route_exception_inventory_v31()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ensure_post_route_exception_inventory_v32(new.id);
  return new;
end
$$;

create or replace function public.create_post_route_exception_inventory_on_last_stop_v31()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('done', 'skipped')
     and old.status is distinct from new.status then
    perform public.ensure_post_route_exception_inventory_v32(new.route_plan_id);
  end if;
  return new;
end
$$;

update public.inventory_audit_items item
set unit_cost = public.inventory_product_unit_cost_v32(item.product_id),
    difference_value = round(
      item.difference_quantity * coalesce(public.inventory_product_unit_cost_v32(item.product_id), 0),
      2
    )
from public.inventory_audits audit
where audit.id = item.audit_id
  and audit.audit_origin = 'post_route_exception'
  and item.unit_cost is null;

update public.inventory_audits audit
set book_quantity_total = totals.book_quantity_total,
    counted_quantity_total = totals.counted_quantity_total,
    difference_quantity_total = totals.difference_quantity_total,
    difference_value_total = totals.difference_value_total
from (
  select
    item.audit_id,
    coalesce(sum(item.book_quantity), 0) as book_quantity_total,
    coalesce(sum(item.counted_quantity), 0) as counted_quantity_total,
    coalesce(sum(item.difference_quantity), 0) as difference_quantity_total,
    coalesce(sum(item.difference_value), 0) as difference_value_total
  from public.inventory_audit_items item
  join public.inventory_audits source_audit on source_audit.id = item.audit_id
  where source_audit.audit_origin = 'post_route_exception'
  group by item.audit_id
) totals
where audit.id = totals.audit_id;

do $$
declare
  v_audit_49 numeric;
  v_audit_50 numeric;
begin
  select difference_value_total into v_audit_49 from public.inventory_audits where id = 49;
  select difference_value_total into v_audit_50 from public.inventory_audits where id = 50;

  if v_audit_49 is distinct from -70.74 then
    raise exception 'Inventura #49 ma neocekavanou hodnotu %', v_audit_49;
  end if;
  if v_audit_50 is distinct from -56.10 then
    raise exception 'Inventura #50 ma neocekavanou hodnotu %', v_audit_50;
  end if;
end
$$;

commit;
