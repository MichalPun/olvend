begin;

create temporary table tmp_telemetry_sales_recovery on commit drop as
with linked_devices as (
  select distinct mel.external_machine_id as device_id, mel.machine_id
  from public.machine_external_links mel
  where lower(mel.provider) = 'ima' and mel.telemetry_enabled = true
), before_ingest as (
  select distinct on (i.device_id) i.id, i.device_id, i.raw_dex, i.dex_read_datetime
  from public.telemetry_dex_ingests i
  join linked_devices d on d.device_id = i.device_id
  where i.status = 'parsed' and i.created_at <= '2026-07-31 20:27:02+00'::timestamptz
  order by i.device_id, i.created_at desc
), after_ingest as (
  select distinct on (i.device_id) i.id, i.device_id, i.raw_dex, i.dex_read_datetime
  from public.telemetry_dex_ingests i
  join linked_devices d on d.device_id = i.device_id
  where i.status = 'parsed'
  order by i.device_id, i.created_at desc
), before_counters as (
  select b.device_id, m[1] as selection_code, m[2]::numeric as total_count
  from before_ingest b
  cross join lateral regexp_matches(
    b.raw_dex,
    E'PA1\\*([^*\\r\\n]+)\\*[^\\r\\n]*\\r?\\nPA2\\*([^*\\r\\n]+)\\*',
    'g'
  ) m
), after_counters as (
  select a.id as ingest_id, a.device_id, a.dex_read_datetime,
         m[1] as selection_code, m[2]::numeric as total_count
  from after_ingest a
  cross join lateral regexp_matches(
    a.raw_dex,
    E'PA1\\*([^*\\r\\n]+)\\*[^\\r\\n]*\\r?\\nPA2\\*([^*\\r\\n]+)\\*',
    'g'
  ) m
), deltas as (
  select d.machine_id, a.device_id, a.ingest_id, a.dex_read_datetime,
         a.selection_code,
         greatest(0, a.total_count - coalesce(b.total_count, a.total_count)) as quantity
  from after_counters a
  join linked_devices d on d.device_id = a.device_id
  left join before_counters b
    on b.device_id = a.device_id and b.selection_code = a.selection_code
)
select d.machine_id, d.device_id, d.ingest_id, d.dex_read_datetime,
       d.selection_code, d.quantity,
       s.id as planogram_slot_id, s.product_name, s.product_sku,
       coalesce(s.customer_price_czk, s.dex_price_czk, s.price_czk) as unit_price_czk
from deltas d
join public.machine_planogram_slots s
  on s.machine_id = d.machine_id
 and s.active = true
 and trim(s.slot_code) = trim(d.selection_code)
where d.quantity > 0;

do $$
declare
  v_rows integer;
  v_units numeric;
  v_max numeric;
begin
  select count(*), coalesce(sum(quantity), 0), coalesce(max(quantity), 0)
    into v_rows, v_units, v_max
  from tmp_telemetry_sales_recovery;
  if v_rows <> 87 or v_units <> 123 or v_max > 10 then
    raise exception 'Obnova telemetrie neodpovídá ověřenému náhledu: rows %, units %, max %.', v_rows, v_units, v_max;
  end if;
end;
$$;

with inserted as (
  insert into public.telemetry_sales_events (
    provider, ingest_id, machine_id, planogram_slot_id, selection_code,
    product_name, product_sku, quantity, cash_quantity, cashless_quantity,
    unknown_payment_quantity, unit_price_czk, total_amount_czk, cash_amount_czk,
    cashless_amount_czk, unknown_payment_amount_czk, source_event_at,
    source_event_key, event_part
  )
  select
    'IMA-recovery', null, r.machine_id, r.planogram_slot_id, r.selection_code,
    r.product_name, r.product_sku, r.quantity, 0, 0, r.quantity,
    r.unit_price_czk,
    case when r.unit_price_czk is null then null else round(r.quantity * r.unit_price_czk, 2) end,
    null, null,
    case when r.unit_price_czk is null then null else round(r.quantity * r.unit_price_czk, 2) end,
    coalesce(r.dex_read_datetime, now()),
    'recovery-20260801-' || r.device_id || '-' || r.selection_code,
    1
  from tmp_telemetry_sales_recovery r
  on conflict (provider, source_event_key, event_part)
    where source_event_key is not null
  do nothing
  returning planogram_slot_id, quantity
), depleted as (
  select planogram_slot_id, sum(quantity) as quantity
  from inserted
  group by planogram_slot_id
)
update public.machine_planogram_slots s
set current_units = greatest(0, coalesce(s.current_units, 0) - d.quantity),
    fill_percent = case
      when coalesce(s.capacity_units, 0) > 0
        then round(greatest(0, coalesce(s.current_units, 0) - d.quantity) / s.capacity_units * 100, 2)
      else null
    end,
    updated_at = now()
from depleted d
where s.id = d.planogram_slot_id;

commit;

select count(*) as recovered_rows, coalesce(sum(quantity), 0) as recovered_units,
       min(source_event_at) as earliest_recovery_event,
       max(source_event_at) as latest_recovery_event
from public.telemetry_sales_events
where provider = 'IMA-recovery'
  and source_event_key like 'recovery-20260801-%';
