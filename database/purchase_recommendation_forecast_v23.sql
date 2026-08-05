-- OLVEND v23: nákupní predikce podle skutečného čistého výdeje centrálního skladu.

create or replace view public.purchase_product_recommendations_v13 as
with profile_base as (
  select
    ppp.*,
    ppp.id as profile_id,
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
    sum(case when sl.location_type = 'warehouse'
      and coalesce(w.code, '') <> 'AUTOMATY'
      and lower(coalesce(sl.name, '')) <> 'automaty'
      then slb.quantity_on_hand else 0 end) as warehouse_qty,
    sum(case when sl.location_type = 'vehicle' then slb.quantity_on_hand else 0 end) as vehicle_qty,
    sum(case when sl.location_type = 'warehouse' and coalesce(w.code, '') = 'AUTOMATY'
      then slb.quantity_on_hand else 0 end) as automaty_qty
  from public.stock_location_balances slb
  join public.stock_locations sl on sl.id = slb.stock_location_id
  left join public.warehouses w on w.id = sl.warehouse_id
  where sl.active = true
  group by slb.product_id
),
usage_28d as (
  select
    sm.product_id,
    greatest(
      sum(case when sm.movement_type = 'load_vehicle' then sm.quantity_base_units else 0 end)
      - sum(case when sm.movement_type = 'return' and destination.location_type = 'warehouse' then sm.quantity_base_units else 0 end),
      0
    ) as net_usage_28d
  from public.stock_movements_v13 sm
  left join public.stock_locations destination on destination.id = sm.to_stock_location_id
  where sm.created_at >= now() - interval '28 days'
  group by sm.product_id
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
    io.next_delivery_date,
    coalesce(u.net_usage_28d, 0) as estimated_usage_28d,
    round(coalesce(u.net_usage_28d, 0) / 28.0, 3) as avg_daily_usage_28d
  from profile_base pb
  left join stock_totals st on st.product_id = pb.product_id
  left join usage_28d u on u.product_id = pb.product_id
  left join incoming_orders io on io.product_id = pb.product_id
),
recommended as (
  select
    c.*,
    greatest(
      greatest(
        coalesce(c.target_stock_quantity, 0),
        (c.avg_daily_usage_28d * greatest(c.lead_time_days + c.target_cover_days, 1))
          + coalesce(c.safety_stock_quantity, 0)
      ) - (c.available_qty + c.incoming_qty),
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
  r.estimated_usage_28d as estimated_usage_14d,
  r.avg_daily_usage_28d as avg_daily_usage_14d,
  case when r.avg_daily_usage_28d <= 0 then null
    else round((r.available_qty + r.incoming_qty) / r.avg_daily_usage_28d, 1)
  end as estimated_days_cover,
  greatest(
    case
      when r.raw_recommended_qty <= 0 then 0
      else ceil(r.raw_recommended_qty / coalesce(nullif(r.package_quantity, 0), nullif(r.order_multiple_quantity, 0), 1))
        * coalesce(nullif(r.package_quantity, 0), nullif(r.order_multiple_quantity, 0), 1)
    end,
    case when r.raw_recommended_qty > 0 then r.min_order_quantity else 0 end
  ) as recommended_order_qty,
  r.note as profile_note
from recommended r;
