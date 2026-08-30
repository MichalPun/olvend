begin;

do $$
declare
  v_rawbar_id bigint;
  v_brigit_id bigint;
  v_changed integer;
begin
  select id into strict v_rawbar_id from public.products where sku = 'SOCO-RAWBAR-PEANUTS' and active is true;
  select id into strict v_brigit_id from public.products where sku = 'SOCO-BRIGIT-90' and active is true;

  -- Sportisimo EV 99 zůstává silným doprodejovým místem pro starší sortiment.
  -- Hotel Kovák EV 23: Margot je prázdný, takže RawBar lze nasadit bez stahování zboží.
  update public.machine_planogram_slots
  set pending_product_id = v_rawbar_id,
      pending_product_sku = 'SOCO-RAWBAR-PEANUTS',
      pending_product_name = 'RawBar with peanuts 40g',
      pending_price_czk = 19,
      planned_product_sku = 'SOCO-RAWBAR-PEANUTS',
      planned_product_name = 'RawBar with peanuts 40g',
      planned_price_czk = 19,
      pending_change_mode = 'full_swap',
      pending_change_effective_date = date '2026-08-31',
      pending_change_note = 'Pilot SOCO: pozice Margot je prázdná; nasadit RawBar bez stahování starého zboží.',
      updated_at = now()
  where id = 1376 and machine_id = 19 and slot_code = '40' and product_sku = '40'
    and pending_product_sku is null;
  get diagnostics v_changed = row_count;
  if v_changed <> 1 then raise exception 'EV 23 / pozice 40 nebyla bezpečně spárována.'; end if;

  -- RIGUM EV 100: po jediném zbývajícím Margotu se nasadí Brigit.
  update public.machine_planogram_slots
  set pending_product_id = v_brigit_id,
      pending_product_sku = 'SOCO-BRIGIT-90',
      pending_product_name = 'Brigit kokosová tyčinka v tmavé polevě 90g',
      pending_price_czk = 25,
      planned_product_sku = 'SOCO-BRIGIT-90',
      planned_product_name = 'Brigit kokosová tyčinka v tmavé polevě 90g',
      planned_price_czk = 25,
      pending_change_mode = 'full_swap',
      pending_change_effective_date = date '2026-08-31',
      pending_change_note = 'Pilot SOCO: stáhnout 1 ks Margot do vozidla Michala a doprodat při další jižní trase.',
      updated_at = now()
  where id = 2014 and machine_id = 80 and slot_code = '36' and product_sku = '40'
    and pending_product_sku is null;
  get diagnostics v_changed = row_count;
  if v_changed <> 1 then raise exception 'EV 100 / pozice 36 nebyla bezpečně spárována.'; end if;

end
$$;

commit;

notify pgrst, 'reload schema';
