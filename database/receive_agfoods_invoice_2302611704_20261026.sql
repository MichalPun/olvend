begin;

-- AG FOODS invoice P01 2302611704 / delivery note DOL2302648530.
-- The invoice is expressed in cartons. The confirmed conversions are:
--   Caffé PRESTO: 10 cartons x 6 x 1 kg = 60 kg
--   ENZO BENCINI 10% cocoa: 20 cartons x 10 x 1 kg = 200 kg
-- Existing ingredient cards are intentionally renamed instead of duplicated,
-- because their product IDs are already linked to machines and recipes.
do $$
declare
  v_supplier_id bigint := 11;
  v_stock_location_id bigint := 1;
  v_order_id bigint;
  v_presto_batch_id bigint;
  v_cocoa_batch_id bigint;
  v_series_number integer;
  v_internal_number text;
  v_received_at timestamptz := now();
  v_base_note text := '[typ:invoice][splatnost:2026-10-22][mena:CZK][kurz:1][dph-rezim:domestic] '
    || 'Objednávka OBJ2302606924. Importováno z PDF. '
    || 'Dodací list DOL2302648530; VS 2302611704; základ 28 300,00 Kč; DPH 3 396,00 Kč; celkem 31 696,00 Kč.';
begin
  if not exists (
    select 1 from public.purchase_suppliers
    where id = v_supplier_id
      and company_id = '05651531'
      and active = true
  ) then
    raise exception 'Chybí aktivní dodavatel AG FOODS Group a.s. (ID 11).';
  end if;

  if not exists (
    select 1 from public.stock_locations
    where id = v_stock_location_id
      and location_type = 'warehouse'
      and warehouse_id = 1
      and active = true
  ) then
    raise exception 'Chybí aktivní skladová lokace BLUČINA (ID 1).';
  end if;

  if not exists (
    select 1 from public.products
    where id = 26 and sku = '201' and base_unit = 'kg' and active = true
  ) then
    raise exception 'Skladová karta kávy SKU 201 (ID 26) neodpovídá očekávání.';
  end if;

  if not exists (
    select 1 from public.products
    where id = 106 and sku = '47' and base_unit = 'kg' and active = true
  ) then
    raise exception 'Skladová karta kakaa SKU 47 (ID 106) neodpovídá očekávání.';
  end if;

  update public.products
  set name = 'Caffé Presto 1 kg',
      ean = '8594003664045',
      purchase_price = 225.00,
      vat_rate = 12,
      note = case
        when coalesce(note, '') like '%[agfoods-presto-20261008]%'
          then note
        else concat_ws(E'\n', nullif(note, ''),
          '[agfoods-presto-20261008] Přejmenováno z Barbera Tris; dodavatel AG FOODS, kód 510006, karton 6 x 1 kg.')
      end,
      updated_at = now()
  where id = 26;

  update public.products
  set name = 'Cocoa 10% Enzo Bencini 1 kg',
      ean = '8594162110872',
      purchase_price = 74.00,
      vat_rate = 12,
      note = case
        when coalesce(note, '') like '%[agfoods-enzo-20261008]%'
          then note
        else concat_ws(E'\n', nullif(note, ''),
          '[agfoods-enzo-20261008] Přejmenováno z oVe DRINK WITH COCOA; dodavatel AG FOODS, kód 20396, karton 10 x 1 kg.')
      end,
      updated_at = now()
  where id = 106;

  update public.product_packages
  set package_name = 'Karton 6 x 1 kg',
      units_per_package = 6,
      updated_at = now()
  where id = 99 and product_id = 26 and is_default = false;

  update public.product_packages
  set package_name = 'Karton 10 x 1 kg',
      units_per_package = 10,
      updated_at = now()
  where id = 110 and product_id = 106 and is_default = false;

  update public.machine_coffee_containers
  set product_name = case product_id
      when 26 then 'Caffé Presto 1 kg'
      when 106 then 'Cocoa 10% Enzo Bencini 1 kg'
    end,
    updated_at = now()
  where product_id in (26, 106);

  update public.machine_coffee_recipe_items
  set ingredient_name = case product_id
      when 26 then 'Caffé Presto 1 kg'
      when 106 then 'Cocoa 10% Enzo Bencini 1 kg'
    end,
    updated_at = now()
  where product_id in (26, 106);

  update public.machine_coffee_buttons
  set product_name = case product_id
      when 26 then 'Caffé Presto 1 kg'
      when 106 then 'Cocoa 10% Enzo Bencini 1 kg'
    end,
    updated_at = now()
  where product_id in (26, 106);

  insert into public.supplier_product_mappings (
    supplier_id, product_id, supplier_item_code, ean, supplier_item_name,
    invoice_unit_code, base_units_per_invoice_unit, last_unit_price,
    last_seen_at, active
  ) values
  (v_supplier_id, 26, '510006', '8594003664045', 'Caffé PRESTO 1000 g', 'kt', 6, 225.00, v_received_at, true),
  (v_supplier_id, 106, '20396', '8594162110872', 'ENZO BENCINI 10% cocoa 1000 g', 'kt', 10, 74.00, v_received_at, true)
  on conflict (supplier_id, supplier_item_code) do update
  set product_id = excluded.product_id,
      ean = excluded.ean,
      supplier_item_name = excluded.supplier_item_name,
      invoice_unit_code = excluded.invoice_unit_code,
      base_units_per_invoice_unit = excluded.base_units_per_invoice_unit,
      last_unit_price = excluded.last_unit_price,
      last_seen_at = excluded.last_seen_at,
      active = true,
      updated_at = now();

  select id into v_order_id
  from public.purchase_orders
  where replace(upper(coalesce(invoice_number, '')), ' ', '') = 'P012302611704'
    and status <> 'cancelled'
  order by id
  limit 1;

  if v_order_id is not null then
    if not exists (
      select 1
      from public.purchase_orders po
      where po.id = v_order_id
        and po.supplier_id = v_supplier_id
        and po.status = 'received'
        and po.delivery_note_number = 'DOL2302648530'
        and po.received_stock_location_id = v_stock_location_id
    ) or not exists (
      select 1
      from public.purchase_order_items poi
      where poi.purchase_order_id = v_order_id and poi.product_id = 26
        and poi.received_quantity = 60 and poi.unit_cost = 225
    ) or not exists (
      select 1
      from public.purchase_order_items poi
      where poi.purchase_order_id = v_order_id and poi.product_id = 106
        and poi.received_quantity = 200 and poi.unit_cost = 74
    ) then
      raise exception 'Faktura P01 2302611704 existuje, ale neodpovídá potvrzenému příjmu.';
    end if;
    return;
  end if;

  select coalesce(max(substring(note from '\[rada:OVFP26-([0-9]+)\]')::integer), 0) + 1
  into v_series_number
  from public.purchase_orders
  where note ~ '\[rada:OVFP26-[0-9]+\]';

  v_internal_number := 'OVFP26-' || lpad(v_series_number::text, 4, '0');

  insert into public.purchase_orders (
    supplier_id, order_scope, status, order_date, delivery_date, note,
    delivery_note_number, invoice_number, received_at, received_stock_location_id
  ) values (
    v_supplier_id, 'general', 'received', date '2026-10-08', date '2026-10-08',
    '[rada:' || v_internal_number || '] ' || v_base_note,
    'DOL2302648530', 'P01 2302611704', v_received_at, v_stock_location_id
  ) returning id into v_order_id;

  insert into public.purchase_order_items (
    purchase_order_id, product_id, ordered_quantity, received_quantity, unit_cost, note
  ) values
  (
    v_order_id, 26, 60, 60, 225.00,
    '[dph:12][celkem-bez-dph:13500.00][celkem-s-dph:15120.00][mena:CZK][kurz:1]'
      || '[doklad-bez-dph:13500.00][doklad-celkem:15120.00]' || E'\n'
      || '510006 Caffé PRESTO 1000 g · 10 kartonů x 6 ks x 1 kg = 60 kg '
      || '· 225,00 Kč/kg · expirace 2028-08-19'
  ),
  (
    v_order_id, 106, 200, 200, 74.00,
    '[dph:12][celkem-bez-dph:14800.00][celkem-s-dph:16576.00][mena:CZK][kurz:1]'
      || '[doklad-bez-dph:14800.00][doklad-celkem:16576.00]' || E'\n'
      || '20396 ENZO BENCINI 10% cocoa 1000 g · 20 kartonů x 10 ks x 1 kg = 200 kg '
      || '· 74,00 Kč/kg · expirace 2028-02-26'
  );

  insert into public.inventory_batches (
    product_id, lot_code, best_before_date, received_at, supplier_name, note
  ) values (
    26, 'AG-2302611704-510006', date '2028-08-19', v_received_at,
    'AG FOODS Group a.s.', 'Faktura P01 2302611704; 10 kartonů x 6 x 1 kg'
  ) returning id into v_presto_batch_id;

  insert into public.inventory_batches (
    product_id, lot_code, best_before_date, received_at, supplier_name, note
  ) values (
    106, 'AG-2302611704-20396', date '2028-02-26', v_received_at,
    'AG FOODS Group a.s.', 'Faktura P01 2302611704; 20 kartonů x 10 x 1 kg'
  ) returning id into v_cocoa_batch_id;

  insert into public.stock_movements_v13 (
    product_id, batch_id, to_stock_location_id, movement_type,
    quantity_base_units, package_id, package_count, unit_price,
    reference_type, reference_id, note, created_at
  ) values
  (26, v_presto_batch_id, v_stock_location_id, 'receipt', 60, 99, 10, 225.00,
    'purchase_order', v_order_id::text, v_base_note, v_received_at),
  (106, v_cocoa_batch_id, v_stock_location_id, 'receipt', 200, 110, 20, 74.00,
    'purchase_order', v_order_id::text, v_base_note, v_received_at);

  insert into public.stock_location_balances (
    stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
  ) values
  (v_stock_location_id, 26, v_presto_batch_id, 60, 0, v_received_at),
  (v_stock_location_id, 106, v_cocoa_batch_id, 200, 0, v_received_at)
  on conflict (stock_location_id, product_id, batch_id) do update
  set quantity_on_hand = public.stock_location_balances.quantity_on_hand + excluded.quantity_on_hand,
      updated_at = excluded.updated_at;

  if not exists (
    select 1 from public.purchase_order_items
    where purchase_order_id = v_order_id and product_id = 26
      and received_quantity = 60 and unit_cost = 225
  ) or not exists (
    select 1 from public.purchase_order_items
    where purchase_order_id = v_order_id and product_id = 106
      and received_quantity = 200 and unit_cost = 74
  ) then
    raise exception 'Položky faktury P01 2302611704 nebyly uloženy správně.';
  end if;
end
$$;

commit;

select json_build_object(
  'purchase_order_id', po.id,
  'internal_number', substring(po.note from '\[rada:([^]]+)\]'),
  'invoice_number', po.invoice_number,
  'status', po.status,
  'supplier', ps.name,
  'warehouse', sl.name,
  'received_kg', sum(poi.received_quantity),
  'net_czk', sum(poi.received_quantity * poi.unit_cost),
  'items', json_agg(json_build_object(
    'product_id', p.id,
    'sku', p.sku,
    'name', p.name,
    'quantity_kg', poi.received_quantity,
    'unit_cost_czk_kg', poi.unit_cost
  ) order by poi.id)
) as receipt
from public.purchase_orders po
join public.purchase_suppliers ps on ps.id = po.supplier_id
join public.stock_locations sl on sl.id = po.received_stock_location_id
join public.purchase_order_items poi on poi.purchase_order_id = po.id
join public.products p on p.id = poi.product_id
where replace(upper(coalesce(po.invoice_number, '')), ' ', '') = 'P012302611704'
  and po.status <> 'cancelled'
group by po.id, ps.name, sl.name;
