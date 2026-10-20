-- EV 78 / RÖHLÍQ SUUS Holubice: operátor 16. 10. 2026 na pozici 44
-- zaznamenal kompletní výměnu Havlíku za Arašídy. Manažer následně potvrdil,
-- že fyzicky je na pozici 44 Havlík; Arašídy jsou pouze na pozici 49 a
-- Pistácie na pozici 48. Tato oprava vrací falešné skladové přesuny, opravuje
-- plánogram i uzavřenou návštěvu a doplňuje chybějící fyzický stav Havlíku.

begin;

create table if not exists public.repair_ev78_rohliq_slot44_havlik_audit_20261016 (
  repair_key text primary key,
  before_state jsonb not null,
  after_state jsonb,
  repaired_at timestamptz not null default now()
);

-- Internal rollback evidence only. It must never be reachable from a client
-- session, even by an authenticated employee account.
alter table public.repair_ev78_rohliq_slot44_havlik_audit_20261016 enable row level security;
revoke all on table public.repair_ev78_rohliq_slot44_havlik_audit_20261016 from public, anon, authenticated;

do $$
declare
  v_machine public.machines%rowtype;
  v_visit public.route_machine_visits%rowtype;
  v_slot43 public.machine_planogram_slots%rowtype;
  v_slot44 public.machine_planogram_slots%rowtype;
  v_slot48 public.machine_planogram_slots%rowtype;
  v_slot49 public.machine_planogram_slots%rowtype;
  v_havlik public.products%rowtype;
  v_peanuts public.products%rowtype;
  v_actor_id uuid;
  v_correction_audit_id bigint;
  v_before jsonb;
  v_after jsonb;
begin
  if exists (
    select 1
    from public.repair_ev78_rohliq_slot44_havlik_audit_20261016
    where repair_key = 'ev78-rohliq-slot44-havlik-2026-10-16'
      and after_state is not null
  ) then
    return;
  end if;

  select * into strict v_machine
  from public.machines
  where id = 58
    and evidence_number = 78
    and location_id = 121
    and status = 'ok'
    and active = true
    and sales_tracking_mode = 'telemetry'
  for update;

  select * into strict v_visit
  from public.route_machine_visits
  where id = 1307
    and machine_id = v_machine.id
    and visit_date = date '2026-10-16'
    and status = 'completed'
    and correction_revision = 1
  for update;

  select id into strict v_actor_id
  from public.employees
  where id = 'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid
    and name = 'Michal'
    and active = true
    and lower(role) in ('admin', 'manager');

  select * into strict v_slot43
  from public.machine_planogram_slots
  where machine_id = v_machine.id and slot_code = '43' and active = true
  for update;

  select * into strict v_slot44
  from public.machine_planogram_slots
  where machine_id = v_machine.id and slot_code = '44' and active = true
  for update;

  select * into strict v_slot48
  from public.machine_planogram_slots
  where machine_id = v_machine.id and slot_code = '48' and active = true
  for update;

  select * into strict v_slot49
  from public.machine_planogram_slots
  where machine_id = v_machine.id and slot_code = '49' and active = true
  for update;

  select * into strict v_havlik
  from public.products
  where id = 62 and sku = '38' and active = true;

  select * into strict v_peanuts
  from public.products
  where id = 241 and sku = 'VA-ARASIDY-PRAZ-SOL-100' and active = true;

  if v_slot43.product_sku <> v_havlik.sku
     or v_slot43.current_units <> 4
     or v_slot43.capacity_units <> 6
     or v_slot43.customer_price_czk <> 19 then
    raise exception 'Referencni Havlik pozice 43 se zmenila.';
  end if;

  if v_slot44.product_sku <> v_peanuts.sku
     or v_slot44.current_units <> 6
     or v_slot44.capacity_units <> 6
     or v_slot44.customer_price_czk <> 20 then
    raise exception 'Chybny mezistav pozice 44 uz neodpovida auditu.';
  end if;

  if v_slot48.product_sku <> 'VA-PISTACIE-PRAZ-SOL-60'
     or v_slot48.current_units <> 6
     or v_slot49.product_sku <> v_peanuts.sku
     or v_slot49.current_units <> 6 then
    raise exception 'Potvrzene pozice 48/49 se zmenily.';
  end if;

  if not exists (
    select 1 from public.route_machine_visit_items
    where id = 36847 and visit_id = v_visit.id and planogram_slot_id = v_slot44.id
      and actual_product_id = v_peanuts.id
      and actual_before_quantity = 6
      and actual_add_quantity = 6
      and removed_quantity = 6
      and final_quantity = 6
  ) then
    raise exception 'Chybny radek navstevy pro pozici 44 uz neodpovida auditu.';
  end if;

  if not exists (
    select 1 from public.route_machine_visit_food_fills
    where id = 13571 and visit_id = v_visit.id and planogram_slot_id = v_slot44.id
      and product_id = v_peanuts.id and quantity = 6
      and stock_reference_id = 'route_visit_1307_food_slot_1656_fill_0_241'
  ) then
    raise exception 'Chybne doplneni Arasidu na pozici 44 uz neodpovida auditu.';
  end if;

  if (select coalesce(sum(quantity_base_units), 0)
      from public.stock_movements_v13
      where reference_id = 'route_visit_1307_food_slot_1656_full_swap_return_62'
        and product_id = v_havlik.id and from_stock_location_id = 36 and to_stock_location_id = 2) <> 6 then
    raise exception 'Puvodni chybny vratkovy pohyb Havliku uz neodpovida auditu.';
  end if;

  if (select coalesce(sum(quantity_base_units), 0)
      from public.stock_movements_v13
      where reference_id = 'route_visit_1307_food_slot_1656_fill_0_241'
        and product_id = v_peanuts.id and batch_id = 851
        and from_stock_location_id = 2 and to_stock_location_id = 36) <> 6 then
    raise exception 'Puvodni chybny pohyb Arasidu uz neodpovida auditu.';
  end if;

  if (select coalesce(sum(quantity_on_hand), 0)
      from public.stock_location_balances
      where stock_location_id = 36 and product_id = v_havlik.id) <> -2 then
    raise exception 'Vychozi skladovy stav Havliku EV 78 neni -2 ks.';
  end if;

  if (select coalesce(sum(quantity_on_hand), 0)
      from public.stock_location_balances
      where stock_location_id = 36 and product_id = v_peanuts.id) <> 12 then
    raise exception 'Vychozi skladovy stav Arasidu EV 78 neni 12 ks.';
  end if;

  if (select coalesce(sum(quantity_on_hand), 0)
      from public.stock_location_balances
      where stock_location_id = 2 and product_id = v_havlik.id) <> 35 then
    raise exception 'Vychozi skladovy stav Havliku v aute neni 35 ks.';
  end if;

  v_before := jsonb_build_object(
    'visit', to_jsonb(v_visit),
    'slot43', to_jsonb(v_slot43),
    'slot44', to_jsonb(v_slot44),
    'slot48', to_jsonb(v_slot48),
    'slot49', to_jsonb(v_slot49),
    'visit_item_44', (
      select to_jsonb(item) from public.route_machine_visit_items item where item.id = 36847
    ),
    'fills_44', (
      select coalesce(jsonb_agg(to_jsonb(fill) order by fill.id), '[]'::jsonb)
      from public.route_machine_visit_food_fills fill
      where fill.visit_id = v_visit.id and fill.planogram_slot_id = v_slot44.id
    ),
    'balances', (
      select coalesce(jsonb_agg(to_jsonb(balance) order by balance.stock_location_id, balance.product_id, balance.batch_id), '[]'::jsonb)
      from public.stock_location_balances balance
      where balance.stock_location_id in (2, 36)
        and balance.product_id in (v_havlik.id, v_peanuts.id)
    )
  );

  insert into public.repair_ev78_rohliq_slot44_havlik_audit_20261016
    (repair_key, before_state)
  values ('ev78-rohliq-slot44-havlik-2026-10-16', v_before)
  on conflict (repair_key) do nothing;

  insert into public.route_visit_corrections
    (visit_id, actor_id, reason, before_data, after_data)
  values (
    v_visit.id,
    v_actor_id,
    'EV 78 RÖHLÍQ: pozice 44 je fyzicky Havlík; zrušení chybně zapsané výměny za Arašídy.',
    v_before,
    '{}'::jsonb
  )
  returning id into v_correction_audit_id;

  perform set_config('olvend.route_correction', 'on', true);

  perform public.apply_stock_movements_v13(jsonb_build_array(
    jsonb_build_object(
      'product_id', v_peanuts.id,
      'batch_id', 851,
      'from_stock_location_id', 36,
      'to_stock_location_id', 2,
      'movement_type', 'return',
      'quantity_base_units', 6,
      'reference_type', 'route_correction',
      'reference_id', 'repair_ev78_slot44_return_false_peanuts_20261016',
      'created_by', v_actor_id,
      'note', 'EV 78 RÖHLÍQ · pozice 44 · vrácení chybně evidovaných Arašídů do vozidla'
    ),
    jsonb_build_object(
      'product_id', v_havlik.id,
      'batch_id', null,
      'from_stock_location_id', 2,
      'to_stock_location_id', 36,
      'movement_type', 'fill_machine',
      'quantity_base_units', 6,
      'reference_type', 'route_correction',
      'reference_id', 'repair_ev78_slot44_reverse_false_havlik_return_20261016',
      'created_by', v_actor_id,
      'note', 'EV 78 RÖHLÍQ · pozice 44 · zrušení chybně evidovaného vrácení Havlíku do vozidla'
    ),
    jsonb_build_object(
      'product_id', v_havlik.id,
      'batch_id', null,
      'from_stock_location_id', null,
      'to_stock_location_id', 36,
      'movement_type', 'adjustment',
      'quantity_base_units', 6,
      'reference_type', 'route_correction',
      'reference_id', 'repair_ev78_slot44_havlik_physical_stock_20261016',
      'created_by', v_actor_id,
      'note', 'EV 78 RÖHLÍQ · pozice 44 · fyzicky potvrzen Havlík 6 ks, dříve chyběl v souhrnné skladové evidenci stroje'
    )
  ));

  delete from public.route_machine_visit_food_fills
  where id = 13571 and visit_id = v_visit.id and planogram_slot_id = v_slot44.id;

  if not found then
    raise exception 'Chybne doplneni Arasidu na pozici 44 nebylo odstraneno.';
  end if;

  update public.machine_planogram_slots
  set product_sku = v_havlik.sku,
      product_name = v_havlik.name,
      price_czk = v_slot43.price_czk,
      dex_price_czk = v_slot43.dex_price_czk,
      customer_price_czk = v_slot43.customer_price_czk,
      current_units = 6,
      last_units = 6,
      desired_units = 0,
      fill_percent = 100,
      target_units = 6,
      replenishment_mode = v_slot43.replenishment_mode,
      product_family = v_slot43.product_family,
      product_variant = v_slot43.product_variant,
      substitution_policy = v_slot43.substitution_policy,
      allowed_substitutes = v_slot43.allowed_substitutes,
      operator_instruction = 'Pozice 44 · Havlík Tyčinky originál 90g SKU 38. Při návštěvě ověř počet a expiraci.',
      planned_product_sku = null,
      planned_product_name = null,
      planned_price_czk = null,
      pending_product_id = null,
      pending_product_sku = null,
      pending_product_name = null,
      pending_price_czk = null,
      pending_change_effective_date = null,
      pending_change_note = null,
      pending_change_mode = 'sell_through',
      changeover_old_units = null,
      changeover_new_units = null,
      changeover_started_at = null,
      expiry_date = null,
      note = concat_ws(' · ', nullif(note, ''), '16. 10. 2026: RÖHLÍQ Holubice, manažersky potvrzen Havlík 6 ks; chybný zápis výměny za Arašídy zrušen.'),
      updated_at = now()
  where id = v_slot44.id;

  update public.route_machine_visit_items
  set planned_product_id = v_havlik.id,
      planned_product_sku = v_havlik.sku,
      planned_product_name = v_havlik.name,
      actual_product_id = v_havlik.id,
      actual_product_sku = v_havlik.sku,
      actual_product_name = v_havlik.name,
      sale_price_czk = v_slot43.customer_price_czk,
      system_current_quantity = 6,
      actual_before_quantity = 6,
      suggested_add_quantity = 0,
      actual_add_quantity = 0,
      removed_quantity = 0,
      final_quantity = 6,
      capacity_quantity = 6,
      issue_type = 'telemetry_mismatch',
      substitution_reason = 'Mobil chybně zaznamenal výměnu Havlíku za Arašídy.',
      operator_note = 'Manažerská oprava 16. 10. 2026: pozice 44 je fyzicky Havlík 6 ks. Chybně zapsaná výměna za Arašídy byla zrušena; nic nebylo doplněno ani odvezeno.',
      updated_at = now()
  where id = 36847 and visit_id = v_visit.id and planogram_slot_id = v_slot44.id;

  if not found then
    raise exception 'Radek navstevy pro pozici 44 nebyl opraven.';
  end if;

  update public.route_machine_visits
  set food_preparation = jsonb_set(
        coalesce(food_preparation, '{}'::jsonb),
        array[v_slot44.id::text],
        coalesce(food_preparation -> v_slot44.id::text, '{}'::jsonb) || jsonb_build_object(
          'selectedProductId', v_havlik.id,
          'existingProductId', v_havlik.id,
          'actualBefore', 6,
          'actualAdd', 0,
          'capacityUnits', 6,
          'fillItems', '[]'::jsonb,
          'pickedQuantity', 0,
          'preparedQuantity', 0,
          'basePreparedQuantity', 0,
          'extraVehicleQuantity', 0,
          'picked', false,
          'skipped', false,
          'skipReason', '',
          'notInsertedReason', '',
          'note', 'Manažerská oprava: fyzicky Havlík 6 ks; chybná výměna za Arašídy byla zrušena.',
          'accepted', true
        ),
        true
      ),
      correction_revision = correction_revision + 1,
      operator_note = concat_ws(' · ', nullif(operator_note, ''), 'Oprava pozice 44: Havlík 6 ks, nikoli Arašídy.'),
      synced_at = now(),
      updated_at = now()
  where id = v_visit.id;

  if (select coalesce(sum(quantity_on_hand), 0)
      from public.stock_location_balances
      where stock_location_id = 36 and product_id = v_havlik.id) <> 10 then
    raise exception 'Skladovy stav Havliku EV 78 po oprave neni 10 ks.';
  end if;

  if (select coalesce(sum(quantity_on_hand), 0)
      from public.stock_location_balances
      where stock_location_id = 36 and product_id = v_peanuts.id) <> 6 then
    raise exception 'Skladovy stav Arasidu EV 78 po oprave neni 6 ks.';
  end if;

  if (select coalesce(sum(quantity_on_hand), 0)
      from public.stock_location_balances
      where stock_location_id = 2 and product_id = v_havlik.id) <> 29 then
    raise exception 'Skladovy stav Havliku v aute po oprave neni 29 ks.';
  end if;

  if exists (
    select 1 from public.route_machine_visit_food_fills
    where visit_id = v_visit.id and planogram_slot_id = v_slot44.id
  ) then
    raise exception 'Pozice 44 ma po oprave stale zaznam doplneni.';
  end if;

  v_after := jsonb_build_object(
    'visit', (select to_jsonb(visit) from public.route_machine_visits visit where visit.id = v_visit.id),
    'slot43', (select to_jsonb(slot) from public.machine_planogram_slots slot where slot.id = v_slot43.id),
    'slot44', (select to_jsonb(slot) from public.machine_planogram_slots slot where slot.id = v_slot44.id),
    'slot48', (select to_jsonb(slot) from public.machine_planogram_slots slot where slot.id = v_slot48.id),
    'slot49', (select to_jsonb(slot) from public.machine_planogram_slots slot where slot.id = v_slot49.id),
    'visit_item_44', (select to_jsonb(item) from public.route_machine_visit_items item where item.id = 36847),
    'fills_44', (
      select coalesce(jsonb_agg(to_jsonb(fill) order by fill.id), '[]'::jsonb)
      from public.route_machine_visit_food_fills fill
      where fill.visit_id = v_visit.id and fill.planogram_slot_id = v_slot44.id
    ),
    'balances', (
      select coalesce(jsonb_agg(to_jsonb(balance) order by balance.stock_location_id, balance.product_id, balance.batch_id), '[]'::jsonb)
      from public.stock_location_balances balance
      where balance.stock_location_id in (2, 36)
        and balance.product_id in (v_havlik.id, v_peanuts.id)
    )
  );

  update public.repair_ev78_rohliq_slot44_havlik_audit_20261016
  set after_state = v_after,
      repaired_at = now()
  where repair_key = 'ev78-rohliq-slot44-havlik-2026-10-16';

  update public.route_visit_corrections
  set after_data = v_after
  where id = v_correction_audit_id;

  perform set_config('olvend.route_correction', 'off', true);
end;
$$;

commit;

select jsonb_build_object(
  'slots', (
    select jsonb_agg(jsonb_build_object(
      'slot', slot.slot_code,
      'sku', slot.product_sku,
      'name', slot.product_name,
      'current', slot.current_units,
      'capacity', slot.capacity_units,
      'desired', slot.desired_units,
      'price', slot.customer_price_czk
    ) order by slot.slot_code)
    from public.machine_planogram_slots slot
    where slot.machine_id = 58 and slot.active = true
      and slot.slot_code in ('43','44','47','48','49')
  ),
  'machine_balances', (
    select jsonb_agg(jsonb_build_object('sku', product.sku, 'quantity', balance.quantity) order by product.sku)
    from (
      select product_id, sum(quantity_on_hand) as quantity
      from public.stock_location_balances
      where stock_location_id = 36 and product_id in (62,241,256)
      group by product_id
    ) balance
    join public.products product on product.id = balance.product_id
  ),
  'vehicle_balances', (
    select jsonb_agg(jsonb_build_object('sku', product.sku, 'quantity', balance.quantity) order by product.sku)
    from (
      select product_id, sum(quantity_on_hand) as quantity
      from public.stock_location_balances
      where stock_location_id = 2 and product_id in (62,241)
      group by product_id
    ) balance
    join public.products product on product.id = balance.product_id
  ),
  'visit_item_44', (
    select jsonb_build_object(
      'planned_sku', item.planned_product_sku,
      'actual_sku', item.actual_product_sku,
      'before', item.actual_before_quantity,
      'added', item.actual_add_quantity,
      'removed', item.removed_quantity,
      'final', item.final_quantity,
      'price', item.sale_price_czk
    )
    from public.route_machine_visit_items item where item.id = 36847
  ),
  'fill_rows_44', (
    select count(*) from public.route_machine_visit_food_fills
    where visit_id = 1307 and planogram_slot_id = 1656
  ),
  'revision', (select correction_revision from public.route_machine_visits where id = 1307)
) as verification;
