-- EV 11 / Europa Snack Side: correct the physical cabinet layout.
-- The customer sees native Side selections 11-66, while the shared EV 105
-- controller keeps a separate non-overlapping telemetry range 33-68.

begin;

do $$
declare
  v_machine_id bigint;
  v_controller_machine_id bigint;
  v_active_count integer;
  v_invalid_count integer;
begin
  select id into strict v_machine_id
  from public.machines
  where evidence_number = 11;

  select id into strict v_controller_machine_id
  from public.machines
  where evidence_number = 105;

  perform pg_advisory_xact_lock(hashtextextended('ev11-side-layout-20261006', 0));

  create temporary table ev11_layout_desired (
    old_code text primary key,
    new_code text not null unique,
    expected_sku text not null,
    telemetry_key text not null unique,
    sort_order integer not null unique
  ) on commit drop;

  insert into ev11_layout_desired (old_code, new_code, expected_sku, telemetry_key, sort_order)
  values
    -- 1. rada odspodu: zakaznicke volby 11-16.
    ('65','11','163','33',1),
    ('66','12','163','34',2),
    ('67','13','4','35',3),
    ('68','14','190','36',4),
    ('69','15','6','37',5),
    ('70','16','41','38',6),
    -- 2. rada odspodu: zakaznicke volby 21-26.
    ('58','21','71','39',7),
    ('59','22','67','40',8),
    ('60','23','70','41',9),
    ('61','24','209','42',10),
    ('62','25','156','43',11),
    ('63','26','2','44',12),
    -- 3. rada odspodu: zakaznicke volby 31-37.
    ('51','31','SIMPLY-DEBRECIN','45',13),
    ('52','32','SIMPLY-PORIZEK','46',14),
    ('53','33','SIMPLY-MLSKA','47',15),
    ('54','34','38','48',16),
    ('55','35','210','49',17),
    ('56','36','277','50',18),
    ('57','37','207','51',19),
    -- 4. rada odspodu: zakaznicke volby 41-47.
    ('44','41','36','52',20),
    ('45','42','35','53',21),
    ('46','43','33','54',22),
    ('47','44','24','55',23),
    ('48','45','28','56',24),
    ('49','46','SOCO-BRIGIT-90','57',25),
    ('50','47','208','58',26),
    -- 5. rada odspodu: zakaznicke volby 51-57.
    ('37','51','SOCO-PROTEIN-VANILKA-45','59',27),
    ('38','52','SOCO-EXTASY-PEANUT-45','60',28),
    ('39','53','165','61',29),
    ('40','54','254','62',30),
    ('41','55','SOCO-RAWBAR-PEANUTS','63',31),
    ('42','56','SOCO-BONGO-ORIGINAL-40','64',32),
    ('43','57','261','65',33),
    -- 6. horni zdvojena rada: zakaznicke volby 62, 64 a 66.
    ('33','62','39','66',34),
    ('34','64','42','67',35),
    ('35','66','BERTYCKY-TVARUZKOVE','68',36);

  select count(*) into v_active_count
  from public.machine_planogram_slots
  where machine_id = v_machine_id
    and active;

  if v_active_count = 36 and not exists (
    select 1
    from ev11_layout_desired desired
    left join public.machine_planogram_slots slot
      on slot.machine_id = v_machine_id
     and slot.slot_code = desired.new_code
     and slot.active
    where slot.id is null
       or slot.product_sku is distinct from desired.expected_sku
       or slot.customer_selection_code is distinct from desired.new_code
       or slot.telemetry_key is distinct from desired.telemetry_key
       or slot.sort_order is distinct from desired.sort_order
  ) then
    raise notice 'EV 11 Europa Snack Side layout is already corrected.';
    return;
  end if;

  if exists (select 1 from public.route_machine_visits where machine_id = v_machine_id)
     or exists (select 1 from public.route_machine_visit_items where machine_id = v_machine_id)
     or exists (
       select 1 from public.route_plan_stops
       where machine_id = v_machine_id and status not in ('done', 'skipped')
     ) then
    raise exception 'EV 11 already has route usage; automatic layout replacement is not safe.';
  end if;

  if exists (
    select 1
    from public.stock_locations location
    join public.stock_location_balances balance on balance.stock_location_id = location.id
    where location.machine_id = v_machine_id
      and balance.quantity_on_hand <> 0
  ) then
    raise exception 'EV 11 has non-zero machine stock; automatic layout replacement is not safe.';
  end if;

  if v_active_count <> 39 then
    raise exception 'Expected 39 active source positions on EV 11, found %.', v_active_count;
  end if;

  select count(*) into v_invalid_count
  from ev11_layout_desired desired
  left join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id
   and slot.slot_code = desired.old_code
   and slot.active
  where slot.id is null
     or slot.product_sku is distinct from desired.expected_sku
     or slot.current_units <> 0;

  if v_invalid_count <> 0 then
    raise exception 'EV 11 source planogram does not match % expected positions.', v_invalid_count;
  end if;

  if exists (
    select 1
    from public.machine_planogram_slots
    where machine_id = v_machine_id
      and active
      and slot_code in ('36', '64', '71')
      and current_units <> 0
  ) then
    raise exception 'A product removed for physical capacity still has stock.';
  end if;

  -- Free the unique (machine_id, slot_code) values before assigning native Side codes.
  update public.machine_planogram_slots
  set slot_code = 'ev11-old-' || slot_code,
      customer_selection_code = null,
      telemetry_key = null,
      active = false,
      updated_at = now()
  where machine_id = v_machine_id
    and active;

  update public.machine_planogram_slots slot
  set slot_code = desired.new_code,
      customer_selection_code = desired.new_code,
      telemetry_key = desired.telemetry_key,
      sort_order = desired.sort_order,
      active = true,
      note = concat_ws(' · ', nullif(slot.note, ''),
        '6. 10. 2026: fyzická pozice Europa Snack Side opravena; zákaznická volba '
        || desired.new_code || ', telemetrie EV 105 volba ' || desired.telemetry_key || '.'),
      updated_at = now()
  from ev11_layout_desired desired
  where slot.machine_id = v_machine_id
    and slot.slot_code = 'ev11-old-' || desired.old_code
    and slot.product_sku = desired.expected_sku;

  update public.machine_planogram_slots
  set active = false,
      customer_selection_code = null,
      telemetry_key = null,
      desired_units = 0,
      target_units = 0,
      fill_percent = 0,
      note = concat_ws(' · ', nullif(note, ''),
        case slot_code
          when 'ev11-old-36' then '6. 10. 2026: Yoohoo vyřazeno; horní zdvojená řada má pouze 3 volby.'
          when 'ev11-old-64' then '6. 10. 2026: Staropramen Cool vyřazen; druhá řada má pouze 6 voleb.'
          when 'ev11-old-71' then '6. 10. 2026: Hello vyřazeno; první spodní řada má pouze 6 voleb.'
        end),
      updated_at = now()
  where machine_id = v_machine_id
    and slot_code in ('ev11-old-36', 'ev11-old-64', 'ev11-old-71');

  update public.machine_telemetry_selection_routes
  set selection_from = 33,
      selection_to = 68,
      note = 'EV 11 Europa Snack Side: telemetrie EV 105 volby 33-68; zákaznické volby na Side 11-66.',
      updated_at = now()
  where controller_machine_id = v_controller_machine_id
    and member_machine_id = v_machine_id;

  update public.machines
  set note = concat_ws(' · ',
        nullif(replace(note, 'telemetrické volby 33–71', 'telemetrické volby 33–68'), ''),
        '6. 10. 2026: fyzické řady odspodu 11-16, 21-26, 31-37, 41-47, 51-57; horní zdvojená 62/64/66.'
      ),
      updated_at = now()
  where id = v_machine_id;

  select count(*) into v_active_count
  from public.machine_planogram_slots
  where machine_id = v_machine_id
    and active;

  select count(*) into v_invalid_count
  from ev11_layout_desired desired
  left join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id
   and slot.slot_code = desired.new_code
   and slot.active
  where slot.id is null
     or slot.product_sku is distinct from desired.expected_sku
     or slot.customer_selection_code is distinct from desired.new_code
     or slot.telemetry_key is distinct from desired.telemetry_key
     or slot.sort_order is distinct from desired.sort_order;

  if v_active_count <> 36 or v_invalid_count <> 0 then
    raise exception 'EV 11 layout validation failed: active %, invalid %.', v_active_count, v_invalid_count;
  end if;

  if not exists (
    select 1
    from public.machine_telemetry_selection_routes
    where controller_machine_id = v_controller_machine_id
      and member_machine_id = v_machine_id
      and active
      and selection_from = 33
      and selection_to = 68
  ) then
    raise exception 'EV 11 telemetry route validation failed.';
  end if;
end
$$;

commit;

select jsonb_build_object(
  'active_positions', count(*),
  'customer_codes', jsonb_agg(slot_code order by sort_order),
  'telemetry_keys', jsonb_agg(telemetry_key order by sort_order),
  'rows', jsonb_build_object(
    '1_bottom', count(*) filter (where slot_code between '11' and '16'),
    '2', count(*) filter (where slot_code between '21' and '26'),
    '3', count(*) filter (where slot_code between '31' and '37'),
    '4', count(*) filter (where slot_code between '41' and '47'),
    '5', count(*) filter (where slot_code between '51' and '57'),
    '6_top_double', count(*) filter (where slot_code in ('62','64','66'))
  )
) as verification
from public.machine_planogram_slots
where machine_id = (select id from public.machines where evidence_number = 11)
  and active;
