-- Ruční převod fyzicky předaných surovin z vozu Veroniky Jirdové do EV 97:
-- 2 × 1 kg bílá čokoláda a 1 × 1 kg smetana.
-- Zásobníky automatu se zde záměrně nepřepisují: 2 kg bílé čokolády by podle
-- aktuální evidence překročily kapacitu násypky. Převod proto eviduje zásobu
-- předanou do automatu/lokality, nikoli neověřený finální stav násypky.

begin;

do $$
declare
  v_reference_id constant text := 'manual-ev97-veronika-jirdova-20261020-white-choc2-creamer1';
  v_employee_id uuid;
  v_vehicle_id bigint;
  v_vehicle_stock_location_id bigint;
  v_machine_id bigint;
  v_machine_stock_location_id bigint;
  v_white_product_id bigint;
  v_creamer_product_id bigint;
  v_white_package_id bigint;
  v_creamer_package_id bigint;
  v_white_source_before numeric(12,3);
  v_creamer_source_before numeric(12,3);
  v_white_target_before numeric(12,3);
  v_creamer_target_before numeric(12,3);
  v_result jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended(v_reference_id, 0));

  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'manual_transfer'
      and reference_id = v_reference_id
  ) then
    raise exception 'Převod % už byl zaúčtován.', v_reference_id;
  end if;

  select e.id
  into strict v_employee_id
  from public.employees e
  where e.name = 'Veronika'
    and e.surname = 'Jirdová'
    and coalesce(e.active, true);

  select v.id, sl.id
  into strict v_vehicle_id, v_vehicle_stock_location_id
  from public.vehicles v
  join public.stock_locations sl
    on sl.location_type = 'vehicle'
   and sl.vehicle_id = v.id
   and coalesce(sl.active, true)
  where v.assigned_employee_id = v_employee_id
    and v.plate = '3BU9736';

  if not exists (
    select 1
    from public.attendance_days a
    where a.employee_id = v_employee_id
      and a.attendance_date = date '2026-10-20'
      and a.vehicle_id = v_vehicle_id
      and a.status = 'open'
      and a.actual_start is not null
      and a.actual_end is null
  ) then
    raise exception 'Veronika Jirdová dnes nemá otevřenou směnu s vozem 3BU9736.';
  end if;

  select m.id, sl.id
  into strict v_machine_id, v_machine_stock_location_id
  from public.machines m
  join public.locations l on l.id = m.location_id
  join public.stock_locations sl
    on sl.location_type = 'machine'
   and sl.machine_id = m.id
   and coalesce(sl.active, true)
  where m.evidence_number = 97
    and lower(coalesce(m.machine_type, '')) = 'coffee'
    and l.name = 'Soukromá střední odborná škola Frýdek-Místek'
    and l.city = 'Frýdek-Místek';

  select p.id, pp.id
  into strict v_white_product_id, v_white_package_id
  from public.products p
  join public.product_packages pp
    on pp.product_id = p.id
   and pp.is_default
   and coalesce(pp.active, true)
  where p.sku = '51'
    and p.name = 'oVe DRINK WITH CHOC WHITE FLAVOUR 1000g'
    and p.base_unit = 'kg'
    and pp.units_per_package = 1
    and coalesce(p.active, true);

  select p.id, pp.id
  into strict v_creamer_product_id, v_creamer_package_id
  from public.products p
  join public.product_packages pp
    on pp.product_id = p.id
   and pp.is_default
   and coalesce(pp.active, true)
  where p.sku = '48'
    and p.name = 'oVe COFFEE CREAMER WHITE 1 kg'
    and p.base_unit = 'kg'
    and pp.units_per_package = 1
    and coalesce(p.active, true);

  if not exists (
    select 1 from public.machine_coffee_containers c
    where c.machine_id = v_machine_id
      and c.product_id = v_white_product_id
      and c.container_code = 'Z1'
      and coalesce(c.active, true)
  ) or not exists (
    select 1 from public.machine_coffee_containers c
    where c.machine_id = v_machine_id
      and c.product_id = v_creamer_product_id
      and c.container_code = 'Z2'
      and coalesce(c.active, true)
  ) then
    raise exception 'EV 97 nemá očekávané aktivní zásobníky Z1/Z2.';
  end if;

  select b.quantity_on_hand
  into strict v_white_source_before
  from public.stock_location_balances b
  where b.stock_location_id = v_vehicle_stock_location_id
    and b.product_id = v_white_product_id
    and b.batch_id is null
  for update;

  select b.quantity_on_hand
  into strict v_creamer_source_before
  from public.stock_location_balances b
  where b.stock_location_id = v_vehicle_stock_location_id
    and b.product_id = v_creamer_product_id
    and b.batch_id is null
  for update;

  if v_white_source_before < 2 then
    raise exception 'V autě není dost bílé čokolády: dostupné % kg.', v_white_source_before;
  end if;
  if v_creamer_source_before < 1 then
    raise exception 'V autě není dost smetany: dostupné % kg.', v_creamer_source_before;
  end if;

  select b.quantity_on_hand
  into strict v_white_target_before
  from public.stock_location_balances b
  where b.stock_location_id = v_machine_stock_location_id
    and b.product_id = v_white_product_id
    and b.batch_id is null
  for update;

  select b.quantity_on_hand
  into strict v_creamer_target_before
  from public.stock_location_balances b
  where b.stock_location_id = v_machine_stock_location_id
    and b.product_id = v_creamer_product_id
    and b.batch_id is null
  for update;

  select public.apply_stock_movements_v13(jsonb_build_array(
    jsonb_build_object(
      'product_id', v_white_product_id,
      'batch_id', null,
      'from_stock_location_id', v_vehicle_stock_location_id,
      'to_stock_location_id', v_machine_stock_location_id,
      'movement_type', 'fill_machine',
      'quantity_base_units', 2,
      'reference_type', 'manual_transfer',
      'reference_id', v_reference_id,
      'note', 'EV 97 · Frýdek-Místek · z auta Veroniky Jirdové 2 × 1 kg bílá čokoláda'
    ),
    jsonb_build_object(
      'product_id', v_creamer_product_id,
      'batch_id', null,
      'from_stock_location_id', v_vehicle_stock_location_id,
      'to_stock_location_id', v_machine_stock_location_id,
      'movement_type', 'fill_machine',
      'quantity_base_units', 1,
      'reference_type', 'manual_transfer',
      'reference_id', v_reference_id,
      'note', 'EV 97 · Frýdek-Místek · z auta Veroniky Jirdové 1 × 1 kg smetana'
    )
  )) into v_result;

  if coalesce((v_result->>'inserted')::integer, 0) <> 2 then
    raise exception 'Skladový převod nevytvořil oba očekávané pohyby: %.', v_result;
  end if;

  update public.stock_movements_v13
  set package_id = case
        when product_id = v_white_product_id then v_white_package_id
        when product_id = v_creamer_product_id then v_creamer_package_id
      end,
      package_count = case
        when product_id = v_white_product_id then 2
        when product_id = v_creamer_product_id then 1
      end,
      created_by = v_employee_id
  where reference_type = 'manual_transfer'
    and reference_id = v_reference_id;

  if (select count(*) from public.stock_movements_v13
      where reference_type = 'manual_transfer' and reference_id = v_reference_id) <> 2 then
    raise exception 'Kontrola počtu pohybů po převodu selhala.';
  end if;

  if (select quantity_on_hand from public.stock_location_balances
      where stock_location_id = v_vehicle_stock_location_id
        and product_id = v_white_product_id and batch_id is null) <> v_white_source_before - 2 then
    raise exception 'Kontrola bílé čokolády v autě po převodu selhala.';
  end if;
  if (select quantity_on_hand from public.stock_location_balances
      where stock_location_id = v_vehicle_stock_location_id
        and product_id = v_creamer_product_id and batch_id is null) <> v_creamer_source_before - 1 then
    raise exception 'Kontrola smetany v autě po převodu selhala.';
  end if;
  if (select quantity_on_hand from public.stock_location_balances
      where stock_location_id = v_machine_stock_location_id
        and product_id = v_white_product_id and batch_id is null) <> v_white_target_before + 2 then
    raise exception 'Kontrola bílé čokolády u EV 97 po převodu selhala.';
  end if;
  if (select quantity_on_hand from public.stock_location_balances
      where stock_location_id = v_machine_stock_location_id
        and product_id = v_creamer_product_id and batch_id is null) <> v_creamer_target_before + 1 then
    raise exception 'Kontrola smetany u EV 97 po převodu selhala.';
  end if;
end
$$;

commit;

select
  p.name as product,
  b.quantity_on_hand as vehicle_quantity_after,
  mb.quantity_on_hand as ev97_quantity_after,
  sm.package_count,
  sm.quantity_base_units,
  sm.created_at,
  sm.reference_id
from public.stock_movements_v13 sm
join public.products p on p.id = sm.product_id
join public.stock_location_balances b
  on b.stock_location_id = sm.from_stock_location_id
 and b.product_id = sm.product_id
 and b.batch_id is not distinct from sm.batch_id
join public.stock_location_balances mb
  on mb.stock_location_id = sm.to_stock_location_id
 and mb.product_id = sm.product_id
 and mb.batch_id is not distinct from sm.batch_id
where sm.reference_type = 'manual_transfer'
  and sm.reference_id = 'manual-ev97-veronika-jirdova-20261020-white-choc2-creamer1'
order by sm.product_id;
