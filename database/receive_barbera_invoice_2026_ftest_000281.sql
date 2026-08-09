-- Přijetí doprovodné faktury Barbera 2026/FTEST/000281 do hlavního skladu BLUČINA.
-- Zdroj: Fatt_Accompagnatoria - 2026_FTEST_000281 (2).pdf
-- Kurz EUR dle kurzovního lístku ČNB pro 23. 7. 2026: 24,185 CZK/EUR.

do $$
declare
  v_supplier_id bigint := 5;
  v_stock_location_id bigint := 1;
  v_order_id bigint;
  v_series_number integer;
  v_internal_number text;
  v_received_at timestamptz := now();
  v_base_note text := '[typ:invoice][splatnost:2026-07-23][mena:EUR][kurz:24.185][dph-rezim:eu_reverse_charge] '
    || 'Objednávka 2026/ODV/003303. Importováno z PDF. '
    || 'Faktura byla dle dokladu uhrazena 20. 7. 2026; zbývá uhradit 0 EUR.';
begin
  if exists (
    select 1
    from public.purchase_orders
    where replace(upper(coalesce(invoice_number, '')), ' ', '') = '2026/FTEST/000281'
      and status <> 'cancelled'
  ) then
    raise exception 'Faktura 2026/FTEST/000281 už je v systému založená.';
  end if;

  if not exists (
    select 1
    from public.purchase_suppliers
    where id = v_supplier_id
      and lower(name) like '%barbera%'
      and active = true
  ) then
    raise exception 'Chybí aktivní dodavatel Barbera Caffe SpA (ID 5).';
  end if;

  if not exists (
    select 1
    from public.stock_locations
    where id = v_stock_location_id
      and location_type = 'warehouse'
      and warehouse_id = 1
      and active = true
  ) then
    raise exception 'Chybí aktivní skladová lokace BLUČINA (ID 1).';
  end if;

  if not exists (
    select 1 from public.products
    where id = 26 and name = 'Barbera Tris 1 kg' and base_unit = 'kg' and active = true
  ) then
    raise exception 'Skladová karta Barbera Tris 1 kg (ID 26) neodpovídá očekávání.';
  end if;

  if not exists (
    select 1 from public.products
    where id = 21 and name = 'Barbera 1870 1 kg' and base_unit = 'kg' and active = true
  ) then
    raise exception 'Skladová karta Barbera 1870 1 kg (ID 21) neodpovídá očekávání.';
  end if;

  select coalesce(max(substring(note from '\[rada:OVFP26-([0-9]+)\]')::integer), 0) + 1
  into v_series_number
  from public.purchase_orders
  where note ~ '\[rada:OVFP26-[0-9]+\]';

  v_internal_number := 'OVFP26-' || lpad(v_series_number::text, 4, '0');

  insert into public.purchase_orders (
    supplier_id,
    order_scope,
    status,
    order_date,
    delivery_date,
    note,
    delivery_note_number,
    invoice_number,
    received_at,
    received_stock_location_id
  ) values (
    v_supplier_id,
    'general',
    'received',
    date '2026-07-23',
    date '2026-07-23',
    '[rada:' || v_internal_number || '] ' || v_base_note,
    null,
    '2026/FTEST/000281',
    v_received_at,
    v_stock_location_id
  )
  returning id into v_order_id;

  -- Řádky jsou vedené v kg, stejně jako skladové karty. Nákupní cena je
  -- přepočtena shodně s PDF importem aplikace: jednotková cena × kurz, na 2 desetinná místa.
  insert into public.purchase_order_items (
    purchase_order_id,
    product_id,
    ordered_quantity,
    received_quantity,
    unit_cost,
    note
  ) values
  (
    v_order_id,
    26,
    117,
    117,
    215.25,
    '[dph:0][celkem-bez-dph:25184.25][celkem-s-dph:25184.25][mena:EUR][kurz:24.185]'
      || '[doklad-bez-dph:1041.30][doklad-celkem:1041.30]' || E'\n'
      || 'TRIS WHOLE BEAN COFFEE 1 KG · EAN 8007597000149 · kód dodavatele 001047 '
      || '· jednotka faktury kg · 117.00 kg · šarže 270526 · expirace 2028-05-26 '
      || '· doklad 1 041,30 EUR · kurz 24.185'
  ),
  (
    v_order_id,
    21,
    36,
    36,
    239.43,
    '[dph:0][celkem-bez-dph:8619.48][celkem-s-dph:8619.48][mena:EUR][kurz:24.185]'
      || '[doklad-bez-dph:356.40][doklad-celkem:356.40]' || E'\n'
      || '1870 "WHITE" WHOLE BEAN COFFEE 1KG · EAN 8007597003256 · kód dodavatele 000023 '
      || '· jednotka faktury kg · 36.00 kg · šarže 130726 · expirace 2028-07-12 '
      || '· doklad 356,40 EUR · kurz 24.185'
  );

  insert into public.stock_movements_v13 (
    product_id,
    batch_id,
    to_stock_location_id,
    movement_type,
    quantity_base_units,
    unit_price,
    reference_type,
    reference_id,
    note,
    created_at
  ) values
  (26, null, v_stock_location_id, 'receipt', 117, 215.25, 'purchase_order', v_order_id::text, v_base_note, v_received_at),
  (21, null, v_stock_location_id, 'receipt', 36, 239.43, 'purchase_order', v_order_id::text, v_base_note, v_received_at);

  update public.stock_location_balances
  set quantity_on_hand = round(quantity_on_hand + 117, 3),
      updated_at = v_received_at
  where stock_location_id = v_stock_location_id
    and product_id = 26
    and batch_id is null;

  if not found then
    insert into public.stock_location_balances (
      stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
    ) values (
      v_stock_location_id, 26, null, 117, 0, v_received_at
    );
  end if;

  update public.stock_location_balances
  set quantity_on_hand = round(quantity_on_hand + 36, 3),
      updated_at = v_received_at
  where stock_location_id = v_stock_location_id
    and product_id = 21
    and batch_id is null;

  if not found then
    insert into public.stock_location_balances (
      stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
    ) values (
      v_stock_location_id, 21, null, 36, 0, v_received_at
    );
  end if;

  insert into public.supplier_product_mappings (
    supplier_id,
    product_id,
    supplier_item_code,
    ean,
    supplier_item_name,
    invoice_unit_code,
    base_units_per_invoice_unit,
    last_unit_price,
    last_seen_at,
    active
  ) values
  (v_supplier_id, 26, '001047', '8007597000149', 'TRIS WHOLE BEAN COFFEE 1 KG', 'kg', 1, 215.25, v_received_at, true),
  (v_supplier_id, 21, '000023', '8007597003256', '1870 "WHITE" WHOLE BEAN COFFEE 1KG', 'kg', 1, 239.43, v_received_at, true)
  on conflict (supplier_id, supplier_item_code) do update
  set product_id = excluded.product_id,
      ean = excluded.ean,
      supplier_item_name = excluded.supplier_item_name,
      invoice_unit_code = excluded.invoice_unit_code,
      base_units_per_invoice_unit = excluded.base_units_per_invoice_unit,
      last_unit_price = excluded.last_unit_price,
      last_seen_at = excluded.last_seen_at,
      active = true;
end
$$;

select
  po.id as purchase_order_id,
  substring(po.note from '\[rada:([^]]+)\]') as internal_number,
  po.invoice_number,
  po.status,
  po.order_date,
  po.delivery_date,
  ps.name as supplier_name,
  sl.name as received_to,
  sum(poi.received_quantity) as received_quantity_kg,
  sum(substring(poi.note from '\[doklad-celkem:([0-9.]+)\]')::numeric) as document_total_eur,
  count(*) as item_count
from public.purchase_orders po
join public.purchase_suppliers ps on ps.id = po.supplier_id
join public.stock_locations sl on sl.id = po.received_stock_location_id
join public.purchase_order_items poi on poi.purchase_order_id = po.id
where po.invoice_number = '2026/FTEST/000281'
group by po.id, ps.name, sl.name;
