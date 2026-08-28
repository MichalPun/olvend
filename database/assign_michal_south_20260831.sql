begin;

insert into public.operator_territory_assignments (
  location_id, primary_employee_id, backup_employee_id, assignment_scope,
  selected_machine_ids, effective_from, locked, note, updated_at
)
select locations.id,
       'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid,
       current_assignment.primary_employee_id,
       'location',
       '{}',
       date '2026-08-31',
       true,
       'Jižní rajón Michala Punčocháře od 31. 8. 2026.',
       now()
from public.locations locations
left join public.operator_territory_assignments current_assignment
  on current_assignment.location_id = locations.id
where locations.active is distinct from false
  and locations.latitude < 49.05
on conflict (location_id) do update set
  primary_employee_id = excluded.primary_employee_id,
  backup_employee_id = case
    when operator_territory_assignments.primary_employee_id = excluded.primary_employee_id
      then operator_territory_assignments.backup_employee_id
    else operator_territory_assignments.primary_employee_id
  end,
  assignment_scope = 'location',
  selected_machine_ids = '{}',
  effective_from = excluded.effective_from,
  locked = true,
  note = excluded.note,
  updated_at = now();

insert into public.operator_territory_assignment_history (
  location_id, primary_employee_id, backup_employee_id, assignment_scope,
  selected_machine_ids, effective_from, note
)
select location_id, primary_employee_id, backup_employee_id, assignment_scope,
       selected_machine_ids, effective_from, note
from public.operator_territory_assignments
where primary_employee_id = 'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid
  and effective_from = date '2026-08-31'
  and note = 'Jižní rajón Michala Punčocháře od 31. 8. 2026.';

commit;
