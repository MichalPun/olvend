-- Novy Jetinno JL300 EV131 pro Domov senioru Breclav, hlavni budova.
-- Konfigurace a receptury jsou kopii overeneho EV126; vsechny napoje stoji 16 Kc.
-- Zasoby se pouze zalozi s nulovym stavem. Prvni novy DEX TID 587381 vytvori baseline.

begin;

do $$
declare
  v_source_machine_id bigint;
  v_target_machine_id bigint;
  v_location_id bigint;
  v_stock_location_id bigint;
begin
  select id into strict v_source_machine_id
  from public.machines
  where evidence_number=126
    and name='Jetinno JL300'
    and brand='Jetinno'
    and model='JL300'
    and status='ok'
    and active=true;

  select id into strict v_location_id
  from public.locations
  where id=18
    and name='Domov seniorů'
    and customer_name='Domov seniorů hl.budova'
    and city='Břeclav'
    and active=true;

  if exists (select 1 from public.machines where evidence_number=131) then
    raise exception 'Evidencni cislo EV131 uz existuje.';
  end if;

  if exists (select 1 from public.machines where qr_token='jetinno-jl300-ev131') then
    raise exception 'QR token pro EV131 uz existuje.';
  end if;

  if exists (
    select 1 from public.machine_external_links
    where external_machine_id='587381'
  ) then
    raise exception 'TID 587381 uz je prirazen k automatu.';
  end if;

  if not exists (
    select 1
    from public.telemetry_dex_ingests
    where device_id='587381'
      and provider='IMA'
      and status='parsed'
      and parse_error is null
      and created_at > now() - interval '1 hour'
  ) then
    raise exception 'TID 587381 neposlal v posledni hodine platny IMA DEX.';
  end if;

  if (select count(*) from public.machine_coffee_containers where machine_id=v_source_machine_id and active)<>8
     or (select count(*) from public.machine_coffee_buttons where machine_id=v_source_machine_id and active)<>18
     or (select count(*) from public.machine_coffee_recipe_items where machine_id=v_source_machine_id and active)<>55
     or (select count(*) from public.machine_planogram_slots where machine_id=v_source_machine_id and active)<>18 then
    raise exception 'Zdrojova konfigurace EV126 neni kompletni 8/18/55/18.';
  end if;

  insert into public.machines(
    location_id,name,machine_type,brand,model,serial_number,evidence_number,
    status,active,note,qr_token,sales_tracking_mode,stock_initialized_at,
    subsidy_default_enabled,subsidy_default_amount,subsidy_default_partner,subsidy_default_basis
  ) values (
    v_location_id,'Jetinno JL300','Coffee','Jetinno','JL300',null,131,
    'ok',true,
    'Nový Jetinno JL300 na lokalitě Domov seniorů Břeclav · TID 587381 · všechny nápoje 16 Kč · konfigurace převzata z EV126 · výchozí zásoby 0.',
    'jetinno-jl300-ev131','telemetry',null,
    false,0,null,'net'
  ) returning id into v_target_machine_id;

  insert into public.machine_transfers(
    machine_id,from_location_id,to_location_id,transfer_kind,
    from_status,to_status,from_active,to_active,transferred_at,transferred_by,note
  ) values (
    v_target_machine_id,null,v_location_id,'relocation',
    'installing','ok',true,true,now(),'Codex / potvrzeno Michal Punčochář',
    'První umístění Jetinno JL300 EV131 na lokalitu Domov seniorů Břeclav dne 16. 10. 2026.'
  );

  insert into public.machine_service_rules(
    machine_id,service_frequency,fill_frequency,stock_critical_percent,max_visit_interval_days,
    route_visit_rules_active,route_planning_paused_until,route_planning_excluded_months,
    route_planning_note,last_service_at,last_fill_at,note
  )
  select v_target_machine_id,service_frequency,fill_frequency,stock_critical_percent,max_visit_interval_days,
         route_visit_rules_active,null,route_planning_excluded_months,
         route_planning_note,null,null,'Výchozí servisní pravidla převzata z Jetinno EV126.'
  from public.machine_service_rules
  where machine_id=v_source_machine_id;

  insert into public.machine_coffee_containers(
    machine_id,container_code,product_sku,product_name,capacity_quantity,current_quantity,
    unit,refill_package_quantity,refill_package_unit,min_refill_quantity,sort_order,active,note,product_id
  )
  select v_target_machine_id,container_code,product_sku,product_name,capacity_quantity,0,
         unit,refill_package_quantity,refill_package_unit,min_refill_quantity,sort_order,active,
         'Jetinno JL300 EV131 · konfigurace převzata z EV126 · výchozí stav 0 '||unit||'.',product_id
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
  select v_target_machine_id,selection_code,product_sku,product_name,16,null,
         grid_column,grid_row_from_bottom,sort_order,active,
         'Jetinno JL300 EV131 · nabídka převzata z EV126 · prodejní cena 16 Kč.',16,
         settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,
         settlement_note,planned_product_name,planned_product_sku,
         case when planned_price_czk is null then null else 16 end,
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
  select v_target_machine_id,slot_code,product_name,product_sku,16,capacity_units,null,
         null,active,sort_order,
         'Zrcadlový slot Jetinno JL300 EV131 · konfigurace z EV126 · prodejní cena 16 Kč.',
         16,null,null,telemetry_key,null,product_family,product_variant,
         planned_product_name,planned_product_sku,
         case when planned_price_czk is null then null else 16 end,
         substitution_policy,allowed_substitutes,operator_instruction,16,
         subsidy_amount_czk,subsidy_payer,subsidy_billing_enabled,subsidy_note,
         settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,
         settlement_note,target_units,replenishment_mode,null,null,null,null,null,null,
         null,null,null,pending_change_mode
  from public.machine_planogram_slots
  where machine_id=v_source_machine_id and active=true
  order by sort_order;

  insert into public.machine_external_links(
    machine_id,provider,external_machine_id,external_location_id,telemetry_enabled,note
  ) values
    (v_target_machine_id,'IMA','587381',null,true,
     'TID 587381 · Jetinno JL300 EV131 · Domov seniorů Břeclav · aktivní IMA telemetrie od 16. 10. 2026.'),
    (v_target_machine_id,'GP','587381',null,true,
     'TID 587381 · Jetinno JL300 EV131 · Domov seniorů Břeclav · aktivní platební terminál od 16. 10. 2026.');

  insert into public.stock_locations(location_type,name,machine_id,active,note)
  values('machine','Automat EV 131',v_target_machine_id,true,
         'Skladové místo Jetinno JL300 EV131 · Domov seniorů Břeclav · výchozí stav zásob 0.')
  returning id into v_stock_location_id;

  if (select count(*) from public.machine_coffee_containers where machine_id=v_target_machine_id and active)<>8
     or (select count(*) from public.machine_coffee_buttons where machine_id=v_target_machine_id and active)<>18
     or (select count(*) from public.machine_coffee_recipe_items where machine_id=v_target_machine_id and active)<>55
     or (select count(*) from public.machine_planogram_slots where machine_id=v_target_machine_id and active)<>18 then
    raise exception 'Kopie konfigurace EV131 neni kompletni 8/18/55/18.';
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
    raise exception 'Receptury EV131 nejsou presnou kopii EV126.';
  end if;

  if (select count(*) from public.machine_coffee_buttons
      where machine_id=v_target_machine_id and active and sale_price_czk=16 and customer_price_czk=16)<>18
     or (select count(*) from public.machine_planogram_slots
         where machine_id=v_target_machine_id and active
           and price_czk=16 and customer_price_czk=16 and dex_price_czk=16)<>18 then
    raise exception 'Ne vsechny ceny EV131 jsou nastaveny na 16 Kc.';
  end if;

  if (select count(*) from public.machine_external_links
      where machine_id=v_target_machine_id and external_machine_id='587381'
        and provider in ('IMA','GP') and telemetry_enabled=true)<>2 then
    raise exception 'EV131 nema obe aktivni vazby IMA/GP pro TID 587381.';
  end if;

  if exists (select 1 from public.machine_telemetry_state where machine_id=v_target_machine_id)
     or exists (select 1 from public.telemetry_planogram_counters where machine_id=v_target_machine_id)
     or exists (select 1 from public.telemetry_sales_events where machine_id=v_target_machine_id) then
    raise exception 'EV131 nesmi pri zalozeni obsahovat stav, citace ani prodeje; prvni novy DEX musi byt baseline.';
  end if;

  if exists (select 1 from public.machine_coffee_containers where machine_id=v_target_machine_id and current_quantity<>0)
     or exists (select 1 from public.stock_location_balances where stock_location_id=v_stock_location_id and quantity_on_hand<>0) then
    raise exception 'EV131 nema nulovy pocatecni stav zasob.';
  end if;
end $$;

commit;

select jsonb_build_object(
  'machine', jsonb_build_object(
    'id',m.id,'evidence_number',m.evidence_number,'name',m.name,'location_id',m.location_id,
    'location',l.name,'customer_name',l.customer_name,'city',l.city,'status',m.status,
    'active',m.active,'sales_tracking_mode',m.sales_tracking_mode
  ),
  'configuration', jsonb_build_object(
    'containers',(select count(*) from public.machine_coffee_containers c where c.machine_id=m.id and c.active),
    'buttons',(select count(*) from public.machine_coffee_buttons b where b.machine_id=m.id and b.active),
    'recipe_items',(select count(*) from public.machine_coffee_recipe_items r where r.machine_id=m.id and r.active),
    'slots',(select count(*) from public.machine_planogram_slots s where s.machine_id=m.id and s.active),
    'buttons_at_16',(select count(*) from public.machine_coffee_buttons b where b.machine_id=m.id and b.active and b.customer_price_czk=16),
    'slots_at_16',(select count(*) from public.machine_planogram_slots s where s.machine_id=m.id and s.active and s.customer_price_czk=16)
  ),
  'links',(select jsonb_agg(jsonb_build_object('provider',x.provider,'tid',x.external_machine_id,'enabled',x.telemetry_enabled) order by x.provider)
           from public.machine_external_links x where x.machine_id=m.id),
  'stock',(select jsonb_build_object('stock_location_id',sl.id,'name',sl.name,'nonzero_balances',
           (select count(*) from public.stock_location_balances b where b.stock_location_id=sl.id and b.quantity_on_hand<>0))
           from public.stock_locations sl where sl.machine_id=m.id),
  'telemetry_baseline_pending', not exists(select 1 from public.machine_telemetry_state t where t.machine_id=m.id),
  'sales_count',(select count(*) from public.telemetry_sales_events e where e.machine_id=m.id)
) as verification
from public.machines m
join public.locations l on l.id=m.location_id
where m.evidence_number=131;
