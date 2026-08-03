-- OLVEND v24: denní vyhodnocení tras včetně dopadu doporučení nakládky.
-- Jediný RPC výstup je určen pro report-routes-daily.html a PDF export.

create or replace function public.get_daily_route_evaluation_v24(
  p_report_date date default current_date
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with route_base as (
  select
    rp.*,
    concat_ws(' ', e.name, e.surname) as employee_name,
    e.role as employee_role,
    v.name as vehicle_name,
    v.plate as vehicle_plate,
    v.brand as vehicle_brand,
    v.model as vehicle_model
  from public.route_plans rp
  join public.employees e on e.id = rp.planned_employee_id
  left join public.vehicles v on v.id = rp.vehicle_id
  where rp.planning_date = p_report_date
),
visit_stats as (
  select
    v.route_plan_id,
    min(v.arrived_at) filter (where v.status = 'completed') as first_arrival,
    max(v.completed_at) filter (where v.status = 'completed') as last_completed_visit,
    count(*) filter (where v.status = 'completed') as completed_visits,
    count(*) filter (where v.status = 'completed' and v.machine_kind = 'coffee') as coffee_visits,
    count(*) filter (where v.status = 'completed' and v.machine_kind = 'food') as food_visits,
    round(sum(extract(epoch from (v.completed_at - v.arrived_at)) / 60)
      filter (where v.status = 'completed' and v.arrived_at is not null and v.completed_at is not null)::numeric, 1) as active_service_minutes,
    round(avg(extract(epoch from (v.completed_at - v.arrived_at)) / 60)
      filter (where v.status = 'completed' and v.arrived_at is not null and v.completed_at is not null)::numeric, 1) as average_service_minutes,
    round(percentile_cont(0.5) within group (
      order by extract(epoch from (v.completed_at - v.arrived_at)) / 60
    ) filter (where v.status = 'completed' and v.arrived_at is not null and v.completed_at is not null)::numeric, 1) as median_service_minutes
  from public.route_machine_visits v
  join route_base rb on rb.id = v.route_plan_id
  group by v.route_plan_id
),
stop_stats as (
  select
    s.route_plan_id,
    count(*) as total_stops,
    count(*) filter (where s.status in ('done', 'completed')) as completed_stops,
    count(*) filter (where s.status = 'skipped') as skipped_stops,
    count(*) filter (where s.status not in ('done', 'completed', 'skipped')) as open_stops
  from public.route_plan_stops s
  join route_base rb on rb.id = s.route_plan_id
  group by s.route_plan_id
),
route_metrics as (
  select
    rb.id as route_id,
    rb.planning_date,
    rb.title,
    rb.employee_name,
    rb.employee_role,
    rb.vehicle_id,
    concat_ws(' · ', nullif(rb.vehicle_plate, ''), nullif(rb.vehicle_brand, ''), nullif(rb.vehicle_model, ''), nullif(rb.vehicle_name, '')) as vehicle_label,
    rb.execution_status,
    rb.planned_departure_time,
    rb.started_at,
    rb.completed_at,
    vs.first_arrival,
    vs.last_completed_visit,
    coalesce(ss.total_stops, 0) as total_stops,
    coalesce(ss.completed_stops, 0) as completed_stops,
    coalesce(ss.skipped_stops, 0) as skipped_stops,
    coalesce(ss.open_stops, 0) as open_stops,
    coalesce(vs.completed_visits, 0) as completed_visits,
    coalesce(vs.coffee_visits, 0) as coffee_visits,
    coalesce(vs.food_visits, 0) as food_visits,
    vs.active_service_minutes,
    vs.average_service_minutes,
    vs.median_service_minutes,
    case
      when rb.started_at is not null and vs.last_completed_visit is not null
        then round((extract(epoch from (vs.last_completed_visit - rb.started_at)) / 60)::numeric, 1)
      else null
    end as route_window_minutes,
    case when coalesce(ss.total_stops, 0) > 0
      then round((100.0 * coalesce(ss.completed_stops, 0) / ss.total_stops)::numeric, 1)
      else 0 end as completion_percent,
    rb.estimated_distance_km,
    rb.estimated_drive_minutes,
    rb.estimated_service_minutes
  from route_base rb
  left join visit_stats vs on vs.route_plan_id = rb.id
  left join stop_stats ss on ss.route_plan_id = rb.id
),
stop_rows as (
  select
    rb.id as route_id,
    s.id as stop_id,
    s.stop_order,
    s.status,
    coalesce(l.name, s.title, m.name, 'Bez názvu') as location_name,
    l.city,
    m.evidence_number,
    m.name as machine_name,
    mv.machine_kind,
    mv.arrived_at,
    mv.completed_at,
    mv.skipped_at,
    mv.skip_reason,
    case when mv.completed_at is not null and mv.arrived_at is not null
      then round((extract(epoch from (mv.completed_at - mv.arrived_at)) / 60)::numeric, 1)
      else null end as service_minutes
  from route_base rb
  join public.route_plan_stops s on s.route_plan_id = rb.id
  left join public.locations l on l.id = s.location_id
  left join public.machines m on m.id = s.machine_id
  left join lateral (
    select v.*
    from public.route_machine_visits v
    where v.route_plan_stop_id = s.id
    order by v.created_at desc
    limit 1
  ) mv on true
),
replenishment_summary as (
  select
    v.route_plan_id as route_id,
    i.item_kind,
    coalesce(i.unit, 'ks') as unit,
    count(*) as checked_positions,
    count(*) filter (where coalesce(i.actual_add_quantity, 0) > 0) as replenished_positions,
    sum(coalesce(i.suggested_add_quantity, 0)) as suggested_quantity,
    sum(coalesce(i.actual_add_quantity, 0)) as actual_quantity,
    sum(coalesce(i.removed_quantity, 0)) as removed_quantity,
    count(*) filter (
      where coalesce(i.actual_add_quantity, 0) + 0.001 < coalesce(i.suggested_add_quantity, 0)
    ) as below_suggestion_positions,
    count(*) filter (where i.issue_type = 'missing_stock') as missing_stock_positions,
    count(*) filter (where i.issue_type = 'telemetry_mismatch') as telemetry_mismatch_positions,
    count(*) filter (where i.issue_type = 'substitution') as substitution_positions
  from public.route_machine_visit_items i
  join public.route_machine_visits v on v.id = i.visit_id
  join route_base rb on rb.id = v.route_plan_id
  where i.item_kind in ('coffee_container', 'food_slot')
  group by v.route_plan_id, i.item_kind, coalesce(i.unit, 'ks')
),
food_fills as (
  select
    v.route_plan_id as route_id,
    coalesce(f.product_id, i.actual_product_id, i.planned_product_id) as product_id,
    coalesce(f.product_name, i.actual_product_name, i.planned_product_name, p.name, 'Neurčený produkt') as product_name,
    'ks'::text as unit,
    sum(coalesce(f.quantity, 0)) as actual_quantity
  from public.route_machine_visit_food_fills f
  join public.route_machine_visits v on v.id = f.visit_id
  join route_base rb on rb.id = v.route_plan_id
  left join public.route_machine_visit_items i on i.id = f.visit_item_id
  left join public.products p on p.id = coalesce(f.product_id, i.actual_product_id, i.planned_product_id)
  group by v.route_plan_id,
    coalesce(f.product_id, i.actual_product_id, i.planned_product_id),
    coalesce(f.product_name, i.actual_product_name, i.planned_product_name, p.name, 'Neurčený produkt')
),
coffee_fills as (
  select
    v.route_plan_id as route_id,
    coalesce(i.actual_product_id, i.planned_product_id) as product_id,
    coalesce(i.actual_product_name, i.planned_product_name, p.name, 'Neurčený produkt') as product_name,
    coalesce(i.unit, p.base_unit, 'ks') as unit,
    sum(coalesce(i.actual_add_quantity, 0)) as actual_quantity
  from public.route_machine_visit_items i
  join public.route_machine_visits v on v.id = i.visit_id
  join route_base rb on rb.id = v.route_plan_id
  left join public.products p on p.id = coalesce(i.actual_product_id, i.planned_product_id)
  where i.item_kind = 'coffee_container'
    and coalesce(i.actual_add_quantity, 0) > 0
  group by v.route_plan_id,
    coalesce(i.actual_product_id, i.planned_product_id),
    coalesce(i.actual_product_name, i.planned_product_name, p.name, 'Neurčený produkt'),
    coalesce(i.unit, p.base_unit, 'ks')
),
fill_summary as (
  select route_id, product_id, product_name, unit, sum(actual_quantity) as actual_quantity
  from (
    select * from food_fills
    union all
    select * from coffee_fills
  ) x
  group by route_id, product_id, product_name, unit
),
top_fill_rows as (
  select
    x.*,
    row_number() over (partition by route_id, unit order by actual_quantity desc, product_name) as unit_rank
  from fill_summary x
),
visit_demand as (
  select
    v.route_plan_id as route_id,
    coalesce(i.planned_product_id, i.actual_product_id) as product_id,
    coalesce(i.planned_product_name, i.actual_product_name, p.name, 'Neurčený produkt') as product_name,
    coalesce(i.unit, p.base_unit, 'ks') as unit,
    sum(coalesce(i.suggested_add_quantity, 0)) as visit_suggested_quantity,
    sum(coalesce(i.actual_add_quantity, 0)) as visit_actual_quantity,
    count(*) filter (
      where coalesce(i.actual_add_quantity, 0) + 0.001 < coalesce(i.suggested_add_quantity, 0)
    ) as unfilled_positions,
    count(*) filter (where i.issue_type = 'missing_stock' or lower(coalesce(i.operator_note, '')) ~ '(nem[aá]m|chyb.*aut)') as vehicle_shortage_positions,
    count(*) filter (where i.issue_type = 'telemetry_mismatch') as telemetry_mismatch_positions,
    count(*) filter (where i.issue_type = 'substitution') as substitution_positions,
    count(*) filter (
      where lower(coalesce(i.operator_note, '')) ~ '(potvrdil.*nevzal|oprava podle oper[aá]tora|nebyla vlo[zž]ena|nevzal nebo nevlo[zž]il)'
    ) as operator_override_positions
  from public.route_machine_visit_items i
  join public.route_machine_visits v on v.id = i.visit_id
  join route_base rb on rb.id = v.route_plan_id
  left join public.products p on p.id = coalesce(i.planned_product_id, i.actual_product_id)
  where i.item_kind in ('coffee_container', 'food_slot')
  group by v.route_plan_id,
    coalesce(i.planned_product_id, i.actual_product_id),
    coalesce(i.planned_product_name, i.actual_product_name, p.name, 'Neurčený produkt'),
    coalesce(i.unit, p.base_unit, 'ks')
),
request_base as (
  select r.*
  from public.mobile_stock_requests r
  join route_base rb on rb.id = r.route_plan_id
  where r.request_type in ('vehicle_order', 'vehicle_load')
    and r.status <> 'cancelled'
),
request_summary as (
  select
    r.route_plan_id as route_id,
    count(distinct r.id) as request_count,
    min(r.created_at) as first_request_at,
    max(r.confirmed_at) as last_confirmed_at,
    bool_or(r.stock_applied_at is not null) as stock_applied,
    sum(coalesce(i.requested_quantity, 0)) as requested_quantity,
    sum(coalesce(i.prepared_quantity, i.requested_quantity, 0)) as prepared_quantity,
    sum(coalesce(i.confirmed_quantity, i.prepared_quantity, i.requested_quantity, 0)) as confirmed_quantity,
    count(i.id) as product_rows
  from request_base r
  left join public.mobile_stock_request_items i on i.request_id = r.id
  group by r.route_plan_id
),
request_products as (
  select
    r.route_plan_id as route_id,
    i.product_id,
    coalesce(i.product_name, p.name, 'Neurčený produkt') as product_name,
    coalesce(nullif(i.unit, ''), p.base_unit, 'ks') as unit,
    sum(coalesce(i.requested_quantity, 0)) as requested_quantity,
    sum(coalesce(i.prepared_quantity, i.requested_quantity, 0)) as prepared_quantity,
    sum(coalesce(i.confirmed_quantity, i.prepared_quantity, i.requested_quantity, 0)) as confirmed_quantity
  from request_base r
  join public.mobile_stock_request_items i on i.request_id = r.id
  left join public.products p on p.id = i.product_id
  group by r.route_plan_id, i.product_id,
    coalesce(i.product_name, p.name, 'Neurčený produkt'),
    coalesce(nullif(i.unit, ''), p.base_unit, 'ks')
),
impact_keys as (
  select route_id, product_id, product_name, unit from request_products
  union
  select route_id, product_id, product_name, unit from visit_demand
),
load_impact as (
  select
    k.route_id,
    k.product_id,
    k.product_name,
    k.unit,
    (rs.route_id is not null) as has_linked_request,
    coalesce(rp.requested_quantity, 0) as requested_quantity,
    coalesce(rp.prepared_quantity, 0) as prepared_quantity,
    coalesce(rp.confirmed_quantity, 0) as confirmed_quantity,
    coalesce(vd.visit_suggested_quantity, 0) as visit_suggested_quantity,
    coalesce(vd.visit_actual_quantity, 0) as visit_actual_quantity,
    greatest(coalesce(vd.visit_suggested_quantity, 0) - coalesce(vd.visit_actual_quantity, 0), 0) as not_filled_quantity,
    coalesce(vd.unfilled_positions, 0) as unfilled_positions,
    coalesce(vd.vehicle_shortage_positions, 0) as vehicle_shortage_positions,
    coalesce(vd.telemetry_mismatch_positions, 0) as telemetry_mismatch_positions,
    coalesce(vd.substitution_positions, 0) as substitution_positions,
    coalesce(vd.operator_override_positions, 0) as operator_override_positions,
    case
      when rs.route_id is null then 'no_linked_load_document'
      when coalesce(rp.prepared_quantity, 0) + 0.001 < coalesce(rp.requested_quantity, 0)
        and coalesce(vd.visit_actual_quantity, 0) + 0.001 < coalesce(vd.visit_suggested_quantity, 0)
        then 'warehouse_shortfall'
      when vd.vehicle_shortage_positions > 0 and rp.route_id is null
        then 'omitted_from_recommendation'
      when vd.vehicle_shortage_positions > 0
        and coalesce(rp.requested_quantity, 0) + 0.001 < coalesce(vd.visit_suggested_quantity, 0)
        then 'recommendation_too_low'
      when vd.vehicle_shortage_positions > 0 then 'vehicle_shortage'
      when vd.telemetry_mismatch_positions > 0 then 'online_state_changed'
      when vd.operator_override_positions > 0 then 'operator_or_other'
      when vd.substitution_positions > 0 then 'substitution_or_assortment_change'
      when coalesce(vd.visit_actual_quantity, 0) + 0.001 < coalesce(vd.visit_suggested_quantity, 0)
        then 'operator_or_other'
      when coalesce(vd.visit_actual_quantity, 0) > coalesce(vd.visit_suggested_quantity, 0) + 0.001
        then 'more_than_suggested'
      else 'fulfilled'
    end as impact_reason
  from impact_keys k
  left join request_products rp
    on rp.route_id = k.route_id
   and rp.product_id is not distinct from k.product_id
   and lower(rp.unit) = lower(k.unit)
  left join visit_demand vd
    on vd.route_id = k.route_id
   and vd.product_id is not distinct from k.product_id
   and lower(vd.unit) = lower(k.unit)
  left join request_summary rs on rs.route_id = k.route_id
),
issue_rows as (
  select
    v.route_plan_id as route_id,
    v.id as visit_id,
    coalesce(l.name, m.name, 'Bez lokality') as location_name,
    m.evidence_number,
    i.physical_position_label,
    i.item_kind,
    coalesce(i.actual_product_name, i.planned_product_name, p.name, 'Neurčený produkt') as product_name,
    coalesce(i.unit, p.base_unit, 'ks') as unit,
    coalesce(i.suggested_add_quantity, 0) as suggested_quantity,
    coalesce(i.actual_add_quantity, 0) as actual_quantity,
    coalesce(i.removed_quantity, 0) as removed_quantity,
    i.issue_type,
    i.substitution_reason,
    i.operator_note
  from public.route_machine_visit_items i
  join public.route_machine_visits v on v.id = i.visit_id
  join route_base rb on rb.id = v.route_plan_id
  left join public.machines m on m.id = v.machine_id
  left join public.locations l on l.id = m.location_id
  left join public.products p on p.id = coalesce(i.actual_product_id, i.planned_product_id)
  where i.issue_type <> 'none'
     or coalesce(i.actual_add_quantity, 0) + 0.001 < coalesce(i.suggested_add_quantity, 0)
),
attendance_rows as (
  select
    rb.id as route_id,
    ad.id as attendance_day_id,
    ad.actual_start,
    ad.actual_end,
    ad.break_minutes,
    ad.payable_minutes,
    ad.status as attendance_status,
    vol.started_at as vehicle_started_at,
    vol.ended_at as vehicle_ended_at,
    vol.start_odometer_km,
    vol.end_odometer_km,
    vol.distance_km
  from route_base rb
  left join public.attendance_days ad
    on ad.employee_id = rb.planned_employee_id
   and ad.attendance_date = rb.planning_date
  left join lateral (
    select x.*
    from public.vehicle_operation_logs x
    where x.attendance_day_id = ad.id
    order by x.created_at desc
    limit 1
  ) vol on true
),
negative_vehicle_stock as (
  select
    rb.id as route_id,
    p.name as product_name,
    p.base_unit,
    sum(b.quantity_on_hand) as quantity
  from route_base rb
  join public.stock_locations sl
    on sl.location_type = 'vehicle'
   and sl.vehicle_id = rb.vehicle_id
   and sl.active = true
  join public.stock_location_balances b on b.stock_location_id = sl.id
  join public.products p on p.id = b.product_id
  group by rb.id, p.id, p.name, p.base_unit
  having sum(b.quantity_on_hand) < -0.001
)
select jsonb_build_object(
  'report_date', p_report_date,
  'generated_at', now(),
  'routes', coalesce((select jsonb_agg(to_jsonb(x) order by x.employee_name, x.route_id) from route_metrics x), '[]'::jsonb),
  'stops', coalesce((select jsonb_agg(to_jsonb(x) order by x.route_id, x.stop_order) from stop_rows x), '[]'::jsonb),
  'replenishment', coalesce((select jsonb_agg(to_jsonb(x) order by x.route_id, x.item_kind, x.unit) from replenishment_summary x), '[]'::jsonb),
  'top_fills', coalesce((select jsonb_agg(to_jsonb(x) order by x.route_id, x.unit, x.unit_rank) from top_fill_rows x where x.unit_rank <= 10), '[]'::jsonb),
  'load_requests', coalesce((select jsonb_agg(to_jsonb(x) order by x.route_id) from request_summary x), '[]'::jsonb),
  'load_impact', coalesce((select jsonb_agg(to_jsonb(x) order by x.route_id, x.impact_reason, x.product_name) from load_impact x), '[]'::jsonb),
  'issues', coalesce((select jsonb_agg(to_jsonb(x) order by x.route_id, x.visit_id, x.physical_position_label) from issue_rows x), '[]'::jsonb),
  'attendance', coalesce((select jsonb_agg(to_jsonb(x) order by x.route_id) from attendance_rows x), '[]'::jsonb),
  'negative_vehicle_stock', coalesce((select jsonb_agg(to_jsonb(x) order by x.route_id, x.product_name) from negative_vehicle_stock x), '[]'::jsonb)
);
$$;

comment on function public.get_daily_route_evaluation_v24(date) is
  'Denní manažerské vyhodnocení tras, doplnění, nakládky a dopadu doporučení zboží.';

revoke all on function public.get_daily_route_evaluation_v24(date) from public;
grant execute on function public.get_daily_route_evaluation_v24(date) to authenticated, anon;
