do $$
declare
  v_machine_id bigint := 95;
begin
  delete from public.machine_coffee_recipe_items
  where machine_id = v_machine_id;

  insert into public.machine_coffee_recipe_items (
    machine_id,
    coffee_button_id,
    coffee_container_id,
    product_id,
    container_code,
    ingredient_name,
    quantity_per_vend,
    unit,
    sort_order,
    active
  )
  select
    v_machine_id,
    button.id,
    container.id,
    recipe_item.product_id,
    container.container_code,
    container.product_name,
    recipe_item.quantity,
    recipe_item.unit,
    recipe_item.id,
    true
  from public.machine_coffee_buttons button
  join lateral (
    select recipe.*
    from public.recipes recipe
    where recipe.machine_type = 'product_catalog'
      and recipe.selection_code = 'product:' || button.product_id::text
    order by (recipe.sale_price = button.sale_price_czk) desc nulls last, recipe.id desc
    limit 1
  ) recipe on true
  join public.recipe_items recipe_item on recipe_item.recipe_id = recipe.id
  join public.machine_coffee_containers container
    on container.machine_id = v_machine_id
   and container.product_id = recipe_item.product_id
   and container.active = true
  where button.machine_id = v_machine_id
    and button.active = true;

  insert into public.machine_planogram_slots (
    machine_id,
    slot_code,
    product_name,
    product_sku,
    price_czk,
    dex_price_czk,
    capacity_units,
    current_units,
    fill_percent,
    active,
    sort_order,
    telemetry_key,
    customer_price_czk,
    settlement_type,
    settlement_amount_czk,
    settlement_partner,
    settlement_billing_enabled,
    settlement_note,
    planned_product_name,
    planned_product_sku,
    planned_price_czk,
    substitution_policy,
    allowed_substitutes,
    operator_instruction,
    note
  )
  select
    v_machine_id,
    selection_code,
    product_name,
    product_sku,
    sale_price_czk,
    sale_price_czk,
    null,
    null,
    null,
    active,
    sort_order,
    selection_code,
    customer_price_czk,
    settlement_type,
    settlement_amount_czk,
    settlement_partner,
    settlement_billing_enabled,
    settlement_note,
    planned_product_name,
    planned_product_sku,
    planned_price_czk,
    substitution_policy,
    allowed_substitutes,
    operator_instruction,
    'Zrcadlový slot pro telemetrii kávy TID 592144 / automat 117.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update set
    product_name = excluded.product_name,
    product_sku = excluded.product_sku,
    price_czk = excluded.price_czk,
    dex_price_czk = excluded.dex_price_czk,
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
end $$;
