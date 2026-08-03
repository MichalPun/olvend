begin;

do $$
declare
  v_machine_id bigint;
  v_changed integer;
begin
  select id into v_machine_id
  from public.machines
  where evidence_number::text = '5'
  order by id
  limit 1;

  if v_machine_id is null then
    raise exception 'Food machine EV 5 was not found.';
  end if;

  update public.machine_planogram_slots
  set pending_change_mode = 'sell_through',
      pending_change_note = concat_ws(
        ' · ',
        nullif(trim(pending_change_note), ''),
        '3. 8. 2026: operátor rozhodl ponechat původní bagety k řízenému doprodeji'
      ),
      updated_at = now()
  where machine_id = v_machine_id
    and slot_code in ('23', '24')
    and active is true
    and pending_change_mode = 'full_swap';

  get diagnostics v_changed = row_count;
  if v_changed <> 2 then
    raise exception 'Expected to switch 2 EV 5 slots to sell-through, changed %.', v_changed;
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
