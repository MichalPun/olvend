-- EV 32: copy the complete Luce X2 I/E coffee setup from EV 67 / Jamne.
-- Customer vends are free; the regular Jamne vend price is billed to the partner.

do $$
declare
  v_source_machine_id bigint;
  v_target_machine_id bigint;
  v_partner_label text := 'Partner lokality ev. č. 32';
begin
  select id into strict v_source_machine_id
  from public.machines
  where evidence_number::text = '67';

  select id into strict v_target_machine_id
  from public.machines
  where evidence_number::text = '32';

  if (select count(*) from public.machine_coffee_containers where machine_id = v_source_machine_id and active) <> 10 then
    raise exception 'Zdrojovy automat 67 nema ocekavanych 10 aktivnich zasobniku.';
  end if;

  if (select count(*) from public.machine_coffee_buttons where machine_id = v_source_machine_id and active) <> 24 then
    raise exception 'Zdrojovy automat 67 nema ocekavanych 24 aktivnich voleb.';
  end if;

  update public.machine_coffee_containers set active = false where machine_id = v_target_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_target_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_target_machine_id;
  delete from public.machine_coffee_recipe_items where machine_id = v_target_machine_id;
  delete from public.telemetry_planogram_counters where machine_id = v_target_machine_id;

  insert into public.machine_coffee_containers (
    machine_id, container_code, product_id, product_sku, product_name,
    capacity_quantity, current_quantity, unit, refill_package_quantity,
    refill_package_unit, min_refill_quantity, sort_order, active, note
  )
  select
    v_target_machine_id, source.container_code, source.product_id, source.product_sku, source.product_name,
    source.capacity_quantity, 0, source.unit, source.refill_package_quantity,
    source.refill_package_unit, source.min_refill_quantity, source.sort_order, source.active,
    concat('Zkopirovano z automatu 67 / Jamne dne 10. 8. 2026. Novy fyzicky stav zacina na 0. ', coalesce(source.note, ''))
  from public.machine_coffee_containers source
  where source.machine_id = v_source_machine_id
  on conflict (machine_id, container_code) do update set
    product_id = excluded.product_id,
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

  insert into public.machine_coffee_buttons (
    machine_id, selection_code, product_id, product_sku, product_name,
    sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk,
    settlement_partner, settlement_billing_enabled, settlement_note,
    planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction,
    last_counter, grid_column, grid_row_from_bottom, sort_order, active, note
  )
  select
    v_target_machine_id, source.selection_code, source.product_id, source.product_sku, source.product_name,
    0, 0, 'subsidy_receivable', coalesce(source.customer_price_czk, source.sale_price_czk, 0),
    v_partner_label, true,
    'Zakaznik 0 Kc; beznou cenu volby hradi partner. Konkretni nazev partnera doplnit po prirazeni lokality.',
    source.planned_product_name, source.planned_product_sku,
    case when source.planned_product_name is null then null else 0 end,
    source.substitution_policy, source.allowed_substitutes, source.operator_instruction,
    null, source.grid_column, source.grid_row_from_bottom, source.sort_order, source.active,
    concat('Rozlozeni a produkt z automatu 67 / Jamne. Cena pro zakaznika 0 Kc; partner hradi ',
      coalesce(source.customer_price_czk, source.sale_price_czk, 0), ' Kc za vydanou volbu.')
  from public.machine_coffee_buttons source
  where source.machine_id = v_source_machine_id
  on conflict (machine_id, selection_code) do update set
    product_id = excluded.product_id,
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
  left join public.machine_coffee_containers source_container
    on source_container.id = source_recipe.coffee_container_id
  left join public.machine_coffee_containers target_container
    on target_container.machine_id = v_target_machine_id
   and target_container.container_code = coalesce(source_container.container_code, source_recipe.container_code)
  where source_recipe.machine_id = v_source_machine_id
    and source_recipe.coffee_container_id is not null;

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk,
    capacity_units, current_units, fill_percent, active, sort_order, note,
    dex_price_czk, desired_units, expiry_date, telemetry_key, last_units,
    product_family, product_variant, planned_product_name, planned_product_sku,
    planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction,
    customer_price_czk, subsidy_amount_czk, subsidy_payer,
    subsidy_billing_enabled, subsidy_note, settlement_type,
    settlement_amount_czk, settlement_partner, settlement_billing_enabled,
    settlement_note, target_units, replenishment_mode
  )
  select
    v_target_machine_id, source.slot_code, source.product_name, source.product_sku, 0,
    source.capacity_units, null, null, source.active, source.sort_order,
    'Zrcadlovy slot kavy z automatu 67 / Jamne. Zakaznik 0 Kc; beznou cenu hradi partner.',
    0, source.desired_units, null, source.telemetry_key, null,
    source.product_family, source.product_variant, source.planned_product_name, source.planned_product_sku,
    case when source.planned_product_name is null then null else 0 end,
    source.substitution_policy, source.allowed_substitutes, source.operator_instruction,
    0, 0, null, false, null, 'subsidy_receivable',
    coalesce(source.customer_price_czk, source.price_czk, 0), v_partner_label, true,
    'Zakaznik 0 Kc; beznou cenu volby hradi partner. Konkretni nazev partnera doplnit po prirazeni lokality.',
    source.target_units, source.replenishment_mode
  from public.machine_planogram_slots source
  where source.machine_id = v_source_machine_id
  on conflict (machine_id, slot_code) do update set
    product_name = excluded.product_name,
    product_sku = excluded.product_sku,
    price_czk = excluded.price_czk,
    capacity_units = excluded.capacity_units,
    current_units = excluded.current_units,
    fill_percent = excluded.fill_percent,
    active = excluded.active,
    sort_order = excluded.sort_order,
    note = excluded.note,
    dex_price_czk = excluded.dex_price_czk,
    desired_units = excluded.desired_units,
    expiry_date = excluded.expiry_date,
    telemetry_key = excluded.telemetry_key,
    last_units = excluded.last_units,
    product_family = excluded.product_family,
    product_variant = excluded.product_variant,
    planned_product_name = excluded.planned_product_name,
    planned_product_sku = excluded.planned_product_sku,
    planned_price_czk = excluded.planned_price_czk,
    substitution_policy = excluded.substitution_policy,
    allowed_substitutes = excluded.allowed_substitutes,
    operator_instruction = excluded.operator_instruction,
    customer_price_czk = excluded.customer_price_czk,
    subsidy_amount_czk = excluded.subsidy_amount_czk,
    subsidy_payer = excluded.subsidy_payer,
    subsidy_billing_enabled = excluded.subsidy_billing_enabled,
    subsidy_note = excluded.subsidy_note,
    settlement_type = excluded.settlement_type,
    settlement_amount_czk = excluded.settlement_amount_czk,
    settlement_partner = excluded.settlement_partner,
    settlement_billing_enabled = excluded.settlement_billing_enabled,
    settlement_note = excluded.settlement_note,
    target_units = excluded.target_units,
    replenishment_mode = excluded.replenishment_mode,
    updated_at = now();

  update public.machines
  set note = concat_ws(' · ', note,
    'Planogram a receptury z automatu 67 / Jamne nastaveny 10. 8. 2026. Zakaznicka cena 0 Kc, beznou cenu hradi partner lokality.'),
      updated_at = now()
  where id = v_target_machine_id;

  if (select count(*) from public.machine_coffee_recipe_items where machine_id = v_target_machine_id and active) <>
     (select count(*) from public.machine_coffee_recipe_items where machine_id = v_source_machine_id and active and coffee_container_id is not null) then
    raise exception 'Pocet receptur ciloveho automatu neodpovida zdroji.';
  end if;

  if exists (
    select 1 from public.machine_coffee_recipe_items
    where machine_id = v_target_machine_id and active and coffee_container_id is null
  ) then
    raise exception 'Nektera receptura automatu 32 nema fyzicky zasobnik.';
  end if;
end $$;

select
  machine.id as machine_id,
  machine.evidence_number,
  machine.name,
  (select count(*) from public.machine_coffee_containers where machine_id = machine.id and active) as active_containers,
  (select count(*) from public.machine_coffee_buttons where machine_id = machine.id and active) as active_buttons,
  (select count(*) from public.machine_coffee_recipe_items where machine_id = machine.id and active) as active_recipe_items,
  (select count(*) from public.machine_planogram_slots where machine_id = machine.id and active) as active_slots,
  (select count(*) from public.machine_coffee_buttons where machine_id = machine.id and active and customer_price_czk = 0) as free_buttons,
  (select count(*) from public.machine_coffee_buttons where machine_id = machine.id and active and settlement_type = 'subsidy_receivable' and settlement_billing_enabled) as partner_billed_buttons
from public.machines machine
where machine.evidence_number::text = '32';
