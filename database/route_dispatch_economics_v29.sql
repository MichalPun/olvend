create or replace function public.get_route_dispatch_machine_metrics_v29(
  p_from timestamptz default (now() - interval '30 days'),
  p_to timestamptz default now()
)
returns table (
  machine_id bigint,
  revenue_30_days numeric,
  units_30_days numeric,
  sale_days integer
)
language sql
stable
security invoker
set search_path = public
as $$
  with ranked_events as (
    select
      event.*,
      bool_or(lower(coalesce(event.provider, '')) = 'ima') over (partition by event.machine_id) as has_direct_ima
    from public.telemetry_sales_events event
    where event.source_event_at >= p_from
      and event.source_event_at < p_to
  ),
  source_events as (
    select *
    from ranked_events
    where not (lower(coalesce(provider, '')) = 'vendsoft' and has_direct_ima)
  )
  select
    event.machine_id,
    coalesce(sum(event.total_amount_czk), 0)::numeric as revenue_30_days,
    coalesce(sum(event.quantity), 0)::numeric as units_30_days,
    count(distinct (event.source_event_at at time zone 'Europe/Prague')::date)::integer as sale_days
  from source_events event
  where event.machine_id is not null
  group by event.machine_id;
$$;

revoke all on function public.get_route_dispatch_machine_metrics_v29(timestamptz, timestamptz) from public;
grant execute on function public.get_route_dispatch_machine_metrics_v29(timestamptz, timestamptz) to authenticated, anon;

comment on function public.get_route_dispatch_machine_metrics_v29(timestamptz, timestamptz) is
  'Vrací deduplikované tržby a kusy po automatech pro ekonomické hodnocení denního plánu tras.';

insert into public.machine_service_rules (
  machine_id,
  route_visit_rules_active,
  route_planning_note
)
select
  machine.id,
  false,
  'Testovací automat - nezařazovat do ostrého plánování tras.'
from public.machines machine
where machine.evidence_number in (9991, 9992)
on conflict (machine_id) do update
set route_visit_rules_active = false,
    route_planning_note = excluded.route_planning_note,
    updated_at = now();
