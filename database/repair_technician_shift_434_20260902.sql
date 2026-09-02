begin;

do $$
declare
  v_employee_id uuid := 'ba6be55d-1b4c-4c59-a995-274157d61306';
  v_attendance_id bigint := 434;
  v_end timestamptz := '2026-09-01 21:05:31.263063+00';
  v_break_start timestamptz := '2026-09-01 21:03:20.99+00';
  v_break_minutes integer := 2;
begin
  if not exists (
    select 1
    from attendance_days
    where id = v_attendance_id
      and employee_id = v_employee_id
      and attendance_date = date '2026-09-01'
  ) then
    raise exception 'Attendance day 434 no longer matches the verified technician shift';
  end if;

  update attendance_days
  set status = 'closed',
      actual_end = v_end,
      break_minutes = coalesce(break_minutes, 0) + v_break_minutes,
      payable_minutes = greatest(
        0,
        round(extract(epoch from (v_end - actual_start)) / 60)::integer
          - (coalesce(break_minutes, 0) + v_break_minutes)
      ),
      note = concat_ws(
        E'\n',
        nullif(note, ''),
        'Oprava 2. 9. 2026: směna uzavřena podle poslední doložené aktivity technika; původní mobilní aplikace ukončení blokovala.'
      )
  where id = v_attendance_id
    and actual_end is null;

  if not exists (
    select 1 from attendance_events
    where attendance_day_id = v_attendance_id
      and event_type = 'break_end'
      and event_time >= v_break_start
  ) then
    insert into attendance_events (
      attendance_day_id, employee_id, event_type, event_time, note, created_by
    ) values (
      v_attendance_id, v_employee_id, 'break_end', v_end,
      'Pauza uzavřena při opravě směny · 2 min', v_employee_id
    );
  end if;

  if not exists (
    select 1 from attendance_events
    where attendance_day_id = v_attendance_id
      and event_type = 'shift_end'
  ) then
    insert into attendance_events (
      attendance_day_id, employee_id, event_type, event_time, note, created_by
    ) values (
      v_attendance_id, v_employee_id, 'shift_end', v_end,
      'Směna uzavřena opravou po chybě technické aplikace', v_employee_id
    );
  end if;

  update vehicle_operation_logs
  set ended_at = v_end,
      end_odometer_km = coalesce(end_odometer_km, start_odometer_km),
      trip_note = 'Neuskutečněná jízda: vozidlo přiřadila původní mobilní aplikace automaticky bez volby technika.',
      status = 'closed'
  where attendance_day_id = v_attendance_id
    and ended_at is null;

  update attendance_days
  set vehicle_id = null,
      note = replace(
        note,
        'Technik · kombinovaný den · vozidlo 5AP9000',
        'Technik · kombinovaný den · bez vozidla'
      )
  where id = v_attendance_id
    and vehicle_id = 3;

  update vehicle_operation_logs
  set trip_note = 'Neuskutečněná jízda: vozidlo přiřadila původní mobilní aplikace automaticky bez volby technika.'
  where attendance_day_id = v_attendance_id
    and vehicle_id = 3;
end $$;

commit;
