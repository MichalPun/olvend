-- Keep telemetry revenue assigned to the location where the machine was
-- physically installed at the time of sale. Moving a machine must not rewrite
-- historical location totals on the dashboard.

create or replace function public.get_dashboard_telemetry_summary_v50(
  p_period_start timestamptz,
  p_period_end timestamptz,
  p_compare_start timestamptz,
  p_compare_end timestamptz,
  p_compare_date_keys date[],
  p_compare_elapsed_ms bigint,
  p_trend_start timestamptz,
  p_trend_end timestamptz
)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with base as (
    select public.get_dashboard_telemetry_summary_v27(
      p_period_start,
      p_period_end,
      p_compare_start,
      p_compare_end,
      p_compare_date_keys,
      p_compare_elapsed_ms,
      p_trend_start,
      p_trend_end
    ) as payload
  ),
  period_events as (
    select event.*
    from public.telemetry_sales_events event
    where event.source_event_at >= p_period_start
      and event.source_event_at < p_period_end
      and not (
        lower(coalesce(event.provider, '')) = 'vendsoft'
        and exists (
          select 1
          from public.telemetry_sales_events direct
          where lower(coalesce(direct.provider, '')) = 'ima'
            and direct.machine_id is not distinct from event.machine_id
            and coalesce(direct.selection_code, '') = coalesce(event.selection_code, '')
            and coalesce(direct.product_sku, '') = coalesce(event.product_sku, '')
            and coalesce(direct.quantity, 0) = coalesce(event.quantity, 0)
            and abs(coalesce(direct.total_amount_czk, 0) - coalesce(event.total_amount_czk, 0)) <= 0.01
            and direct.source_event_at between event.source_event_at - interval '20 minutes'
              and event.source_event_at + interval '20 minutes'
        )
      )
  ),
  located_events as (
    select
      event.*,
      coalesce(
        nullif(event.source_location_name, ''),
        nullif(concat_ws(' · ', nullif(location.city, ''), nullif(location.name, '')), ''),
        nullif(machine.name, ''),
        'Bez lokality'
      ) as location_label
    from period_events event
    left join public.machines machine on machine.id = event.machine_id
    left join lateral (
      select true as transfer_found, transfer.from_location_id
      from public.machine_transfers transfer
      where transfer.machine_id = event.machine_id
        and transfer.transferred_at > event.source_event_at
      order by transfer.transferred_at asc, transfer.id asc
      limit 1
    ) historical on true
    left join public.locations location on location.id = case
      when historical.transfer_found then historical.from_location_id
      else machine.location_id
    end
  ),
  location_rows as (
    select
      location_label as label,
      coalesce(sum(quantity), 0)::numeric as quantity,
      coalesce(sum(total_amount_czk), 0)::numeric as revenue,
      coalesce(sum(cash_amount_czk), 0)::numeric as cash,
      coalesce(sum(cashless_amount_czk), 0)::numeric as cashless,
      coalesce(sum(unknown_payment_amount_czk), 0)::numeric as unknown
    from located_events
    group by location_label
  )
  select base.payload || jsonb_build_object(
    'top_locations', coalesce((
      select jsonb_agg(to_jsonb(location) order by location.revenue desc, location.label)
      from location_rows location
    ), '[]'::jsonb)
  )
  from base;
$$;

revoke all on function public.get_dashboard_telemetry_summary_v50(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint, timestamptz, timestamptz
) from public, anon;

grant execute on function public.get_dashboard_telemetry_summary_v50(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint, timestamptz, timestamptz
) to authenticated;

comment on function public.get_dashboard_telemetry_summary_v50(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint, timestamptz, timestamptz
) is 'Dashboard telemetry summary with sale-time location attribution derived from source snapshots and machine transfer history.';
