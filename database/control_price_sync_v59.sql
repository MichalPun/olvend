begin;

-- A manually entered price correction during a control route used to update the
-- active planogram only.  If the same target also had an approved price-change
-- item, that item and its visit tasks stayed pending forever.  Reconcile the
-- approved workflow from the immutable control-adjustment audit row.
create or replace function public.reconcile_control_price_adjustment_v59()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_price numeric;
  v_item public.machine_price_change_items%rowtype;
  v_pending integer;
begin
  if new.adjustment_type <> 'price'
     or new.status <> 'applied'
     or new.target_kind not in ('food_slot', 'coffee_button') then
    return new;
  end if;

  v_price := coalesce(
    nullif(new.after_value->>'price_czk', '')::numeric,
    nullif(new.after_value->>'sale_price_czk', '')::numeric
  );
  if v_price is null then return new; end if;

  select i.* into v_item
  from public.machine_price_change_items i
  where i.machine_id = new.machine_id
    and i.target_type = new.target_kind
    and i.status = 'pending'
    and i.new_price_czk = v_price
    and (
      (new.target_kind = 'food_slot' and i.planogram_slot_id = new.target_record_id)
      or
      (new.target_kind = 'coffee_button' and i.coffee_button_id = new.target_record_id)
    )
  order by i.created_at desc
  limit 1
  for update;

  if not found then return new; end if;

  update public.machine_price_change_items
  set status = 'applied',
      applied_by_employee_id = coalesce(new.created_by, applied_by_employee_id),
      applied_at = coalesce(new.applied_at, now())
  where id = v_item.id;

  update public.route_machine_visit_checks
  set status = 'done',
      completed_at = coalesce(completed_at, new.applied_at, now()),
      operator_note = concat_ws(
        E'\n',
        nullif(operator_note, ''),
        'Cena provedena při manažerské kontrolní trase.'
      )
  where check_key = 'price_change:' || v_item.id::text
    and status <> 'done';

  select count(*) into v_pending
  from public.machine_price_change_items
  where batch_id = v_item.batch_id and status = 'pending';

  update public.machine_price_change_batches
  set status = case when v_pending = 0 then 'completed' else 'in_progress' end,
      completed_at = case when v_pending = 0 then coalesce(completed_at, new.applied_at, now()) else null end
  where id = v_item.batch_id;

  if v_pending = 0 then
    update public.location_operator_messages
    set is_active = false,
        closed_at = coalesce(closed_at, new.applied_at, now())
    where id = (
      select location_operator_message_id
      from public.machine_price_change_batches
      where id = v_item.batch_id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists reconcile_control_price_adjustment_v59
  on public.control_machine_adjustments;
create trigger reconcile_control_price_adjustment_v59
after insert on public.control_machine_adjustments
for each row execute function public.reconcile_control_price_adjustment_v59();

-- Apply every still-pending prepared price on one controlled machine in a
-- single database transaction.  Any bad/missing target aborts the whole call,
-- so the mobile client can no longer stop halfway through a JavaScript loop.
create or replace function public.apply_all_control_price_changes_v59(
  p_control_route_machine_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_employee uuid := public.current_employee_id();
  v_context record;
  v_item public.machine_price_change_items%rowtype;
  v_adjustment_id bigint;
  v_updated integer;
  v_applied integer := 0;
  v_batch_ids uuid[] := array[]::uuid[];
  v_batch_id uuid;
  v_pending integer;
begin
  if v_employee is null then
    raise exception 'Přihlášení vypršelo.' using errcode = '42501';
  end if;

  select crm.*, crs.control_route_id, cr.status as route_status,
         cr.assigned_employee_id
  into v_context
  from public.control_route_machines crm
  join public.control_route_stops crs on crs.id = crm.control_route_stop_id
  join public.control_routes cr on cr.id = crs.control_route_id
  where crm.id = p_control_route_machine_id;

  if not found
     or (v_context.assigned_employee_id <> v_employee and not public.has_manager_access()) then
    raise exception 'Kontrolní automat není dostupný.' using errcode = '42501';
  end if;
  if v_context.route_status <> 'in_progress' then
    raise exception 'Hromadné potvrzení cen je možné pouze během probíhající kontrolní trasy.';
  end if;

  for v_item in
    select i.*
    from public.machine_price_change_items i
    where i.machine_id = v_context.machine_id
      and i.status = 'pending'
    order by i.created_at, i.slot_code, i.id
    for update
  loop
    if v_item.target_type = 'food_slot' then
      update public.machine_planogram_slots
      set price_czk = v_item.new_price_czk,
          customer_price_czk = v_item.new_price_czk,
          pending_price_czk = null
      where id = v_item.planogram_slot_id
        and machine_id = v_context.machine_id;
      get diagnostics v_updated = row_count;
      if v_updated <> 1 then
        raise exception 'Pozice % už v plánogramu neexistuje; žádná cena nebyla uložena.', v_item.slot_code;
      end if;
    elsif v_item.target_type = 'coffee_button' then
      update public.machine_coffee_buttons
      set sale_price_czk = v_item.new_price_czk,
          customer_price_czk = v_item.new_price_czk
      where id = v_item.coffee_button_id
        and machine_id = v_context.machine_id;
      get diagnostics v_updated = row_count;
      if v_updated <> 1 then
        raise exception 'Volba % už v plánogramu neexistuje; žádná cena nebyla uložena.', v_item.slot_code;
      end if;

      update public.machine_planogram_slots
      set price_czk = v_item.new_price_czk,
          customer_price_czk = v_item.new_price_czk,
          pending_price_czk = null
      where machine_id = v_context.machine_id
        and slot_code = v_item.slot_code;
    else
      raise exception 'Nepodporovaný typ cenové položky %.', v_item.target_type;
    end if;

    update public.machine_price_change_items
    set status = 'applied',
        applied_by_employee_id = v_employee,
        applied_at = now()
    where id = v_item.id;

    update public.route_machine_visit_checks
    set status = 'done',
        completed_at = coalesce(completed_at, now()),
        operator_note = concat_ws(
          E'\n',
          nullif(operator_note, ''),
          'Cena provedena při manažerské kontrolní trase.'
        )
    where check_key = 'price_change:' || v_item.id::text
      and status <> 'done';

    insert into public.control_machine_adjustments(
      control_route_id, control_route_stop_id, control_route_machine_id,
      machine_id, planogram_slot_id, target_kind, target_record_id,
      adjustment_type, before_value, after_value, note, status,
      applied_at, created_by
    ) values (
      v_context.control_route_id, v_context.control_route_stop_id,
      p_control_route_machine_id, v_context.machine_id,
      v_item.planogram_slot_id, v_item.target_type,
      coalesce(v_item.planogram_slot_id, v_item.coffee_button_id),
      'price', jsonb_build_object('price_czk', v_item.old_price_czk),
      jsonb_build_object('price_czk', v_item.new_price_czk),
      'Hromadně potvrzeno z připravené cenové sady ' || v_item.batch_id::text,
      'applied', now(), v_employee
    ) returning id into v_adjustment_id;

    v_batch_ids := array_append(v_batch_ids, v_item.batch_id);
    v_applied := v_applied + 1;
  end loop;

  foreach v_batch_id in array v_batch_ids loop
    select count(*) into v_pending
    from public.machine_price_change_items
    where batch_id = v_batch_id and status = 'pending';

    update public.machine_price_change_batches
    set status = case when v_pending = 0 then 'completed' else 'in_progress' end,
        completed_at = case when v_pending = 0 then coalesce(completed_at, now()) else null end
    where id = v_batch_id;

    if v_pending = 0 then
      update public.location_operator_messages
      set is_active = false,
          closed_at = coalesce(closed_at, now())
      where id = (
        select location_operator_message_id
        from public.machine_price_change_batches
        where id = v_batch_id
      );
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'applied_count', v_applied,
    'already_complete', v_applied = 0
  );
end;
$$;

revoke all on function public.apply_all_control_price_changes_v59(bigint)
  from public, anon;
grant execute on function public.apply_all_control_price_changes_v59(bigint)
  to authenticated;

comment on function public.apply_all_control_price_changes_v59(bigint) is
  'Atomicky propíše všechny čekající schválené ceny jednoho automatu během kontrolní trasy.';

notify pgrst, 'reload schema';

commit;
