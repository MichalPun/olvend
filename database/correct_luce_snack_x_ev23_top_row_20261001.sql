-- Oprava EV 23: šestá řada má jen čtyři položky s volbami 6B, 6D, 6F a 6H.

begin;

do $$
declare
  v_machine_id bigint;
  v_active_slots integer;
  v_distinct_choices integer;
begin
  select id
  into strict v_machine_id
  from public.machines
  where evidence_number = 23
    and lower(name) = 'luce snack x';

  update public.machine_planogram_slots
  set active = false,
      customer_selection_code = null,
      updated_at = now()
  where machine_id = v_machine_id
    and slot_code in ('63', '64');

  update public.machine_planogram_slots
  set customer_selection_code = case slot_code
        when '57' then '6B'
        when '59' then '6D'
        when '61' then '6F'
        when '62' then '6H'
      end,
      updated_at = now()
  where machine_id = v_machine_id
    and active is true
    and slot_code in ('57', '59', '61', '62');

  select count(*), count(distinct customer_selection_code)
  into v_active_slots, v_distinct_choices
  from public.machine_planogram_slots
  where machine_id = v_machine_id
    and active is true;

  if v_active_slots <> 49 or v_distinct_choices <> 49 then
    raise exception 'EV 23: očekáváno 49 aktivních pozic a 49 unikátních zákaznických voleb, nalezeno % a %.',
      v_active_slots, v_distinct_choices;
  end if;

  if (
    select array_agg(customer_selection_code order by sort_order)
    from public.machine_planogram_slots
    where machine_id = v_machine_id
      and active is true
      and slot_code in ('57', '59', '61', '62')
  ) is distinct from array['6B', '6D', '6F', '6H']::text[] then
    raise exception 'EV 23: horní řada nemá očekávané volby 6B, 6D, 6F, 6H.';
  end if;
end;
$$;

commit;

notify pgrst, 'reload schema';
