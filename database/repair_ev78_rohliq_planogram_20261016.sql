-- EV 78 / RÖHLÍQ SUUS Holubice: při přesunu 9. 10. 2026 zůstal v pozici 47
-- starý plánogram Vitaru (HAMÉ). Uživatel 16. 10. potvrdil, že fyzický a
-- aktuální plánogram má v této pozici DrWitt. Pozice 44/49 Arašídy a 48
-- Pistácie byly fyzicky potvrzené dnešní návštěvou; jejich produktové mapování
-- je již správné, ale Pistácie chybějí ve skladové evidenci stroje.

begin;

create table if not exists public.repair_ev78_rohliq_planogram_audit_20261016 (
  repair_key text primary key,
  before_state jsonb not null,
  after_state jsonb,
  repaired_at timestamptz not null default now()
);

do $$
declare
  v_machine public.machines%rowtype;
  v_visit public.route_machine_visits%rowtype;
  v_slot45 public.machine_planogram_slots%rowtype;
  v_slot47 public.machine_planogram_slots%rowtype;
  v_slot48 public.machine_planogram_slots%rowtype;
  v_drwitt public.products%rowtype;
  v_pistachio public.products%rowtype;
  v_employee_id uuid;
  v_actor_id uuid;
  v_correction_audit_id bigint;
  v_before jsonb;
  v_after jsonb;
  v_balance numeric(14,3);
begin
  if exists (
    select 1
    from public.repair_ev78_rohliq_planogram_audit_20261016
    where repair_key = 'ev78-rohliq-planogram-2026-10-16'
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

  if not exists (
    select 1
    from public.machine_external_links link
    join public.machine_telemetry_state telemetry
      on telemetry.machine_id = link.machine_id
     and telemetry.provider = link.provider
    where link.machine_id = v_machine.id
      and link.provider = 'IMA'
      and link.external_machine_id = '635461'
      and link.telemetry_enabled = true
      and telemetry.connectivity_status = 'online'
      and telemetry.last_seen_at >= now() - interval '24 hours'
  ) then
    raise exception 'EV 78 nema overene online napojeni IMA 635461.';
  end if;

  select * into strict v_visit
  from public.route_machine_visits
  where id = 1307
    and machine_id = v_machine.id
    and visit_date = date '2026-10-16'
    and status = 'completed'
  for update;

  v_employee_id := v_visit.employee_id;

  select id into strict v_actor_id
  from public.employees
  where id = 'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid
    and name = 'Michal'
    and active = true
    and lower(role) in ('admin', 'manager');

  select * into strict v_slot45
  from public.machine_planogram_slots
  where machine_id = v_machine.id and slot_code = '45' and active = true
  for update;

  select * into strict v_slot47
  from public.machine_planogram_slots
  where machine_id = v_machine.id and slot_code = '47' and active = true
  for update;

  select * into strict v_slot48
  from public.machine_planogram_slots
  where machine_id = v_machine.id and slot_code = '48' and active = true
  for update;

  select * into strict v_drwitt
  from public.products
  where id = 156 and sku = '276' and active = true;

  select * into strict v_pistachio
  from public.products
  where id = 256 and sku = 'VA-PISTACIE-PRAZ-SOL-60' and active = true;

  if v_slot45.product_sku <> v_drwitt.sku
     or v_slot45.current_units <> 6
     or v_slot45.capacity_units <> 6 then
    raise exception 'Referencni DrWitt pozice 45 se zmenila.';
  end if;

  if v_slot47.product_sku <> 'HAME-KURECI-STRIPS'
     or v_slot47.current_units <> 0
     or v_slot47.capacity_units <> 6 then
    raise exception 'Stara HAMÉ pozice 47 uz neodpovida auditu.';
  end if;

  if v_slot48.product_sku <> v_pistachio.sku
     or v_slot48.current_units <> 6
     or v_slot48.capacity_units <> 6 then
    raise exception 'Pistácie v pozici 48 uz neodpovidaji dnesnimu fyzickemu potvrzeni.';
  end if;

  if not exists (
    select 1 from public.machine_planogram_slots
    where machine_id = v_machine.id and slot_code = '44' and active = true
      and product_sku = 'VA-ARASIDY-PRAZ-SOL-100' and current_units = 6
  ) or not exists (
    select 1 from public.machine_planogram_slots
    where machine_id = v_machine.id and slot_code = '49' and active = true
      and product_sku = 'VA-ARASIDY-PRAZ-SOL-100' and current_units = 6
  ) then
    raise exception 'Arašídy v pozicich 44/49 neodpovidaji dnesnimu fyzickemu potvrzeni.';
  end if;

  select coalesce(sum(balance.quantity_on_hand), 0)
    into v_balance
  from public.stock_location_balances balance
  where balance.stock_location_id = 36
    and balance.product_id = v_drwitt.id;
  if v_balance <> 6 then
    raise exception 'Vychozi skladovy stav DrWitt EV 78 je %, ocekavano 6.', v_balance;
  end if;

  select coalesce(sum(balance.quantity_on_hand), 0)
    into v_balance
  from public.stock_location_balances balance
  where balance.stock_location_id = 36
    and balance.product_id = v_pistachio.id;
  if v_balance <> 0 then
    raise exception 'Vychozi skladovy stav Pistacii EV 78 je %, ocekavano 0.', v_balance;
  end if;

  v_before := jsonb_build_object(
    'machine', to_jsonb(v_machine),
    'visit', to_jsonb(v_visit),
    'slot45', to_jsonb(v_slot45),
    'slot47', to_jsonb(v_slot47),
    'slot48', to_jsonb(v_slot48),
    'visit_item_47', (
      select to_jsonb(item)
      from public.route_machine_visit_items item
      where item.visit_id = v_visit.id and item.planogram_slot_id = v_slot47.id
    ),
    'balances', (
      select coalesce(jsonb_agg(to_jsonb(balance) order by balance.product_id), '[]'::jsonb)
      from public.stock_location_balances balance
      where balance.stock_location_id = 36
        and balance.product_id in (v_drwitt.id, v_pistachio.id, 239, 241)
    )
  );

  insert into public.repair_ev78_rohliq_planogram_audit_20261016
    (repair_key, before_state)
  values ('ev78-rohliq-planogram-2026-10-16', v_before)
  on conflict (repair_key) do nothing;

  insert into public.route_visit_corrections
    (visit_id, actor_id, reason, before_data, after_data)
  values (
    v_visit.id,
    v_actor_id,
    'EV 78 RÖHLÍQ: oprava starého plánogramu Vitaru v pozici 47 a fyzicky potvrzených stavů DrWitt/Pistácie.',
    v_before,
    '{}'::jsonb
  )
  returning id into v_correction_audit_id;

  -- Následující změny uzavřené návštěvy jsou výslovná manažerská korekce.
  -- Kontext zároveň zabrání tomu, aby je ochranné triggery zaměnily za starý
  -- mobilní zápis operátora.
  perform set_config('olvend.route_correction', 'on', true);

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'route_correction'
      and reference_id = 'repair_ev78_slot47_drwitt_20261016'
  ) then
    perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
      'product_id', v_drwitt.id,
      'batch_id', null,
      'from_stock_location_id', null,
      'to_stock_location_id', 36,
      'movement_type', 'adjustment',
      'quantity_base_units', 6,
      'reference_type', 'route_correction',
      'reference_id', 'repair_ev78_slot47_drwitt_20261016',
      'created_by', v_employee_id,
      'note', 'EV 78 RÖHLÍQ · pozice 47 · oprava starého plánogramu Vitaru: fyzicky DrWitt 6 ks, nikoli HAMÉ'
    )));
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'route_correction'
      and reference_id = 'repair_ev78_slot48_pistachio_20261016'
  ) then
    perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
      'product_id', v_pistachio.id,
      'batch_id', null,
      'from_stock_location_id', null,
      'to_stock_location_id', 36,
      'movement_type', 'adjustment',
      'quantity_base_units', 6,
      'reference_type', 'route_correction',
      'reference_id', 'repair_ev78_slot48_pistachio_20261016',
      'created_by', v_employee_id,
      'note', 'EV 78 RÖHLÍQ · pozice 48 · doplnění skladové evidence podle fyzického potvrzení Pistácií 6 ks dne 16. 10. 2026'
    )));
  end if;

  update public.machine_planogram_slots
  set product_sku = v_drwitt.sku,
      product_name = v_drwitt.name,
      price_czk = v_slot45.price_czk,
      dex_price_czk = v_slot45.dex_price_czk,
      customer_price_czk = v_slot45.customer_price_czk,
      current_units = 6,
      last_units = 6,
      desired_units = 0,
      fill_percent = 100,
      target_units = 6,
      replenishment_mode = v_slot45.replenishment_mode,
      product_family = v_slot45.product_family,
      product_variant = 'Citrus',
      substitution_policy = v_slot45.substitution_policy,
      allowed_substitutes = v_slot45.allowed_substitutes,
      operator_instruction = 'Pozice 47 · DrWitt citrus SKU 276. Při návštěvě ověř počet a expiraci.',
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
      note = concat_ws(' · ', nullif(note, ''), '16. 10. 2026: RÖHLÍQ Holubice, oprava starého plánogramu Vitaru; fyzicky potvrzen DrWitt 6 ks.'),
      updated_at = now()
  where id = v_slot47.id;

  update public.route_machine_visit_items
  set planned_product_id = v_drwitt.id,
      planned_product_sku = v_drwitt.sku,
      planned_product_name = v_drwitt.name,
      actual_product_id = v_drwitt.id,
      actual_product_sku = v_drwitt.sku,
      actual_product_name = v_drwitt.name,
      sale_price_czk = v_slot45.customer_price_czk,
      system_current_quantity = 0,
      actual_before_quantity = 6,
      suggested_add_quantity = 0,
      actual_add_quantity = 0,
      removed_quantity = 0,
      final_quantity = 6,
      capacity_quantity = 6,
      issue_type = 'telemetry_mismatch',
      substitution_reason = 'Při přesunu na RÖHLÍQ zůstal uložen starý plánogram Vitaru.',
      operator_note = 'Manažerská oprava 16. 10. 2026: pozice 47 byla fyzicky DrWitt 6 ks; aplikace chybně nabízela HAMÉ ze starého plánogramu Vitaru. Nic nebylo doplněno.',
      updated_at = now()
  where visit_id = v_visit.id
    and planogram_slot_id = v_slot47.id;

  if not found then
    raise exception 'Dnesni radek navstevy EV 78 pro pozici 47 nebyl nalezen.';
  end if;

  update public.route_machine_visits
  set food_preparation = jsonb_set(
        coalesce(food_preparation, '{}'::jsonb),
        array[v_slot47.id::text],
        coalesce(food_preparation -> v_slot47.id::text, '{}'::jsonb) || jsonb_build_object(
          'selectedProductId', v_drwitt.id,
          'existingProductId', v_drwitt.id,
          'actualBefore', 6,
          'actualAdd', 0,
          'capacityUnits', 6,
          'fillItems', jsonb_build_array(jsonb_build_object(
            'productId', v_drwitt.id,
            'quantity', 0,
            'batchId', null,
            'expiryDate', ''
          )),
          'pickedQuantity', 0,
          'preparedQuantity', 0,
          'basePreparedQuantity', 0,
          'extraVehicleQuantity', 0,
          'picked', false,
          'skipped', false,
          'skipReason', '',
          'notInsertedReason', '',
          'note', 'Manažerská oprava: fyzicky DrWitt 6 ks; starý plánogram HAMÉ byl chybný.',
          'accepted', true
        ),
        true
      ),
      correction_revision = coalesce(correction_revision, 0) + 1,
      operator_note = concat_ws(' · ', nullif(operator_note, ''), 'Oprava plánogramu pozice 47: DrWitt 6 ks místo HAMÉ.'),
      synced_at = now(),
      updated_at = now()
  where id = v_visit.id;

  if (select coalesce(sum(balance.quantity_on_hand), 0)
      from public.stock_location_balances balance
      where balance.stock_location_id = 36 and balance.product_id = v_drwitt.id) <> 12 then
    raise exception 'Skladovy stav DrWitt po oprave neni 12 ks.';
  end if;

  if (select coalesce(sum(balance.quantity_on_hand), 0)
      from public.stock_location_balances balance
      where balance.stock_location_id = 36 and balance.product_id = v_pistachio.id) <> 6 then
    raise exception 'Skladovy stav Pistacii po oprave neni 6 ks.';
  end if;

  if (select coalesce(sum(balance.quantity_on_hand), 0)
      from public.stock_location_balances balance
      where balance.stock_location_id = 36 and balance.product_id = 241) <> 12 then
    raise exception 'Skladovy stav Arasidu po oprave neni 12 ks.';
  end if;

  if not exists (
    select 1
    from public.machine_planogram_slots
    where id = v_slot47.id
      and product_sku = v_drwitt.sku
      and current_units = 6
      and desired_units = 0
      and fill_percent = 100
  ) then
    raise exception 'Pozice 47 se nepodarila prepnout na DrWitt 6 ks.';
  end if;

  v_after := jsonb_build_object(
    'slot47', (select to_jsonb(slot) from public.machine_planogram_slots slot where slot.id = v_slot47.id),
    'visit_item_47', (
      select to_jsonb(item)
      from public.route_machine_visit_items item
      where item.visit_id = v_visit.id and item.planogram_slot_id = v_slot47.id
    ),
    'balances', (
      select coalesce(jsonb_agg(to_jsonb(balance) order by balance.product_id), '[]'::jsonb)
      from public.stock_location_balances balance
      where balance.stock_location_id = 36
        and balance.product_id in (v_drwitt.id, v_pistachio.id, 239, 241)
    )
  );

  update public.repair_ev78_rohliq_planogram_audit_20261016
  set after_state = v_after,
      repaired_at = now()
  where repair_key = 'ev78-rohliq-planogram-2026-10-16';

  update public.route_visit_corrections
  set after_data = v_after
  where id = v_correction_audit_id;

  perform set_config('olvend.route_correction', 'off', true);
end;
$$;

commit;

select jsonb_build_object(
  'slot47', (
    select jsonb_build_object(
      'slot_code', slot.slot_code,
      'product_sku', slot.product_sku,
      'product_name', slot.product_name,
      'current_units', slot.current_units,
      'capacity_units', slot.capacity_units,
      'desired_units', slot.desired_units,
      'price_czk', slot.customer_price_czk
    )
    from public.machine_planogram_slots slot
    where slot.machine_id = 58 and slot.slot_code = '47' and slot.active = true
  ),
  'nuts', (
    select jsonb_agg(jsonb_build_object(
      'slot_code', slot.slot_code,
      'product_sku', slot.product_sku,
      'product_name', slot.product_name,
      'current_units', slot.current_units,
      'desired_units', slot.desired_units
    ) order by slot.slot_code)
    from public.machine_planogram_slots slot
    where slot.machine_id = 58 and slot.slot_code in ('44','48','49') and slot.active = true
  ),
  'balances', (
    select jsonb_agg(jsonb_build_object(
      'sku', product.sku,
      'quantity', balance.quantity
    ) order by product.sku)
    from (
      select product_id, sum(quantity_on_hand) as quantity
      from public.stock_location_balances
      where stock_location_id = 36
        and product_id in (156, 239, 241, 256)
      group by product_id
    ) balance
    join public.products product on product.id = balance.product_id
  ),
  'visit_item_47', (
    select jsonb_build_object(
      'planned_product_sku', item.planned_product_sku,
      'actual_product_sku', item.actual_product_sku,
      'actual_before_quantity', item.actual_before_quantity,
      'actual_add_quantity', item.actual_add_quantity,
      'final_quantity', item.final_quantity,
      'issue_type', item.issue_type
    )
    from public.route_machine_visit_items item
    where item.visit_id = 1307 and item.planogram_slot_id = 1624
  )
) as verification;
