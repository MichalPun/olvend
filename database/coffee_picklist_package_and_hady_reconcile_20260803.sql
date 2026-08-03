-- Systémová oprava balení kávových picklistů a dorovnání návštěvy Hády #86.
--
-- Katalog je zdrojem pravdy pro celé balení ve stejné základní jednotce.
-- Současně vracíme do Renaultu 50 kelímků a 1 kg Barbera Tris, které aplikace
-- při návštěvě #86 odečetla navíc proti fyzickému doplnění operátora.

begin;

update public.machine_coffee_containers container
set
  refill_package_quantity = package.units_per_package,
  refill_package_unit = container.unit,
  min_refill_quantity = package.units_per_package,
  product_name = product.name,
  updated_at = now()
from public.products product
join public.product_packages package
  on package.product_id = product.id
 and package.active
 and package.is_default
where container.product_id = product.id
  and container.active
  and lower(coalesce(container.unit, '')) = lower(coalesce(product.base_unit, ''))
  and package.units_per_package > 1
  and container.refill_package_quantity is distinct from package.units_per_package;

do $$
declare
  v_vehicle_location constant bigint := 2;
  v_machine_location constant bigint := 42;
begin
  if not exists (
    select 1 from public.route_machine_visits
    where id = 86 and machine_id = 83 and vehicle_id = 1 and visit_date = date '2026-08-03'
  ) then
    raise exception 'Návštěva #86 neodpovídá očekávaným Hádům / EV103 / Renaultu.';
  end if;

  if not exists (
    select 1 from public.stock_locations
    where id = v_vehicle_location and location_type = 'vehicle' and vehicle_id = 1
  ) or not exists (
    select 1 from public.stock_locations
    where id = v_machine_location and location_type = 'machine' and machine_id = 83
  ) then
    raise exception 'Skladová místa Renaultu nebo automatu Hády neodpovídají auditu.';
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id = 'route-visit-86-hady-cups-return-50'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 79,
          'batch_id', null,
          'from_stock_location_id', v_machine_location,
          'to_stock_location_id', v_vehicle_location,
          'movement_type', 'return',
          'quantity_base_units', 50,
          'reference_type', 'data_repair',
          'reference_id', 'route-visit-86-hady-cups-return-50',
          'note', 'Hády EV103 · návštěva #86 · fyzicky vloženy 3 tyče po 50 ks, aplikace chybně odečetla 200 ks'
        )
      )
    );

    update public.machine_coffee_containers
    set current_quantity = greatest(0, current_quantity - 50), updated_at = now()
    where id = 535 and machine_id = 83 and product_id = 79;
  end if;

  update public.route_machine_visit_items
  set
    suggested_add_quantity = 150,
    actual_add_quantity = 150,
    final_quantity = actual_before_quantity + 150,
    operator_note = case
      when coalesce(operator_note, '') like '%Oprava podle operátora: vloženy 3 tyče po 50 ks%'
        then operator_note
      else concat_ws(' · ', nullif(operator_note, ''), 'Oprava podle operátora: vloženy 3 tyče po 50 ks')
    end,
    updated_at = now()
  where id = 1738 and visit_id = 86 and coffee_container_id = 535;

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id = 'route-visit-86-hady-barbera-return-1kg'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 26,
          'batch_id', null,
          'from_stock_location_id', v_machine_location,
          'to_stock_location_id', v_vehicle_location,
          'movement_type', 'return',
          'quantity_base_units', 1,
          'reference_type', 'data_repair',
          'reference_id', 'route-visit-86-hady-barbera-return-1kg',
          'note', 'Hády EV103 · návštěva #86 · Barbera Tris nebyla fyzicky vložena'
        )
      )
    );

    update public.machine_coffee_containers
    set current_quantity = greatest(0, current_quantity - 1000), updated_at = now()
    where id = 528 and machine_id = 83 and product_id = 26;
  end if;

  update public.route_machine_visit_items
  set
    actual_add_quantity = 0,
    final_quantity = actual_before_quantity,
    operator_note = case
      when coalesce(operator_note, '') like '%Oprava podle operátora: Barbera Tris nebyla vložena%'
        then operator_note
      else concat_ws(' · ', nullif(operator_note, ''), 'Oprava podle operátora: Barbera Tris nebyla vložena')
    end,
    updated_at = now()
  where id = 1739 and visit_id = 86 and coffee_container_id = 528;
end
$$;

commit;

select
  machine.evidence_number,
  container.container_code,
  container.product_sku,
  container.product_name,
  container.current_quantity,
  container.capacity_quantity,
  container.refill_package_quantity,
  container.refill_package_unit
from public.machine_coffee_containers container
join public.machines machine on machine.id = container.machine_id
where container.id in (206, 535, 554, 11, 528)
order by machine.evidence_number, container.container_code;
