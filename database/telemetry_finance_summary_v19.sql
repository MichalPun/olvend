create or replace function public.get_telemetry_finance_summary_v19(
  p_from timestamptz,
  p_to timestamptz,
  p_stock_location_id bigint default null
)
returns table (
  sale_date date,
  stock_location_id bigint,
  product_id bigint,
  product_name text,
  product_sku text,
  quantity numeric,
  revenue numeric,
  event_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    timezone('Europe/Prague', event.source_event_at)::date as sale_date,
    machine_stock.id as stock_location_id,
    matched_product.id as product_id,
    coalesce(matched_product.name, event.product_name, 'Telemetrický prodej') as product_name,
    coalesce(matched_product.sku, event.product_sku) as product_sku,
    sum(coalesce(event.quantity, 0)) as quantity,
    sum(coalesce(
      event.total_amount_czk,
      event.quantity * event.unit_price_czk,
      0
    )) as revenue,
    count(*) as event_count
  from public.telemetry_sales_events event
  left join lateral (
    select location.id
    from public.stock_locations location
    where location.machine_id = event.machine_id
      and location.active is not false
    order by location.id
    limit 1
  ) machine_stock on true
  left join lateral (
    select product.id, product.name, product.sku
    from public.products product
    where event.product_sku is not null
      and product.sku = event.product_sku
    order by product.active desc nulls last, product.id
    limit 1
  ) matched_product on true
  where event.source_event_at >= p_from
    and event.source_event_at < p_to
    and (
      p_stock_location_id is null
      or machine_stock.id = p_stock_location_id
    )
  group by
    timezone('Europe/Prague', event.source_event_at)::date,
    machine_stock.id,
    matched_product.id,
    matched_product.name,
    matched_product.sku,
    event.product_name,
    event.product_sku;
$$;

revoke all on function public.get_telemetry_finance_summary_v19(timestamptz, timestamptz, bigint) from public;
grant execute on function public.get_telemetry_finance_summary_v19(timestamptz, timestamptz, bigint) to authenticated, anon;

comment on function public.get_telemetry_finance_summary_v19(timestamptz, timestamptz, bigint) is
  'Aggregates telemetry vending revenue for the finance dashboard without sending individual sales events to the browser.';
