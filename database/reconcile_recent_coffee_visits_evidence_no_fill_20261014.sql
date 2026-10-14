begin;

create temporary table evidence_no_fill (
  visit_id bigint not null,
  container_id bigint not null,
  actual_before numeric not null,
  primary key (visit_id, container_id)
) on commit drop;

insert into evidence_no_fill (visit_id, container_id, actual_before) values
  (1037, 475, 184.000),
  (1056, 615, 1456.700),
  (1061, 537, 652.600),
  (1075, 212, 1696.000),
  (1088, 537, 506.300),
  (1152, 537, 345.500),
  (1153, 596, 1748.800),
  (1162, 487, 1000.000),
  (1163, 537, 299.700),
  (1202, 549, 1874.400);

do $$
declare
  v_row record;
  v_batch record;
  v_reference text;
begin
  for v_row in
    select
      evidence.visit_id,
      evidence.container_id,
      evidence.actual_before,
      visit.machine_id,
      visit.vehicle_id,
      visit.completed_at,
      container.container_code,
      container.product_id,
      container.capacity_quantity,
      container.refill_package_quantity,
      container.unit,
      product.sku product_sku,
      product.name product_name,
      machine_location.id machine_location_id,
      vehicle_location.id vehicle_location_id,
      coalesce(nullif(visit.coffee_preparation->'containers'->(evidence.container_id::text)->>'packages','')::numeric,0) draft_packages
    from evidence_no_fill evidence
    join public.route_machine_visits visit on visit.id=evidence.visit_id
    join public.machine_coffee_containers container on container.id=evidence.container_id and container.machine_id=visit.machine_id
    join public.products product on product.id=container.product_id
    join public.stock_locations machine_location on machine_location.location_type='machine' and machine_location.machine_id=visit.machine_id
    join public.stock_locations vehicle_location on vehicle_location.location_type='vehicle' and vehicle_location.vehicle_id=visit.vehicle_id
    where visit.status='completed'
    order by evidence.visit_id,evidence.container_id
  loop
    for v_batch in
      select movement.batch_id,
        sum(case
          when movement.to_stock_location_id=v_row.machine_location_id then movement.quantity_base_units
          when movement.from_stock_location_id=v_row.machine_location_id then -movement.quantity_base_units
          else 0 end) net_quantity
      from public.stock_movements_v13 movement
      where movement.reference_type='mobile_stock_request'
        and movement.reference_id like format('route_visit_%s_container_%s_%%',v_row.visit_id,v_row.container_id)
        and movement.product_id=v_row.product_id
      group by movement.batch_id
      having sum(case
        when movement.to_stock_location_id=v_row.machine_location_id then movement.quantity_base_units
        when movement.from_stock_location_id=v_row.machine_location_id then -movement.quantity_base_units
        else 0 end)>0.0001
    loop
      v_reference:=format('route_visit_%s_container_%s_evidence_back_%s_20261014',
        v_row.visit_id,v_row.container_id,coalesce(v_batch.batch_id::text,'none'));

      if not exists(select 1 from public.stock_movements_v13 where reference_type='mobile_stock_request' and reference_id=v_reference) then
        perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
          'product_id',v_row.product_id,
          'batch_id',v_batch.batch_id,
          'from_stock_location_id',v_row.machine_location_id,
          'to_stock_location_id',v_row.vehicle_location_id,
          'movement_type','return',
          'quantity_base_units',v_batch.net_quantity,
          'reference_type','mobile_stock_request',
          'reference_id',v_reference,
          'note',format('Systemova revize 14. 10. 2026 · navsteva #%s · %s: nulove doplneni prokazano mezi fyzickymi odecty a telemetrickou spotrebou; chybny pohyb vracen do vozidla',v_row.visit_id,v_row.container_code)
        )));
      end if;
    end loop;

    if not exists (
      select 1 from public.route_machine_visit_items item
      where item.visit_id=v_row.visit_id and item.coffee_container_id=v_row.container_id
    ) then
      insert into public.route_machine_visit_items (
      visit_id,client_uuid,machine_id,item_kind,coffee_container_id,
      physical_position_label,
      planned_product_id,planned_product_sku,planned_product_name,
      actual_product_id,actual_product_sku,actual_product_name,
      system_current_quantity,actual_before_quantity,suggested_add_quantity,
      actual_add_quantity,removed_quantity,final_quantity,capacity_quantity,unit,
      issue_type,operator_note,accepted_at
    ) values (
      v_row.visit_id,
      md5(format('coffee-evidence-no-fill:%s:%s',v_row.visit_id,v_row.container_id))::uuid,
      v_row.machine_id,'coffee_container',v_row.container_id,
      v_row.container_code,
      v_row.product_id,v_row.product_sku,v_row.product_name,
      v_row.product_id,v_row.product_sku,v_row.product_name,
      null,v_row.actual_before,v_row.draft_packages*v_row.refill_package_quantity,
      0,0,v_row.actual_before,v_row.capacity_quantity,v_row.unit,
      'telemetry_mismatch',
      'Systemova revize 14. 10. 2026: nulove doplneni zpetne prokazano fyzickymi odecty pred a po navsteve a presnou telemetrickou spotrebou mezi nimi.',
      v_row.completed_at
      );
    end if;

    update public.route_machine_visits
    set coffee_preparation=jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(coalesce(coffee_preparation,'{}'::jsonb),
                array['containers',v_row.container_id::text,'accepted'],'true'::jsonb,true),
              array['containers',v_row.container_id::text,'actualBeforeQuantity'],to_jsonb(v_row.actual_before),true),
            array['containers',v_row.container_id::text,'packages'],'0'::jsonb,true),
          array['containers',v_row.container_id::text,'movedPackages'],'0'::jsonb,true),
        synced_at=now()
    where id=v_row.visit_id;
  end loop;
end
$$;

select jsonb_build_object(
  'items_created',(select count(*) from evidence_no_fill evidence join public.route_machine_visit_items item on item.visit_id=evidence.visit_id and item.coffee_container_id=evidence.container_id),
  'return_movements',(select count(*) from public.stock_movements_v13 where reference_id like 'route_visit_%_container_%_evidence_back_%_20261014')
) as verification;

commit;

