-- EV37 / Microtechnic: doplnění chybějícího planogramu podle stejného typu
-- Luce X1 I/E EV38. EV22 je starý, již neumístěný stroj; nesmí být nadále
-- vedený na lokalitě ViaPharma ani vstupovat do plánování tras.

begin;

do $$
declare
  v_source_machine_id bigint;
  v_target_machine_id bigint;
  v_retired_machine_id bigint;
begin
  select id into strict v_source_machine_id
  from public.machines
  where id = 32
    and evidence_number = 38
    and machine_type = 'Coffee'
    and name = 'Luce X1 I/E'
    and location_id = 43;

  select id into strict v_target_machine_id
  from public.machines
  where id = 31
    and evidence_number = 37
    and machine_type = 'Coffee'
    and name = 'Luce X1 I/E'
    and location_id = 44;

  select id into strict v_retired_machine_id
  from public.machines
  where id = 18
    and evidence_number = 22
    and machine_type = 'Coffee';

  if (select count(*) from public.machine_coffee_containers
      where machine_id = v_source_machine_id and active) <> 7
     or (select count(*) from public.machine_coffee_buttons
         where machine_id = v_source_machine_id and active) <> 16
     or (select count(*) from public.machine_coffee_recipe_items
         where machine_id = v_source_machine_id and active) <> 60
     or (select count(*) from public.machine_planogram_slots
         where machine_id = v_source_machine_id and active) <> 17 then
    raise exception 'EV38 nemá očekávaný úplný planogram 7/16/60/17; změna byla zrušena.';
  end if;

  if (select count(*) from public.machine_external_links
      where machine_id = v_target_machine_id
        and provider in ('IMA', 'GP')
        and external_machine_id = '592145'
        and telemetry_enabled) <> 2 then
    raise exception 'EV37 nemá obě aktivní vazby TID 592145; změna byla zrušena.';
  end if;

  if not exists (
    select 1
    from public.machines
    where evidence_number = 43
      and machine_type = 'Coffee'
      and location_id = 54
      and status = 'ok'
  ) then
    raise exception 'Na ViaPharmě nebyl potvrzen provozní EV43; EV22 nebude vyřazen.';
  end if;

  -- EV22 zůstává v majetkové evidenci, ale již není umístěný ani provozní.
  update public.machine_external_links
  set telemetry_enabled = false,
      note = concat_ws(' ', nullif(note, ''),
        'EV22 není umístěný; vazba ponechána pouze historicky a vypnuta 2026-10-21.'),
      updated_at = now()
  where machine_id = v_retired_machine_id;

  update public.machine_coffee_containers
  set active = false
  where machine_id = v_retired_machine_id;

  update public.machine_coffee_buttons
  set active = false
  where machine_id = v_retired_machine_id;

  update public.machine_planogram_slots
  set active = false
  where machine_id = v_retired_machine_id;

  delete from public.telemetry_planogram_counters
  where machine_id = v_retired_machine_id;

  update public.machines
  set location_id = null,
      status = 'removed',
      active = true,
      sales_tracking_mode = 'none',
      stock_initialized_at = null,
      note = concat_ws(' ', nullif(note, ''),
        '2026-10-21: potvrzeno, že EV22 již není ve ViaPharmě umístěný; vyřazeno z lokality a provozního plánování. Historická GP vazba 597848 zůstává vypnutá.'),
      updated_at = now()
  where id = v_retired_machine_id;

  -- EV37 přebírá pouze strukturu a obchodní nastavení stejného typu EV38.
  -- Fyzický stav zásob se z cizího stroje nesmí zkopírovat.
  update public.machines
  set machine_type = 'Coffee',
      brand = (select brand from public.machines where id = v_source_machine_id),
      model = (select model from public.machines where id = v_source_machine_id),
      name = 'Luce X1 I/E',
      status = 'ok',
      active = true,
      sales_tracking_mode = 'telemetry',
      stock_initialized_at = null,
      note = concat_ws(' ', nullif(note, ''),
        'Planogram doplněn 2026-10-21 podle stejného typu Luce X1 I/E EV38; ceny a receptury převzaty, fyzické zásoby záměrně neinicializovány. TID 592145.'),
      updated_at = now()
  where id = v_target_machine_id;

  update public.machine_coffee_containers
  set active = false
  where machine_id = v_target_machine_id;

  insert into public.machine_coffee_containers (
    machine_id, container_code, product_id, product_sku, product_name,
    capacity_quantity, current_quantity, unit, refill_package_quantity,
    refill_package_unit, min_refill_quantity, sort_order, active, note
  )
  select
    v_target_machine_id, container_code, product_id, product_sku, product_name,
    capacity_quantity, null, unit, refill_package_quantity,
    refill_package_unit, min_refill_quantity, sort_order, true,
    'Struktura převzata z EV38 dne 2026-10-21; počáteční fyzický stav musí operátor potvrdit na místě.'
  from public.machine_coffee_containers
  where machine_id = v_source_machine_id and active
  on conflict (machine_id, container_code) do update
  set product_id = excluded.product_id,
      product_sku = excluded.product_sku,
      product_name = excluded.product_name,
      capacity_quantity = excluded.capacity_quantity,
      current_quantity = null,
      unit = excluded.unit,
      refill_package_quantity = excluded.refill_package_quantity,
      refill_package_unit = excluded.refill_package_unit,
      min_refill_quantity = excluded.min_refill_quantity,
      sort_order = excluded.sort_order,
      active = true,
      note = excluded.note,
      updated_at = now();

  update public.machine_coffee_buttons
  set active = false
  where machine_id = v_target_machine_id;

  insert into public.machine_coffee_buttons (
    machine_id, selection_code, product_id, product_sku, product_name,
    sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk,
    settlement_partner, settlement_billing_enabled, settlement_note,
    planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction,
    last_counter, grid_column, grid_row_from_bottom, sort_order, active, note,
    subsidy_mode
  )
  select
    v_target_machine_id, selection_code, product_id, product_sku, product_name,
    sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk,
    settlement_partner, settlement_billing_enabled, settlement_note,
    planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction,
    0, grid_column, grid_row_from_bottom, sort_order, true,
    'Planogram a ceny převzaty z EV38 dne 2026-10-21.', subsidy_mode
  from public.machine_coffee_buttons
  where machine_id = v_source_machine_id and active
  on conflict (machine_id, selection_code) do update
  set product_id = excluded.product_id,
      product_sku = excluded.product_sku,
      product_name = excluded.product_name,
      sale_price_czk = excluded.sale_price_czk,
      customer_price_czk = excluded.customer_price_czk,
      settlement_type = excluded.settlement_type,
      settlement_amount_czk = excluded.settlement_amount_czk,
      settlement_partner = excluded.settlement_partner,
      settlement_billing_enabled = excluded.settlement_billing_enabled,
      settlement_note = excluded.settlement_note,
      planned_product_name = excluded.planned_product_name,
      planned_product_sku = excluded.planned_product_sku,
      planned_price_czk = excluded.planned_price_czk,
      substitution_policy = excluded.substitution_policy,
      allowed_substitutes = excluded.allowed_substitutes,
      operator_instruction = excluded.operator_instruction,
      last_counter = 0,
      grid_column = excluded.grid_column,
      grid_row_from_bottom = excluded.grid_row_from_bottom,
      sort_order = excluded.sort_order,
      active = true,
      note = excluded.note,
      subsidy_mode = excluded.subsidy_mode,
      updated_at = now();

  delete from public.machine_coffee_recipe_items
  where machine_id = v_target_machine_id;

  insert into public.machine_coffee_recipe_items (
    machine_id, coffee_button_id, coffee_container_id, product_id,
    container_code, ingredient_name, quantity_per_vend, unit, sort_order, active
  )
  select
    v_target_machine_id,
    target_button.id,
    target_container.id,
    source_recipe.product_id,
    source_recipe.container_code,
    source_recipe.ingredient_name,
    source_recipe.quantity_per_vend,
    source_recipe.unit,
    source_recipe.sort_order,
    true
  from public.machine_coffee_recipe_items source_recipe
  join public.machine_coffee_buttons source_button
    on source_button.id = source_recipe.coffee_button_id
  join public.machine_coffee_buttons target_button
    on target_button.machine_id = v_target_machine_id
   and target_button.selection_code = source_button.selection_code
  left join public.machine_coffee_containers target_container
    on target_container.machine_id = v_target_machine_id
   and target_container.container_code = source_recipe.container_code
  where source_recipe.machine_id = v_source_machine_id
    and source_recipe.active;

  update public.machine_planogram_slots
  set active = false
  where machine_id = v_target_machine_id;

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    capacity_units, current_units, fill_percent, active, sort_order, telemetry_key,
    customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner,
    settlement_billing_enabled, settlement_note, planned_product_name,
    planned_product_sku, planned_price_czk, substitution_policy,
    allowed_substitutes, operator_instruction, note,
    subsidy_amount_czk, subsidy_payer, subsidy_billing_enabled, subsidy_note,
    customer_selection_code
  )
  select
    v_target_machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    null, null, null, true, sort_order, telemetry_key,
    customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner,
    settlement_billing_enabled, settlement_note, planned_product_name,
    planned_product_sku, planned_price_czk, substitution_policy,
    allowed_substitutes, operator_instruction,
    'Planogram převzat z EV38 dne 2026-10-21; bez kopírování fyzického stavu.',
    subsidy_amount_czk, subsidy_payer, subsidy_billing_enabled, subsidy_note,
    customer_selection_code
  from public.machine_planogram_slots
  where machine_id = v_source_machine_id and active
  on conflict (machine_id, slot_code) do update
  set product_name = excluded.product_name,
      product_sku = excluded.product_sku,
      price_czk = excluded.price_czk,
      dex_price_czk = excluded.dex_price_czk,
      capacity_units = null,
      current_units = null,
      fill_percent = null,
      active = true,
      sort_order = excluded.sort_order,
      telemetry_key = excluded.telemetry_key,
      customer_price_czk = excluded.customer_price_czk,
      settlement_type = excluded.settlement_type,
      settlement_amount_czk = excluded.settlement_amount_czk,
      settlement_partner = excluded.settlement_partner,
      settlement_billing_enabled = excluded.settlement_billing_enabled,
      settlement_note = excluded.settlement_note,
      planned_product_name = excluded.planned_product_name,
      planned_product_sku = excluded.planned_product_sku,
      planned_price_czk = excluded.planned_price_czk,
      substitution_policy = excluded.substitution_policy,
      allowed_substitutes = excluded.allowed_substitutes,
      operator_instruction = excluded.operator_instruction,
      note = excluded.note,
      subsidy_amount_czk = excluded.subsidy_amount_czk,
      subsidy_payer = excluded.subsidy_payer,
      subsidy_billing_enabled = excluded.subsidy_billing_enabled,
      subsidy_note = excluded.subsidy_note,
      customer_selection_code = excluded.customer_selection_code,
      updated_at = now();

  -- Čítače jiného terminálu se nesmějí přenést. EV37 posílá živé
  -- souhrnné události TERMINAL_SUMMARY a ty se evidují bez odpočtu receptury.
  delete from public.telemetry_planogram_counters
  where machine_id = v_target_machine_id;

  if not exists (
    select 1 from public.machines
    where id = v_retired_machine_id
      and location_id is null
      and status = 'removed'
      and sales_tracking_mode = 'none'
  ) or exists (
    select 1 from public.machine_external_links
    where machine_id = v_retired_machine_id and telemetry_enabled
  ) then
    raise exception 'Kontrola vyřazení EV22 selhala.';
  end if;

  if (select count(*) from public.machine_coffee_containers
      where machine_id = v_target_machine_id and active) <> 7
     or (select count(*) from public.machine_coffee_containers
         where machine_id = v_target_machine_id and active and current_quantity is not null) <> 0
     or (select count(*) from public.machine_coffee_buttons
         where machine_id = v_target_machine_id and active) <> 16
     or (select count(*) from public.machine_coffee_recipe_items
         where machine_id = v_target_machine_id and active) <> 60
     or (select count(*) from public.machine_planogram_slots
         where machine_id = v_target_machine_id and active) <> 17
     or (select count(*) from public.machine_planogram_slots
         where machine_id = v_target_machine_id and active and slot_code = '0') <> 1
     or (select count(*) from public.machine_external_links
         where machine_id = v_target_machine_id
           and provider in ('IMA', 'GP')
           and external_machine_id = '592145'
           and telemetry_enabled) <> 2 then
    raise exception 'Závěrečná kontrola planogramu EV37 selhala.';
  end if;

  if exists (
    (select container_code, product_sku, capacity_quantity, unit,
            refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order
     from public.machine_coffee_containers
     where machine_id = v_source_machine_id and active
     except
     select container_code, product_sku, capacity_quantity, unit,
            refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order
     from public.machine_coffee_containers
     where machine_id = v_target_machine_id and active)
  ) or exists (
    (select selection_code, product_sku, sale_price_czk, customer_price_czk,
            grid_column, grid_row_from_bottom, sort_order
     from public.machine_coffee_buttons
     where machine_id = v_source_machine_id and active
     except
     select selection_code, product_sku, sale_price_czk, customer_price_czk,
            grid_column, grid_row_from_bottom, sort_order
     from public.machine_coffee_buttons
     where machine_id = v_target_machine_id and active)
  ) then
    raise exception 'EV37 se neshoduje se strukturou a cenami vzorového EV38.';
  end if;
end;
$$;

commit;

select
  m.evidence_number,
  m.name,
  m.location_id,
  m.status,
  m.active,
  m.sales_tracking_mode,
  m.stock_initialized_at,
  count(distinct c.id) filter (where c.active) as active_containers,
  count(distinct b.id) filter (where b.active) as active_buttons,
  count(distinct s.id) filter (where s.active) as active_slots
from public.machines m
left join public.machine_coffee_containers c on c.machine_id = m.id
left join public.machine_coffee_buttons b on b.machine_id = m.id
left join public.machine_planogram_slots s on s.machine_id = m.id
where m.evidence_number in (22, 37)
group by m.id
order by m.evidence_number;
