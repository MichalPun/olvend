begin;

select public.apply_telemetry_coffee_depletion(array(
  select s.id
  from public.telemetry_sales_events s
  where s.source_event_at >= '2026-08-01 00:00:00+02'::timestamptz
    and s.provider in ('IMA','IMA-recovery')
  order by s.id
));

select public.apply_telemetry_stock_depletion(array(
  select s.id from public.telemetry_sales_events s
  where s.source_event_at >= '2026-08-01 00:00:00+02'::timestamptz
    and s.provider in ('IMA','IMA-recovery') order by s.id
));

commit;

select count(*) depletion_rows, count(distinct sale_event_id) sale_events,
       count(distinct coffee_container_id) containers,
       round(sum(quantity),3) total_recipe_quantity
from public.telemetry_coffee_recipe_depletions
where created_at >= '2026-08-01 00:00:00+02'::timestamptz;
