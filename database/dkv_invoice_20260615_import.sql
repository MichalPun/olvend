begin;

-- DKV invoice 26/652641267/002 issued 2026-06-15.
-- Ignored cards: JEDNATEL 1, JEDNATEL 2, JEDNATEL 3.
-- Management card is a company Nissan not registered in public.vehicles,
-- so it is imported as a budget expense entry instead of vehicle fuel logs.

update public.vehicle_operation_logs
set fuel_liters = 47.26,
    fuel_cost = 1758.81,
    fuel_odometer_km = 292238,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652641267/002%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652641267/002 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 505270')
    end,
    status = 'review'
where id = 81;

update public.vehicle_operation_logs
set fuel_liters = 51.35,
    fuel_cost = 1858.57,
    fuel_odometer_km = 293032,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652641267/002%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652641267/002 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno-Venkov tx 515497')
    end,
    status = 'review'
where id = 88;

update public.vehicle_operation_logs
set fuel_liters = 42.18,
    fuel_cost = 1526.69,
    fuel_odometer_km = 293682,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652641267/002%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652641267/002 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 526515')
    end,
    status = 'review'
where id = 99;

update public.vehicle_operation_logs
set fuel_liters = 36.71,
    fuel_cost = 1328.68,
    fuel_odometer_km = 294235,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652641267/002%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652641267/002 OPERATOR 1 Fiat Doblo 5AP9000 ONO Brno tx 536497')
    end,
    status = 'review'
where id = 103;

update public.vehicle_operation_logs
set fuel_liters = 38.47,
    fuel_cost = 1431.62,
    fuel_odometer_km = 133213,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652641267/002%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652641267/002 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 504806')
    end,
    status = 'review'
where id = 82;

update public.vehicle_operation_logs
set fuel_liters = 64.29,
    fuel_cost = 2326.87,
    fuel_odometer_km = 134099,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652641267/002%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652641267/002 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 515275')
    end,
    status = 'review'
where id = 89;

update public.vehicle_operation_logs
set fuel_liters = 67.29,
    fuel_cost = 2435.44,
    fuel_odometer_km = 134992,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652641267/002%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652641267/002 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Brno tx 519346')
    end,
    status = 'review'
where id = 95;

update public.vehicle_operation_logs
set fuel_liters = 65.89,
    fuel_cost = 2384.84,
    fuel_odometer_km = 135904,
    fuel_note = case
      when coalesce(fuel_note, '') ilike '%DKV 26/652641267/002%' then fuel_note
      else concat_ws(' | ', nullif(fuel_note, ''), 'DKV 26/652641267/002 OPERATOR 2 Opel Vivaro 3BJ1780 ONO Břešť tx 529856')
    end,
    status = 'review'
where id = 101;

insert into public.vehicle_operation_logs
  (vehicle_id, employee_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  4,
  'ba6be55d-1b4c-4c59-a995-274157d61306',
  '2026-06-01',
  51.01,
  2040.16,
  88850,
  'DKV 26/652641267/002 SERVIS 2 Lukáš Urbánek Opel Movano 2BN7419 EuroOil Vojkovice tx 86537',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 4
    and employee_id = 'ba6be55d-1b4c-4c59-a995-274157d61306'
    and log_date = '2026-06-01'
    and fuel_odometer_km = 88850
    and abs(coalesce(fuel_cost, 0) - 2040.16) < 0.01
);

insert into public.vehicle_operation_logs
  (vehicle_id, employee_id, log_date, fuel_liters, fuel_cost, fuel_odometer_km, fuel_note, status)
select
  4,
  'ba6be55d-1b4c-4c59-a995-274157d61306',
  '2026-06-08',
  49.00,
  1813.39,
  89666,
  'DKV 26/652641267/002 SERVIS 2 Lukáš Urbánek Opel Movano 2BN7419 EuroOil Vojkovice tx 90698',
  'review'
where not exists (
  select 1 from public.vehicle_operation_logs
  where vehicle_id = 4
    and employee_id = 'ba6be55d-1b4c-4c59-a995-274157d61306'
    and log_date = '2026-06-08'
    and fuel_odometer_km = 89666
    and abs(coalesce(fuel_cost, 0) - 1813.39) < 0.01
);

insert into public.vehicle_expenses
  (vehicle_id, expense_date, category, amount, vendor, note)
select
  4,
  '2026-06-08',
  'other',
  125.49,
  'DKV / EuroOil Vojkovice',
  'DKV 26/652641267/002 SERVIS 2 Lukáš Urbánek Opel Movano 2BN7419 příslušenství tx 90698'
where not exists (
  select 1 from public.vehicle_expenses
  where vehicle_id = 4
    and expense_date = '2026-06-08'
    and category = 'other'
    and abs(amount - 125.49) < 0.01
    and coalesce(note, '') ilike '%26/652641267/002%'
);

insert into public.vehicle_expenses
  (vehicle_id, expense_date, category, amount, vendor, note)
select
  4,
  '2026-06-08',
  'fuel_card',
  188.14,
  'DKV / ONO Brno-Venkov',
  'DKV 26/652641267/002 SERVIS 2 Lukáš Urbánek Opel Movano 2BN7419 AdBlue 15.05 l tx 521405'
where not exists (
  select 1 from public.vehicle_expenses
  where vehicle_id = 4
    and expense_date = '2026-06-08'
    and category = 'fuel_card'
    and abs(amount - 188.14) < 0.01
    and coalesce(note, '') ilike '%26/652641267/002%'
);

insert into public.budget_expense_entries
  (expense_date, category_key, description, amount, vat_mode, source, note, created_by)
select
  '2026-06-05',
  'fuel',
  'DKV PHM Management / služební Nissan',
  1666.80,
  'with_vat',
  'import',
  'DKV 26/652641267/002 MANAGEMENT 1 Michal Punčochář služební Nissan EuroOil Vojkovice SUPER 42.89 l tx 89144',
  'abad3293-29a0-4668-97c5-0c6fa08ece0f'
where not exists (
  select 1 from public.budget_expense_entries
  where expense_date = '2026-06-05'
    and source = 'import'
    and amount = 1666.80
    and coalesce(note, '') ilike '%26/652641267/002%'
);

commit;
