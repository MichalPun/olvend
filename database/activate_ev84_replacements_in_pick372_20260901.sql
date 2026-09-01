begin;

do $$
declare
  v_request public.mobile_stock_requests%rowtype;
  v_updated integer;
begin
  select * into strict v_request
  from public.mobile_stock_requests
  where id = 372
  for update;

  if v_request.route_plan_id <> 83
     or v_request.vehicle_id <> 2
     or v_request.status not in ('requested', 'picking')
     or v_request.stock_applied_at is not null then
    raise exception 'Vychystani #372 uz neni bezpecne upravitelne.';
  end if;

  update public.machine_planogram_slots slot
  set planned_product_name = replacement.name,
      planned_product_sku = replacement.sku,
      planned_price_czk = replacement.sale_price,
      pending_product_id = replacement.id,
      pending_product_name = replacement.name,
      pending_product_sku = replacement.sku,
      pending_price_czk = replacement.sale_price,
      pending_change_effective_date = date '2026-09-02',
      pending_change_mode = 'sell_through',
      pending_change_note = 'EV84 Marius Pedersen: schvalena nahrada. Stary produkt doprodat pouze ze zasoby Michaely; volne misto doplnit novym produktem.',
      operator_instruction = 'Doprodej zbytek stareho produktu. Volne misto dopln schvalenou nahradou; zbozi z jineho auta nepresouvej.',
      substitution_policy = 'exact',
      allowed_substitutes = replacement.sku,
      changeover_old_units = slot.current_units,
      changeover_new_units = 0,
      updated_at = now()
  from (
    select old_sku, product.id, product.name, product.sku, product.sale_price
    from (values
      ('40', 'SOCO-BRIGIT-90'),
      ('26', 'SOCO-BONGO-ORIGINAL-40'),
      ('31', 'SOCO-RAWBAR-PEANUTS'),
      ('27', 'SOCO-EXTASY-PEANUT-45'),
      ('25', 'SOCO-PROTEIN-VANILKA-45')
    ) mapping(old_sku, replacement_sku)
    join public.products product on product.sku = mapping.replacement_sku
      and product.active is true
  ) replacement
  where slot.machine_id = 64
    and slot.active is true
    and slot.product_sku = replacement.old_sku;

  get diagnostics v_updated = row_count;
  if v_updated <> 5 then
    raise exception 'Na EV84 bylo upraveno % z 5 ocekavanych pozic.', v_updated;
  end if;

  insert into public.mobile_stock_request_items (
    request_id, product_id, product_name, sku, unit,
    requested_quantity, prepared_quantity, confirmed_quantity,
    note, batch_selection_mode
  )
  select 372, product.id, product.name, product.sku, package.package_name,
         1, 1, null,
         'EV84 Marius Pedersen · nahrada za 3Bit · 1 karton = 24 ks; 4 ks pro volne misto, zbytek zustava Michaele pro dalsi jeji automaty',
         'auto'
  from public.products product
  join lateral (
    select pp.package_name
    from public.product_packages pp
    where pp.product_id = product.id
      and pp.active is distinct from false
    order by pp.is_default desc, pp.id
    limit 1
  ) package on true
  where product.sku = 'SOCO-BONGO-ORIGINAL-40'
    and not exists (
      select 1
      from public.mobile_stock_request_items item
      where item.request_id = 372
        and item.product_id = product.id
    );

  update public.mobile_stock_requests
  set note = concat_ws(
        ' · ',
        nullif(note, ''),
        'EV84 NAHRADY: 3Bit→Bongo pridan 1 karton; Kit Kat→Peanut Extasy a Minonky→RawBar kryje stavajici zasoba Vivara; Twix je zatim plny; Margot→Brigit ceka, Brigit je na Blucine 0 ks'
      ),
      updated_at = now()
  where id = 372;
end
$$;

commit;

select
  slot.slot_code,
  slot.product_name,
  slot.current_units,
  slot.capacity_units,
  slot.pending_product_name,
  slot.pending_change_mode
from public.machine_planogram_slots slot
where slot.machine_id = 64
  and slot.product_sku in ('40', '26', '31', '27', '25')
order by slot.slot_code;

select
  item.product_name,
  item.unit,
  item.requested_quantity,
  item.prepared_quantity,
  item.note
from public.mobile_stock_request_items item
where item.request_id = 372
  and item.sku = 'SOCO-BONGO-ORIGINAL-40';
