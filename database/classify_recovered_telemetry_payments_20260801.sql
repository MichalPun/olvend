begin;

create temporary table tmp_recovery_payment_targets (
  machine_id bigint primary key,
  cash_qty integer not null,
  card_qty integer not null,
  cash_amount_czk numeric(12,2) not null,
  card_amount_czk numeric(12,2) not null
) on commit drop;

insert into tmp_recovery_payment_targets values
  (3,   0,  1,   0,  26),
  (13,  0,  3,   0,  42),
  (19,  9,  1, 198,  29),
  (23,  2,  0,  40,   0),
  (25,  1,  1,  14,  14),
  (37,  0,  2,   0,  24),
  (49,  0,  2,   0,  52),
  (57,  3,  0,  41,   0),
  (58,  0, 13,   0, 370),
  (66,  1,  0,   5,   0),
  (68,  2,  1,  24,  12),
  (69,  2,  0,   0,   0),
  (71,  1,  0,  20,   0),
  (72,  1,  0,   0,   0),
  (74,  8, 19, 240, 639),
  (80, 13,  8, 331, 287),
  (81,  3,  2,  70,  40),
  (82,  1,  1,   7,   7),
  (83,  3,  3,  50,  52),
  (101,12,  4, 168,  66);

do $$
declare
  v_event_qty numeric;
  v_target_qty numeric;
begin
  select coalesce(sum(quantity), 0) into v_event_qty
  from public.telemetry_sales_events
  where provider = 'IMA-recovery' and source_event_key like 'recovery-20260801-%';

  select coalesce(sum(cash_qty + card_qty), 0) into v_target_qty
  from tmp_recovery_payment_targets;

  if v_event_qty <> 123 or v_target_qty <> 123 then
    raise exception 'Nesouhlasí množství obnovy (%) a platebních cílů (%).', v_event_qty, v_target_qty;
  end if;
end;
$$;

with recovery_units as (
  select e.id, e.machine_id, u.unit_no,
         row_number() over (partition by e.machine_id order by e.id, u.unit_no) as machine_unit_no
  from public.telemetry_sales_events e
  cross join lateral generate_series(1, e.quantity::integer) u(unit_no)
  where e.provider = 'IMA-recovery'
    and e.source_event_key like 'recovery-20260801-%'
), classified_units as (
  select u.id, u.machine_id,
         count(*) filter (where u.machine_unit_no <= t.cash_qty)::numeric as cash_qty,
         count(*) filter (where u.machine_unit_no > t.cash_qty)::numeric as card_qty
  from recovery_units u
  join tmp_recovery_payment_targets t using (machine_id)
  group by u.id, u.machine_id
), allocations as (
  select c.id, c.cash_qty, c.card_qty,
         case when t.cash_qty > 0 then round(t.cash_amount_czk * c.cash_qty / t.cash_qty, 2) else null end as cash_amount,
         case when t.card_qty > 0 then round(t.card_amount_czk * c.card_qty / t.card_qty, 2) else null end as card_amount
  from classified_units c
  join tmp_recovery_payment_targets t using (machine_id)
)
update public.telemetry_sales_events e
set cash_quantity = a.cash_qty,
    cashless_quantity = a.card_qty,
    unknown_payment_quantity = 0,
    cash_amount_czk = a.cash_amount,
    cashless_amount_czk = a.card_amount,
    unknown_payment_amount_czk = null,
    total_amount_czk = coalesce(a.cash_amount, 0) + coalesce(a.card_amount, 0)
from allocations a
where e.id = a.id;

-- Correct rounding residue on the last classified row of each payment method.
with totals as (
  select e.machine_id,
         sum(e.cash_amount_czk) as cash_amount,
         sum(e.cashless_amount_czk) as card_amount
  from public.telemetry_sales_events e
  where e.provider = 'IMA-recovery' and e.source_event_key like 'recovery-20260801-%'
  group by e.machine_id
), cash_last as (
  select distinct on (e.machine_id) e.id, e.machine_id
  from public.telemetry_sales_events e
  where e.provider = 'IMA-recovery' and e.source_event_key like 'recovery-20260801-%'
    and e.cash_quantity > 0
  order by e.machine_id, e.id desc
), card_last as (
  select distinct on (e.machine_id) e.id, e.machine_id
  from public.telemetry_sales_events e
  where e.provider = 'IMA-recovery' and e.source_event_key like 'recovery-20260801-%'
    and e.cashless_quantity > 0
  order by e.machine_id, e.id desc
), cash_fix as (
  update public.telemetry_sales_events e
  set cash_amount_czk = e.cash_amount_czk + (t.cash_amount_czk - x.cash_amount),
      total_amount_czk = e.total_amount_czk + (t.cash_amount_czk - x.cash_amount)
  from cash_last l
  join totals x using (machine_id)
  join tmp_recovery_payment_targets t using (machine_id)
  where e.id = l.id and t.cash_qty > 0
  returning e.id
)
update public.telemetry_sales_events e
set cashless_amount_czk = e.cashless_amount_czk + (t.card_amount_czk - x.card_amount),
    total_amount_czk = e.total_amount_czk + (t.card_amount_czk - x.card_amount)
from card_last l
join totals x using (machine_id)
join tmp_recovery_payment_targets t using (machine_id)
where e.id = l.id and t.card_qty > 0;

commit;

select sum(quantity) as quantity,
       sum(cash_quantity) as cash_quantity,
       sum(cashless_quantity) as card_quantity,
       sum(unknown_payment_quantity) as unknown_quantity,
       sum(cash_amount_czk) as cash_amount_czk,
       sum(cashless_amount_czk) as card_amount_czk,
       sum(unknown_payment_amount_czk) as unknown_amount_czk
from public.telemetry_sales_events
where provider = 'IMA-recovery' and source_event_key like 'recovery-20260801-%';
