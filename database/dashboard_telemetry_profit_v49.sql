begin;

create or replace function public.get_dashboard_telemetry_profit_v49(
  p_period_start timestamptz,
  p_period_end timestamptz,
  p_compare_start timestamptz,
  p_compare_end timestamptz,
  p_compare_date_keys date[],
  p_compare_elapsed_ms bigint
)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with settings as (
    select coalesce(cardinality(p_compare_date_keys), 0) as compare_key_count
  ),
  source_events as (
    select
      event.*,
      (event.source_event_at at time zone 'Europe/Prague')::date as local_sale_date,
      floor(extract(epoch from (event.source_event_at at time zone 'Europe/Prague')::time) * 1000)::bigint as local_elapsed_ms
    from public.telemetry_sales_events event
    where event.source_event_at >= least(p_period_start, p_compare_start)
      and event.source_event_at < greatest(p_period_end, p_compare_end)
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
            and direct.source_event_at between event.source_event_at - interval '20 minutes' and event.source_event_at + interval '20 minutes'
        )
      )
  ),
  valued_events as (
    select
      event.*,
      coalesce(product.purchase_price, 0)::numeric as unit_cost,
      coalesce(product.vat_rate, 21)::numeric as vat_rate,
      (product.id is null or coalesce(product.purchase_price, 0) <= 0) as missing_cost
    from source_events event
    left join lateral (
      select candidate.id, candidate.purchase_price, candidate.vat_rate
      from public.products candidate
      where (
        nullif(event.product_sku, '') is not null
        and candidate.sku = event.product_sku
      ) or (
        nullif(event.product_sku, '') is null
        and lower(trim(candidate.name)) = lower(trim(coalesce(event.product_name, '')))
      )
      order by case when candidate.sku = event.product_sku then 0 else 1 end, candidate.active desc, candidate.id
      limit 1
    ) product on true
  ),
  period_events as (
    select * from valued_events
    where source_event_at >= p_period_start and source_event_at < p_period_end
  ),
  compare_events as (
    select event.*
    from valued_events event
    cross join settings
    where (
      settings.compare_key_count > 0
      and event.local_sale_date = any(p_compare_date_keys)
      and (p_compare_elapsed_ms is null or event.local_elapsed_ms <= p_compare_elapsed_ms)
    ) or (
      settings.compare_key_count = 0
      and event.source_event_at >= p_compare_start
      and event.source_event_at < p_compare_end
    )
  ),
  period_total as (
    select
      coalesce(sum(total_amount_czk / (1 + vat_rate / 100)), 0)::numeric as revenue_net,
      coalesce(sum(quantity * unit_cost), 0)::numeric as cost,
      coalesce(sum(total_amount_czk / (1 + vat_rate / 100) - quantity * unit_cost), 0)::numeric as profit,
      count(*) filter (where missing_cost and quantity > 0)::bigint as missing_cost_count
    from period_events
  ),
  compare_total as (
    select
      coalesce(sum(total_amount_czk / (1 + vat_rate / 100)), 0)::numeric as revenue_net,
      coalesce(sum(quantity * unit_cost), 0)::numeric as cost,
      coalesce(sum(total_amount_czk / (1 + vat_rate / 100) - quantity * unit_cost), 0)::numeric as profit,
      count(*) filter (where missing_cost and quantity > 0)::bigint as missing_cost_count
    from compare_events
  )
  select jsonb_build_object(
    'period', (select to_jsonb(row) from period_total row),
    'compare', (select to_jsonb(row) from compare_total row)
  );
$$;

revoke all on function public.get_dashboard_telemetry_profit_v49(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint
) from public, anon;
grant execute on function public.get_dashboard_telemetry_profit_v49(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint
) to authenticated;

comment on function public.get_dashboard_telemetry_profit_v49(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint
) is 'Hrubý zisk telemetrických prodejů bez DPH podle nákupních cen produktů.';

commit;
