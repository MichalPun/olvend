begin;

-- Dvě fyzicky provedené ceny z kontrolní trasy 2 neměly kvůli původnímu
-- klientskému hromadnému potvrzení auditní záznam. Uživatel jejich provedení
-- výslovně potvrdil; oprava je záměrně omezena na přesné stroje, pozice a ceny.
do $$
declare
  v_employee uuid;
  v_item record;
  v_pending integer;
  v_repaired integer := 0;
begin
  select assigned_employee_id into v_employee
  from public.control_routes
  where id = 2 and planned_date = date '2026-10-20';
  if v_employee is null then
    raise exception 'Kontrolní trasa 2 z 20. 10. 2026 nebyla nalezena.';
  end if;

  for v_item in
    select
      i.*,
      crm.id as control_route_machine_id,
      crs.id as control_route_stop_id,
      s.id as live_slot_id,
      coalesce(s.customer_price_czk, s.price_czk) as live_price_czk
    from public.machine_price_change_items i
    join public.machines m on m.id = i.machine_id
    join public.machine_planogram_slots s
      on s.id = i.planogram_slot_id and s.machine_id = i.machine_id
    join public.control_route_stops crs on crs.control_route_id = 2
    join public.control_route_machines crm
      on crm.control_route_stop_id = crs.id and crm.machine_id = i.machine_id
    where i.status = 'pending'
      and i.target_type = 'food_slot'
      and (
        (m.evidence_number = 7 and i.slot_code = '4'
          and i.old_price_czk = 48 and i.new_price_czk = 54
          and coalesce(s.customer_price_czk, s.price_czk) = 48)
        or
        (m.evidence_number = 9 and i.slot_code = '35'
          and i.old_price_czk = 20 and i.new_price_czk = 21
          and coalesce(s.customer_price_czk, s.price_czk) = 20)
      )
    order by m.evidence_number
    for update of i, s
  loop
    update public.machine_planogram_slots
    set price_czk = v_item.new_price_czk,
        customer_price_czk = v_item.new_price_czk,
        pending_price_czk = null
    where id = v_item.live_slot_id;

    update public.machine_price_change_items
    set status = 'applied',
        applied_by_employee_id = v_employee,
        applied_at = now()
    where id = v_item.id;

    update public.route_machine_visit_checks
    set status = 'done',
        completed_at = coalesce(completed_at, now()),
        operator_note = concat_ws(
          E'\n', nullif(operator_note, ''),
          'Cena doplněna po opravě přerušeného hromadného potvrzení kontrolní trasy.'
        )
    where check_key = 'price_change:' || v_item.id::text
      and status <> 'done';

    insert into public.control_machine_adjustments(
      control_route_id, control_route_stop_id, control_route_machine_id,
      machine_id, planogram_slot_id, target_kind, target_record_id,
      adjustment_type, before_value, after_value, note, status,
      applied_at, created_by
    ) values (
      2, v_item.control_route_stop_id, v_item.control_route_machine_id,
      v_item.machine_id, v_item.planogram_slot_id, 'food_slot',
      v_item.planogram_slot_id, 'price',
      jsonb_build_object('price_czk', v_item.old_price_czk),
      jsonb_build_object('price_czk', v_item.new_price_czk),
      'Doplněno po opravě přerušeného hromadného potvrzení dne 20. 10. 2026.',
      'applied', now(), v_employee
    );

    select count(*) into v_pending
    from public.machine_price_change_items
    where batch_id = v_item.batch_id and status = 'pending';

    update public.machine_price_change_batches
    set status = case when v_pending = 0 then 'completed' else 'in_progress' end,
        completed_at = case when v_pending = 0 then coalesce(completed_at, now()) else null end
    where id = v_item.batch_id;

    if v_pending = 0 then
      update public.location_operator_messages
      set is_active = false,
          closed_at = coalesce(closed_at, now())
      where id = (
        select location_operator_message_id
        from public.machine_price_change_batches
        where id = v_item.batch_id
      );
    end if;

    v_repaired := v_repaired + 1;
  end loop;

  if v_repaired <> 2 then
    raise exception 'Očekávány byly přesně 2 chybějící ceny, nalezeno %; oprava byla vrácena zpět.', v_repaired;
  end if;
end;
$$;

commit;
