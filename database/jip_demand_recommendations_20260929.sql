-- Read-only recommendation view. No stock/order mutations. Invoker RLS remains enforced.
begin;
create or replace view public.purchase_jip_demand_v1 with (security_invoker=true) as
with catalog as (
 select p.id product_id,p.name,p.sku,p.base_unit,f.id profile_id,
 greatest(1,coalesce(f.lead_time_days,1)+coalesce(f.target_cover_days,8)) horizon,
 coalesce(f.safety_stock_quantity,0) safety,coalesce(f.target_stock_quantity,0) target,
 coalesce(nullif(f.package_quantity,0),pk.pack) pack,coalesce(f.min_order_quantity,0) min_qty
 from products p left join purchase_product_profiles f on f.product_id=p.id and f.supplier_id=3 and f.pilot_scope='general'
 left join lateral(select case when count(distinct units_per_package)=1 then max(units_per_package) end pack from product_packages where product_id=p.id and active and package_name='Celé balení') pk on true
 where p.active and p.base_unit='ks' and coalesce(f.active,true) and coalesce(f.reorder_enabled,true)
 and exists(select 1 from supplier_product_mappings m where m.product_id=p.id and m.supplier_id=3 and m.active)
), wh as (
 select l.id from stock_locations l join warehouses w on w.id=l.warehouse_id
 where l.active and l.location_type='warehouse' and l.id=1
), stock as (
 select b.product_id,sum(b.quantity_on_hand) qty from stock_location_balances b join wh on wh.id=b.stock_location_id group by 1
), flows as (
 select sm.product_id,(sm.created_at at time zone 'Europe/Prague')::date as day,
 sum(case when sm.to_stock_location_id in(select id from wh) then sm.quantity_base_units else 0 end
 -case when sm.from_stock_location_id in(select id from wh) then sm.quantity_base_units else 0 end) delta,
 sum(case when sm.from_stock_location_id in(select id from wh) and dst.location_type in('vehicle','machine') then sm.quantity_base_units
 when sm.to_stock_location_id in(select id from wh) and src.location_type in('vehicle','machine') then -sm.quantity_base_units else 0 end) used
 from stock_movements_v13 sm left join stock_locations src on src.id=sm.from_stock_location_id left join stock_locations dst on dst.id=sm.to_stock_location_id
 where sm.created_at >= (((now() at time zone 'Europe/Prague')::date-28)::timestamp at time zone 'Europe/Prague')
 and (sm.from_stock_location_id in(select id from wh) or sm.to_stock_location_id in(select id from wh)) group by 1,2
), days as (
 select c.product_id,d::date as day,coalesce(f.used,0) used,coalesce(f.delta,0) delta,
 coalesce(s.qty,0)-coalesce((select sum(f2.delta) from flows f2 where f2.product_id=c.product_id and f2.day>=d::date),0) opening
 from catalog c cross join generate_series((now() at time zone 'Europe/Prague')::date-28,(now() at time zone 'Europe/Prague')::date-1,'1 day') d
 left join flows f on f.product_id=c.product_id and f.day=d::date left join stock s on s.product_id=c.product_id
), history as (
 select product_id,greatest(sum(used),0) issued,
 count(*) filter(where opening>0 or opening+delta>0 or used>0) available_days from days group by 1
), sales as (
 select p.product_id,sum(e.quantity)/28.0 daily from catalog p join telemetry_sales_events e on e.product_sku=p.sku
 where e.source_event_at>=(((now() at time zone 'Europe/Prague')::date-28)::timestamp at time zone 'Europe/Prague')
 and e.source_event_at<((now() at time zone 'Europe/Prague')::date::timestamp at time zone 'Europe/Prague') and e.quantity>0 group by 1
), requests as (
 select r.* from mobile_stock_requests r left join route_plans rp on rp.id=r.route_plan_id
 where r.request_type='vehicle_load' and r.status in('requested','picking','ready')
 and r.stock_applied_at is null and r.requested_for_date>=(now() at time zone 'Europe/Prague')::date
 and coalesce(rp.execution_status,'planned') not in('done','cancelled')
), request_items as (
 select c.product_id,r.id,r.route_plan_id,r.requested_for_date,
 sum(i.requested_quantity*case when i.unit=c.base_unit then 1 else pk.factor end) qty,
 count(*) filter(where i.unit is distinct from c.base_unit and pk.factor is null) unknown_units
 from catalog c join mobile_stock_request_items i on i.product_id=c.product_id
 join requests r on r.id=i.request_id and r.requested_for_date<(now() at time zone 'Europe/Prague')::date+c.horizon and r.source_stock_location_id in(select id from wh)
 left join lateral(select case when count(distinct units_per_package)=1 then max(units_per_package) end factor
 from product_packages where active and product_id=c.product_id and package_name=i.unit)pk on true
 group by c.product_id,r.id,r.route_plan_id,r.requested_for_date
), route_needs as (
 -- Repeated snapshots of one route overlap; keep the highest product demand, not their sum.
 select product_id,requested_for_date,max(qty) qty,max(unknown_units) unknown_units
 from request_items group by product_id,requested_for_date,coalesce('route:'||route_plan_id,'request:'||id)
 union all
 -- Direct-stock food routes have no vehicle loading request. One current refill per machine.
 select c.product_id,min(rp.planning_date),greatest(0,coalesce(s.target_units,s.desired_units,s.capacity_units,0)-greatest(0,coalesce(s.current_units,0))),0
 from catalog c join machine_planogram_slots s on s.product_sku=c.sku and s.active
 join route_plan_stops rs on rs.machine_id=s.machine_id and coalesce(rs.status,'planned') not in('completed','skipped')
 join route_plans rp on rp.id=rs.route_plan_id and rp.vehicle_id is null and rp.warehouse_id=1
 and rp.route_payload->>'stock_source_mode'='warehouse_direct'
 and rp.planning_date>=(now() at time zone 'Europe/Prague')::date and rp.planning_date<(now() at time zone 'Europe/Prague')::date+c.horizon
 and coalesce(rp.execution_status,'planned') not in('done','cancelled')
 where not exists(select 1 from requests r where r.route_plan_id=rp.id)
 group by c.product_id,s.id
), needs as (
 select product_id,sum(qty) qty,sum(unknown_units) unknown_units from route_needs group by product_id
), incoming as (
 select i.product_id,sum(greatest(i.ordered_quantity-i.received_quantity,0)) qty from purchase_order_items i
 join purchase_orders o on o.id=i.purchase_order_id join catalog c on c.product_id=i.product_id
 where o.status='ordered' and o.supplier_id=3 and o.delivery_date>=(now() at time zone 'Europe/Prague')::date and o.delivery_date<(now() at time zone 'Europe/Prague')::date+c.horizon group by 1
), shortages as (
 -- Date-only deliveries count AFTER the delivery day: they cannot promise a morning load.
 select n.product_id,max(greatest(0,
 (select coalesce(sum(n2.qty),0) from route_needs n2 where n2.product_id=n.product_id and n2.requested_for_date<=n.requested_for_date)
 -coalesce(s.qty,0)
 -(select coalesce(sum(greatest(i.ordered_quantity-i.received_quantity,0)),0)
 from purchase_order_items i join purchase_orders o on o.id=i.purchase_order_id
 where i.product_id=n.product_id and o.supplier_id=3 and o.status='ordered'
 and o.delivery_date>=(now() at time zone 'Europe/Prague')::date and o.delivery_date<n.requested_for_date)
 )) urgent_qty
 from route_needs n left join stock s on s.product_id=n.product_id group by n.product_id
), calc as (
 select c.*,coalesce(u.urgent_qty,0) urgent_qty,coalesce(s.qty,0) stock,coalesce(n.qty,0) routes,coalesce(n.unknown_units,0) unknown_units,
 coalesce(o.qty,0) incoming,h.available_days,h.issued,
 greatest(coalesce(h.issued/nullif(h.available_days,0),0),coalesce(sa.daily,0)) daily
 from catalog c left join stock s on s.product_id=c.product_id left join history h on h.product_id=c.product_id
 left join shortages u on u.product_id=c.product_id left join needs n on n.product_id=c.product_id left join incoming o on o.product_id=c.product_id left join sales sa on sa.product_id=c.product_id
), result as (
 select *,greatest(safety,daily*3) reserve,
 greatest(0,greatest(target,routes,daily*horizon)+greatest(safety,daily*3)-stock-incoming) raw from calc
)
select product_id,name,profile_id,3::bigint supplier_id,'general'::text pilot_scope,
 stock as warehouse_qty,routes as route_demand_qty,round(daily,3) as daily_usage,
 available_days as estimated_available_days,round(reserve,3) as safety_qty,
 incoming as incoming_qty,pack as package_quantity,horizon as coverage_days,urgent_qty,
 greatest(0,daily*horizon-routes) as additional_forecast_qty,
 case when unknown_units>0 or pack is null or pack<=0 or not exists(select 1 from wh) then null
 when greatest(raw,urgent_qty)>0 then ceil(greatest(raw,urgent_qty,min_qty)/pack)*pack else 0 end as recommended_order_qty,
 unknown_units,case when not exists(select 1 from wh) then 'Sklad Blučina není dostupný.'
 when unknown_units>0 then 'Požadavek obsahuje neznámou jednotku.'
 when pack is null or pack<=0 then 'Doplň jednoznačné objednací balení.' else null end as calculation_error
 from result;

revoke all on public.purchase_jip_demand_v1 from public, anon;
grant select on public.purchase_jip_demand_v1 to authenticated;
commit;
notify pgrst, 'reload schema';
