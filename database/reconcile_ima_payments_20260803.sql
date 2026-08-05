-- Rebuild the current Prague business day's IMA payment split from immutable
-- adjacent DEX CA2/DA2 counter deltas. VendSoft history is intentionally untouched.
begin;

lock table public.telemetry_sales_events in share row exclusive mode;

create table if not exists public.telemetry_sales_payment_backup_v25_20260803 (
  id bigint primary key,
  row_data jsonb not null,
  backed_up_at timestamptz not null default now()
);

insert into public.telemetry_sales_payment_backup_v25_20260803 (id, row_data)
select sale.id, to_jsonb(sale)
from public.telemetry_sales_events sale
where sale.provider = 'IMA'
  and sale.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
  and sale.source_event_at < timestamptz '2026-08-03 22:00:00+00'
on conflict (id) do nothing;

create temporary table ima_repair_machines on commit drop as
select distinct sale.machine_id
from public.telemetry_sales_events sale
where sale.provider = 'IMA'
  and sale.unpaid_dispense_quantity > 0
  and sale.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
  and sale.source_event_at < timestamptz '2026-08-03 22:00:00+00';

create table if not exists public.telemetry_stock_balance_backup_20260803
  (like public.stock_location_balances including defaults);

create unique index if not exists telemetry_stock_balance_backup_20260803_id_idx
  on public.telemetry_stock_balance_backup_20260803 (id);

insert into public.telemetry_stock_balance_backup_20260803
select balance.*
from public.stock_location_balances balance
join public.stock_locations location
  on location.id = balance.stock_location_id
 and location.location_type = 'machine'
join ima_repair_machines target on target.machine_id = location.machine_id
on conflict (id) do nothing;

create table if not exists public.telemetry_coffee_container_backup_20260803
  (like public.machine_coffee_containers including defaults);

create unique index if not exists telemetry_coffee_container_backup_20260803_id_idx
  on public.telemetry_coffee_container_backup_20260803 (id);

insert into public.telemetry_coffee_container_backup_20260803
select container.*
from public.machine_coffee_containers container
join ima_repair_machines target on target.machine_id = container.machine_id
on conflict (id) do nothing;

create temporary table ima_repair_units (
  unit_id bigint primary key,
  sale_id bigint not null,
  machine_id bigint not null,
  unit_price_hal bigint not null,
  payment_method text
) on commit drop;

insert into ima_repair_units (unit_id, sale_id, machine_id, unit_price_hal)
select
  row_number() over (order by sale.id, unit_number)::bigint,
  sale.id,
  sale.machine_id,
  round(sale.unit_price_czk * 100)::bigint
from public.telemetry_sales_events sale
join ima_repair_machines target using (machine_id)
cross join lateral generate_series(
  1,
  greatest(0, sale.quantity - coalesce(sale.free_vend_quantity, 0))::integer
) unit_number
where sale.provider = 'IMA'
  and sale.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
  and sale.source_event_at < timestamptz '2026-08-03 22:00:00+00';

do $$
begin
  if exists (
    select 1
    from public.telemetry_sales_events sale
    join ima_repair_machines target using (machine_id)
    where sale.provider = 'IMA'
      and sale.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
      and sale.source_event_at < timestamptz '2026-08-03 22:00:00+00'
      and sale.quantity <> trunc(sale.quantity)
  ) then
    raise exception 'IMA repair requires integer sale quantities.';
  end if;
end $$;

create temporary table ima_repair_payment_totals on commit drop as
with ingest_sequence as (
  select
    ingest.id,
    ingest.device_id,
    coalesce(ingest.dex_read_datetime, ingest.transaction_time, ingest.created_at) as event_at,
    greatest(0,
      (regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint
      - lag((regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint)
        over (partition by ingest.device_id order by ingest.id)
    ) as cash_amount_hal,
    greatest(0,
      (regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint
      - lag((regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint)
        over (partition by ingest.device_id order by ingest.id)
    ) as cash_quantity,
    greatest(0,
      (regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint
      - lag((regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint)
        over (partition by ingest.device_id order by ingest.id)
    ) as card_amount_hal,
    greatest(0,
      (regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint
      - lag((regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint)
        over (partition by ingest.device_id order by ingest.id)
    ) as card_quantity
  from public.telemetry_dex_ingests ingest
  where ingest.provider = 'IMA'
), device_links as (
  select distinct link.machine_id, link.external_machine_id as device_id
  from public.machine_external_links link
  join ima_repair_machines target using (machine_id)
  where link.provider = 'IMA'
    and link.telemetry_enabled = true
), payment_totals as (
  select
    link.machine_id,
    sum(sequence.cash_quantity)::integer as cash_quantity,
    sum(sequence.cash_amount_hal)::bigint as cash_amount_hal,
    sum(sequence.card_quantity)::integer as card_quantity,
    sum(sequence.card_amount_hal)::bigint as card_amount_hal
  from ingest_sequence sequence
  join device_links link using (device_id)
  where sequence.event_at >= timestamptz '2026-08-02 22:00:00+00'
    and sequence.event_at < timestamptz '2026-08-03 22:00:00+00'
  group by link.machine_id
), vend_totals as (
  select machine_id, count(*)::integer as vend_quantity
  from ima_repair_units
  group by machine_id
)
select
  vend.machine_id,
  vend.vend_quantity,
  coalesce(payment.cash_quantity, 0) as cash_quantity,
  coalesce(payment.cash_amount_hal, 0) as cash_amount_hal,
  coalesce(payment.card_quantity, 0) as card_quantity,
  coalesce(payment.card_amount_hal, 0) as card_amount_hal,
  case
    when coalesce(payment.cash_quantity, 0) + coalesce(payment.card_quantity, 0) <= vend.vend_quantity
      then least(vend.vend_quantity, coalesce(payment.cash_quantity, 0))
    when coalesce(payment.cash_quantity, 0) + coalesce(payment.card_quantity, 0) > 0
      then least(
        vend.vend_quantity,
        round(
          vend.vend_quantity::numeric * coalesce(payment.cash_quantity, 0)
          / (coalesce(payment.cash_quantity, 0) + coalesce(payment.card_quantity, 0))
        )::integer
      )
    else 0
  end as assigned_cash_quantity,
  least(
    greatest(0, vend.vend_quantity - case
      when coalesce(payment.cash_quantity, 0) + coalesce(payment.card_quantity, 0) <= vend.vend_quantity
        then least(vend.vend_quantity, coalesce(payment.cash_quantity, 0))
      when coalesce(payment.cash_quantity, 0) + coalesce(payment.card_quantity, 0) > 0
        then least(
          vend.vend_quantity,
          round(
            vend.vend_quantity::numeric * coalesce(payment.cash_quantity, 0)
            / (coalesce(payment.cash_quantity, 0) + coalesce(payment.card_quantity, 0))
          )::integer
        )
      else 0
    end),
    coalesce(payment.card_quantity, 0)
  ) as assigned_card_quantity
from vend_totals vend
left join payment_totals payment using (machine_id);

do $$
begin
  if exists (
    select 1
    from ima_repair_payment_totals
    where vend_quantity <= 0
       or assigned_cash_quantity < 0
       or assigned_card_quantity < 0
       or assigned_cash_quantity + assigned_card_quantity > vend_quantity
  ) then
    raise exception 'Invalid IMA payment assignment targets.';
  end if;
end $$;

create temporary table ima_repair_cash_states (
  machine_id bigint not null,
  picked_count integer not null,
  amount_hal bigint not null,
  picked_units bigint[] not null,
  primary key (machine_id, picked_count, amount_hal)
) on commit drop;

create temporary table ima_repair_card_states (
  machine_id bigint not null,
  picked_count integer not null,
  amount_hal bigint not null,
  picked_units bigint[] not null,
  primary key (machine_id, picked_count, amount_hal)
) on commit drop;

do $$
declare
  target record;
  unit_row record;
  v_cash_units bigint[];
  v_card_units bigint[];
begin
  for target in
    select
      totals.*,
      case
        when totals.assigned_cash_quantity = 0 or totals.cash_quantity = 0 then 0
        else round(
          totals.cash_amount_hal::numeric * totals.assigned_cash_quantity / totals.cash_quantity
        )::bigint
      end as assigned_cash_amount_hal,
      case
        when totals.assigned_card_quantity = 0 or totals.card_quantity = 0 then 0
        else round(
          totals.card_amount_hal::numeric * totals.assigned_card_quantity / totals.card_quantity
        )::bigint
      end as assigned_card_amount_hal
    from ima_repair_payment_totals totals
    order by totals.machine_id
  loop
    insert into ima_repair_cash_states (machine_id, picked_count, amount_hal, picked_units)
    values (target.machine_id, 0, 0, array[]::bigint[]);

    for unit_row in
      select unit_id, unit_price_hal
      from ima_repair_units
      where machine_id = target.machine_id
      order by unit_id
    loop
      insert into ima_repair_cash_states (machine_id, picked_count, amount_hal, picked_units)
      select
        state.machine_id,
        state.picked_count + 1,
        state.amount_hal + unit_row.unit_price_hal,
        state.picked_units || unit_row.unit_id
      from ima_repair_cash_states state
      where state.machine_id = target.machine_id
        and state.picked_count < target.assigned_cash_quantity
      on conflict (machine_id, picked_count, amount_hal) do nothing;
    end loop;

    select state.picked_units
      into v_cash_units
    from ima_repair_cash_states state
    where state.machine_id = target.machine_id
      and state.picked_count = target.assigned_cash_quantity
    order by abs(state.amount_hal - target.assigned_cash_amount_hal), state.amount_hal
    limit 1;

    v_cash_units := coalesce(v_cash_units, array[]::bigint[]);
    update ima_repair_units
    set payment_method = 'cash'
    where machine_id = target.machine_id
      and unit_id = any(v_cash_units);

    insert into ima_repair_card_states (machine_id, picked_count, amount_hal, picked_units)
    values (target.machine_id, 0, 0, array[]::bigint[]);

    for unit_row in
      select unit_id, unit_price_hal
      from ima_repair_units
      where machine_id = target.machine_id
        and payment_method is null
      order by unit_id
    loop
      insert into ima_repair_card_states (machine_id, picked_count, amount_hal, picked_units)
      select
        state.machine_id,
        state.picked_count + 1,
        state.amount_hal + unit_row.unit_price_hal,
        state.picked_units || unit_row.unit_id
      from ima_repair_card_states state
      where state.machine_id = target.machine_id
        and state.picked_count < target.assigned_card_quantity
      on conflict (machine_id, picked_count, amount_hal) do nothing;
    end loop;

    select state.picked_units
      into v_card_units
    from ima_repair_card_states state
    where state.machine_id = target.machine_id
      and state.picked_count = target.assigned_card_quantity
    order by abs(state.amount_hal - target.assigned_card_amount_hal), state.amount_hal
    limit 1;

    v_card_units := coalesce(v_card_units, array[]::bigint[]);
    update ima_repair_units
    set payment_method = 'card'
    where machine_id = target.machine_id
      and unit_id = any(v_card_units);

    update ima_repair_units
    set payment_method = 'unpaid'
    where machine_id = target.machine_id
      and payment_method is null;
  end loop;
end $$;

with rebuilt as (
  select
    unit.sale_id,
    count(*) filter (where unit.payment_method = 'cash')::numeric as cash_quantity,
    count(*) filter (where unit.payment_method = 'card')::numeric as card_quantity,
    count(*) filter (where unit.payment_method = 'unpaid')::numeric as unpaid_quantity
  from ima_repair_units unit
  group by unit.sale_id
)
update public.telemetry_sales_events sale
set
  cash_quantity = rebuilt.cash_quantity,
  cashless_quantity = rebuilt.card_quantity,
  unknown_payment_quantity = 0,
  unpaid_dispense_quantity = rebuilt.unpaid_quantity,
  cash_amount_czk = round(rebuilt.cash_quantity * sale.unit_price_czk, 2),
  cashless_amount_czk = round(rebuilt.card_quantity * sale.unit_price_czk, 2),
  unknown_payment_amount_czk = 0,
  total_amount_czk = round((rebuilt.cash_quantity + rebuilt.card_quantity) * sale.unit_price_czk, 2)
from rebuilt
where sale.id = rebuilt.sale_id;

do $$
declare
  remaining_unknown numeric;
  remaining_unpaid numeric;
  expected_unpaid numeric;
  broken_rows integer;
begin
  select coalesce(sum(sale.unknown_payment_quantity), 0)
  into remaining_unknown
  from public.telemetry_sales_events sale
  join ima_repair_machines target using (machine_id)
  where sale.provider = 'IMA'
    and sale.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
    and sale.source_event_at < timestamptz '2026-08-03 22:00:00+00';

  select coalesce(sum(sale.unpaid_dispense_quantity), 0)
  into remaining_unpaid
  from public.telemetry_sales_events sale
  join ima_repair_machines target using (machine_id)
  where sale.provider = 'IMA'
    and sale.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
    and sale.source_event_at < timestamptz '2026-08-03 22:00:00+00';

  select coalesce(sum(greatest(0, vend_quantity - assigned_cash_quantity - assigned_card_quantity)), 0)
  into expected_unpaid
  from ima_repair_payment_totals;

  select count(*)
  into broken_rows
  from public.telemetry_sales_events sale
  join ima_repair_machines target using (machine_id)
  where sale.provider = 'IMA'
    and sale.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
    and sale.source_event_at < timestamptz '2026-08-03 22:00:00+00'
    and sale.cash_quantity + sale.cashless_quantity
      + sale.free_vend_quantity + sale.unknown_payment_quantity
      + sale.unpaid_dispense_quantity <> sale.quantity;

  if remaining_unknown <> 0 or remaining_unpaid <> expected_unpaid or broken_rows <> 0 then
    raise exception 'IMA repair validation failed: unknown %, unpaid %/% expected, broken rows %',
      remaining_unknown, remaining_unpaid, expected_unpaid, broken_rows;
  end if;
end $$;

-- Product counters prove the physical vend independently of payment timing.
-- Run the idempotent RPCs one event at a time so repeated products cannot share
-- the same pre-update balance in a bulk allocation.
do $$
declare
  sale record;
begin
  for sale in
    select event.id
    from public.telemetry_sales_events event
    join ima_repair_machines target using (machine_id)
    where event.provider = 'IMA'
      and event.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
      and event.source_event_at < timestamptz '2026-08-03 22:00:00+00'
    order by event.source_event_at, event.id
  loop
    perform public.apply_telemetry_coffee_depletion(array[sale.id]);
    perform public.apply_telemetry_stock_depletion(array[sale.id]);
  end loop;
end $$;

select
  machine.evidence_number,
  sum(sale.quantity) as quantity,
  sum(sale.cash_quantity) as cash_quantity,
  sum(sale.cashless_quantity) as card_quantity,
  sum(sale.unknown_payment_quantity) as unknown_quantity,
  sum(sale.unpaid_dispense_quantity) as unpaid_quantity,
  sum(sale.total_amount_czk) as amount_czk
from public.telemetry_sales_events sale
join public.machines machine on machine.id = sale.machine_id
join ima_repair_machines target on target.machine_id = sale.machine_id
where sale.provider = 'IMA'
  and sale.source_event_at >= timestamptz '2026-08-02 22:00:00+00'
  and sale.source_event_at < timestamptz '2026-08-03 22:00:00+00'
group by machine.evidence_number
order by machine.evidence_number;

commit;
