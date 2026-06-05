begin;

-- DKV invoice 26/652265207/001 issued 2026-05-31.
-- Ignored cards: JEDNATEL 1, JEDNATEL 2, JEDNATEL 3.
-- Management card is a company Nissan not registered in public.vehicles,
-- so it is imported as budget expense entries instead of vehicle fuel logs.

update public.vehicle_operation_logs
set fuel_liters = 41.93,
    fuel_cost = 1646.14,
    fuel_odometer_km = 290302,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652265207/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652265207/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 474156')
    end,
    status = 'review'
where id = 61;

update public.vehicle_operation_logs
set fuel_liters = 36.88,
    fuel_cost = 1447.83,
    fuel_odometer_km = 290892,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652265207/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652265207/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 482497')
    end,
    status = 'review'
where id = 66;

insert into public.vehicle_operation_logs
  (vehicle_id, employee_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  3,
  '9133f82b-89a6-4581-955c-d2138b947a8d',
  '2026-05-27',
  40.02,
  1530.27,
  291539,
  'DKV 26/652265207/001 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno-Venkov tx 494179',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 3
    and employee_id = '9133f82b-89a6-4581-955c-d2138b947a8d'
    and log_date = '2026-05-27'
    and fuel_odometer_km = 291539
    and abs(coalesce(fuel_cost, 0) - 1530.27) < 0.01
);

insert into public.vehicle_operation_logs
  (vehicle_id, employee_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  2,
  '7f724803-eb2e-44fc-afba-0b87b82cdbc5',
  '2026-04-12',
  44.24,
  2029.10,
  123470,
  'DKV 26/652265207/001 OPERATOR 2 Opel Vivaro 3BJ1780 EuroOil Vojkovice tx 56379 diesel; prior-period line on May invoice',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 2
    and employee_id = '7f724803-eb2e-44fc-afba-0b87b82cdbc5'
    and log_date = '2026-04-12'
    and fuel_odometer_km = 123470
    and abs(coalesce(fuel_cost, 0) - 2029.10) < 0.01
);

update public.vehicle_operation_logs
set fuel_liters = 34.00,
    fuel_cost = 1334.79,
    fuel_odometer_km = 130330,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652265207/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652265207/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 473533')
    end,
    status = 'review'
where id = 60;

update public.vehicle_operation_logs
set fuel_liters = 65.94,
    fuel_cost = 2588.75,
    fuel_odometer_km = 131285,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652265207/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652265207/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 480783')
    end,
    status = 'review'
where id = 65;

insert into public.vehicle_operation_logs
  (vehicle_id, employee_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  2,
  '7f724803-eb2e-44fc-afba-0b87b82cdbc5',
  '2026-05-25',
  34.02,
  1335.60,
  131802,
  'DKV 26/652265207/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 489020',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 2
    and employee_id = '7f724803-eb2e-44fc-afba-0b87b82cdbc5'
    and log_date = '2026-05-25'
    and fuel_odometer_km = 131802
    and abs(coalesce(fuel_cost, 0) - 1335.60) < 0.01
);

update public.vehicle_operation_logs
set fuel_liters = 59.49,
    fuel_cost = 2213.94,
    fuel_odometer_km = 132716,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652265207/001%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652265207/001 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 499472')
    end,
    status = 'review'
where id = 79;

insert into public.vehicle_operation_logs
  (vehicle_id, employee_id, log_date, fuel_liters, fuel_cost, fuel_note, status)
select
  4,
  'ba6be55d-1b4c-4c59-a995-274157d61306',
  '2026-05-27',
  44.59,
  1705.01,
  'DKV 26/652265207/001 SERVIS 2 Lukáš Urbánek Opel Movano 2BN7419 ONO Brno-Venkov tx 494471',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 4
    and employee_id = 'ba6be55d-1b4c-4c59-a995-274157d61306'
    and log_date = '2026-05-27'
    and abs(coalesce(fuel_cost, 0) - 1705.01) < 0.01
);

insert into public.vehicle_expenses
  (vehicle_id, expense_date, category, amount, vendor, note)
select
  2,
  '2026-04-12',
  'fuel_card',
  196.99,
  'DKV / EuroOil Vojkovice',
  'DKV 26/652265207/001 OPERATOR 2 Opel Vivaro 3BJ1780 AdBlue 12.37 l tx 56379; prior-period line on May invoice'
where not exists (
  select 1 from public.vehicle_expenses
  where vehicle_id = 2
    and expense_date = '2026-04-12'
    and category = 'fuel_card'
    and abs(amount - 196.99) < 0.01
    and coalesce(note, '') ilike '%26/652265207/001%'
);

insert into public.vehicle_expenses
  (vehicle_id, expense_date, category, amount, vendor, note)
select
  2,
  '2026-05-29',
  'fuel_card',
  138.04,
  'DKV / ONO Brno',
  'DKV 26/652265207/001 OPERATOR 2 Opel Vivaro 3BJ1780 AdBlue 10.70 l tx 499472'
where not exists (
  select 1 from public.vehicle_expenses
  where vehicle_id = 2
    and expense_date = '2026-05-29'
    and category = 'fuel_card'
    and abs(amount - 138.04) < 0.01
    and coalesce(note, '') ilike '%26/652265207/001%'
);

insert into public.budget_expense_entries
  (expense_date, category_key, description, amount, vat_mode, source, note, created_by)
select
  '2026-05-20',
  'fuel',
  'DKV PHM Management / služební Nissan',
  2160.68,
  'with_vat',
  'import',
  'DKV 26/652265207/001 MANAGEMENT 1 Michal Punčochář služební Nissan ONO Studénka SUPER 52.39 l tx 479889',
  'abad3293-29a0-4668-97c5-0c6fa08ece0f'
where not exists (
  select 1 from public.budget_expense_entries
  where expense_date = '2026-05-20'
    and source = 'import'
    and amount = 2160.68
    and coalesce(note, '') ilike '%26/652265207/001%'
);

insert into public.budget_expense_entries
  (expense_date, category_key, description, amount, vat_mode, source, note, created_by)
select
  '2026-05-27',
  'fuel',
  'DKV PHM Management / služební Nissan',
  1548.51,
  'with_vat',
  'import',
  'DKV 26/652265207/001 MANAGEMENT 1 Michal Punčochář služební Nissan EuroOil Vojkovice SUPER 36.62 l tx 83427',
  'abad3293-29a0-4668-97c5-0c6fa08ece0f'
where not exists (
  select 1 from public.budget_expense_entries
  where expense_date = '2026-05-27'
    and source = 'import'
    and amount = 1548.51
    and coalesce(note, '') ilike '%26/652265207/001%'
);

insert into public.budget_expense_entries
  (expense_date, category_key, description, amount, vat_mode, source, note, created_by)
select
  '2026-05-29',
  'fuel',
  'DKV PHM Management / služební Nissan',
  2171.79,
  'with_vat',
  'import',
  'DKV 26/652265207/001 MANAGEMENT 1 Michal Punčochář služební Nissan EuroOil Bystřice p. SUPER 51.36 l tx 70709',
  'abad3293-29a0-4668-97c5-0c6fa08ece0f'
where not exists (
  select 1 from public.budget_expense_entries
  where expense_date = '2026-05-29'
    and source = 'import'
    and amount = 2171.79
    and coalesce(note, '') ilike '%26/652265207/001%'
);

commit;
