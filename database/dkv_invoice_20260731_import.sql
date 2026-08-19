begin;

-- DKV invoice 26/653689759/001 issued 2026-07-31.
-- Mapping confirmed from odometer sequences:
-- MANAGEMENT 1 diesel = Renault Kangoo 2TX7928; petrol ignored.
-- OPERATOR 1 = Fiat Doblo 5AP9000.
-- OPERATOR 2 = Opel Vivaro 3BJ1780.
-- SERVIS 1 = Opel Movano 2BN7419.
-- SERVIS 2 = Opel Combo 7Z71808.
-- JEDNATEL 1-3 ignored.
-- Imported fleet diesel: 707.06 l / 29,092.13 CZK gross.
-- Imported vehicle AdBlue: 11.92 l / 141.84 CZK gross.

insert into public.vehicle_operation_logs
  (vehicle_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  1, '2026-07-31', 58.66, 2690.82, null,
  'DKV 26/653689759/001 MANAGEMENT 1 Renault Kangoo 2TX7928 Shell Hustopece diesel tx 1',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 1
    and log_date = '2026-07-31'
    and coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%MANAGEMENT 1%'
);

update public.vehicle_operation_logs
set fuel_liters = 40.64, fuel_cost = 1470.94, fuel_odometer_km = 300427,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 606649') end,
    status = 'review'
where id = 168;

update public.vehicle_operation_logs
set fuel_liters = 39.32, fuel_cost = 1487.40, fuel_odometer_km = 300949,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno-Venkov tx 614158') end,
    status = 'review'
where id = 172;

update public.vehicle_operation_logs
set fuel_liters = 54.20, fuel_cost = 2271.79, fuel_odometer_km = 301703,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 620696') end,
    status = 'review'
where id = 179;

update public.vehicle_operation_logs
set fuel_liters = 45.11, fuel_cost = 1936.90, fuel_odometer_km = 302366,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 628936') end,
    status = 'review'
where id = 187;

update public.vehicle_operation_logs
set fuel_liters = 44.93, fuel_cost = 1929.12, fuel_odometer_km = 303000,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brest tx 634865') end,
    status = 'review'
where id = 193;

update public.vehicle_operation_logs
set fuel_liters = 61.40, fuel_cost = 2322.64, fuel_odometer_km = 140624,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 614418') end,
    status = 'review'
where id = 174;

insert into public.vehicle_expenses
  (vehicle_id, expense_date, category, amount, vendor, note)
select
  2, '2026-07-20', 'fuel_card', 141.84, 'DKV / ONO Brno',
  'DKV 26/653689759/001 OPERATOR 2 Opel Vivaro 3BJ1780 AdBlue 11.92 l tx 614418'
where not exists (
  select 1 from public.vehicle_expenses
  where vehicle_id = 2
    and expense_date = '2026-07-20'
    and abs(amount - 141.84) < 0.01
    and coalesce(note, '') ilike '%DKV 26/653689759/001%'
);

insert into public.vehicle_operation_logs
  (vehicle_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  2, '2026-07-23', 5.89, 236.16, 141533,
  'DKV 26/653689759/001 OPERATOR 2 Opel Vivaro 3BJ1780 EuroOil Vojkovice tx 118448',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 2
    and log_date = '2026-07-23'
    and fuel_odometer_km = 141533
    and coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%'
);

update public.vehicle_operation_logs
set fuel_liters = 66.00, fuel_cost = 2766.39, fuel_odometer_km = 141550,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno-Venkov tx 623898') end,
    status = 'review'
where id = 183;

update public.vehicle_operation_logs
set fuel_liters = 68.08, fuel_cost = 2923.12, fuel_odometer_km = 142466,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brest tx 629388') end,
    status = 'review'
where id = 188;

update public.vehicle_operation_logs
set fuel_liters = 70.47, fuel_cost = 3054.55, fuel_odometer_km = 143415,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Studenka tx 638832') end,
    status = 'review'
where id = 200;

insert into public.vehicle_operation_logs
  (vehicle_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  4, '2026-07-17', 67.50, 2635.13, 146670,
  'DKV 26/653689759/001 SERVIS 1 Opel Movano 2BN7419 EuroOil Vojkovice tx 114477',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 4
    and log_date = '2026-07-17'
    and fuel_odometer_km = 146670
    and coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%'
);

update public.vehicle_operation_logs
set fuel_liters = 40.99, fuel_cost = 1483.53, fuel_odometer_km = 92903,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 SERVIS 2 Opel Combo 7Z71808 ONO Brno-Venkov tx 606349; invoice date 2026-07-16') end,
    status = 'review'
where id = 171;

update public.vehicle_operation_logs
set fuel_liters = 43.87, fuel_cost = 1883.64, fuel_odometer_km = 93488,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653689759/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653689759/001 SERVIS 2 Opel Combo 7Z71808 ONO Brno-Venkov tx 630822') end,
    status = 'review'
where id = 190;

commit;
