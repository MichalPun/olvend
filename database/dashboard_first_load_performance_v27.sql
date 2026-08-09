-- Rychlý první start nástěnky:
-- prohlížeč dostane hotové agregace v jednom požadavku místo desítek stránkovaných dotazů.

create or replace function public.get_dashboard_finance_source_v27(
  p_from date,
  p_to date,
  p_stock_location_id bigint default null
)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with dated_movements as (
    select
      movement.product_id,
      movement.movement_type,
      movement.quantity_base_units,
      movement.unit_price,
      movement.reference_type,
      movement.from_stock_location_id,
      coalesce(
        ((regexp_match(coalesce(movement.note, ''), '\m20[0-9]{2}-[0-9]{2}-[0-9]{2}\M'))[1])::date,
        (movement.created_at at time zone 'Europe/Prague')::date
      ) as sale_date
    from public.stock_movements_v13 movement
    where movement.movement_type in ('sale', 'sale_revenue')
      and (p_stock_location_id is null or movement.from_stock_location_id = p_stock_location_id)
  ),
  grouped_movements as (
    select
      product_id,
      movement_type,
      sum(quantity_base_units)::numeric as quantity_base_units,
      unit_price,
      reference_type,
      from_stock_location_id,
      sale_date,
      count(*)::bigint as source_count
    from dated_movements
    where sale_date >= p_from
      and sale_date < p_to
    group by
      product_id,
      movement_type,
      unit_price,
      reference_type,
      from_stock_location_id,
      sale_date
  ),
  balances as (
    select
      balance.stock_location_id,
      balance.product_id,
      balance.quantity_on_hand
    from public.stock_location_balances balance
    where p_stock_location_id is null
       or balance.stock_location_id = p_stock_location_id
  )
  select jsonb_build_object(
    'movements', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'product_id', movement.product_id,
          'movement_type', movement.movement_type,
          'quantity_base_units', movement.quantity_base_units,
          'unit_price', movement.unit_price,
          'reference_type', movement.reference_type,
          'from_stock_location_id', movement.from_stock_location_id,
          'created_at', movement.sale_date::text || 'T12:00:00+00:00',
          'note', '',
          'source_count', movement.source_count
        )
        order by movement.sale_date desc, movement.product_id
      )
      from grouped_movements movement
    ), '[]'::jsonb),
    'balances', coalesce((
      select jsonb_agg(to_jsonb(balance) order by balance.stock_location_id, balance.product_id)
      from balances balance
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_dashboard_finance_source_v27(date, date, bigint) from public, anon;
grant execute on function public.get_dashboard_finance_source_v27(date, date, bigint) to authenticated;

comment on function public.get_dashboard_finance_source_v27(date, date, bigint) is
  'Vrací filtrované a agregované skladové zdroje pro finanční část nástěnky v jediném požadavku.';

create or replace function public.get_dashboard_telemetry_summary_v27(
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
  with settings as (
    select
      least(p_period_start, p_compare_start, p_trend_start) as fetch_start,
      greatest(p_period_end, p_compare_end, p_trend_end) as fetch_end,
      coalesce(cardinality(p_compare_date_keys), 0) as compare_key_count
  ),
  source_events as (
    select
      event.*,
      (event.source_event_at at time zone 'Europe/Prague')::date as local_sale_date,
      floor(extract(epoch from (event.source_event_at at time zone 'Europe/Prague')::time) * 1000)::bigint as local_elapsed_ms
    from public.telemetry_sales_events event
    cross join settings
    where event.source_event_at >= settings.fetch_start
      and event.source_event_at < settings.fetch_end
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
  period_events as (
    select *
    from source_events
    where source_event_at >= p_period_start
      and source_event_at < p_period_end
  ),
  compare_events as (
    select event.*
    from source_events event
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
  trend_events as (
    select *
    from source_events
    where source_event_at >= p_trend_start
      and source_event_at < p_trend_end
  ),
  period_totals as (
    select
      coalesce(sum(quantity), 0)::numeric as quantity,
      coalesce(sum(total_amount_czk), 0)::numeric as revenue,
      coalesce(sum(coalesce(unpaid_dispense_quantity, 0) * coalesce(unit_price_czk, 0)), 0)::numeric as "pendingAmount",
      coalesce(sum(cash_amount_czk), 0)::numeric as "cashAmount",
      coalesce(sum(cashless_amount_czk), 0)::numeric as "cashlessAmount",
      coalesce(sum(unknown_payment_amount_czk), 0)::numeric as "unknownAmount",
      coalesce(sum(cash_quantity), 0)::numeric as "cashQuantity",
      coalesce(sum(cashless_quantity), 0)::numeric as "cashlessQuantity",
      coalesce(sum(free_vend_quantity), 0)::numeric as "freeQuantity",
      coalesce(sum(unpaid_dispense_quantity), 0)::numeric as "pendingQuantity",
      coalesce(sum(unknown_payment_quantity), 0)::numeric as "unknownQuantity",
      count(distinct machine_id)::bigint as "machineCount"
    from period_events
  ),
  compare_totals as (
    select
      coalesce(sum(quantity), 0)::numeric as quantity,
      coalesce(sum(total_amount_czk), 0)::numeric as revenue,
      coalesce(sum(coalesce(unpaid_dispense_quantity, 0) * coalesce(unit_price_czk, 0)), 0)::numeric as "pendingAmount",
      coalesce(sum(cash_amount_czk), 0)::numeric as "cashAmount",
      coalesce(sum(cashless_amount_czk), 0)::numeric as "cashlessAmount",
      coalesce(sum(unknown_payment_amount_czk), 0)::numeric as "unknownAmount",
      coalesce(sum(cash_quantity), 0)::numeric as "cashQuantity",
      coalesce(sum(cashless_quantity), 0)::numeric as "cashlessQuantity",
      coalesce(sum(free_vend_quantity), 0)::numeric as "freeQuantity",
      coalesce(sum(unpaid_dispense_quantity), 0)::numeric as "pendingQuantity",
      coalesce(sum(unknown_payment_quantity), 0)::numeric as "unknownQuantity"
    from compare_events
  ),
  trend_days as (
    select day::date as sale_date
    from generate_series(
      (p_trend_start at time zone 'Europe/Prague')::date,
      ((p_trend_end at time zone 'Europe/Prague')::date - 1),
      interval '1 day'
    ) day
  ),
  trend_totals as (
    select
      local_sale_date as sale_date,
      coalesce(sum(total_amount_czk), 0)::numeric as revenue,
      coalesce(sum(cash_amount_czk), 0)::numeric as cash,
      coalesce(sum(cashless_amount_czk), 0)::numeric as cashless,
      coalesce(sum(unknown_payment_amount_czk), 0)::numeric as unknown,
      coalesce(sum(quantity), 0)::numeric as quantity
    from trend_events
    group by local_sale_date
  ),
  day_rows as (
    select
      day.sale_date::text as date,
      coalesce(total.revenue, 0)::numeric as revenue,
      coalesce(total.cash, 0)::numeric as cash,
      coalesce(total.cashless, 0)::numeric as cashless,
      coalesce(total.unknown, 0)::numeric as unknown,
      coalesce(total.quantity, 0)::numeric as quantity
    from trend_days day
    left join trend_totals total using (sale_date)
  ),
  product_rows as (
    select
      coalesce(nullif(product_name, ''), nullif(product_sku, ''), 'Bez produktu') as label,
      coalesce(sum(quantity), 0)::numeric as quantity,
      coalesce(sum(total_amount_czk), 0)::numeric as revenue,
      coalesce(sum(cash_amount_czk), 0)::numeric as cash,
      coalesce(sum(cashless_amount_czk), 0)::numeric as cashless,
      coalesce(sum(unknown_payment_amount_czk), 0)::numeric as unknown
    from period_events
    group by coalesce(nullif(product_name, ''), nullif(product_sku, ''), 'Bez produktu')
  ),
  location_rows as (
    select
      coalesce(
        nullif(concat_ws(' · ', nullif(location.city, ''), nullif(location.name, '')), ''),
        nullif(machine.name, ''),
        'Bez lokality'
      ) as label,
      coalesce(sum(event.quantity), 0)::numeric as quantity,
      coalesce(sum(event.total_amount_czk), 0)::numeric as revenue,
      coalesce(sum(event.cash_amount_czk), 0)::numeric as cash,
      coalesce(sum(event.cashless_amount_czk), 0)::numeric as cashless,
      coalesce(sum(event.unknown_payment_amount_czk), 0)::numeric as unknown
    from period_events event
    left join public.machines machine on machine.id = event.machine_id
    left join public.locations location on location.id = machine.location_id
    group by coalesce(
      nullif(concat_ws(' · ', nullif(location.city, ''), nullif(location.name, '')), ''),
      nullif(machine.name, ''),
      'Bez lokality'
    )
  )
  select jsonb_build_object(
    'period_totals', (select to_jsonb(total) from period_totals total),
    'compare_totals', (select to_jsonb(total) from compare_totals total),
    'compare_sample_count', case
      when coalesce(cardinality(p_compare_date_keys), 0) > 0
        then (select count(distinct local_sale_date) from compare_events)
      else 1
    end,
    'day_rows', coalesce((
      select jsonb_agg(to_jsonb(day) order by day.date)
      from day_rows day
    ), '[]'::jsonb),
    'top_products', coalesce((
      select jsonb_agg(to_jsonb(product) order by product.revenue desc, product.label)
      from product_rows product
    ), '[]'::jsonb),
    'top_locations', coalesce((
      select jsonb_agg(to_jsonb(location) order by location.revenue desc, location.label)
      from location_rows location
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_dashboard_telemetry_summary_v27(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint, timestamptz, timestamptz
) from public, anon;
grant execute on function public.get_dashboard_telemetry_summary_v27(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint, timestamptz, timestamptz
) to authenticated;

comment on function public.get_dashboard_telemetry_summary_v27(
  timestamptz, timestamptz, timestamptz, timestamptz, date[], bigint, timestamptz, timestamptz
) is 'Vrací souhrny prodejů, srovnání a čtrnáctidenní trend v jediném požadavku.';
