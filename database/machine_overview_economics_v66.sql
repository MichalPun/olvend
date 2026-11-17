-- Compact, deduplicated economics for the machine overview.
-- Telemetry revenue is normalized to an average calendar month over the
-- shorter of the requested rolling period and the machine's current placement.
-- Revenue from an earlier location is deliberately excluded. A fixed partner
-- invoice is added separately and distributed only between the active machines
-- covered by that billing rule.
create or replace function public.get_machine_overview_economics_v66(
  p_from timestamptz default (now() - interval '90 days'),
  p_to timestamptz default now()
)
returns table (
  machine_id bigint,
  telemetry_period_revenue numeric,
  telemetry_monthly_average numeric,
  invoicing_monthly_average numeric,
  combined_monthly_average numeric,
  current_month_revenue numeric,
  observed_days numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      least(p_from, p_to) as date_from,
      greatest(p_from, p_to) as date_to,
      date_trunc('month', timezone('Europe/Prague', greatest(p_from, p_to)))
        at time zone 'Europe/Prague' as current_month_from
  ),
  machine_periods as (
    select
      machine.id as machine_id,
      greatest(
        params.date_from,
        least(
          params.date_to,
          coalesce(placement.transferred_at, machine.created_at, params.date_from)
        )
      ) as observed_from,
      params.date_to as observed_to,
      greatest(
        extract(epoch from (
          params.date_to - greatest(
            params.date_from,
            least(
              params.date_to,
              coalesce(placement.transferred_at, machine.created_at, params.date_from)
            )
          )
        )) / 86400.0,
        1::numeric
      ) as observed_days
    from public.machines machine
    cross join params
    left join lateral (
      select transfer.transferred_at
      from public.machine_transfers transfer
      where transfer.machine_id = machine.id
        and transfer.to_location_id is not distinct from machine.location_id
        and transfer.transferred_at < params.date_to
      order by transfer.transferred_at desc, transfer.id desc
      limit 1
    ) placement on true
  ),
  ranked_events as (
    select
      event.*,
      bool_or(lower(coalesce(event.provider, '')) = 'ima')
        over (partition by event.machine_id) as has_direct_ima
    from public.telemetry_sales_events event
    join machine_periods period on period.machine_id = event.machine_id
    where event.machine_id is not null
      and event.source_event_at >= period.observed_from
      and event.source_event_at < period.observed_to
  ),
  source_events as (
    select *
    from ranked_events
    where not (
      lower(coalesce(provider, '')) = 'vendsoft'
      and has_direct_ima
    )
  ),
  telemetry as (
    select
      event.machine_id,
      sum(coalesce(event.total_amount_czk, event.quantity * event.unit_price_czk, 0))::numeric
        as period_revenue,
      sum(
        case when event.source_event_at >= params.current_month_from
          then coalesce(event.total_amount_czk, event.quantity * event.unit_price_czk, 0)
          else 0
        end
      )::numeric as current_month_revenue
    from source_events event
    cross join params
    group by event.machine_id
  ),
  active_machine_scope as (
    select
      profile.id as profile_id,
      machine.id as machine_id,
      profile.fixed_monthly_amount,
      count(*) over (partition by profile.id) as covered_machine_count
    from public.partner_billing_profiles profile
    join public.machines machine
      on machine.location_id = profile.location_id
     and machine.active is not false
     and machine.status is distinct from 'removed'
    where profile.active is not false
      and coalesce(profile.billing_direction, 'from_partner') = 'from_partner'
      and coalesce(profile.fixed_monthly_amount, 0) > 0
      and (
        coalesce(cardinality(profile.billing_machine_types), 0) = 0
        or exists (
          select 1
          from unnest(profile.billing_machine_types) as allowed_type
          where lower(coalesce(machine.machine_type, '')) like '%' || lower(allowed_type) || '%'
             or lower(allowed_type) like '%' || lower(coalesce(machine.machine_type, '')) || '%'
             or (
               lower(allowed_type) = 'coffee'
               and translate(lower(coalesce(machine.machine_type, '')), 'áčďéěíňóřšťúůýž', 'acdeeinorstuuyz') like '%kav%'
             )
             or (
               lower(allowed_type) = 'food'
               and (
                 translate(lower(coalesce(machine.machine_type, '')), 'áčďéěíňóřšťúůýž', 'acdeeinorstuuyz') like '%potrav%'
                 or lower(coalesce(machine.machine_type, '')) like '%snack%'
               )
             )
        )
      )
  ),
  invoicing as (
    select
      scope.machine_id,
      sum(scope.fixed_monthly_amount / nullif(scope.covered_machine_count, 0))::numeric
        as monthly_amount
    from active_machine_scope scope
    group by scope.machine_id
  )
  select
    machine.id as machine_id,
    round(coalesce(telemetry.period_revenue, 0), 2) as telemetry_period_revenue,
    round(coalesce(telemetry.period_revenue, 0) / period.observed_days * 30.4375, 2)
      as telemetry_monthly_average,
    round(coalesce(invoicing.monthly_amount, 0), 2) as invoicing_monthly_average,
    round(
      coalesce(telemetry.period_revenue, 0) / period.observed_days * 30.4375
      + coalesce(invoicing.monthly_amount, 0),
      2
    ) as combined_monthly_average,
    round(coalesce(telemetry.current_month_revenue, 0), 2) as current_month_revenue,
    round(period.observed_days, 2) as observed_days
  from public.machines machine
  join machine_periods period on period.machine_id = machine.id
  left join telemetry on telemetry.machine_id = machine.id
  left join invoicing on invoicing.machine_id = machine.id;
$$;

revoke all on function public.get_machine_overview_economics_v66(timestamptz, timestamptz) from public;
grant execute on function public.get_machine_overview_economics_v66(timestamptz, timestamptz) to authenticated;

comment on function public.get_machine_overview_economics_v66(timestamptz, timestamptz) is
  'Deduplicated revenue from the current placement (up to the requested rolling window) plus separately allocated fixed partner billing for the PC machine overview.';
