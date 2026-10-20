begin;

-- Jednorázová oprava dnešní kontrolní trasy. Za provedené označí pouze ty
-- čekající položky, pro které existuje audit stejného cíle a přesně stejné nové
-- ceny. Ostatní ceny zůstanou čekající, protože není doloženo fyzické provedení.
do $$
declare
  v_match record;
  v_pending integer;
  v_repaired integer := 0;
begin
  for v_match in
    select distinct on (i.id)
      i.id as item_id,
      i.batch_id,
      a.created_by,
      a.applied_at
    from public.machine_price_change_items i
    join public.control_machine_adjustments a
      on a.machine_id = i.machine_id
     and a.target_kind = i.target_type
     and a.target_record_id = coalesce(i.planogram_slot_id, i.coffee_button_id)
     and a.adjustment_type = 'price'
     and a.status = 'applied'
     and coalesce(
       nullif(a.after_value->>'price_czk', '')::numeric,
       nullif(a.after_value->>'sale_price_czk', '')::numeric
     ) = i.new_price_czk
    join public.control_routes r on r.id = a.control_route_id
    where i.status = 'pending'
      and r.id = 2
      and r.planned_date = date '2026-10-20'
    order by i.id, a.applied_at desc, a.id desc
  loop
    update public.machine_price_change_items
    set status = 'applied',
        applied_by_employee_id = coalesce(v_match.created_by, applied_by_employee_id),
        applied_at = coalesce(v_match.applied_at, now())
    where id = v_match.item_id and status = 'pending';

    if found then
      v_repaired := v_repaired + 1;
      update public.route_machine_visit_checks
      set status = 'done',
          completed_at = coalesce(completed_at, v_match.applied_at, now()),
          operator_note = concat_ws(
            E'\n', nullif(operator_note, ''),
            'Cena zpětně spárována s auditem manažerské kontrolní trasy.'
          )
      where check_key = 'price_change:' || v_match.item_id::text
        and status <> 'done';
    end if;

    select count(*) into v_pending
    from public.machine_price_change_items
    where batch_id = v_match.batch_id and status = 'pending';

    update public.machine_price_change_batches
    set status = case when v_pending = 0 then 'completed' else 'in_progress' end,
        completed_at = case when v_pending = 0 then coalesce(completed_at, v_match.applied_at, now()) else null end
    where id = v_match.batch_id;

    if v_pending = 0 then
      update public.location_operator_messages
      set is_active = false,
          closed_at = coalesce(closed_at, v_match.applied_at, now())
      where id = (
        select location_operator_message_id
        from public.machine_price_change_batches
        where id = v_match.batch_id
      );
    end if;
  end loop;

  raise notice 'Repaired % price workflow items from control route 2.', v_repaired;
end;
$$;

commit;
