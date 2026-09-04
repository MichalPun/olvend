-- Druhy Jetinno JL300 na lokalite Vitar.
-- Presna konfiguracni kopie EV125, bez terminalove vazby (TID zatim nezname).
-- Prvni naplneni: pouze 450 ks Kelimek 250 ml ze skladu BLUCINA do Z8.

begin;

do $$
declare
  v_source_machine_id bigint;
  v_target_machine_id bigint;
  v_target_stock_location_id bigint;
  v_cup_product_id bigint;
  v_cup_container_id bigint;
  v_blucina_before numeric;
  v_reference_id constant text := 'jetinno-ev126-cups255-initial-fill-20260904';
begin
  select id into strict v_source_machine_id
  from public.machines
  where evidence_number=125 and brand='Jetinno' and model='JL300'
    and location_id=60 and status='ok' and active=true;

  if exists (select 1 from public.machines where evidence_number=126) then
    raise exception 'Evidencni cislo 126 uz existuje.';
  end if;

  if exists (select 1 from public.machines where qr_token='jetinno-jl300-ev126') then
    raise exception 'QR token pro EV126 uz existuje.';
  end if;

  if (select count(*) from public.machine_coffee_containers where machine_id=v_source_machine_id and active)<>8
     or (select count(*) from public.machine_coffee_buttons where machine_id=v_source_machine_id and active)<>18
     or (select count(*) from public.machine_coffee_recipe_items where machine_id=v_source_machine_id and active)<>55
     or (select count(*) from public.machine_planogram_slots where machine_id=v_source_machine_id and active)<>18 then
    raise exception 'Zdrojova konfigurace EV125 neni kompletni 8/18/55/18.';
  end if;

  if not exists (select 1 from public.locations where id=60 and name='Vitar' and active=true) then
    raise exception 'Aktivni lokalita Vitar ID60 nebyla nalezena.';
  end if;

  insert into public.machines(
    location_id,name,machine_type,brand,model,serial_number,evidence_number,
    status,active,note,qr_token,sales_tracking_mode,stock_initialized_at
  ) values (
    60,'Jetinno JL300','Coffee','Jetinno','JL300',null,126,
    'ok',true,
    'Druhý Jetinno JL300 na lokalitě Vitar · sestava shodná s EV125 · číslo platebního terminálu bude doplněno po zjištění.',
    'jetinno-jl300-ev126','telemetry',null
  ) returning id into v_target_machine_id;

  insert into public.machine_transfers(
    machine_id,from_location_id,to_location_id,transfer_kind,
    from_status,to_status,from_active,to_active,transferred_at,transferred_by,note
  ) values (
    v_target_machine_id,null,60,'relocation','installing','ok',true,true,now(),
    'Codex / potvrzeno Michal Punčochář',
    'První umístění Jetinno JL300 EV126 na lokalitu Vitar dne 4. 9. 2026; TID bude doplněno později.'
  );

  insert into public.machine_service_rules(
    machine_id,service_frequency,fill_frequency,stock_critical_percent,max_visit_interval_days,
    route_visit_rules_active,route_planning_paused_until,route_planning_excluded_months,
    route_planning_note,last_service_at,last_fill_at,note
  )
  select v_target_machine_id,service_frequency,fill_frequency,stock_critical_percent,max_visit_interval_days,
         route_visit_rules_active,null,route_planning_excluded_months,
         route_planning_note,null,null,'Výchozí servisní pravidla převzata z Jetinno EV125.'
  from public.machine_service_rules where machine_id=v_source_machine_id;

  insert into public.machine_coffee_containers(
    machine_id,container_code,product_sku,product_name,capacity_quantity,current_quantity,
    unit,refill_package_quantity,refill_package_unit,min_refill_quantity,sort_order,active,note,product_id
  )
  select v_target_machine_id,container_code,product_sku,product_name,capacity_quantity,0,
         unit,refill_package_quantity,refill_package_unit,min_refill_quantity,sort_order,active,
         'Jetinno JL300 EV126 · konfigurace převzata z EV125 · výchozí stav 0 '||unit||'.',product_id
  from public.machine_coffee_containers
  where machine_id=v_source_machine_id and active=true
  order by sort_order;

  insert into public.machine_coffee_buttons(
    machine_id,selection_code,product_sku,product_name,sale_price_czk,last_counter,
    grid_column,grid_row_from_bottom,sort_order,active,note,customer_price_czk,
    settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,
    settlement_note,planned_product_name,planned_product_sku,planned_price_czk,
    substitution_policy,allowed_substitutes,operator_instruction,product_id
  )
  select v_target_machine_id,selection_code,product_sku,product_name,sale_price_czk,null,
         grid_column,grid_row_from_bottom,sort_order,active,
         'Jetinno JL300 EV126 · nabídka a cena převzata z EV125.',customer_price_czk,
         settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,
         settlement_note,planned_product_name,planned_product_sku,planned_price_czk,
         substitution_policy,allowed_substitutes,operator_instruction,product_id
  from public.machine_coffee_buttons
  where machine_id=v_source_machine_id and active=true
  order by sort_order;

  insert into public.machine_coffee_recipe_items(
    machine_id,coffee_button_id,coffee_container_id,container_code,ingredient_name,
    quantity_per_vend,unit,sort_order,active,product_id
  )
  select v_target_machine_id,target_button.id,target_container.id,source_item.container_code,
         source_item.ingredient_name,source_item.quantity_per_vend,source_item.unit,
         source_item.sort_order,source_item.active,source_item.product_id
  from public.machine_coffee_recipe_items source_item
  join public.machine_coffee_buttons source_button on source_button.id=source_item.coffee_button_id
  join public.machine_coffee_buttons target_button
    on target_button.machine_id=v_target_machine_id
   and target_button.selection_code=source_button.selection_code
  join public.machine_coffee_containers target_container
    on target_container.machine_id=v_target_machine_id
   and target_container.container_code=source_item.container_code
  where source_item.machine_id=v_source_machine_id and source_item.active=true;

  insert into public.machine_planogram_slots(
    machine_id,slot_code,product_name,product_sku,price_czk,capacity_units,current_units,
    fill_percent,active,sort_order,note,dex_price_czk,desired_units,expiry_date,telemetry_key,
    last_units,product_family,product_variant,planned_product_name,planned_product_sku,
    planned_price_czk,substitution_policy,allowed_substitutes,operator_instruction,
    customer_price_czk,subsidy_amount_czk,subsidy_payer,subsidy_billing_enabled,subsidy_note,
    settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,
    settlement_note,target_units,replenishment_mode,pending_product_id,pending_product_sku,
    pending_product_name,pending_price_czk,pending_change_effective_date,pending_change_note,
    changeover_old_units,changeover_new_units,changeover_started_at,pending_change_mode
  )
  select v_target_machine_id,slot_code,product_name,product_sku,price_czk,capacity_units,null,
         null,active,sort_order,'Zrcadlový slot Jetinno JL300 EV126 · konfigurace převzata z EV125.',
         dex_price_czk,null,null,telemetry_key,null,product_family,product_variant,
         planned_product_name,planned_product_sku,planned_price_czk,substitution_policy,
         allowed_substitutes,operator_instruction,customer_price_czk,subsidy_amount_czk,
         subsidy_payer,subsidy_billing_enabled,subsidy_note,settlement_type,
         settlement_amount_czk,settlement_partner,settlement_billing_enabled,settlement_note,
         target_units,replenishment_mode,null,null,null,null,null,null,null,null,null,pending_change_mode
  from public.machine_planogram_slots
  where machine_id=v_source_machine_id and active=true
  order by sort_order;

  if (select count(*) from public.machine_coffee_containers where machine_id=v_target_machine_id and active)<>8
     or (select count(*) from public.machine_coffee_buttons where machine_id=v_target_machine_id and active)<>18
     or (select count(*) from public.machine_coffee_recipe_items where machine_id=v_target_machine_id and active)<>55
     or (select count(*) from public.machine_planogram_slots where machine_id=v_target_machine_id and active)<>18 then
    raise exception 'Kopie konfigurace EV126 neni kompletni 8/18/55/18.';
  end if;

  if exists (
    select 1 from (
      (select sb.selection_code,ri.container_code,p.sku,ri.quantity_per_vend,ri.unit
       from public.machine_coffee_recipe_items ri
       join public.machine_coffee_buttons sb on sb.id=ri.coffee_button_id
       join public.products p on p.id=ri.product_id
       where ri.machine_id=v_source_machine_id and ri.active
       except all
       select tb.selection_code,ri.container_code,p.sku,ri.quantity_per_vend,ri.unit
       from public.machine_coffee_recipe_items ri
       join public.machine_coffee_buttons tb on tb.id=ri.coffee_button_id
       join public.products p on p.id=ri.product_id
       where ri.machine_id=v_target_machine_id and ri.active)
      union all
      (select tb.selection_code,ri.container_code,p.sku,ri.quantity_per_vend,ri.unit
       from public.machine_coffee_recipe_items ri
       join public.machine_coffee_buttons tb on tb.id=ri.coffee_button_id
       join public.products p on p.id=ri.product_id
       where ri.machine_id=v_target_machine_id and ri.active
       except all
       select sb.selection_code,ri.container_code,p.sku,ri.quantity_per_vend,ri.unit
       from public.machine_coffee_recipe_items ri
       join public.machine_coffee_buttons sb on sb.id=ri.coffee_button_id
       join public.products p on p.id=ri.product_id
       where ri.machine_id=v_source_machine_id and ri.active)
    ) difference
  ) then
    raise exception 'Receptury EV126 nejsou presnou kopii EV125.';
  end if;

  if (select count(*) from public.machine_coffee_buttons where machine_id=v_target_machine_id and active and sale_price_czk=10)<>12
     or (select count(*) from public.machine_coffee_buttons where machine_id=v_target_machine_id and active and sale_price_czk=7)<>6 then
    raise exception 'Ceny EV126 neodpovidaji 12x10 Kc a 6x7 Kc.';
  end if;

  if exists (select 1 from public.machine_external_links where machine_id=v_target_machine_id) then
    raise exception 'EV126 nesmi mit terminalovou vazbu pred zjistenim TID.';
  end if;

  insert into public.stock_locations(location_type,name,machine_id,active,note)
  values('machine','Automat EV 126',v_target_machine_id,true,
         'Skladové místo druhého Jetinno JL300 na Vitaru; založeno 4. 9. 2026.')
  returning id into v_target_stock_location_id;

  select id into strict v_cup_product_id from public.products where sku='255' and active=true;
  select id into strict v_cup_container_id
  from public.machine_coffee_containers
  where machine_id=v_target_machine_id and container_code='Z8' and product_id=v_cup_product_id
    and capacity_quantity=450 and current_quantity=0 and active=true
  for update;

  select quantity_on_hand into strict v_blucina_before
  from public.stock_location_balances
  where stock_location_id=1 and product_id=v_cup_product_id and batch_id is null
  for update;

  if v_blucina_before<450 then
    raise exception 'Sklad BLUCINA nema 450 ks Kelimek 250 ml; stav je %.',v_blucina_before;
  end if;

  perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
    'product_id',v_cup_product_id,'batch_id',null,
    'from_stock_location_id',1,'to_stock_location_id',v_target_stock_location_id,
    'movement_type','fill_machine','quantity_base_units',450,
    'reference_type','manual_transfer','reference_id',v_reference_id,
    'note','První naplnění Jetinno JL300 EV126 na Vitaru · Z8 · 450 ks Kelímek 250 ml ze skladu BLUČINA',
    'allow_negative_source',false
  )));

  update public.machine_coffee_containers
  set current_quantity=450,
      note='Jetinno JL300 EV126 · Z8 · kapacita 450 ks · první naplnění 450 ks ze skladu BLUČINA dne 4. 9. 2026.',
      updated_at=now()
  where id=v_cup_container_id;

  update public.machines
  set stock_initialized_at=now(),updated_at=now()
  where id=v_target_machine_id;

  if (select quantity_on_hand from public.stock_location_balances
      where stock_location_id=1 and product_id=v_cup_product_id and batch_id is null)<>v_blucina_before-450 then
    raise exception 'Kontrola zůstatku skladu BLUCINA selhala.';
  end if;

  if (select quantity_on_hand from public.stock_location_balances
      where stock_location_id=v_target_stock_location_id and product_id=v_cup_product_id and batch_id is null)<>450
     or (select current_quantity from public.machine_coffee_containers where id=v_cup_container_id)<>450 then
    raise exception 'Kontrola stavu kelimku EV126 selhala.';
  end if;
end $$;

commit;

select m.id,m.evidence_number,m.name,m.location_id,m.status,m.sales_tracking_mode,
       count(distinct c.id) filter(where c.active) active_containers,
       count(distinct b.id) filter(where b.active) active_buttons,
       count(distinct ri.id) filter(where ri.active) active_recipe_items,
       max(c.current_quantity) filter(where c.product_sku='255' and c.active) cups_z8,
       (select quantity_on_hand from public.stock_location_balances where stock_location_id=1 and product_id=79 and batch_id is null) blucina_cups
from public.machines m
left join public.machine_coffee_containers c on c.machine_id=m.id
left join public.machine_coffee_buttons b on b.machine_id=m.id
left join public.machine_coffee_recipe_items ri on ri.machine_id=m.id
where m.evidence_number=126
group by m.id,m.evidence_number,m.name,m.location_id,m.status,m.sales_tracking_mode;
