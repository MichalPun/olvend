begin;

do $$
declare
  v_source_machine_id bigint;
  v_target_machine_id bigint;
  v_ev integer;
begin
  select id into strict v_source_machine_id
  from public.machines
  where evidence_number = 16;

  foreach v_ev in array array[20, 51, 55]
  loop
    select id into strict v_target_machine_id
    from public.machines
    where evidence_number = v_ev;

    update public.machines
    set
      name = 'Luce H6',
      machine_type = 'Coffee',
      brand = 'Rheavendors',
      active = true,
      status = 'ok',
      note = concat_ws(
        ' ',
        nullif(note, ''),
        case
          when v_ev = 20 then 'Připraveno podle provozního planogramu Luce H6. TID 587382 převzato z VendSoftu.'
          when v_ev = 51 then 'Připraveno podle provozního planogramu Luce H6; bez telemetrického terminálu.'
          when v_ev = 55 then 'Připraveno podle provozního planogramu Luce H6; lokalita Mutěnice Vinařství, bez telemetrického terminálu.'
        end
      )
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
      capacity_quantity, 0, unit, refill_package_quantity,
      refill_package_unit, min_refill_quantity, sort_order, active,
      'Výchozí nastavení převzaté z provozního planogramu Luce H6 EV16; počáteční stav 0.'
    from public.machine_coffee_containers
    where machine_id = v_source_machine_id and active = true
    on conflict (machine_id, container_code) do update
    set product_id = excluded.product_id,
        product_sku = excluded.product_sku,
        product_name = excluded.product_name,
        capacity_quantity = excluded.capacity_quantity,
        current_quantity = excluded.current_quantity,
        unit = excluded.unit,
        refill_package_quantity = excluded.refill_package_quantity,
        refill_package_unit = excluded.refill_package_unit,
        min_refill_quantity = excluded.min_refill_quantity,
        sort_order = excluded.sort_order,
        active = excluded.active,
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
      last_counter, grid_column, grid_row_from_bottom, sort_order, active, note
    )
    select
      v_target_machine_id, selection_code, product_id, product_sku, product_name,
      sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk,
      settlement_partner, settlement_billing_enabled, settlement_note,
      planned_product_name, planned_product_sku, planned_price_czk,
      substitution_policy, allowed_substitutes, operator_instruction,
      0, grid_column, grid_row_from_bottom, sort_order, active,
      'Výchozí nastavení převzaté z provozního planogramu Luce H6 EV16; počáteční čítač 0.'
    from public.machine_coffee_buttons
    where machine_id = v_source_machine_id and active = true
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
        last_counter = excluded.last_counter,
        grid_column = excluded.grid_column,
        grid_row_from_bottom = excluded.grid_row_from_bottom,
        sort_order = excluded.sort_order,
        active = excluded.active,
        note = excluded.note,
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
      source_recipe.active
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
      and source_recipe.active = true;

    update public.machine_planogram_slots
    set active = false
    where machine_id = v_target_machine_id;

    insert into public.machine_planogram_slots (
      machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
      capacity_units, current_units, fill_percent, active, sort_order, telemetry_key,
      customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner,
      settlement_billing_enabled, settlement_note, planned_product_name,
      planned_product_sku, planned_price_czk, substitution_policy,
      allowed_substitutes, operator_instruction, note
    )
    select
      v_target_machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
      null, null, null, active, sort_order, telemetry_key,
      customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner,
      settlement_billing_enabled, settlement_note, planned_product_name,
      planned_product_sku, planned_price_czk, substitution_policy,
      allowed_substitutes, operator_instruction,
      'Výchozí zrcadlový slot převzatý z provozního planogramu Luce H6 EV16.'
    from public.machine_planogram_slots
    where machine_id = v_source_machine_id
      and active = true
      and (v_ev = 20 or slot_code <> '0')
    on conflict (machine_id, slot_code) do update
    set product_name = excluded.product_name,
        product_sku = excluded.product_sku,
        price_czk = excluded.price_czk,
        dex_price_czk = excluded.dex_price_czk,
        capacity_units = excluded.capacity_units,
        current_units = excluded.current_units,
        fill_percent = excluded.fill_percent,
        active = excluded.active,
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
        updated_at = now();
  end loop;
end;
$$;

-- EV20 already has both IMA and GP links for VendSoft TID 587382.
update public.machine_external_links
set telemetry_enabled = true,
    note = 'EV20 · Luce H6 · TID 587382 převzato z VendSoftu.',
    updated_at = now()
where machine_id = (select id from public.machines where evidence_number = 20)
  and provider in ('IMA', 'GP')
  and external_machine_id = '587382';

-- The remaining machines from the reviewed list are physically stored in Blučina.
-- Keep their asset records and history, but remove them from active customer locations.
update public.machines
set
  location_id = null,
  active = false,
  status = 'removed',
  note = concat_ws(' ', nullif(note, ''), 'Odvezeno na sklad dílna Blučina; potvrzeno 2026-07-31.'),
  updated_at = now()
where evidence_number in (11, 13, 39, 42, 54, 56);

commit;
