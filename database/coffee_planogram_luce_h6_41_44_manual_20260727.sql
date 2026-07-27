-- Manual Luce H6 planograms imported from VendSoft exports dated 2026-07-27.
-- Machines 41 and 44 have no telemetry or payment terminal.
-- Operators record only irreversible revenue/portion counters and real container refills.

do $$
declare
  machine_row record;
begin
  for machine_row in
    select *
    from (values
      (35::bigint, 41::integer, 15::numeric, array[1400,3000,1000,2000,3000,1999,399]::numeric[]),
      (38::bigint, 44::integer, 16::numeric, array[1400,3000,999,2000,2999,1999,398]::numeric[])
    ) as source(machine_id, evidence_number, sale_price, current_quantities)
  loop
    update public.machines
    set
      machine_type = 'Coffee',
      brand = 'Rheavendors',
      name = 'Luce H6',
      sales_tracking_mode = 'manual_counters',
      note = concat_ws(' ', nullif(note, ''), 'Ruční H6: operátor zapisuje nemazací tržbu, porce a skutečně doplněná balení zásobníků. Prodeje tlačítek se ručně neevidují.')
    where id = machine_row.machine_id;

    update public.machine_coffee_containers
    set active = false
    where machine_id = machine_row.machine_id;

    update public.machine_coffee_buttons
    set active = false
    where machine_id = machine_row.machine_id;

    update public.machine_planogram_slots
    set active = false
    where machine_id = machine_row.machine_id;

    insert into public.machine_coffee_containers (
      machine_id,
      container_code,
      product_id,
      product_sku,
      product_name,
      capacity_quantity,
      current_quantity,
      unit,
      refill_package_quantity,
      refill_package_unit,
      min_refill_quantity,
      sort_order,
      active,
      note
    )
    select
      machine_row.machine_id,
      definition.container_code,
      product.id,
      product.sku,
      product.name,
      definition.capacity_quantity,
      machine_row.current_quantities[definition.sort_order],
      definition.unit,
      definition.refill_package_quantity,
      definition.refill_package_unit,
      definition.refill_package_quantity,
      definition.sort_order,
      true,
      format(
        'Ruční zásobník H6, automat %s. Operátor zapisuje počet skutečně doplněných celých balení.',
        machine_row.evidence_number
      )
    from (values
      ('Z1', '52', 1400::numeric, 'g', 700::numeric, 'g', 1),
      ('Z2', '43', 3000::numeric, 'g', 1500::numeric, 'g', 2),
      ('Z3', '44', 1000::numeric, 'g', 500::numeric, 'g', 3),
      ('Z4', '48', 2000::numeric, 'g', 1000::numeric, 'g', 4),
      ('Z5', '47', 3000::numeric, 'g', 1000::numeric, 'g', 5),
      ('Z6', '46', 2000::numeric, 'g', 1000::numeric, 'g', 6),
      ('Z7', '45', 400::numeric, 'ks', 50::numeric, 'ks', 7)
    ) as definition(
      container_code,
      product_sku,
      capacity_quantity,
      unit,
      refill_package_quantity,
      refill_package_unit,
      sort_order
    )
    join public.products product on product.sku = definition.product_sku
    on conflict (machine_id, container_code) do update
    set
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
      active = true,
      note = excluded.note,
      updated_at = now();

    insert into public.machine_coffee_buttons (
      machine_id,
      selection_code,
      product_id,
      product_sku,
      product_name,
      sale_price_czk,
      customer_price_czk,
      settlement_type,
      settlement_amount_czk,
      settlement_billing_enabled,
      substitution_policy,
      last_counter,
      grid_column,
      grid_row_from_bottom,
      sort_order,
      active,
      note
    )
    select
      machine_row.machine_id,
      definition.selection_code,
      product.id,
      product.sku,
      product.name,
      machine_row.sale_price,
      machine_row.sale_price,
      'none',
      0,
      false,
      'exact',
      null,
      definition.grid_column,
      definition.grid_row_from_bottom,
      definition.sort_order,
      true,
      format(
        'Manažerský planogram H6, automat %s. Operátor prodeje jednotlivých tlačítek nezapisuje.',
        machine_row.evidence_number
      )
    from (values
      ('1',  '242', 1, 4, 1),
      ('2',  '215', 1, 3, 2),
      ('3',  '239', 1, 2, 3),
      ('4',  '215', 1, 1, 4),
      ('5',  '222', 2, 4, 5),
      ('6',  '253', 2, 3, 6),
      ('7',  '222', 2, 2, 7),
      ('8',  '245', 2, 1, 8),
      ('9',  '233', 3, 4, 9),
      ('10', '238', 3, 3, 10),
      ('11', '234', 3, 2, 11),
      ('12', '230', 3, 1, 12)
    ) as definition(selection_code, product_sku, grid_column, grid_row_from_bottom, sort_order)
    join public.products product on product.sku = definition.product_sku
    on conflict (machine_id, selection_code) do update
    set
      product_id = excluded.product_id,
      product_sku = excluded.product_sku,
      product_name = excluded.product_name,
      sale_price_czk = excluded.sale_price_czk,
      customer_price_czk = excluded.customer_price_czk,
      settlement_type = excluded.settlement_type,
      settlement_amount_czk = excluded.settlement_amount_czk,
      settlement_billing_enabled = excluded.settlement_billing_enabled,
      substitution_policy = excluded.substitution_policy,
      last_counter = null,
      grid_column = excluded.grid_column,
      grid_row_from_bottom = excluded.grid_row_from_bottom,
      sort_order = excluded.sort_order,
      active = true,
      note = excluded.note,
      updated_at = now();

    delete from public.machine_coffee_recipe_items
    where machine_id = machine_row.machine_id;

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
      machine_row.machine_id,
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
      order by
        (recipe.sale_price = button.sale_price_czk) desc nulls last,
        recipe.id desc
      limit 1
    ) recipe on true
    join public.recipe_items recipe_item on recipe_item.recipe_id = recipe.id
    left join public.machine_coffee_containers container
      on container.machine_id = machine_row.machine_id
     and container.product_id = recipe_item.product_id
    where button.machine_id = machine_row.machine_id
      and button.active;

    insert into public.machine_planogram_slots (
      machine_id,
      slot_code,
      product_name,
      product_sku,
      price_czk,
      dex_price_czk,
      active,
      sort_order,
      telemetry_key,
      customer_price_czk,
      settlement_type,
      settlement_amount_czk,
      settlement_billing_enabled,
      substitution_policy,
      note
    )
    select
      machine_row.machine_id,
      button.selection_code,
      button.product_name,
      button.product_sku,
      button.sale_price_czk,
      button.sale_price_czk,
      true,
      button.sort_order,
      null,
      button.customer_price_czk,
      button.settlement_type,
      button.settlement_amount_czk,
      button.settlement_billing_enabled,
      button.substitution_policy,
      'Manažerský planogram ručního H6; bez telemetrického párování prodejů tlačítek.'
    from public.machine_coffee_buttons button
    where button.machine_id = machine_row.machine_id
      and button.active
    on conflict (machine_id, slot_code) do update
    set
      product_name = excluded.product_name,
      product_sku = excluded.product_sku,
      price_czk = excluded.price_czk,
      dex_price_czk = excluded.dex_price_czk,
      active = true,
      sort_order = excluded.sort_order,
      telemetry_key = null,
      customer_price_czk = excluded.customer_price_czk,
      settlement_type = excluded.settlement_type,
      settlement_amount_czk = excluded.settlement_amount_czk,
      settlement_billing_enabled = excluded.settlement_billing_enabled,
      substitution_policy = excluded.substitution_policy,
      note = excluded.note,
      updated_at = now();
  end loop;
end $$;

select
  machine.evidence_number,
  machine.sales_tracking_mode,
  count(distinct container.id) filter (where container.active) as active_containers,
  count(distinct button.id) filter (where button.active) as active_buttons,
  count(distinct recipe_item.id) filter (where recipe_item.active) as active_recipe_items
from public.machines machine
left join public.machine_coffee_containers container on container.machine_id = machine.id
left join public.machine_coffee_buttons button on button.machine_id = machine.id
left join public.machine_coffee_recipe_items recipe_item on recipe_item.machine_id = machine.id
where machine.id in (35, 38)
group by machine.evidence_number, machine.sales_tracking_mode
order by machine.evidence_number;
