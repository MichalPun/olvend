begin;

-- DKV card SERVIS 2 follows the 88xxx-93xxx odometer sequence of Opel Combo 7Z71808.
-- DKV card SERVIS 1 follows the 145xxx-148xxx sequence of Opel Movano 2BN7419.
-- Repair historical SERVIS 2 rows that were imported before both sequences were known.

update public.vehicle_operation_logs
set vehicle_id = 5,
    fuel_note = replace(fuel_note, 'Opel Movano 2BN7419', 'Opel Combo 7Z71808')
where id in (93, 111, 112, 239)
  and vehicle_id = 4
  and fuel_note ilike '%DKV%SERVIS 2%';

update public.vehicle_expenses
set vehicle_id = 5,
    note = replace(note, 'Opel Movano 2BN7419', 'Opel Combo 7Z71808')
where id in (4, 5)
  and vehicle_id = 4
  and note ilike '%DKV%SERVIS 2%';

commit;
