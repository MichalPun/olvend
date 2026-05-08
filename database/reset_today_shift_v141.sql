-- OLVEND 1.41
-- Reset dnešní směny pro jednoho zaměstnance včetně navázané nakládky, tankování a pohybů.
-- Uprav jen target_employee_email a případně target_date.

do $$
declare
  target_employee_email text := 'DOPLN_EMAIL_ZAMESTNANCE';
  target_date date := current_date;
begin
  if target_employee_email = 'DOPLN_EMAIL_ZAMESTNANCE' then
    raise exception 'Nejdřív doplň target_employee_email v reset_today_shift_v141.sql';
  end if;

  create temporary table tmp_reset_employee on commit drop as
  select id
  from public.employees
  where lower(email) = lower(target_employee_email)
  limit 1;

  if not exists (select 1 from tmp_reset_employee) then
    raise exception 'Zaměstnanec s emailem % nebyl nalezen.', target_employee_email;
  end if;

  create temporary table tmp_reset_days on commit drop as
  select d.id, d.vehicle_id
  from public.attendance_days d
  join tmp_reset_employee e on e.id = d.employee_id
  where d.attendance_date = target_date;

  if not exists (select 1 from tmp_reset_days) then
    raise notice 'Pro % a datum % nebyla nalezena žádná směna.', target_employee_email, target_date;
    return;
  end if;

  create temporary table tmp_reset_sessions on commit drop as
  select ls.id
  from public.loading_sessions ls
  where ls.attendance_day_id in (select id from tmp_reset_days);

  create temporary table tmp_reset_movements on commit drop as
  select
    sm.id,
    sm.product_id,
    sm.batch_id,
    sm.from_stock_location_id,
    sm.to_stock_location_id,
    sm.quantity_base_units
  from public.stock_movements_v13 sm
  where sm.reference_type = 'loading_session'
    and sm.reference_id in (select id::text from tmp_reset_sessions);

  update public.stock_location_balances bal
  set quantity_on_hand = round((coalesce(bal.quantity_on_hand, 0) - mov.quantity_base_units)::numeric, 3),
      updated_at = now()
  from tmp_reset_movements mov
  where mov.to_stock_location_id is not null
    and bal.stock_location_id = mov.to_stock_location_id
    and bal.product_id = mov.product_id
    and bal.batch_id is not distinct from mov.batch_id;

  update public.stock_location_balances bal
  set quantity_on_hand = round((coalesce(bal.quantity_on_hand, 0) + mov.quantity_base_units)::numeric, 3),
      updated_at = now()
  from tmp_reset_movements mov
  where mov.from_stock_location_id is not null
    and bal.stock_location_id = mov.from_stock_location_id
    and bal.product_id = mov.product_id
    and bal.batch_id is not distinct from mov.batch_id;

  delete from public.stock_location_balances
  where quantity_on_hand = 0
    and coalesce(reserved_quantity, 0) = 0;

  delete from public.stock_movements_v13
  where id in (select id from tmp_reset_movements);

  delete from public.loading_sessions
  where id in (select id from tmp_reset_sessions);

  delete from public.pick_list_drafts
  where attendance_day_id in (select id from tmp_reset_days);

  delete from public.employee_location_logs
  where attendance_day_id in (select id from tmp_reset_days);

  delete from public.vehicle_operation_logs
  where attendance_day_id in (select id from tmp_reset_days);

  delete from public.attendance_days
  where id in (select id from tmp_reset_days);

  raise notice 'Dnešní směna pro % byla resetována.', target_employee_email;
end $$;
