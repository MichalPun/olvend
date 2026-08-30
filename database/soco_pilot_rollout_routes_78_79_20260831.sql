begin;

do $$
declare
  v_bongo_id bigint;
  v_rawbar_id bigint;
  v_brigit_id bigint;
  v_extasy_id bigint;
  v_changed integer;
begin
  select id into strict v_bongo_id from public.products where sku = 'SOCO-BONGO-ORIGINAL-40' and active is true;
  select id into strict v_rawbar_id from public.products where sku = 'SOCO-RAWBAR-PEANUTS' and active is true;
  select id into strict v_brigit_id from public.products where sku = 'SOCO-BRIGIT-90' and active is true;
  select id into strict v_extasy_id from public.products where sku = 'SOCO-EXTASY-COCONUT-45' and active is true;

  -- Sportisimo EV 99: KitKat, Twix a Margot zůstávají jako silná doprodejová místa.
  update public.machine_planogram_slots
  set pending_product_id = v_bongo_id,
      pending_product_sku = 'SOCO-BONGO-ORIGINAL-40',
      pending_product_name = 'Bongo kokos originál v mléčné polevě 40g',
      pending_price_czk = 16,
      planned_product_sku = 'SOCO-BONGO-ORIGINAL-40',
      planned_product_name = 'Bongo kokos originál v mléčné polevě 40g',
      planned_price_czk = 16,
      pending_change_mode = 'full_swap',
      pending_change_effective_date = date '2026-08-31',
      pending_change_note = 'Pilot SOCO: stáhnout 4 ks 3Bit do vozidla Michaely; ponechat k doprodeji na další vhodné trase.',
      updated_at = now()
  where id = 1947 and machine_id = 79 and slot_code = '26' and product_sku = '26'
    and pending_product_sku is null;
  get diagnostics v_changed = row_count;
  if v_changed <> 1 then raise exception 'EV 99 / pozice 26 nebyla bezpečně spárována.'; end if;

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
      pending_change_note = 'Pilot SOCO: stáhnout 4 ks Miňonky do vozidla Michaely; nejdřív využít volnou kapacitu na dalších potravinových automatech.',
      updated_at = now()
  where id = 1959 and machine_id = 79 and slot_code = '25' and product_sku = '31'
    and pending_product_sku is null;
  get diagnostics v_changed = row_count;
  if v_changed <> 1 then raise exception 'EV 99 / pozice 25 nebyla bezpečně spárována.'; end if;

  -- RIGUM EV 100: téměř prázdný Margot a slabší KitKat uvolní místo novinkám.
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

  update public.machine_planogram_slots
  set pending_product_id = v_extasy_id,
      pending_product_sku = 'SOCO-EXTASY-COCONUT-45',
      pending_product_name = 'Coconut Extasy tyčinka s arašídovým máslem 45g',
      pending_price_czk = 21,
      planned_product_sku = 'SOCO-EXTASY-COCONUT-45',
      planned_product_name = 'Coconut Extasy tyčinka s arašídovým máslem 45g',
      planned_price_czk = 21,
      pending_change_mode = 'full_swap',
      pending_change_effective_date = date '2026-08-31',
      pending_change_note = 'Pilot SOCO: stáhnout 6 ks KitKat do vozidla Michala a doprodat při další jižní trase; Sportisimo zůstává hlavním doprodejovým místem KitKat.',
      updated_at = now()
  where id = 2013 and machine_id = 80 and slot_code = '22' and product_sku = '27'
    and pending_product_sku is null;
  get diagnostics v_changed = row_count;
  if v_changed <> 1 then raise exception 'EV 100 / pozice 22 nebyla bezpečně spárována.'; end if;
end
$$;

commit;

notify pgrst, 'reload schema';
