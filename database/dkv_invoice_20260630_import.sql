begin;

-- DKV invoice 26/652992510/001 issued 2026-06-30.
-- Ignored cards: JEDNATEL 1, JEDNATEL 2, JEDNATEL 3 and all other cards not listed by the user.
-- Current mapping:
-- MANAGEMENT 1 = Renault Kangoo
-- OPERATOR 1 = Fiat Doblo
-- OPERATOR 2 = Opel Vivaro

update public.vehicle_operation_logs
set fuel_liters = 56.86,
    fuel_cost = 1911.99,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652992510/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652992510/001 MANAGEMENT 1 Renault Kangoo 2TX7928 EuroOil Křenovice tx 148059')
    end,
    status = 'review'
where id = 121;

insert into public.vehicle_expenses
  (vehicle_id, expense_date, category, amount, vendor, note)
select
  1,
  '2026-06-28',
  'fuel_card',
  243.32,
  'DKV / EuroOil Vojkovice',
  'DKV 26/652992510/001 MANAGEMENT 1 Renault Kangoo 2TX7928 AdBlue 15.28 l tx 103021'
where not exists (
  select 1 from public.vehicle_expenses
  where vehicle_id = 1
    and expense_date = '2026-06-28'
    and category = 'fuel_card'
    and abs(amount - 243.32) < 0.01
    and coalesce(note, '') ilike '%26/652992510/001%'
);

update public.vehicle_operation_logs
set fuel_liters = 40.54,
    fuel_cost = 1425.82,
    fuel_odometer_km = 294842,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652992510/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652992510/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 541953; invoice date 2026-06-17')
    end,
    status = 'review'
where id = 108;

update public.vehicle_operation_logs
set fuel_liters = 33.28,
    fuel_cost = 1136.53,
    fuel_odometer_km = 295335,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652992510/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652992510/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 547156')
    end,
    status = 'review'
where id = 109;

update public.vehicle_operation_logs
set fuel_liters = 37.03,
    fuel_cost = 1264.57,
    fuel_odometer_km = 295824,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652992510/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652992510/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 552662')
    end,
    status = 'review'
where id = 115;

update public.vehicle_operation_logs
set fuel_liters = 32.37,
    fuel_cost = 1105.40,
    fuel_odometer_km = 296272,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652992510/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652992510/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno-Venkov tx 557594')
    end,
    status = 'review'
where id = 119;

update public.vehicle_operation_logs
set fuel_liters = 37.81,
    fuel_cost = 1252.56,
    fuel_odometer_km = 296774,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652992510/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652992510/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno-Venkov tx 563012')
    end,
    status = 'review'
where id = 124;

update public.vehicle_operation_logs
set fuel_liters = 11.15,
    fuel_cost = 393.64,
    fuel_odometer_km = 297507,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652992510/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652992510/001 OPERATOR 1 Fiat Doblo 5AP9000 ORLEN Pohořelice tx 13')
    end,
    status = 'review'
where id = 130;

update public.vehicle_operation_logs
set fuel_liters = 48.59,
    fuel_cost = 1609.70,
    fuel_odometer_km = 136488,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652992510/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652992510/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 571329')
    end,
    status = 'review'
where id = 132;

insert into public.vehicle_expenses
  (vehicle_id, expense_date, category, amount, vendor, note)
select
  2,
  '2026-06-30',
  'fuel_card',
  130.52,
  'DKV / ONO Brno',
  'DKV 26/652992510/001 OPERATOR 2 Opel Vivaro 3BJ1780 AdBlue 10.44 l tx 571329'
where not exists (
  select 1 from public.vehicle_expenses
  where vehicle_id = 2
    and expense_date = '2026-06-30'
    and category = 'fuel_card'
    and abs(amount - 130.52) < 0.01
    and coalesce(note, '') ilike '%26/652992510/001%'
);

commit;
