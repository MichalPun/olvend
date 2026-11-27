-- EK Hodonin / EV 11 / visit 2075.
-- Physical state confirmed by the operator, left to right:
-- slot 31 Debrecin 4 pcs, slot 32 Mlska 4 pcs, slot 33 Hamka 2 pcs.
-- The mobile app saved Debrecin in slot 32 and Mlska in slot 33, then blocked
-- the correct Debrecin assignment in slot 31 as a duplicate.

begin;

do $$
declare
  v_visit public.route_machine_visits%rowtype;
  v_actor uuid;
  v_audit_id bigint;
  v_before jsonb;
  v_after jsonb;
begin
  if exists (
    select 1 from public.route_visit_corrections
    where visit_id = 2075
      and reason = 'EK Hodonin: srovnani baget na pozicich 31-33 podle fyzickeho stavu operatora'
  ) then
    raise notice 'EK Hodonin visit 2075 bagette repair already applied.';
    return;
  end if;

  select * into strict v_visit
  from public.route_machine_visits
  where id = 2075
    and route_plan_id = 237
    and route_plan_stop_id = 2865
    and machine_id = 8
    and vehicle_id = 6
    and visit_date = date '2026-11-27'
    and status = 'completed'
    and correction_revision = 0
  for update;

  if exists (
    select 1 from public.route_machine_visits newer
    where newer.machine_id = v_visit.machine_id
      and newer.id <> v_visit.id
      and coalesce(newer.arrived_at,newer.created_at) > coalesce(v_visit.arrived_at,v_visit.created_at)
      and newer.status in ('arrived','completed')
  ) then
    raise exception 'EV 11 already has a newer visit; repair requires a new physical check.';
  end if;

  if not exists (
    select 1 from public.route_machine_visit_items
    where id=58638 and visit_id=2075 and planogram_slot_id=2486
      and actual_product_id=236 and actual_before_quantity=0
      and actual_add_quantity=0 and final_quantity=0
  ) or not exists (
    select 1 from public.route_machine_visit_items
    where id=58637 and visit_id=2075 and planogram_slot_id=2488
      and actual_product_id=236 and actual_before_quantity=0
      and actual_add_quantity=4 and final_quantity=4
  ) or not exists (
    select 1 from public.route_machine_visit_items
    where id=58636 and visit_id=2075 and planogram_slot_id=2487
      and actual_product_id=238 and actual_before_quantity=0
      and actual_add_quantity=2 and final_quantity=2
  ) then
    raise exception 'Visit items no longer match the audited pre-repair state.';
  end if;

  if not exists (
    select 1 from public.route_machine_visit_food_fills
    where id=21529 and visit_item_id=58637 and planogram_slot_id=2488
      and product_id=236 and quantity=4 and expiry_date=date '2026-12-05'
  ) or not exists (
    select 1 from public.route_machine_visit_food_fills
    where id=21528 and visit_item_id=58636 and planogram_slot_id=2487
      and product_id=238 and quantity=2 and expiry_date=date '2026-12-05'
  ) then
    raise exception 'Saved food fills no longer match the audited pre-repair state.';
  end if;

  if coalesce((select quantity_on_hand from public.stock_location_balances
               where stock_location_id=93 and product_id=238 and batch_id=992),0) < 2
     or coalesce((select quantity_on_hand from public.stock_location_balances
                 where stock_location_id=93 and product_id=254 and batch_id=991),0) < 2 then
    raise exception 'Vehicle no longer has the two Mlska and two Hamka pieces required by the physical repair.';
  end if;

  select id into strict v_actor
  from public.employees
  where active is true
    and lower(role) in ('admin','manager')
    and lower(name)='michal'
    and lower(surname) like 'pun%'
  order by id
  limit 1;

  perform set_config('olvend.route_correction','on',true);

  v_before := jsonb_build_object(
    'visit',to_jsonb(v_visit),
    'items',(select jsonb_agg(to_jsonb(i) order by i.physical_position_label)
             from public.route_machine_visit_items i where i.id in (58638,58637,58636)),
    'fills',(select jsonb_agg(to_jsonb(f) order by f.id)
             from public.route_machine_visit_food_fills f where f.id in (21529,21528)),
    'layers',(select jsonb_agg(to_jsonb(l) order by l.planogram_slot_id,l.layer_order)
              from public.machine_planogram_slot_layers l where l.planogram_slot_id in (2486,2488,2487))
  );

  insert into public.route_visit_corrections(visit_id,actor_id,reason,before_data,after_data)
  values (
    2075,v_actor,
    'EK Hodonin: srovnani baget na pozicich 31-33 podle fyzickeho stavu operatora',
    v_before,'{}'::jsonb
  ) returning id into v_audit_id;

  perform public.apply_stock_movements_v13(jsonb_build_array(
    jsonb_build_object(
      'product_id',238,'batch_id',992,
      'from_stock_location_id',93,'to_stock_location_id',87,
      'movement_type','fill_machine','quantity_base_units',2,
      'reference_type','route_correction',
      'reference_id','route_correction_'||v_audit_id||'_ek_hodonin_slot32_mlska_extra_2',
      'note','EK Hodonin EV 11 visit 2075: physical slot 32 contains 4 Mlska; add 2 missing pieces'
    ),
    jsonb_build_object(
      'product_id',254,'batch_id',991,
      'from_stock_location_id',93,'to_stock_location_id',87,
      'movement_type','fill_machine','quantity_base_units',2,
      'reference_type','route_correction',
      'reference_id','route_correction_'||v_audit_id||'_ek_hodonin_slot33_hamka_2',
      'note','EK Hodonin EV 11 visit 2075: physical slot 33 contains 2 Hamka'
    )
  ));

  -- Keep the original stock sources but associate them with the physically correct slots.
  update public.route_machine_visit_food_fills
  set visit_item_id=58638, planogram_slot_id=2486,
      correction_sources=jsonb_build_array(jsonb_build_object('product_id',236,'batch_id',990,'quantity',4))
  where id=21529;

  update public.route_machine_visit_food_fills
  set visit_item_id=58637, planogram_slot_id=2488,
      product_id=238, product_sku='SIMPLY-MLSKA', product_name='Snack Mlska 144g',
      quantity=4, expiry_date=date '2026-12-05',
      correction_sources=jsonb_build_array(jsonb_build_object('product_id',238,'batch_id',992,'quantity',4))
  where id=21528;

  insert into public.route_machine_visit_food_fills(
    visit_id,visit_item_id,machine_id,planogram_slot_id,
    product_id,product_sku,product_name,quantity,expiry_date,
    sale_price_czk,load_order,stock_reference_id,correction_sources
  ) values (
    2075,58636,8,2487,
    254,'SIMPLY-HAMKA','Snack Hamka 146g',2,date '2026-12-05',
    44,0,'route_correction_'||v_audit_id||'_ek_hodonin_slot33_hamka_2',
    jsonb_build_array(jsonb_build_object('product_id',254,'batch_id',991,'quantity',2))
  );

  update public.route_machine_visit_items
  set actual_product_id=236,actual_product_sku='SIMPLY-DEBRECIN',actual_product_name='Snack Debrecín 140g',
      actual_add_quantity=4,final_quantity=4,
      operator_note='Inventurni odchylka: evidence 6 ks -> fyzicky 0 ks. Fyzicky vlozeny 4 ks Debrecin; evidence srovnana podle operatora.',
      updated_at=now()
  where id=58638;

  update public.route_machine_visit_items
  set actual_product_id=238,actual_product_sku='SIMPLY-MLSKA',actual_product_name='Snack Mlska 144g',
      actual_add_quantity=4,final_quantity=4,
      operator_note='Inventurni odchylka: evidence 2 ks -> fyzicky 0 ks. Fyzicky vlozeny 4 ks Mlska; evidence srovnana podle operatora.',
      updated_at=now()
  where id=58637;

  update public.route_machine_visit_items
  set actual_product_id=254,actual_product_sku='SIMPLY-HAMKA',actual_product_name='Snack Hamka 146g',
      actual_add_quantity=2,final_quantity=2,
      operator_note='Inventurni odchylka: evidence 4 ks -> fyzicky 0 ks. Fyzicky vlozeny 2 ks Hamka; evidence srovnana podle operatora.',
      updated_at=now()
  where id=58636;

  delete from public.machine_planogram_slot_layers where planogram_slot_id in (2486,2488,2487);
  insert into public.machine_planogram_slot_layers(
    planogram_slot_id,layer_order,product_id,product_sku,product_name,quantity,expiry_date,source,source_visit_id
  ) values
    (2486,1,236,'SIMPLY-DEBRECIN','Snack Debrecín 140g',4,date '2026-12-05','manager_correction',2075),
    (2488,1,238,'SIMPLY-MLSKA','Snack Mlska 144g',4,date '2026-12-05','manager_correction',2075),
    (2487,1,254,'SIMPLY-HAMKA','Snack Hamka 146g',2,date '2026-12-05','manager_correction',2075);

  update public.machine_planogram_slots
  set product_sku='SIMPLY-DEBRECIN',product_name='Snack Debrecín 140g',
      current_units=4,desired_units=2,fill_percent=66.67,expiry_date=date '2026-12-05',updated_at=now()
  where id=2486;
  update public.machine_planogram_slots
  set product_sku='SIMPLY-MLSKA',product_name='Snack Mlska 144g',
      current_units=4,desired_units=2,fill_percent=66.67,expiry_date=date '2026-12-05',updated_at=now()
  where id=2488;
  update public.machine_planogram_slots
  set product_sku='SIMPLY-HAMKA',product_name='Snack Hamka 146g',
      current_units=2,desired_units=4,fill_percent=33.33,expiry_date=date '2026-12-05',updated_at=now()
  where id=2487;

  update public.route_machine_visits
  set food_preparation = jsonb_set(
        jsonb_set(
          jsonb_set(
            coalesce(food_preparation,'{}'::jsonb),
            '{2486}',
            coalesce(food_preparation->'2486','{}'::jsonb) || jsonb_build_object(
              'actualBefore',0,'actualAdd',4,'selectedProductId',236,'existingProductId',236,
              'preparedQuantity',4,'basePreparedQuantity',4,'picked',true,'pickConfirmed',true,'accepted',true,
              'fillItems',jsonb_build_array(jsonb_build_object('productId',236,'batchId',990,'quantity',4,'expiryDate','2026-12-05'))
            ),true
          ),
          '{2488}',
          coalesce(food_preparation->'2488','{}'::jsonb) || jsonb_build_object(
            'actualBefore',0,'actualAdd',4,'selectedProductId',238,'existingProductId',238,
            'preparedQuantity',4,'basePreparedQuantity',4,'picked',true,'pickConfirmed',true,'accepted',true,
            'fillItems',jsonb_build_array(jsonb_build_object('productId',238,'batchId',992,'quantity',4,'expiryDate','2026-12-05'))
          ),true
        ),
        '{2487}',
        coalesce(food_preparation->'2487','{}'::jsonb) || jsonb_build_object(
          'actualBefore',0,'actualAdd',2,'selectedProductId',254,'existingProductId',254,
          'preparedQuantity',2,'basePreparedQuantity',2,'picked',true,'pickConfirmed',true,'accepted',true,
          'fillItems',jsonb_build_array(jsonb_build_object('productId',254,'batchId',991,'quantity',2,'expiryDate','2026-12-05'))
        ),true
      ),
      correction_revision=correction_revision+1,
      synced_at=now(),updated_at=now()
  where id=2075;

  v_after := jsonb_build_object(
    'visit',(select to_jsonb(v) from public.route_machine_visits v where v.id=2075),
    'items',(select jsonb_agg(to_jsonb(i) order by i.physical_position_label)
             from public.route_machine_visit_items i where i.id in (58638,58637,58636)),
    'fills',(select jsonb_agg(to_jsonb(f) order by f.planogram_slot_id,f.id)
             from public.route_machine_visit_food_fills f where f.visit_id=2075 and f.planogram_slot_id in (2486,2488,2487)),
    'layers',(select jsonb_agg(to_jsonb(l) order by l.planogram_slot_id,l.layer_order)
              from public.machine_planogram_slot_layers l where l.planogram_slot_id in (2486,2488,2487))
  );
  update public.route_visit_corrections set after_data=v_after where id=v_audit_id;
end
$$;

commit;

select jsonb_build_object(
  'visit',(select jsonb_build_object('id',id,'status',status,'revision',correction_revision) from public.route_machine_visits where id=2075),
  'items',(select jsonb_agg(jsonb_build_object(
    'position',physical_position_label,'product',actual_product_name,
    'before',actual_before_quantity,'added',actual_add_quantity,'final',final_quantity
  ) order by physical_position_label) from public.route_machine_visit_items where id in (58638,58637,58636)),
  'slots',(select jsonb_agg(jsonb_build_object(
    'position',slot_code,'current_product',product_name,'primary_product',primary_product_name,
    'current',current_units,'capacity',capacity_units
  ) order by slot_code) from public.machine_planogram_slots where id in (2486,2488,2487)),
  'vehicle_balances',(select jsonb_agg(jsonb_build_object(
    'product',p.name,'quantity',b.quantity_on_hand,'expiry',coalesce(ib.use_by_date,ib.best_before_date)
  ) order by p.name) from public.stock_location_balances b
    join public.products p on p.id=b.product_id
    left join public.inventory_batches ib on ib.id=b.batch_id
    where b.stock_location_id=93 and b.batch_id in (990,992,991)),
  'correction',(select jsonb_build_object('id',id,'reason',reason) from public.route_visit_corrections
                where visit_id=2075 order by id desc limit 1)
) verification;
