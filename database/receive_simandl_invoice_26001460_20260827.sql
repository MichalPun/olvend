-- Přijetí faktury SIMANDL 26001460 do hlavního skladu BLUČINA.
-- Zdroj: Faktura vystavená_26001460_13082026.pdf

do $$
declare
  v_supplier_id bigint := 8;
  v_product_id bigint := 110;
  v_stock_location_id bigint := 1;
  v_order_id bigint;
  v_series_number integer;
  v_internal_number text;
  v_received_at timestamptz := now();
  v_base_note text := '[typ:invoice][splatnost:2026-09-12][mena:CZK][kurz:1][dph-rezim:domestic] '
    || 'Objednávka PO261535. Importováno z PDF. '
    || 'Základ 40 200 Kč, DPH 12 % 4 824 Kč, celkem 45 024 Kč.';
begin
  if exists (
    select 1
    from public.purchase_orders
    where replace(upper(coalesce(invoice_number, '')), ' ', '') = '26001460'
      and status <> 'cancelled'
  ) then
    raise exception 'Faktura 26001460 už je v systému založená.';
  end if;

  if not exists (
    select 1
    from public.purchase_suppliers
    where id = v_supplier_id
      and company_id = '63319969'
      and tax_id = 'CZ63319969'
      and active = true
  ) then
    raise exception 'Dodavatel SIMANDL (ID 8) neodpovídá očekávání.';
  end if;

  if not exists (
    select 1
    from public.products
    where id = v_product_id
      and sku = '46'
      and name = 'Irish Cream 1 kg'
      and base_unit = 'kg'
      and active = true
  ) then
    raise exception 'Skladová karta Irish Cream 1 kg (ID 110, SKU 46) neodpovídá očekávání.';
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

  select coalesce(max(substring(note from '\[rada:OVFP26-([0-9]+)\]')::integer), 0) + 1
  into v_series_number
  from public.purchase_orders
  where note ~ '\[rada:OVFP26-[0-9]+\]';

  v_internal_number := 'OVFP26-' || lpad(v_series_number::text, 4, '0');

  update public.purchase_suppliers
  set bank_account = coalesce(bank_account, '104458251'),
      bank_code = coalesce(bank_code, '0300'),
      default_due_days = coalesce(default_due_days, 30)
  where id = v_supplier_id;

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
    date '2026-08-13',
    date '2026-08-13',
    '[rada:' || v_internal_number || '] ' || v_base_note,
    null,
    '26001460',
    v_received_at,
    v_stock_location_id
  )
  returning id into v_order_id;

  insert into public.purchase_order_items (
    purchase_order_id,
    product_id,
    ordered_quantity,
    received_quantity,
    unit_cost,
    note
  ) values (
    v_order_id,
    v_product_id,
    600,
    600,
    67,
    '[dph:12][celkem-bez-dph:40200.00][celkem-s-dph:45024.00][mena:CZK][kurz:1]'
      || '[doklad-bez-dph:40200.00][doklad-celkem:45024.00]' || E'\n'
      || 'DARKOFF VEN Capp. IRISH 1 kG · katalogové číslo 502 · jednotka faktury ks '
      || '· 600 ks × 1 kg = 600 kg · jednotková cena 67 Kč bez DPH'
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
  ) values (
    v_product_id,
    null,
    v_stock_location_id,
    'receipt',
    600,
    67,
    'purchase_order',
    v_order_id::text,
    v_base_note,
    v_received_at
  );

  update public.stock_location_balances
  set quantity_on_hand = round(quantity_on_hand + 600, 3),
      updated_at = v_received_at
  where stock_location_id = v_stock_location_id
    and product_id = v_product_id
    and batch_id is null;

  if not found then
    insert into public.stock_location_balances (
      stock_location_id,
      product_id,
      batch_id,
      quantity_on_hand,
      reserved_quantity,
      updated_at
    ) values (
      v_stock_location_id,
      v_product_id,
      null,
      600,
      0,
      v_received_at
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
  ) values (
    v_supplier_id,
    v_product_id,
    '502',
    null,
    'DARKOFF VEN Capp. IRISH 1 kG',
    'ks',
    1,
    67,
    v_received_at,
    true
  )
  on conflict (supplier_id, supplier_item_code) do update
  set product_id = excluded.product_id,
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
  poi.received_quantity,
  poi.unit_cost,
  substring(poi.note from '\[doklad-celkem:([0-9.]+)\]')::numeric as document_total_czk,
  slb.quantity_on_hand as resulting_stock_quantity
from public.purchase_orders po
join public.purchase_suppliers ps on ps.id = po.supplier_id
join public.stock_locations sl on sl.id = po.received_stock_location_id
join public.purchase_order_items poi on poi.purchase_order_id = po.id
join public.stock_location_balances slb
  on slb.stock_location_id = po.received_stock_location_id
 and slb.product_id = poi.product_id
 and slb.batch_id is null
where po.invoice_number = '26001460';
