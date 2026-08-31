-- LIMA OKNA / EV 82: operátorka fyzicky stáhla 4 ks Kuře teriyaki z pozice 23,
-- ale mobilní potvrzení zablokoval prázdný řádek odpisu. Fyzický stav pozice
-- 23 je 1 ks. Kuřecí stripsy jsou správně 4 ks a oprava se jich nesmí dotknout.

begin;

do $$
declare
  v_machine_id bigint := 62;
  v_machine_location_id bigint;
  v_vehicle_location_id bigint;
  v_visit_id bigint;
  v_product record;
  v_batch record;
  v_remaining numeric;
  v_take numeric;
  v_movements jsonb := '[]'::jsonb;
  v_target numeric;
begin
  if exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id like 'lima-ev82-chicken-transfer-20260831-%'
  ) then
    raise exception 'Srovnání kuřecích přesunů EV 82 už bylo provedeno.';
  end if;

  perform 1 from public.machines
  where id = v_machine_id and evidence_number = 82 and location_id = 73;
  if not found then raise exception 'EV 82 už není na očekávaném stroji/lokalitě LIMA OKNA.'; end if;

  select sl.id into strict v_machine_location_id
  from public.stock_locations sl
  where sl.location_type = 'machine' and sl.machine_id = v_machine_id;

  select v.id, sl.id into strict v_visit_id, v_vehicle_location_id
  from public.route_machine_visits v
  join public.stock_locations sl
    on sl.location_type = 'vehicle' and sl.vehicle_id = v.vehicle_id
  where v.machine_id = v_machine_id
    and v.visit_date = date '2026-08-31'
  order by v.id desc
  limit 1;

  if not exists (
    select 1 from public.machine_planogram_slots s
    where s.machine_id = v_machine_id and s.active = true
      and s.slot_code = '23' and s.product_sku = '282'
      and lower(s.product_name) like '%kuře%teriyaki%'
  ) then
    raise exception 'Pozice 23 už neodpovídá ATM Kuře teriyaki / SKU 282.';
  end if;

  for v_product in
    select p.id as product_id, p.sku,
           sum(greatest(0, s.current_units - 1)) as quantity
    from public.machine_planogram_slots s
    join public.products p on p.sku = s.product_sku
    where s.machine_id = v_machine_id and s.active = true
      and s.slot_code = '23' and s.product_sku = '282'
    group by p.id, p.sku
    having sum(greatest(0, s.current_units - case when s.slot_code = '23' and s.product_sku = '282' then 1 else 0 end)) > 0
  loop
    v_remaining := v_product.quantity;
    for v_batch in
      select b.batch_id, b.quantity_on_hand
      from public.stock_location_balances b
      left join public.inventory_batches ib on ib.id = b.batch_id
      where b.stock_location_id = v_machine_location_id
        and b.product_id = v_product.product_id
        and b.quantity_on_hand > 0
      order by coalesce(ib.use_by_date, ib.best_before_date, date '9999-12-31'), b.batch_id nulls last
    loop
      exit when v_remaining <= 0;
      v_take := least(v_remaining, v_batch.quantity_on_hand);
      v_movements := v_movements || jsonb_build_array(jsonb_build_object(
        'product_id', v_product.product_id,
        'batch_id', v_batch.batch_id,
        'from_stock_location_id', v_machine_location_id,
        'to_stock_location_id', v_vehicle_location_id,
        'movement_type', 'return',
        'quantity_base_units', v_take,
        'reference_type', 'data_repair',
        'reference_id', format('lima-ev82-chicken-transfer-20260831-%s-%s', v_product.product_id, coalesce(v_batch.batch_id::text, 'none')),
        'note', 'EV 82 / LIMA OKNA: fyzicky stažené kuřecí zboží vrácené do vozidla po chybě mobilního potvrzení.',
        'allow_negative_source', false
      ));
      v_remaining := v_remaining - v_take;
    end loop;
    if v_remaining > 0 then
      raise exception 'EV 82: v evidenci automatu chybí % ks produktu %, oprava zastavena.', v_remaining, v_product.sku;
    end if;
  end loop;

  if jsonb_array_length(v_movements) > 0 then
    perform public.apply_stock_movements_v13(v_movements);
  end if;

  update public.machine_planogram_slots s
  set current_units = 1,
      last_units = s.current_units,
      desired_units = greatest(0, coalesce(s.target_units, s.capacity_units, 0) - 1),
      fill_percent = case when coalesce(s.capacity_units, 0) > 0
        then round(1::numeric / s.capacity_units * 100, 2)
        else 0 end,
      note = concat_ws(' ', nullif(s.note,''), '31. 8. 2026: fyzicky srovnáno po zablokovaném mobilním přesunu; pozice 23 obsahuje 1 ks teriyaki. Kuřecí stripsy beze změny.'),
      updated_at = now()
  where s.machine_id = v_machine_id and s.active = true
    and s.slot_code = '23' and s.product_sku = '282';

  -- Odstraň rozpracovaný chybný odpis a zmrazené počty z dnešní návštěvy.
  update public.route_machine_visits v
  set food_preparation = coalesce((
        select jsonb_object_agg(entry.key,
          case when s.id is null then entry.value else
            entry.value || jsonb_build_object(
              'actualBefore', 1,
              'actualAdd', 0, 'wasteItems', '[]'::jsonb,
              'transferQuantity', 0, 'transferRecommendation', null,
              'accepted', false
            ) end)
        from jsonb_each(coalesce(v.food_preparation, '{}'::jsonb)) entry
        left join public.machine_planogram_slots s
          on s.id::text = entry.key and s.machine_id = v_machine_id
          and s.slot_code = '23' and s.product_sku = '282'
      ), '{}'::jsonb),
      synced_at = now()
  where v.id = v_visit_id;
end
$$;

commit;
