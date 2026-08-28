begin;

with target as (
  select
    locations.id as location_id,
    case
      when locations.city in (
        'Bohumín', 'Bruntál', 'Ostrava', 'Otice',
        'Slezská Ostrava-Hrušov', 'Slezská Ostrava-Kunčice'
      ) then '7f724803-eb2e-44fc-afba-0b87b82cdbc5'::uuid
      when locations.city in (
        'Blansko', 'Brno', 'Brno - Černovice', 'Brno - Slatina',
        'Brno-Maloměřice a Obřany', 'Jamné', 'Jihlava', 'Luhačovice',
        'Modřice', 'Osíčko-Chvalčov', 'Otrokovice', 'Podolí u Brna',
        'Rosice', 'Slavičín', 'Tišnov', 'Turovice',
        'Valašské Meziříčí', 'Velké Meziříčí'
      ) then '9133f82b-89a6-4581-955c-d2138b947a8d'::uuid
      when locations.city in (
        'Blučina', 'Břeclav', 'Dubňany', 'Hodonín',
        'Hrušovany nad Jevišovkou', 'Hustopeče u Brna', 'Kyjov',
        'Milovice', 'Mutěnice', 'Opatovice', 'Pohořelice', 'Židlochovice'
      ) then 'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid
      else null::uuid
    end as employee_id
  from public.locations locations
  where locations.active is true
    and locations.name not ilike '[TEST]%'
), saved as (
  insert into public.operator_territory_assignments (
    location_id, primary_employee_id, backup_employee_id, assignment_scope,
    selected_machine_ids, effective_from, locked, note, updated_at
  )
  select
    target.location_id,
    target.employee_id,
    null,
    'location',
    '{}',
    date '2026-08-31',
    true,
    'Prvotní rozdělení tří operátorů od 31. 8. 2026.',
    now()
  from target
  where target.employee_id is not null
  on conflict (location_id) do update set
    primary_employee_id = excluded.primary_employee_id,
    backup_employee_id = case
      when operator_territory_assignments.backup_employee_id = excluded.primary_employee_id
        then null
      else operator_territory_assignments.backup_employee_id
    end,
    assignment_scope = 'location',
    selected_machine_ids = '{}',
    effective_from = excluded.effective_from,
    locked = true,
    note = excluded.note,
    updated_at = now()
  returning *
)
insert into public.operator_territory_assignment_history (
  location_id, primary_employee_id, backup_employee_id, assignment_scope,
  selected_machine_ids, effective_from, note
)
select
  saved.location_id,
  saved.primary_employee_id,
  saved.backup_employee_id,
  saved.assignment_scope,
  saved.selected_machine_ids,
  saved.effective_from,
  saved.note
from saved;

commit;
