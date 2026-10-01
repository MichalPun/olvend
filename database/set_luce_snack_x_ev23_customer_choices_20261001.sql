-- Nastaví zákaznické volby Luce Snack X EV 23 odděleně od interních prodejních identifikátorů.
-- Číslování jde od spodní řady nahoru: 1A–1I, 2A–2I, …; české CH se nepoužívá.
-- Horní řada má tři dvojité pozice (A–B, C–D, E–F), proto používá 6A, 6C, 6E, 6G, 6H, 6I.

begin;

do $$
declare
  v_machine_id bigint;
  v_updated integer;
  v_active_slots integer;
  v_distinct_choices integer;
begin
  select id
  into strict v_machine_id
  from public.machines
  where evidence_number = 23
    and lower(name) = 'luce snack x';

  with choice_map(slot_code, customer_selection_code) as (
    values
      ('1',  '1A'), ('2',  '1B'), ('3',  '1C'), ('4',  '1D'), ('5',  '1E'),
      ('6',  '1F'), ('7',  '1G'), ('8',  '1H'), ('9',  '1I'),
      ('12', '2A'), ('13', '2B'), ('14', '2C'), ('15', '2D'), ('16', '2E'),
      ('17', '2F'), ('18', '2G'), ('19', '2H'), ('20', '2I'),
      ('23', '3A'), ('24', '3B'), ('25', '3C'), ('26', '3D'), ('27', '3E'),
      ('28', '3F'), ('29', '3G'), ('30', '3H'), ('31', '3I'),
      ('34', '4A'), ('35', '4B'), ('36', '4C'), ('37', '4D'), ('38', '4E'),
      ('39', '4F'), ('40', '4G'), ('41', '4H'), ('42', '4I'),
      ('45', '5A'), ('46', '5B'), ('47', '5C'), ('48', '5D'), ('49', '5E'),
      ('50', '5F'), ('51', '5G'), ('52', '5H'), ('53', '5I'),
      ('57', '6A'), ('59', '6C'), ('61', '6E'), ('62', '6G'), ('63', '6H'), ('64', '6I')
  )
  update public.machine_planogram_slots as slot
  set customer_selection_code = choice.customer_selection_code,
      updated_at = now()
  from choice_map choice
  where slot.machine_id = v_machine_id
    and slot.active is true
    and slot.slot_code = choice.slot_code;

  get diagnostics v_updated = row_count;
  if v_updated <> 51 then
    raise exception 'EV 23: očekáváno 51 upravených aktivních pozic, upraveno %.', v_updated;
  end if;

  select count(*), count(distinct customer_selection_code)
  into v_active_slots, v_distinct_choices
  from public.machine_planogram_slots
  where machine_id = v_machine_id
    and active is true;

  if v_active_slots <> 51 or v_distinct_choices <> 51 then
    raise exception 'EV 23: očekáváno 51 aktivních pozic a 51 unikátních zákaznických voleb, nalezeno % a %.',
      v_active_slots, v_distinct_choices;
  end if;

  if exists (
    select 1
    from public.machine_planogram_slots
    where machine_id = v_machine_id
      and active is true
      and customer_selection_code ~ 'CH'
  ) then
    raise exception 'EV 23: zákaznická volba nesmí obsahovat CH.';
  end if;
end;
$$;

commit;

notify pgrst, 'reload schema';
