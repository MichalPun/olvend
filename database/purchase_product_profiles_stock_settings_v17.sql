alter table public.purchase_product_profiles
  add column if not exists target_stock_quantity numeric(12,3) not null default 0,
  add column if not exists package_quantity numeric(12,3) not null default 1;

update public.purchase_product_profiles
set package_quantity = 1
where package_quantity is null or package_quantity <= 0;

drop view if exists public.purchase_product_recommendations_v13;

create view public.purchase_product_recommendations_v13 as
with profile_base as (
  select
    ppp.id as profile_id,
    ppp.product_id,
    ppp.supplier_id,
    ppp.pilot_scope,
    ppp.active,
    ppp.reorder_enabled,
    ppp.order_weekdays,
    ppp.delivery_weekdays,
    ppp.lead_time_days,
    ppp.base_order_quantity,
    ppp.min_order_quantity,
    ppp.order_multiple_quantity,
    ppp.safety_stock_quantity,
    ppp.target_stock_quantity,
    ppp.package_quantity,
    ppp.target_cover_days,
    ppp.note as profile_note,
    pr.name as product_name,
    pr.base_unit,
    ps.name as supplier_name
  from public.purchase_product_profiles ppp
  join public.products pr on pr.id = ppp.product_id
  join public.purchase_suppliers ps on ps.id = ppp.supplier_id
  where ppp.active = true
),
stock_totals as (
  select
    slb.product_id,
    sum(case when sl.location_type = 'warehouse' and not coalesce(w.code, '') = 'AUTOMATY' and lower(coalesce(sl.name, '')) <> 'automaty' then slb.quantity_on_hand else 0 end) as warehouse_qty,
    sum(case when sl.location_type = 'vehicle' then slb.quantity_on_hand else 0 end) as vehicle_qty,
    sum(case when sl.location_type = 'warehouse' and coalesce(w.code, '') = 'AUTOMATY' then slb.quantity_on_hand else 0 end) as automaty_qty
  from public.stock_location_balances slb
  join public.stock_locations sl on sl.id = slb.stock_location_id
  left join public.warehouses w on w.id = sl.warehouse_id
  where sl.active = true
  group by slb.product_id
),
incoming_orders as (
  select
    poi.product_id,
    sum(greatest(poi.ordered_quantity - poi.received_quantity, 0)) as incoming_qty,
    min(po.delivery_date) filter (where po.delivery_date >= current_date) as next_delivery_date
  from public.purchase_order_items poi
  join public.purchase_orders po on po.id = poi.purchase_order_id
  where po.status in ('draft', 'ordered')
    and (po.delivery_date is null or po.delivery_date >= current_date)
  group by poi.product_id
),
calculated as (
  select
    pb.*,
    coalesce(st.warehouse_qty, 0) as warehouse_qty,
    coalesce(st.vehicle_qty, 0) as vehicle_qty,
    coalesce(st.automaty_qty, 0) as automaty_qty,
    coalesce(st.warehouse_qty, 0) as available_qty,
    coalesce(io.incoming_qty, 0) as incoming_qty,
    io.next_delivery_date
  from profile_base pb
  left join stock_totals st on st.product_id = pb.product_id
  left join incoming_orders io on io.product_id = pb.product_id
),
recommended as (
  select
    c.*,
    greatest(
      case
        when coalesce(c.target_stock_quantity, 0) > 0
          and (coalesce(c.warehouse_qty, 0) + coalesce(c.incoming_qty, 0)) <= coalesce(c.safety_stock_quantity, 0)
          then coalesce(c.target_stock_quantity, 0) - (coalesce(c.warehouse_qty, 0) + coalesce(c.incoming_qty, 0))
        else coalesce(c.base_order_quantity, 0)
      end,
      0
    ) as raw_recommended_qty
  from calculated c
)
select
  r.profile_id,
  r.product_id,
  r.product_name,
  r.base_unit,
  r.supplier_id,
  r.supplier_name,
  r.pilot_scope,
  r.reorder_enabled,
  r.order_weekdays,
  r.delivery_weekdays,
  r.lead_time_days,
  r.base_order_quantity,
  r.min_order_quantity,
  r.order_multiple_quantity,
  r.safety_stock_quantity,
  r.target_stock_quantity,
  r.package_quantity,
  r.target_cover_days,
  r.warehouse_qty,
  r.vehicle_qty,
  r.automaty_qty,
  r.available_qty,
  r.incoming_qty,
  r.next_delivery_date,
  0::numeric as estimated_usage_14d,
  0::numeric as avg_daily_usage_14d,
  null::numeric as estimated_days_cover,
  greatest(
    case
      when r.raw_recommended_qty <= 0 then 0
      when coalesce(r.package_quantity, r.order_multiple_quantity, 0) <= 0 then r.raw_recommended_qty
      else ceil(r.raw_recommended_qty / coalesce(nullif(r.package_quantity, 0), nullif(r.order_multiple_quantity, 0), 1)) * coalesce(nullif(r.package_quantity, 0), nullif(r.order_multiple_quantity, 0), 1)
    end,
    case
      when r.raw_recommended_qty > 0 then r.min_order_quantity
      else 0
    end
  ) as recommended_order_qty,
  r.profile_note
from recommended r;
