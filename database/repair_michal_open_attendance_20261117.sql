begin;

do $$
declare
  v_employee constant uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_end_603 constant timestamptz := '2026-11-05 20:21:29.871127+00';
  v_end_608 constant timestamptz := '2026-11-07 08:03:18.307+00';
  v_end_610 constant timestamptz := '2026-11-09 07:52:39.828+00';
  v_end_621 constant timestamptz := '2026-11-12 13:04:07.386+00';
begin
  if (
    select count(*)
    from public.attendance_days
    where id in (603, 608, 610, 621)
      and employee_id = v_employee
      and status = 'open'
      and actual_start is not null
      and actual_end is null
  ) <> 4 then
    raise exception 'Očekávané čtyři otevřené směny Michala nebyly nalezeny ve výchozím stavu.';
  end if;

  update public.attendance_days
  set
    status = 'closed',
    actual_end = case id
      when 603 then v_end_603
      when 608 then v_end_608
      when 610 then v_end_610
      when 621 then v_end_621
    end,
    payable_minutes = case id
      when 603 then greatest(0, round(extract(epoch from (v_end_603 - actual_start)) / 60)::integer - coalesce(break_minutes, 0))
      when 608 then 0
      when 610 then greatest(0, round(extract(epoch from (v_end_610 - actual_start)) / 60)::integer - coalesce(break_minutes, 0))
      when 621 then greatest(0, round(extract(epoch from (v_end_621 - actual_start)) / 60)::integer - coalesce(break_minutes, 0))
    end,
    note = concat_ws(' | ', nullif(note, ''), 'Administrativně uzavřeno 17. 11. 2026 podle uloženého dokončení trasy; směna 608 je testovací záznam s nulovou dobou.')
  where id in (603, 608, 610, 621)
    and employee_id = v_employee;

  update public.vehicle_operation_logs
  set
    status = 'closed',
    ended_at = case attendance_day_id
      when 603 then v_end_603
      when 608 then v_end_608
      when 610 then v_end_610
      when 621 then v_end_621
    end
  where attendance_day_id in (603, 608, 610, 621)
    and employee_id = v_employee
    and ended_at is null;

  insert into public.attendance_events (
    attendance_day_id,
    employee_id,
    event_type,
    event_time,
    note,
    created_by
  )
  select
    repair.attendance_day_id,
    v_employee,
    'shift_end',
    repair.ended_at,
    'Administrativní uzavření podle dokončení trasy; směna 608 uzavřena jako testovací záznam.',
    v_employee
  from (values
    (603::bigint, v_end_603),
    (608::bigint, v_end_608),
    (610::bigint, v_end_610),
    (621::bigint, v_end_621)
  ) as repair(attendance_day_id, ended_at)
  where not exists (
    select 1
    from public.attendance_events existing
    where existing.attendance_day_id = repair.attendance_day_id
      and existing.event_type = 'shift_end'
      and existing.event_time = repair.ended_at
  );

  if exists (
    select 1
    from public.attendance_days
    where id in (603, 608, 610, 621)
      and (status <> 'closed' or actual_end is null or payable_minutes < 0)
  ) then
    raise exception 'Kontrola po opravě docházky selhala.';
  end if;
end $$;

commit;

select id, attendance_date, status, actual_start, actual_end, break_minutes, payable_minutes
from public.attendance_days
where id in (603, 608, 610, 621)
order by id;
