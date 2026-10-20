-- Telemetry-linked machines already report every physical vend through PA2.
-- Mobile test/free drinks must therefore not be subtracted a second time.
-- Reconcile recent authoritative physical baselines to the telemetry ledger and
-- keep a complete before/after audit for every changed container.

begin;

do $$
declare
  v_row record;
  v_key text;
begin
  for v_row in
    select
      container.id as container_id,
      container.machine_id,
      container.current_quantity as before_quantity,
      container.capacity_quantity,
      container.unit,
      container.physical_counted_at,
      container.physical_count_visit_item_id,
      item.final_quantity,
      coalesce((
        select sum(depletion.quantity)
        from public.telemetry_coffee_recipe_depletions depletion
        join public.telemetry_sales_events sale
          on sale.id=depletion.sale_event_id
        where depletion.coffee_container_id=container.id
          and sale.source_event_at>container.physical_counted_at
      ),0)::numeric(14,3) as telemetry_used,
      greatest(0,item.final_quantity-coalesce((
        select sum(depletion.quantity)
        from public.telemetry_coffee_recipe_depletions depletion
        join public.telemetry_sales_events sale
          on sale.id=depletion.sale_event_id
        where depletion.coffee_container_id=container.id
          and sale.source_event_at>container.physical_counted_at
      ),0))::numeric(14,3) as expected_quantity
    from public.machine_coffee_containers container
    join public.machines machine
      on machine.id=container.machine_id
     and machine.active=true
    join public.route_machine_visit_items item
      on item.id=container.physical_count_visit_item_id
     and item.coffee_container_id=container.id
     and item.final_quantity is not null
    where container.active=true
      and container.physical_count_source='route_visit'
      and exists (
        select 1
        from public.machine_external_links link
        where link.machine_id=container.machine_id
          and link.telemetry_enabled=true
      )
      and abs(container.current_quantity-greatest(0,item.final_quantity-coalesce((
        select sum(depletion.quantity)
        from public.telemetry_coffee_recipe_depletions depletion
        join public.telemetry_sales_events sale
          on sale.id=depletion.sale_event_id
        where depletion.coffee_container_id=container.id
          and sale.source_event_at>container.physical_counted_at
      ),0)))>0.011
    order by container.id
    for update of container
  loop
    v_key:='v61-telemetry-authoritative-'||v_row.container_id||'-'||v_row.physical_count_visit_item_id;

    insert into public.machine_coffee_container_correction_audit(
      correction_key,coffee_container_id,machine_id,before_quantity,after_quantity,
      capacity_quantity,unit,reason,source,context
    ) values (
      v_key,v_row.container_id,v_row.machine_id,v_row.before_quantity,v_row.expected_quantity,
      v_row.capacity_quantity,v_row.unit,
      'Sjednocení fyzicky potvrzeného stavu s telemetrickými výdeji; odstranění dvojího ručního odečtu testovacího nebo bezplatného nápoje.',
      'telemetry_authoritative_reconciliation',
      jsonb_build_object(
        'repair_version',61,
        'physical_counted_at',v_row.physical_counted_at,
        'physical_count_visit_item_id',v_row.physical_count_visit_item_id,
        'physical_final_quantity',v_row.final_quantity,
        'telemetry_used_after_physical_count',v_row.telemetry_used,
        'difference',v_row.expected_quantity-v_row.before_quantity
      )
    )
    on conflict(correction_key) do nothing;

    update public.machine_coffee_containers
    set current_quantity=v_row.expected_quantity,
        updated_at=now()
    where id=v_row.container_id;
  end loop;
end $$;

do $$
begin
  if exists (
    select 1
    from public.machine_coffee_containers container
    join public.route_machine_visit_items item
      on item.id=container.physical_count_visit_item_id
     and item.coffee_container_id=container.id
     and item.final_quantity is not null
    where container.active=true
      and container.physical_count_source='route_visit'
      and exists (
        select 1 from public.machine_external_links link
        where link.machine_id=container.machine_id and link.telemetry_enabled=true
      )
      and abs(container.current_quantity-greatest(0,item.final_quantity-coalesce((
        select sum(depletion.quantity)
        from public.telemetry_coffee_recipe_depletions depletion
        join public.telemetry_sales_events sale on sale.id=depletion.sale_event_id
        where depletion.coffee_container_id=container.id
          and sale.source_event_at>container.physical_counted_at
      ),0)))>0.011
  ) then
    raise exception 'Po opravě zůstal telemetrický zásobník mimo autoritativní fyzický stav.';
  end if;
end $$;

select jsonb_build_object(
  'repair_version',61,
  'corrected_containers',(select count(*) from public.machine_coffee_container_correction_audit where correction_key like 'v61-telemetry-authoritative-%'),
  'remaining_invalid_bounds',(select count(*) from public.machine_coffee_containers c join public.machines m on m.id=c.machine_id where c.active=true and m.active=true and (c.current_quantity<0 or (c.capacity_quantity is not null and c.current_quantity>c.capacity_quantity+0.011)))
) verification;

commit;
