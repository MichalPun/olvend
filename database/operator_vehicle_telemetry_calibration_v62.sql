begin;

alter table public.vehicles
  add column if not exists telemetry_baseline_device_km numeric(14,2),
  add column if not exists telemetry_baseline_vehicle_km numeric(14,2),
  add column if not exists telemetry_baseline_at timestamptz;

-- T-Mobile vede oba Fiaty pod shodným názvem. Párování je proto uloženo
-- explicitně podle stabilního Mojio ID, ověřeného proti dnešním trasám a poloze.
update public.vehicles set mojio_vehicle_id = null
where id = 3 and mojio_vehicle_id = 'f5b2029a-20e5-463f-875a-b5769c954359';

update public.vehicles set mojio_vehicle_id = '48c74bfc-2d3a-4f99-9588-840664250eac'
where id = 3;

update public.vehicles set mojio_vehicle_id = 'f5b2029a-20e5-463f-875a-b5769c954359'
where id = 6;

update public.vehicle_live_positions
set vehicle_id = case mojio_vehicle_id
  when '48c74bfc-2d3a-4f99-9588-840664250eac' then 3
  when 'f5b2029a-20e5-463f-875a-b5769c954359' then 6
  else vehicle_id end
where mojio_vehicle_id in (
  '48c74bfc-2d3a-4f99-9588-840664250eac',
  'f5b2029a-20e5-463f-875a-b5769c954359'
);

update public.vehicle_live_position_history
set vehicle_id = case mojio_vehicle_id
  when '48c74bfc-2d3a-4f99-9588-840664250eac' then 3
  when 'f5b2029a-20e5-463f-875a-b5769c954359' then 6
  else vehicle_id end
where mojio_vehicle_id in (
  '48c74bfc-2d3a-4f99-9588-840664250eac',
  'f5b2029a-20e5-463f-875a-b5769c954359'
);

-- Cargo se dnes vrátilo na sklad bezprostředně před posledním telemetrickým
-- odečtem. Tento fyzicky potvrzený konečný stav je bezpečný kalibrační bod.
update public.vehicles v
set telemetry_baseline_device_km = p.odometer_km,
    telemetry_baseline_vehicle_km = v.current_odometer_km,
    telemetry_baseline_at = p.source_updated_at
from public.vehicle_live_positions p
where v.id = 6
  and p.mojio_vehicle_id = 'f5b2029a-20e5-463f-875a-b5769c954359'
  and p.odometer_km is not null;

create or replace function public.get_my_vehicle_mileage_summary_v61(
  p_vehicle_id bigint,
  p_log_date date default current_date
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid;
  v_percent numeric := 5;
  v_month_start date := date_trunc('month', p_log_date)::date;
  v_result jsonb;
begin
  select id into v_employee_id from public.employees where auth_user_id = auth.uid() and active is not false limit 1;
  if v_employee_id is null then raise exception 'Přihlášený účet není aktivní zaměstnanec.'; end if;
  select coalesce(private_mileage_allowance_percent,5) into v_percent from public.vehicles where id = p_vehicle_id;

  with days as (
    select d::date as day
    from generate_series(v_month_start, p_log_date, interval '1 day') d
  ), plans as (
    select planning_date as day, round(sum(coalesce(estimated_distance_km,0))::numeric,2) as planned_km
    from public.route_plans
    where planning_date between v_month_start and p_log_date
      and planned_employee_id = v_employee_id and vehicle_id = p_vehicle_id
      and execution_status not in ('cancelled','draft')
    group by planning_date
  ), logs as (
    select distinct on (log_date) id, log_date as day, start_odometer_km, end_odometer_km, distance_km, status
    from public.vehicle_operation_logs
    where log_date between v_month_start and p_log_date
      and employee_id = v_employee_id and vehicle_id = p_vehicle_id
      and start_odometer_km is not null
    order by log_date, (distance_km is not null) desc, updated_at desc, id desc
  ), explained as (
    select vehicle_operation_log_id, coalesce(sum(distance_km),0) as explained_km
    from public.route_distance_explanations group by vehicle_operation_log_id
  ), rows as (
    select days.day,
      coalesce(plans.planned_km,0) as planned_km,
      case when logs.day = p_log_date and logs.end_odometer_km is null then greatest(
        coalesce((
          select case
            when v.telemetry_baseline_device_km is not null
             and v.telemetry_baseline_vehicle_km is not null
             and max(vlp.odometer_km) >= v.telemetry_baseline_device_km
            then v.telemetry_baseline_vehicle_km + max(vlp.odometer_km) - v.telemetry_baseline_device_km
            else v.current_odometer_km end
          from public.vehicles v
          left join public.vehicle_live_positions vlp on vlp.vehicle_id = v.id
          where v.id = p_vehicle_id
          group by v.id
        ), logs.start_odometer_km) - coalesce(logs.start_odometer_km,0), 0
      ) else coalesce(logs.distance_km,0) end as actual_km,
      coalesce(explained.explained_km,0) as explained_km
    from days left join plans using(day) left join logs using(day)
    left join explained on explained.vehicle_operation_log_id = logs.id
  ), totals as (
    select
      coalesce(sum(planned_km),0) as month_planned_km,
      coalesce(sum(greatest(actual_km - planned_km - explained_km,0)),0) as month_private_used_km,
      coalesce(max(planned_km) filter (where day = p_log_date),0) as today_planned_km,
      coalesce(max(actual_km) filter (where day = p_log_date),0) as today_actual_km,
      coalesce(max(explained_km) filter (where day = p_log_date),0) as today_explained_km
    from rows
  )
  select jsonb_build_object(
    'allowance_percent', v_percent,
    'today_planned_km', round(today_planned_km,2),
    'today_actual_km', round(today_actual_km,2),
    'today_private_allowance_km', round(today_planned_km*v_percent/100,2),
    'today_private_used_km', round(greatest(today_actual_km-today_planned_km-today_explained_km,0),2),
    'today_private_remaining_km', round(greatest(today_planned_km*v_percent/100-greatest(today_actual_km-today_planned_km-today_explained_km,0),0),2),
    'month_planned_km', round(month_planned_km,2),
    'month_private_allowance_km', round(month_planned_km*v_percent/100,2),
    'month_private_used_km', round(month_private_used_km,2),
    'month_private_remaining_km', round(greatest(month_planned_km*v_percent/100-month_private_used_km,0),2)
  ) into v_result from totals;
  return coalesce(v_result,'{}'::jsonb);
end;
$$;

comment on column public.vehicles.telemetry_baseline_device_km is
  'Raw T-Mobile/Mojio odometer at the last physical tachometer confirmation.';
comment on column public.vehicles.telemetry_baseline_vehicle_km is
  'Physical vehicle odometer paired with telemetry_baseline_device_km.';

commit;
