-- Prvni naplneni Jetinno JL300 EV125: 450 ks Kelimek 250 ml (SKU 255)
-- z hlavniho skladu BLUCINA do zasobniku Z8.

begin;

do $$
declare
  v_machine_id bigint;
  v_product_id bigint;
  v_container_id bigint;
  v_machine_stock_location_id bigint;
  v_source_stock_location_id constant bigint := 1;
  v_quantity constant numeric := 450;
  v_reference_id constant text := 'jetinno-ev125-cups255-initial-fill-20260904';
  v_source_before numeric;
  v_target_before numeric;
  v_container_before numeric;
  v_capacity numeric;
begin
  select id into strict v_machine_id
  from public.machines
  where evidence_number=125 and brand='Jetinno' and model='JL300' and location_id=60 and active=true;

  select id into strict v_product_id
  from public.products
  where sku='255' and name='Kelímek 250 ml' and active=true;

  if not exists (
    select 1 from public.stock_locations
    where id=v_source_stock_location_id and location_type='warehouse'
      and name='BLUČINA' and warehouse_id=1 and active=true
  ) then
    raise exception 'Hlavni sklad BLUCINA nebyl nalezen v ocekavanem zaznamu ID1.';
  end if;

  if exists (
    select 1 from public.stock_movements_v13
    where reference_type='manual_transfer' and reference_id=v_reference_id
  ) then
    raise exception 'Prvni naplneni kelimku EV125 uz bylo zauctovano.';
  end if;

  select id,current_quantity,capacity_quantity
  into strict v_container_id,v_container_before,v_capacity
  from public.machine_coffee_containers
  where machine_id=v_machine_id and container_code='Z8'
    and product_id=v_product_id and product_sku='255' and active=true
  for update;

  if v_container_before <> 0 or v_capacity <> 450 then
    raise exception 'Zasobnik Z8 nema ocekavany stav 0/450 (skutecnost %/%).',v_container_before,v_capacity;
  end if;

  select coalesce(quantity_on_hand,0)
  into v_source_before
  from public.stock_location_balances
  where stock_location_id=v_source_stock_location_id
    and product_id=v_product_id and batch_id is null
  for update;

  if coalesce(v_source_before,0) < v_quantity then
    raise exception 'Ve skladu BLUCINA neni 450 ks kelimku; dostupny stav je % ks.',coalesce(v_source_before,0);
  end if;

  select id into v_machine_stock_location_id
  from public.stock_locations
  where location_type='machine' and machine_id=v_machine_id
  order by active desc,id
  limit 1;

  if v_machine_stock_location_id is null then
    insert into public.stock_locations(location_type,name,machine_id,active,note)
    values('machine','Automat EV 125',v_machine_id,true,'Skladové místo založeno při prvním naplnění Jetinno JL300 na Vitaru dne 4. 9. 2026.')
    returning id into v_machine_stock_location_id;
  else
    update public.stock_locations
    set active=true,updated_at=now()
    where id=v_machine_stock_location_id;
  end if;

  select coalesce(sum(quantity_on_hand),0)
  into v_target_before
  from public.stock_location_balances
  where stock_location_id=v_machine_stock_location_id and product_id=v_product_id;

  if v_target_before <> 0 then
    raise exception 'Skladova karta EV125 uz obsahuje % ks kelimku; prvni naplneni bylo zastaveno.',v_target_before;
  end if;

  perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
    'product_id',v_product_id,
    'batch_id',null,
    'from_stock_location_id',v_source_stock_location_id,
    'to_stock_location_id',v_machine_stock_location_id,
    'movement_type','fill_machine',
    'quantity_base_units',v_quantity,
    'reference_type','manual_transfer',
    'reference_id',v_reference_id,
    'note','První naplnění Jetinno JL300 EV125 na Vitaru · Z8 · 450 ks Kelímek 250 ml ze skladu BLUČINA',
    'allow_negative_source',false
  )));

  update public.machine_coffee_containers
  set current_quantity=450,
      note=concat_ws(' ',nullif(note,''),'4. 9. 2026: první fyzické naplnění 450 ks ze skladu BLUČINA.'),
      updated_at=now()
  where id=v_container_id;

  if (select quantity_on_hand from public.stock_location_balances
      where stock_location_id=v_source_stock_location_id and product_id=v_product_id and batch_id is null) <> v_source_before-v_quantity then
    raise exception 'Kontrola zůstatku skladu BLUČINA po převodu selhala.';
  end if;

  if (select coalesce(sum(quantity_on_hand),0) from public.stock_location_balances
      where stock_location_id=v_machine_stock_location_id and product_id=v_product_id) <> 450 then
    raise exception 'Kontrola skladové karty EV125 po převodu selhala.';
  end if;

  if (select current_quantity from public.machine_coffee_containers where id=v_container_id) <> 450 then
    raise exception 'Kontrola fyzického zásobníku Z8 po převodu selhala.';
  end if;
end $$;

commit;

select
  (select quantity_on_hand from public.stock_location_balances where stock_location_id=1 and product_id=79 and batch_id is null) as blucina_cups,
  (select sum(b.quantity_on_hand) from public.stock_location_balances b join public.stock_locations sl on sl.id=b.stock_location_id where sl.machine_id=121 and b.product_id=79) as ev125_stock_cups,
  (select current_quantity from public.machine_coffee_containers where machine_id=121 and product_sku='255' and active) as ev125_z8_cups;
