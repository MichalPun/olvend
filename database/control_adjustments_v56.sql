begin;

-- Zmeny provedene pri kontrole maji vlastni audit, ale zapisuji se atomicky
-- do zdrojoveho planogramu. Doplňovaci route_plans ani route_plan_stops se
-- v teto migraci zamerne nectou ani nemeni.

alter table public.control_machine_adjustments
  add column if not exists target_kind text;

alter table public.control_machine_adjustments
  add column if not exists target_record_id bigint;

update public.control_machine_adjustments
set target_kind = 'food_slot',
    target_record_id = planogram_slot_id
where target_kind is null
  and planogram_slot_id is not null;

alter table public.control_machine_adjustments
  drop constraint if exists control_machine_adjustments_target_kind_check;

alter table public.control_machine_adjustments
  add constraint control_machine_adjustments_target_kind_check
  check (target_kind in ('food_slot', 'coffee_button', 'coffee_container'));

create index if not exists control_machine_adjustments_target_idx
  on public.control_machine_adjustments(target_kind, target_record_id, created_at desc);

create or replace function public.apply_control_machine_adjustment_v56(
  p_control_route_machine_id bigint,
  p_target_kind text,
  p_target_id bigint,
  p_adjustment_type text,
  p_after_value jsonb,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_employee uuid := public.current_employee_id();
  v_route public.control_routes%rowtype;
  v_control_machine public.control_route_machines%rowtype;
  v_stop public.control_route_stops%rowtype;
  v_slot public.machine_planogram_slots%rowtype;
  v_button public.machine_coffee_buttons%rowtype;
  v_container public.machine_coffee_containers%rowtype;
  v_before jsonb := '{}'::jsonb;
  v_after jsonb := '{}'::jsonb;
  v_adjustment_id bigint;
  v_planogram_slot_id bigint;
  v_price numeric;
  v_quantity numeric;
  v_product_name text;
  v_product_sku text;
  v_sort_order integer;
  v_scope_key text;
begin
  if not public.security_active_employee() or v_employee is null then
    raise exception 'Přístup vyžaduje aktivní zaměstnanecký účet.' using errcode = '42501';
  end if;

  select crm.* into v_control_machine
  from public.control_route_machines crm
  where crm.id = p_control_route_machine_id;
  if not found then raise exception 'Kontrolovaný automat neexistuje.'; end if;

  select crs.* into v_stop
  from public.control_route_stops crs
  where crs.id = v_control_machine.control_route_stop_id;

  select cr.* into v_route
  from public.control_routes cr
  where cr.id = v_stop.control_route_id
  for update;

  if v_route.assigned_employee_id is distinct from v_employee then
    raise exception 'Změnu může provést pouze přiřazený kontrolor.' using errcode = '42501';
  end if;
  if v_route.status <> 'in_progress' or v_stop.status <> 'in_progress'
     or v_control_machine.status not in ('planned', 'in_progress') then
    raise exception 'Změnu lze uložit pouze během probíhající kontroly automatu.';
  end if;
  if p_adjustment_type not in ('price', 'stock', 'product', 'position') then
    raise exception 'Nepodporovaný typ změny.';
  end if;

  v_scope_key := case
    when p_adjustment_type = 'price' then 'adjust_price'
    when p_adjustment_type = 'stock' then 'adjust_stock'
    else 'adjust_product'
  end;
  if coalesce((v_route.checklist_config->>v_scope_key)::boolean, true) is not true then
    raise exception 'Tento typ změny není v kontrolní trase povolen.' using errcode = '42501';
  end if;

  if p_target_kind = 'food_slot' then
    select * into v_slot
    from public.machine_planogram_slots
    where id = p_target_id and machine_id = v_control_machine.machine_id and active is true
    for update;
    if not found then raise exception 'Pozice plánogramu nebyla nalezena.'; end if;
    v_planogram_slot_id := v_slot.id;

    if p_adjustment_type = 'price' then
      v_price := nullif(p_after_value->>'price_czk', '')::numeric;
      if v_price is null or v_price < 0 then raise exception 'Zadejte platnou cenu.'; end if;
      v_before := jsonb_build_object('price_czk', v_slot.price_czk, 'customer_price_czk', v_slot.customer_price_czk);
      update public.machine_planogram_slots
      set price_czk = v_price, customer_price_czk = v_price, pending_price_czk = null
      where id = v_slot.id;
      v_after := jsonb_build_object('price_czk', v_price, 'customer_price_czk', v_price);
    elsif p_adjustment_type = 'stock' then
      v_quantity := nullif(p_after_value->>'current_units', '')::numeric;
      if v_quantity is null or v_quantity < 0 or v_quantity <> trunc(v_quantity) then
        raise exception 'Stav zásoby musí být celé nezáporné číslo.';
      end if;
      if v_slot.capacity_units is not null and v_quantity > v_slot.capacity_units then
        raise exception 'Stav zásoby nesmí překročit kapacitu pozice (% ks).', v_slot.capacity_units;
      end if;
      v_before := jsonb_build_object('current_units', v_slot.current_units, 'fill_percent', v_slot.fill_percent);
      update public.machine_planogram_slots
      set current_units = v_quantity::integer,
          fill_percent = case when coalesce(capacity_units, 0) > 0 then round(v_quantity / capacity_units * 100, 2) else null end
      where id = v_slot.id;
      v_after := jsonb_build_object(
        'current_units', v_quantity::integer,
        'fill_percent', case when coalesce(v_slot.capacity_units, 0) > 0 then round(v_quantity / v_slot.capacity_units * 100, 2) else null end
      );
    elsif p_adjustment_type = 'product' then
      v_product_name := nullif(trim(p_after_value->>'product_name'), '');
      v_product_sku := nullif(trim(p_after_value->>'product_sku'), '');
      if v_product_name is null then raise exception 'Zadejte název produktu.'; end if;
      v_before := jsonb_build_object('product_name', v_slot.product_name, 'product_sku', v_slot.product_sku);
      update public.machine_planogram_slots
      set product_name = v_product_name, product_sku = v_product_sku,
          planned_product_name = null, planned_product_sku = null, planned_price_czk = null
      where id = v_slot.id;
      v_after := jsonb_build_object('product_name', v_product_name, 'product_sku', v_product_sku);
    else
      v_sort_order := nullif(p_after_value->>'sort_order', '')::integer;
      if v_sort_order is null or v_sort_order < 0 then raise exception 'Zadejte platné pořadí.'; end if;
      v_before := jsonb_build_object('sort_order', v_slot.sort_order, 'slot_code', v_slot.slot_code);
      update public.machine_planogram_slots set sort_order = v_sort_order where id = v_slot.id;
      v_after := jsonb_build_object('sort_order', v_sort_order, 'slot_code', v_slot.slot_code);
    end if;

  elsif p_target_kind = 'coffee_button' then
    select * into v_button
    from public.machine_coffee_buttons
    where id = p_target_id and machine_id = v_control_machine.machine_id and active is true
    for update;
    if not found then raise exception 'Volba nápoje nebyla nalezena.'; end if;
    if p_adjustment_type not in ('price', 'product', 'position') then
      raise exception 'U volby nápoje lze změnit cenu, produkt nebo pořadí.';
    end if;

    select id into v_planogram_slot_id
    from public.machine_planogram_slots
    where machine_id = v_button.machine_id and slot_code = v_button.selection_code
    limit 1;

    if p_adjustment_type = 'price' then
      v_price := nullif(p_after_value->>'price_czk', '')::numeric;
      if v_price is null or v_price < 0 then raise exception 'Zadejte platnou cenu.'; end if;
      v_before := jsonb_build_object('sale_price_czk', v_button.sale_price_czk, 'customer_price_czk', v_button.customer_price_czk);
      update public.machine_coffee_buttons set sale_price_czk = v_price, customer_price_czk = v_price where id = v_button.id;
      update public.machine_planogram_slots set price_czk = v_price, customer_price_czk = v_price, pending_price_czk = null
      where machine_id = v_button.machine_id and slot_code = v_button.selection_code;
      v_after := jsonb_build_object('sale_price_czk', v_price, 'customer_price_czk', v_price);
    elsif p_adjustment_type = 'product' then
      v_product_name := nullif(trim(p_after_value->>'product_name'), '');
      v_product_sku := nullif(trim(p_after_value->>'product_sku'), '');
      if v_product_name is null then raise exception 'Zadejte název nápoje.'; end if;
      v_before := jsonb_build_object('product_name', v_button.product_name, 'product_sku', v_button.product_sku);
      update public.machine_coffee_buttons
      set product_name = v_product_name, product_sku = v_product_sku,
          planned_product_name = null, planned_product_sku = null, planned_price_czk = null
      where id = v_button.id;
      update public.machine_planogram_slots
      set product_name = v_product_name, product_sku = v_product_sku,
          planned_product_name = null, planned_product_sku = null, planned_price_czk = null
      where machine_id = v_button.machine_id and slot_code = v_button.selection_code;
      v_after := jsonb_build_object('product_name', v_product_name, 'product_sku', v_product_sku);
    else
      v_sort_order := nullif(p_after_value->>'sort_order', '')::integer;
      if v_sort_order is null or v_sort_order < 0 then raise exception 'Zadejte platné pořadí.'; end if;
      v_before := jsonb_build_object('sort_order', v_button.sort_order, 'selection_code', v_button.selection_code);
      update public.machine_coffee_buttons set sort_order = v_sort_order where id = v_button.id;
      update public.machine_planogram_slots set sort_order = v_sort_order
      where machine_id = v_button.machine_id and slot_code = v_button.selection_code;
      v_after := jsonb_build_object('sort_order', v_sort_order, 'selection_code', v_button.selection_code);
    end if;

  elsif p_target_kind = 'coffee_container' then
    select * into v_container
    from public.machine_coffee_containers
    where id = p_target_id and machine_id = v_control_machine.machine_id and active is true
    for update;
    if not found then raise exception 'Zásobník suroviny nebyl nalezen.'; end if;
    if p_adjustment_type not in ('stock', 'product', 'position') then
      raise exception 'U zásobníku lze změnit stav, surovinu nebo pořadí.';
    end if;

    if p_adjustment_type = 'stock' then
      v_quantity := nullif(p_after_value->>'current_quantity', '')::numeric;
      if v_quantity is null or v_quantity < 0 then raise exception 'Stav zásobníku musí být nezáporné číslo.'; end if;
      if v_container.capacity_quantity is not null and v_quantity > v_container.capacity_quantity then
        raise exception 'Stav zásobníku nesmí překročit kapacitu (% %).', v_container.capacity_quantity, v_container.unit;
      end if;
      v_before := jsonb_build_object('current_quantity', v_container.current_quantity, 'unit', v_container.unit);
      update public.machine_coffee_containers set current_quantity = v_quantity where id = v_container.id;
      v_after := jsonb_build_object('current_quantity', v_quantity, 'unit', v_container.unit);
    elsif p_adjustment_type = 'product' then
      v_product_name := nullif(trim(p_after_value->>'product_name'), '');
      v_product_sku := nullif(trim(p_after_value->>'product_sku'), '');
      if v_product_name is null then raise exception 'Zadejte název suroviny.'; end if;
      v_before := jsonb_build_object('product_name', v_container.product_name, 'product_sku', v_container.product_sku);
      update public.machine_coffee_containers
      set product_name = v_product_name, product_sku = v_product_sku
      where id = v_container.id;
      v_after := jsonb_build_object('product_name', v_product_name, 'product_sku', v_product_sku);
    else
      v_sort_order := nullif(p_after_value->>'sort_order', '')::integer;
      if v_sort_order is null or v_sort_order < 0 then raise exception 'Zadejte platné pořadí.'; end if;
      v_before := jsonb_build_object('sort_order', v_container.sort_order, 'container_code', v_container.container_code);
      update public.machine_coffee_containers set sort_order = v_sort_order where id = v_container.id;
      v_after := jsonb_build_object('sort_order', v_sort_order, 'container_code', v_container.container_code);
    end if;
  else
    raise exception 'Nepodporovaný cíl změny.';
  end if;

  insert into public.control_machine_adjustments (
    control_route_id, control_route_stop_id, control_route_machine_id,
    machine_id, planogram_slot_id, target_kind, target_record_id,
    adjustment_type, before_value, after_value, note,
    status, applied_at, created_by
  ) values (
    v_route.id, v_stop.id, v_control_machine.id,
    v_control_machine.machine_id, v_planogram_slot_id, p_target_kind, p_target_id,
    p_adjustment_type, v_before, v_after, nullif(trim(p_note), ''),
    'applied', timezone('utc', now()), v_employee
  ) returning id into v_adjustment_id;

  return jsonb_build_object(
    'adjustment_id', v_adjustment_id,
    'status', 'applied',
    'target_kind', p_target_kind,
    'target_id', p_target_id,
    'before', v_before,
    'after', v_after
  );
end;
$$;

revoke all on function public.apply_control_machine_adjustment_v56(bigint, text, bigint, text, jsonb, text) from public, anon;
grant execute on function public.apply_control_machine_adjustment_v56(bigint, text, bigint, text, jsonb, text) to authenticated;

comment on function public.apply_control_machine_adjustment_v56(bigint, text, bigint, text, jsonb, text) is
  'Atomicky zapise zmenu z kontroly do aktivniho planogramu a soucasne do auditni historie. Bez vlivu na stav doplnovaci trasy.';

comment on column public.control_machine_adjustments.target_kind is
  'Zdrojova cast planogramu: food_slot, coffee_button nebo coffee_container.';

commit;
