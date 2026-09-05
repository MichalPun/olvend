-- Predbezny fyzicky prevod kompatibilniho sortimentu ze stazene Arie EV78
-- do nove Bianchi Vitality L EV128. Pouziva nizsi z planogramoveho stavu,
-- dostupneho skladoveho salda a kapacity EV128. Skutecnost se dorovna auditem.

do $$
declare
  v_source_machine_id constant bigint := 58;
  v_target_machine_id constant bigint := 124;
  v_source_stock_location_id constant bigint := 36;
  v_target_stock_location_id constant bigint := 78;
  v_token constant text := 'EV78_TO_EV128_STOCK_20260905';
  v_item record;
  v_balance record;
  v_slot record;
  v_remaining numeric;
  v_move numeric;
  v_new_current numeric;
  v_total_moved numeric := 0;
begin
  if not exists (
    select 1 from public.machines
    where id=v_source_machine_id and evidence_number=78 and status='removed' and location_id is null
  ) then
    raise exception 'Zdroj EV78 neodpovida ocekavanemu odstavenemu stroji.';
  end if;

  if not exists (
    select 1 from public.machines
    where id=v_target_machine_id and evidence_number=128 and status='ok' and location_id=60
  ) then
    raise exception 'Cil EV128 neodpovida ocekavanemu stroji na Vitaru.';
  end if;

  if not exists (
    select 1 from public.stock_locations
    where id=v_source_stock_location_id and machine_id=v_source_machine_id and active=true
  ) or not exists (
    select 1 from public.stock_locations
    where id=v_target_stock_location_id and machine_id=v_target_machine_id and active=true
  ) then
    raise exception 'Skladova mista EV78 nebo EV128 neodpovidaji.';
  end if;

  if exists (
    select 1 from public.machines
    where id=v_target_machine_id and coalesce(note,'') like '%' || v_token || '%'
  ) or exists (
    select 1 from public.stock_movements_v13
    where reference_type='machine_transfer' and reference_id like lower(v_token) || ':%'
  ) then
    raise exception 'Prevod EV78 -> EV128 uz byl proveden.';
  end if;

  if exists (
    select 1 from public.machine_planogram_slots
    where machine_id=v_target_machine_id and active=true and coalesce(current_units,0)<>0
  ) or exists (
    select 1 from public.stock_location_balances
    where stock_location_id=v_target_stock_location_id and coalesce(quantity_on_hand,0)<>0
  ) then
    raise exception 'EV128 uz neni prazdny; predbezny prevod nebyl spusten.';
  end if;

  for v_item in
    with source_planogram as (
      select product_sku,sum(greatest(coalesce(current_units,0),0)) source_units
      from public.machine_planogram_slots
      where machine_id=v_source_machine_id and active=true and nullif(product_sku,'') is not null
      group by product_sku
    ), target_planogram as (
      select product_sku,sum(greatest(coalesce(capacity_units,0)-coalesce(current_units,0),0)) target_room
      from public.machine_planogram_slots
      where machine_id=v_target_machine_id and active=true and nullif(product_sku,'') is not null
      group by product_sku
    ), source_stock as (
      select product_id,greatest(sum(coalesce(quantity_on_hand,0)-coalesce(reserved_quantity,0)),0) available_units
      from public.stock_location_balances
      where stock_location_id=v_source_stock_location_id
      group by product_id
    )
    select product.id product_id,product.sku,
           least(source.source_units,target.target_room,stock.available_units) move_units
    from target_planogram target
    join source_planogram source using(product_sku)
    join public.products product on product.sku=target.product_sku
    join source_stock stock on stock.product_id=product.id
    where least(source.source_units,target.target_room,stock.available_units)>0
    order by product.sku
  loop
    v_remaining := v_item.move_units;

    -- Fyzicky skladovy prevod po sarzich, FEFO.
    for v_balance in
      select balance.product_id,balance.batch_id,
             greatest(balance.quantity_on_hand-balance.reserved_quantity,0) available_units
      from public.stock_location_balances balance
      left join public.inventory_batches batch on batch.id=balance.batch_id
      where balance.stock_location_id=v_source_stock_location_id
        and balance.product_id=v_item.product_id
        and balance.quantity_on_hand-balance.reserved_quantity>0
      order by coalesce(batch.use_by_date,batch.best_before_date) asc nulls last,balance.id
    loop
      exit when v_remaining<=0;
      v_move := least(v_remaining,v_balance.available_units);

      perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
        'product_id',v_item.product_id,
        'batch_id',v_balance.batch_id,
        'from_stock_location_id',v_source_stock_location_id,
        'to_stock_location_id',v_target_stock_location_id,
        'movement_type','transfer',
        'quantity_base_units',v_move,
        'reference_type','machine_transfer',
        'reference_id',lower(v_token) || ':' || v_item.sku || ':' || coalesce(v_balance.batch_id::text,'no-batch'),
        'note','Predbezny prevod kompatibilniho zbozi z EV78 do EV128 pred auditem skutecneho stavu.'
      )));
      v_remaining := v_remaining-v_move;
    end loop;

    if v_remaining<>0 then
      raise exception 'Nepodarilo se prevest cele mnozstvi SKU %, zbyva %.',v_item.sku,v_remaining;
    end if;

    -- Naplneni cile po pozicich do jejich kapacity.
    v_remaining := v_item.move_units;
    for v_slot in
      select id,current_units,capacity_units,target_units
      from public.machine_planogram_slots
      where machine_id=v_target_machine_id and active=true and product_sku=v_item.sku
      order by sort_order,slot_code::integer,id
      for update
    loop
      exit when v_remaining<=0;
      v_move := least(v_remaining,greatest(v_slot.capacity_units-v_slot.current_units,0));
      v_new_current := v_slot.current_units+v_move;
      update public.machine_planogram_slots
      set current_units=v_new_current,
          fill_percent=case when capacity_units>0 then round(100*v_new_current/capacity_units,2) else 0 end,
          desired_units=greatest(coalesce(target_units,capacity_units,0)-v_new_current,0),
          note=concat_ws(' · ',nullif(note,''),'Predbezny stav preveden z EV78 dne 5. 9. 2026; overit auditem na miste.'),
          updated_at=now()
      where id=v_slot.id;
      v_remaining := v_remaining-v_move;
    end loop;

    if v_remaining<>0 then
      raise exception 'Mnozstvi SKU % se nevejde do pozic EV128, zbyva %.',v_item.sku,v_remaining;
    end if;

    -- Stejne kusy odebereme ze zdrojoveho planogramu, aby nebyly evidovany dvakrat.
    v_remaining := v_item.move_units;
    for v_slot in
      select id,current_units,capacity_units,target_units
      from public.machine_planogram_slots
      where machine_id=v_source_machine_id and active=true and product_sku=v_item.sku and current_units>0
      order by expiry_date asc nulls last,sort_order,slot_code::integer,id
      for update
    loop
      exit when v_remaining<=0;
      v_move := least(v_remaining,v_slot.current_units);
      v_new_current := v_slot.current_units-v_move;
      update public.machine_planogram_slots
      set current_units=v_new_current,
          fill_percent=case when capacity_units>0 then round(100*v_new_current/capacity_units,2) else 0 end,
          desired_units=greatest(coalesce(target_units,capacity_units,0)-v_new_current,0),
          note=concat_ws(' · ',nullif(note,''),'Cast evidovaneho stavu prevedena do EV128 dne 5. 9. 2026.'),
          updated_at=now()
      where id=v_slot.id;
      v_remaining := v_remaining-v_move;
    end loop;

    if v_remaining<>0 then
      raise exception 'Nelze odecist SKU % z planogramu EV78, zbyva %.',v_item.sku,v_remaining;
    end if;

    perform public.sync_machine_slot_expiry_from_stock(v_source_stock_location_id,v_item.product_id);
    perform public.sync_machine_slot_expiry_from_stock(v_target_stock_location_id,v_item.product_id);
    v_total_moved := v_total_moved+v_item.move_units;
  end loop;

  if v_total_moved<>221 then
    raise exception 'Ocekavano 221 ks, vypocteny prevod je % ks.',v_total_moved;
  end if;

  update public.machines
  set note=concat_ws(' · ',nullif(note,''),
      'Predbezne naplneno 221 ks kompatibilniho zbozi z EV78; skutecny stav overit auditem na miste. ' || v_token),
      updated_at=now()
  where id=v_target_machine_id;
end
$$;

-- Kontrolni souhrn: EV128 ma 221 ks a do ciloveho naplneni zbyva 123 ks.
select m.evidence_number,
       count(*) filter(where slot.active) active_slots,
       sum(slot.current_units) filter(where slot.active) current_units,
       sum(greatest(coalesce(slot.target_units,slot.capacity_units,0)-slot.current_units,0)) filter(where slot.active) top_up_units,
       round(sum(slot.fill_percent) filter(where slot.active)/nullif(count(*) filter(where slot.active),0),2) average_fill_percent
from public.machines m
join public.machine_planogram_slots slot on slot.machine_id=m.id
where m.id in (58,124)
group by m.evidence_number
order by m.evidence_number;
