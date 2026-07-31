do $$
declare
  v_product public.products%rowtype;
begin
  select * into v_product
  from public.products
  where sku = '20' and active is true
  limit 1;

  if v_product.id is null then
    raise exception 'Aktivní produkt SKU 20 (Dupetky) nebyl nalezen.';
  end if;

  update public.machine_planogram_slots
  set product_name = v_product.name,
      product_sku = v_product.sku,
      price_czk = 27,
      planned_product_name = v_product.name,
      planned_product_sku = v_product.sku,
      planned_price_czk = 27,
      capacity_units = 7,
      current_units = 0,
      fill_percent = 0,
      substitution_policy = 'exact',
      allowed_substitutes = null,
      operator_instruction = 'Doplnit 7 ks Dupetky Snack pečený hořčice+med+cibulka 70g.',
      note = concat_ws(' ', nullif(note, ''), '2026-07-31: Strážnické brambůrky SKU 139 ukončeny; schválena náhrada Dupetky SKU 20, 7 ks, cena 27 Kč.'),
      updated_at = now()
  where machine_id = 80
    and slot_code = '16'
    and product_sku = '139';

  if not found then
    raise exception 'RIGUM EV100 pozice 16 se Strážnickými brambůrkami nebyla nalezena nebo už byla změněna.';
  end if;
end
$$;
