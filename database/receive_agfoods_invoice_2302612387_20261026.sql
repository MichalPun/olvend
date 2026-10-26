begin;

-- AG FOODS invoice P01 2302612387 / delivery note DOL2302651477.
-- The invoice is expressed in cartons. Confirmed conversions:
--   AG PRO Creamer white: 20 cartons x 10 x 1 kg = 200 kg
--   Caffé PRESTO: 7 cartons x 6 x 1 kg = 42 kg
--   ENZO BENCINI Staccato: 5 cartons x 10 x 0.5 kg = 25 kg
-- Existing ingredient cards are renamed instead of duplicated because their
-- product IDs are already linked to machines, recipes and stock history.
do $$
declare
  v_supplier_id bigint := 11;
  v_stock_location_id bigint := 1;
  v_order_id bigint;
  v_creamer_batch_id bigint;
  v_presto_batch_id bigint;
  v_staccato_batch_id bigint;
  v_series_number integer;
  v_internal_number text;
  v_received_at timestamptz := now();
  v_base_note text := '[typ:invoice][splatnost:2026-11-12][mena:CZK][kurz:1][dph-rezim:domestic] '
    || 'Objednávka OBJ2302607349. Importováno z PDF. '
    || 'Dodací list DOL2302651477; VS 2302612387; základ 37 150,00 Kč; DPH 4 458,00 Kč; celkem 41 608,00 Kč.';
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
    where id = 104 and sku = '48' and base_unit = 'kg' and active = true
  ) then
    raise exception 'Skladová karta Creameru SKU 48 (ID 104) neodpovídá očekávání.';
  end if;

  if not exists (
    select 1 from public.products
    where id = 26 and sku = '201' and base_unit = 'kg' and active = true
  ) then
    raise exception 'Skladová karta kávy SKU 201 (ID 26) neodpovídá očekávání.';
  end if;

  if not exists (
    select 1 from public.products
    where id = 108 and sku = '44' and base_unit = 'kg' and active = true
  ) then
    raise exception 'Skladová karta kávy SKU 44 (ID 108) neodpovídá očekávání.';
  end if;

  if not exists (
    select 1 from public.product_packages
    where id = 7 and product_id = 104 and is_default = true
  ) or not exists (
    select 1 from public.product_packages
    where id = 109 and product_id = 104 and is_default = false
  ) or not exists (
    select 1 from public.product_packages
    where id = 99 and product_id = 26 and is_default = false
  ) or not exists (
    select 1 from public.product_packages
    where id = 32 and product_id = 108 and is_default = true
  ) or not exists (
    select 1 from public.product_packages
    where id = 112 and product_id = 108 and is_default = false
  ) then
    raise exception 'Balení některé položky faktury neodpovídá očekávaným kartám.';
  end if;

  update public.products
  set name = 'Creamer White AG PRO 1 kg',
      purchase_price = 86.00,
      vat_rate = 12,
      image_path = 'static:./assets/product-images/48.jpg',
      image_updated_at = now(),
      note = case
        when coalesce(note, '') like '%[agfoods-creamer-20261022]%'
          then note
        else concat_ws(E'\n', nullif(note, ''),
          '[agfoods-creamer-20261022] Přejmenováno z oVe COFFEE CREAMER WHITE; dodavatel AG FOODS, kód 20430, karton 10 x 1 kg.')
      end,
      updated_at = now()
  where id = 104;

  update public.products
  set name = 'Caffé Presto 1 kg',
      purchase_price = 225.00,
      vat_rate = 12,
      updated_at = now()
  where id = 26;

  update public.products
  set name = 'Staccato 0,5 kg Enzo Bencini',
      ean = '8594003661259',
      purchase_price = 420.00,
      vat_rate = 12,
      image_path = 'static:./assets/product-images/44.jpg',
      image_updated_at = now(),
      note = case
        when coalesce(note, '') like '%[agfoods-staccato-20261022]%'
          then note
        else concat_ws(E'\n', nullif(note, ''),
          '[agfoods-staccato-20261022] Přejmenováno z oVe FD COFFEE SOPHIA 500g; dodavatel AG FOODS, kód 676230, karton 10 x 0,5 kg.')
      end,
      updated_at = now()
  where id = 108;

  update public.product_packages
  set package_name = '1 kg',
      units_per_package = 1,
      updated_at = now()
  where id = 7 and product_id = 104 and is_default = true;

  update public.product_packages
  set package_name = 'Karton 10 x 1 kg',
      units_per_package = 10,
      updated_at = now()
  where id = 109 and product_id = 104 and is_default = false;

  update public.product_packages
  set package_name = '0,5 kg',
      units_per_package = 0.5,
      updated_at = now()
  where id = 32 and product_id = 108 and is_default = true;

  update public.product_packages
  set package_name = 'Karton 10 x 0,5 kg',
      units_per_package = 5,
      updated_at = now()
  where id = 112 and product_id = 108 and is_default = false;

  update public.machine_coffee_containers
  set product_name = case product_id
      when 104 then 'Creamer White AG PRO 1 kg'
      when 108 then 'Staccato 0,5 kg Enzo Bencini'
    end,
    updated_at = now()
  where product_id in (104, 108);

  update public.machine_coffee_recipe_items
  set ingredient_name = case product_id
      when 104 then 'Creamer White AG PRO 1 kg'
      when 108 then 'Staccato 0,5 kg Enzo Bencini'
    end,
    updated_at = now()
  where product_id in (104, 108);

  update public.machine_coffee_buttons
  set product_name = case product_id
      when 104 then 'Creamer White AG PRO 1 kg'
      when 108 then 'Staccato 0,5 kg Enzo Bencini'
    end,
    updated_at = now()
  where product_id in (104, 108);

  insert into public.supplier_product_mappings (
    supplier_id, product_id, supplier_item_code, ean, supplier_item_name,
    invoice_unit_code, base_units_per_invoice_unit, last_unit_price,
    last_seen_at, active
  ) values
  (v_supplier_id, 104, '20430', null, 'AG PRO Creamer white 1000 g', 'kt', 10, 86.00, v_received_at, true),
  (v_supplier_id, 26, '510006', '8594003664045', 'Caffé PRESTO 1000 g', 'kt', 6, 225.00, v_received_at, true),
  (v_supplier_id, 108, '676230', '8594003661259', 'ENZO BENCINI Staccato 500 g', 'kt', 5, 420.00, v_received_at, true)
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
  where replace(upper(coalesce(invoice_number, '')), ' ', '') = 'P012302612387'
    and status <> 'cancelled'
  order by id
  limit 1;

  if v_order_id is not null then
    if not exists (
      select 1 from public.purchase_orders po
      where po.id = v_order_id
        and po.supplier_id = v_supplier_id
        and po.status = 'received'
        and po.delivery_note_number = 'DOL2302651477'
        and po.received_stock_location_id = v_stock_location_id
    ) or not exists (
      select 1 from public.purchase_order_items poi
      where poi.purchase_order_id = v_order_id and poi.product_id = 104
        and poi.received_quantity = 200 and poi.unit_cost = 86
    ) or not exists (
      select 1 from public.purchase_order_items poi
      where poi.purchase_order_id = v_order_id and poi.product_id = 26
        and poi.received_quantity = 42 and poi.unit_cost = 225
    ) or not exists (
      select 1 from public.purchase_order_items poi
      where poi.purchase_order_id = v_order_id and poi.product_id = 108
        and poi.received_quantity = 25 and poi.unit_cost = 420
    ) then
      raise exception 'Faktura P01 2302612387 existuje, ale neodpovídá potvrzenému příjmu.';
    end if;
    return;
  end if;

  select coalesce(max(substring(note from '\[rada:OVFP26-([0-9]+)\]')::integer), 0) + 1
  into v_series_number
  from public.purchase_orders
  where note ~ '\[rada:OVFP26-[0-9]+\]';

  v_internal_number := 'OVFP26-' || lpad(v_series_number::text, 4, '0');

  insert into public.purchase_orders (
    supplier_id, order_scope, status, order_date, delivery_date, document_type,
    due_date, note, delivery_note_number, invoice_number, received_at,
    received_stock_location_id
  ) values (
    v_supplier_id, 'general', 'received', date '2026-10-22', date '2026-10-22',
    'invoice', date '2026-11-12', '[rada:' || v_internal_number || '] ' || v_base_note,
    'DOL2302651477', 'P01 2302612387', v_received_at, v_stock_location_id
  ) returning id into v_order_id;

  insert into public.purchase_order_items (
    purchase_order_id, product_id, ordered_quantity, received_quantity, unit_cost, note
  ) values
  (
    v_order_id, 104, 200, 200, 86.00,
    '[dph:12][celkem-bez-dph:17200.00][celkem-s-dph:19264.00][mena:CZK][kurz:1]'
      || '[doklad-bez-dph:17200.00][doklad-celkem:19264.00]' || E'\n'
      || '20430 AG PRO Creamer white 1000 g · 20 kartonů x 10 ks x 1 kg = 200 kg '
      || '· 86,00 Kč/kg · expirace 2028-04-13'
  ),
  (
    v_order_id, 26, 42, 42, 225.00,
    '[dph:12][celkem-bez-dph:9450.00][celkem-s-dph:10584.00][mena:CZK][kurz:1]'
      || '[doklad-bez-dph:9450.00][doklad-celkem:10584.00]' || E'\n'
      || '510006 Caffé PRESTO 1000 g · 7 kartonů x 6 ks x 1 kg = 42 kg '
      || '· 225,00 Kč/kg · expirace 2028-08-19'
  ),
  (
    v_order_id, 108, 25, 25, 420.00,
    '[dph:12][celkem-bez-dph:10500.00][celkem-s-dph:11760.00][mena:CZK][kurz:1]'
      || '[doklad-bez-dph:10500.00][doklad-celkem:11760.00]' || E'\n'
      || '676230 ENZO BENCINI Staccato 500 g · 5 kartonů x 10 ks x 0,5 kg = 25 kg '
      || '· 420,00 Kč/kg (210,00 Kč/balení) · expirace 2027-01-02'
  );

  insert into public.inventory_batches (
    product_id, lot_code, best_before_date, received_at, supplier_name, note
  ) values (
    104, 'AG-2302612387-20430', date '2028-04-13', v_received_at,
    'AG FOODS Group a.s.', 'Faktura P01 2302612387; 20 kartonů x 10 x 1 kg'
  ) returning id into v_creamer_batch_id;

  insert into public.inventory_batches (
    product_id, lot_code, best_before_date, received_at, supplier_name, note
  ) values (
    26, 'AG-2302612387-510006', date '2028-08-19', v_received_at,
    'AG FOODS Group a.s.', 'Faktura P01 2302612387; 7 kartonů x 6 x 1 kg'
  ) returning id into v_presto_batch_id;

  insert into public.inventory_batches (
    product_id, lot_code, best_before_date, received_at, supplier_name, note
  ) values (
    108, 'AG-2302612387-676230', date '2027-01-02', v_received_at,
    'AG FOODS Group a.s.', 'Faktura P01 2302612387; 5 kartonů x 10 x 0,5 kg'
  ) returning id into v_staccato_batch_id;

  insert into public.stock_movements_v13 (
    product_id, batch_id, to_stock_location_id, movement_type,
    quantity_base_units, package_id, package_count, unit_price,
    reference_type, reference_id, note, created_at
  ) values
  (104, v_creamer_batch_id, v_stock_location_id, 'receipt', 200, 109, 20, 86.00,
    'purchase_order', v_order_id::text, v_base_note, v_received_at),
  (26, v_presto_batch_id, v_stock_location_id, 'receipt', 42, 99, 7, 225.00,
    'purchase_order', v_order_id::text, v_base_note, v_received_at),
  (108, v_staccato_batch_id, v_stock_location_id, 'receipt', 25, 112, 5, 420.00,
    'purchase_order', v_order_id::text, v_base_note, v_received_at);

  insert into public.stock_location_balances (
    stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
  ) values
  (v_stock_location_id, 104, v_creamer_batch_id, 200, 0, v_received_at),
  (v_stock_location_id, 26, v_presto_batch_id, 42, 0, v_received_at),
  (v_stock_location_id, 108, v_staccato_batch_id, 25, 0, v_received_at)
  on conflict (stock_location_id, product_id, batch_id) do update
  set quantity_on_hand = public.stock_location_balances.quantity_on_hand + excluded.quantity_on_hand,
      updated_at = excluded.updated_at;

  if not exists (
    select 1 from public.purchase_order_items
    where purchase_order_id = v_order_id and product_id = 104
      and received_quantity = 200 and unit_cost = 86
  ) or not exists (
    select 1 from public.purchase_order_items
    where purchase_order_id = v_order_id and product_id = 26
      and received_quantity = 42 and unit_cost = 225
  ) or not exists (
    select 1 from public.purchase_order_items
    where purchase_order_id = v_order_id and product_id = 108
      and received_quantity = 25 and unit_cost = 420
  ) then
    raise exception 'Položky faktury P01 2302612387 nebyly uloženy správně.';
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
    'unit_cost_czk_kg', poi.unit_cost,
    'image_path', p.image_path
  ) order by poi.id)
) as receipt
from public.purchase_orders po
join public.purchase_suppliers ps on ps.id = po.supplier_id
join public.stock_locations sl on sl.id = po.received_stock_location_id
join public.purchase_order_items poi on poi.purchase_order_id = po.id
join public.products p on p.id = poi.product_id
where replace(upper(coalesce(po.invoice_number, '')), ' ', '') = 'P012302612387'
  and po.status <> 'cancelled'
group by po.id, ps.name, sl.name;
