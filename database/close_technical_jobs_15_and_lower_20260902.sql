begin;

do $$
declare
  v_employee_id uuid := 'ba6be55d-1b4c-4c59-a995-274157d61306';
  v_now timestamptz := now();
begin
  if exists (
    select 1
    from technical_jobs
    where id in (2, 3, 8, 13, 15)
      and assigned_employee_id is distinct from v_employee_id
  ) then
    raise exception 'One of the verified technical jobs is no longer assigned to the expected technician';
  end if;

  update technical_jobs
  set status = 'closed',
      finished_at = coalesce(finished_at, v_now),
      submitted_at = coalesce(submitted_at, v_now),
      result = coalesce(
        nullif(result, ''),
        'Dokončeno · potvrzeno vedoucím 2. 9. 2026'
      )
  where id in (2, 3, 8, 13, 15)
    and assigned_employee_id = v_employee_id
    and status <> 'closed';
end $$;

commit;
