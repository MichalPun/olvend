-- Odstranění pouze prokazatelných historických expirací převzatých
-- z VendSoft plánogramů 2026-07-30.
--
-- Bezpečnost:
-- - kandidát musí mít stále přesně datum z původního importu,
-- - samostatně fyzicky potvrzené datum se zachová,
-- - při fyzickém doplnění se starý import nahradí nejbližší doloženou
--   expirací vložené šarže,
-- - skladové šarže, inventura #24 ani historie návštěv se nemění,
-- - každý změněný řádek se předem zálohuje.

begin;

lock table public.machine_planogram_slots in share row exclusive mode;

create table if not exists public.planogram_expiry_cleanup_backup_20260802 (
  slot_id bigint primary key,
  machine_id bigint not null,
  evidence_number bigint,
  slot_code text not null,
  product_sku text,
  product_name text,
  old_expiry_date date not null,
  new_expiry_date date,
  cleanup_action text not null
    check (cleanup_action in ('clear_legacy_import', 'replace_with_physical_fill')),
  backed_up_at timestamptz not null default now()
);

alter table public.planogram_expiry_cleanup_backup_20260802 enable row level security;

comment on table public.planogram_expiry_cleanup_backup_20260802 is
  'Vratná záloha expirací plánogramů odstraněných 2026-08-02 jako prokazatelné hodnoty z historického VendSoft importu.';

create temporary table legacy_vendsoft_expiries_20260802 (
  evidence_number bigint not null,
  slot_code text not null,
  legacy_expiry date not null,
  primary key (evidence_number, slot_code)
) on commit drop;

insert into legacy_vendsoft_expiries_20260802 (
  evidence_number,
  slot_code,
  legacy_expiry
)
values
    (100, '41', '2026-08-04'::date),
    (100, '42', '2026-08-04'::date),
    (100, '43', '2026-08-06'::date),
    (100, '44', '2026-02-05'::date),
    (100, '45', '2026-02-05'::date),
    (100, '48', '2026-08-06'::date),
    (78, '40', '2026-08-04'::date),
    (78, '41', '2026-08-06'::date),
    (78, '42', '2026-08-06'::date),
    (78, '43', '2026-02-19'::date),
    (78, '44', '2026-02-24'::date),
    (78, '45', '2026-02-24'::date),
    (78, '47', '2026-08-06'::date),
    (78, '48', '2026-08-06'::date),
    (78, '49', '2026-08-06'::date),
    (1, '23', '2026-08-06'::date),
    (1, '24', '2026-08-06'::date),
    (1, '25', '2026-08-06'::date),
    (1, '26', '2026-02-24'::date),
    (1, '27', '2025-08-20'::date),
    (3, '23', '2026-08-04'::date),
    (3, '24', '2026-08-03'::date),
    (3, '25', '2026-08-04'::date),
    (6, '23', '2026-08-04'::date),
    (6, '24', '2026-08-04'::date),
    (6, '25', '2026-08-04'::date),
    (72, '23', '2026-08-06'::date),
    (72, '24', '2026-08-06'::date),
    (72, '25', '2026-08-06'::date),
    (72, '26', '2025-08-17'::date),
    (72, '27', '2025-08-17'::date),
    (74, '23', '2026-07-30'::date),
    (74, '24', '2026-07-30'::date),
    (74, '25', '2026-07-30'::date),
    (74, '26', '2026-05-05'::date),
    (74, '27', '2026-05-05'::date),
    (7, '23', '2026-08-04'::date),
    (7, '24', '2026-08-04'::date),
    (7, '25', '2026-08-04'::date),
    (7, '26', '2025-12-23'::date),
    (7, '27', '2025-12-23'::date),
    (82, '23', '2026-04-07'::date),
    (82, '24', '2026-04-07'::date),
    (82, '25', '2026-04-07'::date),
    (83, '23', '2026-07-30'::date),
    (83, '24', '2026-06-02'::date),
    (83, '25', '2026-07-30'::date),
    (84, '23', '2026-08-04'::date),
    (84, '24', '2026-08-06'::date),
    (84, '25', '2026-07-30'::date),
    (84, '26', '2025-08-17'::date),
    (9, '23', '2026-08-04'::date),
    (9, '24', '2026-08-04'::date),
    (9, '25', '2026-08-04'::date),
    (9, '26', '2025-08-20'::date),
    (9, '27', '2025-08-20'::date),
    (12, '31', '2026-08-04'::date),
    (12, '32', '2026-08-04'::date),
    (12, '33', '2026-08-06'::date),
    (12, '34', '2025-08-20'::date),
    (65, '31', '2026-08-04'::date),
    (65, '32', '2026-08-06'::date),
    (65, '33', '2026-08-06'::date),
    (65, '34', '2026-02-24'::date),
    (65, '35', '2026-01-13'::date),
    (65, '36', '2026-02-24'::date),
    (65, '37', '2025-08-20'::date),
    (65, '38', '2025-08-24'::date),
    (65, '39', '2025-08-20'::date),
    (65, '40', '2026-08-01'::date),
    (71, '31', '2026-06-16'::date),
    (71, '32', '2026-06-20'::date),
    (71, '33', '2026-06-20'::date),
    (71, '34', '2026-01-06'::date),
    (71, '35', '2026-01-13'::date),
    (71, '36', '2026-01-06'::date),
    (71, '37', '2025-08-21'::date),
    (71, '38', '2026-02-21'::date),
    (71, '39', '2026-02-19'::date),
    (71, '40', '2026-02-19'::date),
    (71, '42', '2025-08-24'::date),
    (71, '43', '2025-08-21'::date),
    (71, '44', '2025-08-20'::date),
    (79, '40', '2026-08-06'::date),
    (79, '41', '2026-08-06'::date),
    (79, '42', '2026-08-06'::date),
    (79, '43', '2026-08-06'::date),
    (79, '48', '2026-08-06'::date),
    (79, '49', '2026-08-06'::date),
    (94, '41', '2026-07-09'::date),
    (94, '42', '2026-07-09'::date),
    (94, '43', '2026-07-09'::date),
    (94, '44', '2026-07-01'::date),
    (94, '45', '2026-02-21'::date),
    (94, '46', '2026-02-21'::date),
    (23, '23', '2026-08-06'::date),
    (23, '24', '2026-08-06'::date),
    (23, '25', '2026-08-06'::date),
    (23, '26', '2026-08-06'::date),
    (23, '27', '2026-08-06'::date),
    (90, '40', '2025-09-13'::date),
    (90, '41', '2026-08-06'::date),
    (90, '42', '2026-08-04'::date),
    (90, '43', '2026-08-06'::date),
    (90, '44', '2026-08-06'::date),
    (90, '45', '2026-08-06'::date),
    (90, '46', '2026-08-04'::date),
    (90, '47', '2026-07-30'::date),
    (90, '48', '2026-08-06'::date);

create temporary table planogram_expiry_cleanup_candidates_20260802
on commit drop
as
with matched as (
  select
    s.id as slot_id,
    s.machine_id,
    m.evidence_number,
    s.slot_code,
    s.product_sku,
    s.product_name,
    s.expiry_date as old_expiry_date,
    (
      select min(f.expiry_date)
      from public.route_machine_visit_food_fills f
      where f.planogram_slot_id = s.id
        and f.expiry_date is not null
    ) as physical_fill_expiry,
    exists (
      select 1
      from public.route_machine_visit_food_fills f
      where f.planogram_slot_id = s.id
        and f.expiry_date = s.expiry_date
    ) as current_expiry_confirmed_by_fill,
    exists (
      select 1
      from public.route_machine_visit_items i
      where i.planogram_slot_id = s.id
        and i.accepted_at is not null
        and coalesce(i.operator_note, '') <>
          'Hromadně potvrzeno: stav pozice sedí, bez doplnění.'
    ) as has_individual_physical_confirmation
  from legacy_vendsoft_expiries_20260802 legacy
  join public.machines m
    on m.evidence_number = legacy.evidence_number
  join public.machine_planogram_slots s
    on s.machine_id = m.id
   and s.slot_code = legacy.slot_code
   and s.expiry_date = legacy.legacy_expiry
)
select
  slot_id,
  machine_id,
  evidence_number,
  slot_code,
  product_sku,
  product_name,
  old_expiry_date,
  case
    when physical_fill_expiry is not null
      and not current_expiry_confirmed_by_fill
      then physical_fill_expiry
    else null
  end as new_expiry_date,
  case
    when physical_fill_expiry is not null
      and not current_expiry_confirmed_by_fill
      then 'replace_with_physical_fill'
    else 'clear_legacy_import'
  end as cleanup_action
from matched
where
  (
    physical_fill_expiry is not null
    and not current_expiry_confirmed_by_fill
  )
  or (
    physical_fill_expiry is null
    and not has_individual_physical_confirmation
  );

do $$
declare
  v_total integer;
  v_clear integer;
  v_replace integer;
  v_changed integer;
  v_existing_backup integer;
begin
  select
    count(*),
    count(*) filter (where cleanup_action = 'clear_legacy_import'),
    count(*) filter (where cleanup_action = 'replace_with_physical_fill')
  into v_total, v_clear, v_replace
  from planogram_expiry_cleanup_candidates_20260802;

  select count(*)
  into v_existing_backup
  from public.planogram_expiry_cleanup_backup_20260802;

  if v_total = 0 and v_existing_backup = 80 then
    raise notice 'Čištění VendSoft expirací už bylo provedeno; beze změny.';
    return;
  end if;

  if v_total <> 80 or v_clear <> 74 or v_replace <> 6 then
    raise exception
      'Bezpečnostní kontrola zastavila čištění: očekáváno 80 (74 smazat, 6 nahradit), nalezeno % (% smazat, % nahradit).',
      v_total, v_clear, v_replace;
  end if;

  if v_existing_backup <> 0 then
    raise exception
      'Záložní tabulka už obsahuje % neočekávaných řádků.',
      v_existing_backup;
  end if;

  insert into public.planogram_expiry_cleanup_backup_20260802 (
    slot_id,
    machine_id,
    evidence_number,
    slot_code,
    product_sku,
    product_name,
    old_expiry_date,
    new_expiry_date,
    cleanup_action
  )
  select
    slot_id,
    machine_id,
    evidence_number,
    slot_code,
    product_sku,
    product_name,
    old_expiry_date,
    new_expiry_date,
    cleanup_action
  from planogram_expiry_cleanup_candidates_20260802;

  update public.machine_planogram_slots s
  set
    expiry_date = candidate.new_expiry_date,
    updated_at = now()
  from planogram_expiry_cleanup_candidates_20260802 candidate
  where s.id = candidate.slot_id
    and s.expiry_date = candidate.old_expiry_date;

  get diagnostics v_changed = row_count;

  if v_changed <> 80 then
    raise exception
      'Bezpečnostní kontrola zastavila čištění: očekáváno změnit 80 řádků, změněno %.',
      v_changed;
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
