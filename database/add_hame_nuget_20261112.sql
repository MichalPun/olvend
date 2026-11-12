-- Nová bageta HAMÉ / Simply Fresh Nuget 185 g.
-- Založí produkt, nákupní profil, cenově bezpečné náhrady a příjem 25 ks
-- do skladu BLUČINA se spotřebou do 19. 11. 2026.

begin;

do $$
declare
  v_supplier_id bigint;
  v_product_id bigint;
  v_stock_location_id bigint;
  v_purchase_order_id bigint;
  v_batch_id bigint;
  v_current_quantity numeric(12,3);
  v_delta numeric(12,3);
  v_substitution_slots integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('add-hame-nuget-20261112', 0));

  select id into strict v_supplier_id
  from public.purchase_suppliers
  where name = 'HAMÉ'
    and active is true;

  select id into strict v_stock_location_id
  from public.stock_locations
  where name = 'BLUČINA'
    and location_type = 'warehouse'
    and active is true;

  insert into public.products (
    sku,
    name,
    product_category,
    usage_type,
    base_unit,
    vat_rate,
    purchase_price,
    sale_price,
    shelf_life_days,
    expiry_tracking_mode,
    expiry_warning_days,
    requires_batch_tracking,
    can_be_sold_directly,
    active,
    note
  ) values (
    'SIMPLY-NUGET',
    'Simply Fresh Nuget 185g',
    'food_ready',
    'direct_sale',
    'ks',
    12,
    28.59,
    50,
    8,
    'use_by',
    3,
    true,
    true,
    true,
    'HAMÉ · Simply Fresh · bageta s kuřecími nugety a pikantním dresinkem · 185 g.'
  )
  on conflict (sku) do update set
    name = excluded.name,
    product_category = excluded.product_category,
    usage_type = excluded.usage_type,
    base_unit = excluded.base_unit,
    vat_rate = excluded.vat_rate,
    purchase_price = excluded.purchase_price,
    sale_price = excluded.sale_price,
    shelf_life_days = excluded.shelf_life_days,
    expiry_tracking_mode = excluded.expiry_tracking_mode,
    expiry_warning_days = excluded.expiry_warning_days,
    requires_batch_tracking = excluded.requires_batch_tracking,
    can_be_sold_directly = excluded.can_be_sold_directly,
    active = true,
    note = excluded.note,
    updated_at = now()
  returning id into v_product_id;

  -- Produkt se zobrazí mezi bagetami v nákupním modulu, ale bez znalosti
  -- pravidelného množství se sám nezařadí do automatické stálé objednávky.
  insert into public.purchase_product_profiles (
    supplier_id,
    product_id,
    pilot_scope,
    active,
    reorder_enabled,
    order_weekdays,
    delivery_weekdays,
    lead_time_days,
    base_order_quantity,
    min_order_quantity,
    order_multiple_quantity,
    safety_stock_quantity,
    target_cover_days,
    target_stock_quantity,
    package_quantity,
    note
  ) values (
    v_supplier_id,
    v_product_id,
    'bagette',
    true,
    true,
    array[1,3,5]::smallint[],
    array[1,3,5]::smallint[],
    2,
    0,
    0,
    1,
    0,
    2,
    0,
    1,
    'HAMÉ · nový sortiment Nuget 185 g. Pravidelné množství zatím není nastaveno.'
  )
  on conflict (supplier_id, product_id, pilot_scope) do update set
    active = true,
    reorder_enabled = true,
    order_weekdays = excluded.order_weekdays,
    delivery_weekdays = excluded.delivery_weekdays,
    lead_time_days = excluded.lead_time_days,
    order_multiple_quantity = excluded.order_multiple_quantity,
    package_quantity = excluded.package_quantity,
    note = excluded.note,
    updated_at = now();

  -- Na pokyn vedení může Nuget nahradit libovolnou bagetu HAMÉ.
  -- Při náhradě se zachová zákaznická cena konkrétní pozice.
  update public.machine_planogram_slots
  set allowed_substitutes = case
        when nullif(trim(allowed_substitutes), '') is null then 'SKU SIMPLY-NUGET'
        else allowed_substitutes || ', SKU SIMPLY-NUGET'
      end,
      updated_at = now()
  where active is true
    and product_family = 'HAMÉ chlazený sortiment'
    and substitution_policy = 'approved_list'
    and position('SKU SIMPLY-NUGET' in coalesce(allowed_substitutes, '')) = 0;

  select count(*) into v_substitution_slots
  from public.machine_planogram_slots
  where active is true
    and product_family = 'HAMÉ chlazený sortiment'
    and substitution_policy = 'approved_list'
    and position('SKU SIMPLY-NUGET' in coalesce(allowed_substitutes, '')) > 0;

  if v_substitution_slots = 0 then
    raise exception 'Nuget nebyl přidán do žádné náhradové pozice.';
  end if;

  -- Auditovatelný jednorázový příjem od HAMÉ.
  select id into v_purchase_order_id
  from public.purchase_orders
  where supplier_id = v_supplier_id
    and delivery_date = date '2026-11-12'
    and note like '%HAME-NUGET-20261112%'
  order by id desc
  limit 1
  for update;

  if v_purchase_order_id is null then
    insert into public.purchase_orders (
      supplier_id,
      order_scope,
      status,
      order_date,
      delivery_date,
      received_at,
      received_stock_location_id,
      note
    ) values (
      v_supplier_id,
      'bagette_pilot',
      'received',
      date '2026-11-12',
      date '2026-11-12',
      now(),
      v_stock_location_id,
      'HAME-NUGET-20261112 · jednorázový příjem novinky Simply Fresh Nuget 185 g.'
    ) returning id into v_purchase_order_id;
  end if;

  insert into public.purchase_order_items (
    purchase_order_id,
    product_id,
    ordered_quantity,
    received_quantity,
    unit_cost,
    note
  ) values (
    v_purchase_order_id,
    v_product_id,
    25,
    25,
    28.59,
    'Přijato 25 ks; spotřebujte do 19. 11. 2026.'
  )
  on conflict (purchase_order_id, product_id) do update set
    ordered_quantity = 25,
    received_quantity = 25,
    unit_cost = 28.59,
    note = excluded.note,
    updated_at = now();

  select id into v_batch_id
  from public.inventory_batches
  where product_id = v_product_id
    and lot_code = 'HAME-NUGET-20261119'
  order by id
  limit 1
  for update;

  if v_batch_id is null then
    insert into public.inventory_batches (
      product_id,
      lot_code,
      use_by_date,
      received_at,
      supplier_name,
      note
    ) values (
      v_product_id,
      'HAME-NUGET-20261119',
      date '2026-11-19',
      now(),
      'HAMÉ',
      'Jednorázový příjem 25 ks dne 12. 11. 2026.'
    ) returning id into v_batch_id;
  end if;

  select coalesce(quantity_on_hand, 0)
    into v_current_quantity
  from public.stock_location_balances
  where stock_location_id = v_stock_location_id
    and product_id = v_product_id
    and batch_id = v_batch_id
  order by id
  limit 1
  for update;

  v_current_quantity := coalesce(v_current_quantity, 0);
  if v_current_quantity > 25 then
    raise exception 'Šarže Nuget už má na BLUČINĚ % ks; očekáváno nejvýše 25.', v_current_quantity;
  end if;

  v_delta := 25 - v_current_quantity;
  if v_delta > 0 then
    perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'batch_id', v_batch_id,
      'from_stock_location_id', null,
      'to_stock_location_id', v_stock_location_id,
      'movement_type', 'receipt',
      'quantity_base_units', v_delta,
      'unit_price', 28.59,
      'reference_type', 'purchase_order',
      'reference_id', v_purchase_order_id::text,
      'note', 'Příjem HAMÉ Simply Fresh Nuget 185 g; expirace 19. 11. 2026.'
    )));
  end if;

  select quantity_on_hand into v_current_quantity
  from public.stock_location_balances
  where stock_location_id = v_stock_location_id
    and product_id = v_product_id
    and batch_id = v_batch_id;

  if v_current_quantity is distinct from 25::numeric then
    raise exception 'Kontrola zásoby Nuget selhala: očekáváno 25 ks, nalezeno %.', v_current_quantity;
  end if;

  if exists (
    select 1 from public.products
    where sku = '15'
      and active is distinct from false
  ) then
    raise exception 'Historický Golf SKU 15 byl neočekávaně aktivován.';
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';

select
  product.id,
  product.sku,
  product.name,
  product.purchase_price,
  product.sale_price,
  batch.use_by_date,
  balance.quantity_on_hand as blucina_quantity,
  (
    select count(*)
    from public.machine_planogram_slots slot
    where slot.active is true
      and position('SKU SIMPLY-NUGET' in coalesce(slot.allowed_substitutes, '')) > 0
  ) as substitute_slots
from public.products product
join public.inventory_batches batch
  on batch.product_id = product.id
 and batch.lot_code = 'HAME-NUGET-20261119'
join public.stock_location_balances balance
  on balance.product_id = product.id
 and balance.batch_id = batch.id
 and balance.stock_location_id = 1
where product.sku = 'SIMPLY-NUGET';
