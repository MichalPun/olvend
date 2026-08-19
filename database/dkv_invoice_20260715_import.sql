begin;

-- DKV invoice 26/653205665/001 issued 2026-07-15.
-- User-confirmed mapping:
-- MANAGEMENT 1 diesel = Renault Kangoo 2TX7928; petrol ignored.
-- OPERATOR 1 = Fiat Doblo 5AP9000.
-- OPERATOR 2 = Opel Vivaro 3BJ1780.
-- SERVIS 1 transaction dated 2026-06-19 = Opel Movano 2BN7419 (confirmed after odometer comparison).
-- SERVIS 2 = Opel Movano 2BN7419.
-- JEDNATEL 1-3 ignored.
-- Imported fleet fuel: 655.98 l / 22,737.63 CZK gross.
-- SERVIS 1 card odometer 145907 aligns with the corrected Opel Movano odometer sequence.

update public.vehicle_operation_logs
set fuel_liters = 52.27,
    fuel_cost = 1916.33,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 MANAGEMENT 1 Renault Kangoo 2TX7928 EuroOil Vojkovice diesel tx 97159')
    end,
    status = 'review'
where id = 110;

update public.vehicle_operation_logs
set fuel_liters = 45.96,
    fuel_cost = 1522.62,
    fuel_odometer_km = 297536,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno-Venkov tx 573659') end,
    status = 'review'
where id = 134;

update public.vehicle_operation_logs
set fuel_liters = 42.42,
    fuel_cost = 1405.29,
    fuel_odometer_km = 298106,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 576452') end,
    status = 'review'
where id = 137;

update public.vehicle_operation_logs
set fuel_liters = 36.96,
    fuel_cost = 1247.13,
    fuel_odometer_km = 298628,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 588374') end,
    status = 'review'
where id = 149;

update public.vehicle_operation_logs
set fuel_liters = 40.30,
    fuel_cost = 1359.85,
    fuel_odometer_km = 299132,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 590933') end,
    status = 'review'
where id = 152;

update public.vehicle_operation_logs
set fuel_liters = 51.85,
    fuel_cost = 1855.47,
    fuel_odometer_km = 299907,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno-Venkov tx 603758') end,
    status = 'review'
where id = 166;

update public.vehicle_operation_logs
set fuel_liters = 67.51,
    fuel_cost = 2277.91,
    fuel_odometer_km = 137354,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brest tx 580171') end,
    status = 'review'
where id = 140;

update public.vehicle_operation_logs
set fuel_liters = 61.42,
    fuel_cost = 2072.44,
    fuel_odometer_km = 138202,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Studenka tx 586985') end,
    status = 'review'
where id = 146;

update public.vehicle_operation_logs
set fuel_liters = 61.93,
    fuel_cost = 2152.92,
    fuel_odometer_km = 138994,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 598696') end,
    status = 'review'
where id = 160;

update public.vehicle_operation_logs
set fuel_liters = 63.20,
    fuel_cost = 2261.60,
    fuel_odometer_km = 139748,
    fuel_note = case when coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/653205665/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Studenka tx 602536') end,
    status = 'review'
where id = 164;

insert into public.vehicle_operation_logs
  (vehicle_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  4, '2026-06-19', 81.46, 2986.48, 145907,
  'DKV 26/653205665/001 SERVIS 1 Opel Movano 2BN7419 EuroOil Vojkovice tx 97104',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 4
    and log_date = '2026-06-19'
    and coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%SERVIS 1%'
);

insert into public.vehicle_operation_logs
  (vehicle_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  4, '2026-07-01', 50.70, 1679.59, null,
  'DKV 26/653205665/001 SERVIS 2 Opel Movano 2BN7419 ONO Brno-Venkov tx 574476',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 4
    and log_date = '2026-07-01'
    and coalesce(fuel_note, '') ilike '%DKV 26/653205665/001%SERVIS 2%'
);

commit;
