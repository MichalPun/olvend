-- Oprava dokončené návštěvy musí spolu se skladovými pohyby upravit i
-- fyzické pořadí produktů v potravinové pružině. Wrapper drží obě změny
-- v jedné databázové transakci; při nejednoznačné opravě vše vrátí zpět.
begin;

create or replace function public.apply_route_visit_layer_fill_changes_v66(
  p_slot_id bigint,
  p_changes jsonb,
  p_source_visit_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_slot public.machine_planogram_slots%rowtype;
  v_change jsonb;
  v_layer public.machine_planogram_slot_layers%rowtype;
  v_product public.products%rowtype;
  v_delta integer;
  v_needed integer;
  v_take integer;
  v_last public.machine_planogram_slot_layers%rowtype;
  v_total integer;
  v_front public.machine_planogram_slot_layers%rowtype;
  v_expiry date;
begin
  select * into strict v_slot
  from public.machine_planogram_slots
  where id=p_slot_id
  for update;

  if jsonb_typeof(coalesce(p_changes,'[]'::jsonb))<>'array' then
    raise exception 'Změny vrstev musí být pole.';
  end if;

  for v_change in select value from jsonb_array_elements(coalesce(p_changes,'[]'::jsonb))
  loop
    v_delta:=coalesce((v_change->>'delta')::integer,0);
    if v_delta=0 then continue; end if;
    select * into strict v_product
    from public.products
    where id=(v_change->>'product_id')::bigint;

    if v_delta<0 then
      v_needed:=abs(v_delta);
      for v_layer in
        select * from public.machine_planogram_slot_layers
        where planogram_slot_id=p_slot_id and product_id=v_product.id
        order by layer_order desc,id desc
        for update
      loop
        exit when v_needed<=0;
        v_take:=least(v_needed,v_layer.quantity);
        if v_take=v_layer.quantity then
          delete from public.machine_planogram_slot_layers where id=v_layer.id;
        else
          update public.machine_planogram_slot_layers
          set quantity=quantity-v_take,updated_at=now()
          where id=v_layer.id;
        end if;
        v_needed:=v_needed-v_take;
      end loop;
      if v_needed>0 then
        raise exception 'Opravu nelze bezpečně provést: % ks produktu % už v pružině není. Ověř fyzický obsah automatu.',v_needed,v_product.name;
      end if;
    else
      select * into v_last
      from public.machine_planogram_slot_layers
      where planogram_slot_id=p_slot_id
      order by layer_order desc,id desc
      limit 1 for update;
      if found and v_last.product_id=v_product.id
         and v_last.expiry_date is not distinct from nullif(v_change->>'expiry_date','')::date then
        update public.machine_planogram_slot_layers
        set quantity=quantity+v_delta,updated_at=now(),source='route_correction',source_visit_id=p_source_visit_id
        where id=v_last.id;
      else
        insert into public.machine_planogram_slot_layers(
          planogram_slot_id,layer_order,product_id,product_sku,product_name,quantity,
          expiry_date,source,source_visit_id
        ) values(
          p_slot_id,coalesce(v_last.layer_order,0)+1,v_product.id,v_product.sku,v_product.name,v_delta,
          nullif(v_change->>'expiry_date','')::date,'route_correction',p_source_visit_id
        );
      end if;
    end if;
  end loop;

  with ordered as (
    select id,row_number() over(order by layer_order,id) next_order
    from public.machine_planogram_slot_layers where planogram_slot_id=p_slot_id
  )
  update public.machine_planogram_slot_layers layer
  set layer_order=ordered.next_order,updated_at=now()
  from ordered where layer.id=ordered.id;

  select coalesce(sum(quantity),0)::integer,min(expiry_date)
  into v_total,v_expiry
  from public.machine_planogram_slot_layers where planogram_slot_id=p_slot_id;
  if v_total<>coalesce(v_slot.current_units,0) then
    raise exception 'Oprava vrstev dává % ks, ale stav pozice je % ks. Změna byla vrácena.',v_total,v_slot.current_units;
  end if;
  if v_total>coalesce(v_slot.capacity_units,v_total) then
    raise exception 'Složení pružiny překračuje kapacitu pozice.';
  end if;

  select * into v_front
  from public.machine_planogram_slot_layers
  where planogram_slot_id=p_slot_id
  order by layer_order,id limit 1;
  update public.machine_planogram_slots
  set product_sku=coalesce(v_front.product_sku,primary_product_sku,product_sku),
      product_name=coalesce(v_front.product_name,primary_product_name,product_name),
      expiry_date=v_expiry,updated_at=now()
  where id=p_slot_id;

  return jsonb_build_object('slot_id',p_slot_id,'total_units',v_total);
end $$;

revoke all on function public.apply_route_visit_layer_fill_changes_v66(bigint,jsonb,bigint) from public,anon,authenticated;

create or replace function public.correct_route_visit_with_layers_v66(
  p_visit_id bigint,
  p_expected_revision integer,
  p_expected_updated_at timestamptz,
  p_reason text,
  p_patch jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_visit public.route_machine_visits%rowtype;
  v_item public.route_machine_visit_items%rowtype;
  v_fill public.route_machine_visit_food_fills%rowtype;
  v_waste public.route_vehicle_waste_items%rowtype;
  v_item_patch jsonb;
  v_fill_patch jsonb;
  v_waste_patch jsonb;
  v_changes jsonb:='[]'::jsonb;
  v_item_changes jsonb;
  v_before_layers jsonb:='[]'::jsonb;
  v_after_layers jsonb:='[]'::jsonb;
  v_new_product_id bigint;
  v_new_quantity integer;
  v_result jsonb;
  v_audit_id bigint;
begin
  select * into strict v_visit from public.route_machine_visits where id=p_visit_id for update;

  for v_item_patch in select value from jsonb_array_elements(coalesce(p_patch->'items','[]'::jsonb))
  loop
    select * into strict v_item
    from public.route_machine_visit_items
    where id=(v_item_patch->>'id')::bigint and visit_id=p_visit_id;
    if v_item.item_kind<>'food_slot' or not exists(
      select 1 from public.machine_planogram_slot_layers where planogram_slot_id=v_item.planogram_slot_id
    ) then continue; end if;

    v_before_layers:=v_before_layers||jsonb_build_array(jsonb_build_object(
      'visit_item_id',v_item.id,'planogram_slot_id',v_item.planogram_slot_id,
      'layers',(select coalesce(jsonb_agg(to_jsonb(layer) order by layer.layer_order),'[]'::jsonb)
                from public.machine_planogram_slot_layers layer where layer.planogram_slot_id=v_item.planogram_slot_id)
    ));
    if coalesce((v_item_patch->>'before')::numeric,v_item.actual_before_quantity)
       is distinct from v_item.actual_before_quantity then
      raise exception 'U složené pružiny nelze změnit jen celkový stav před doplněním. Oprav jednotlivé produkty podle fyzické kontroly.';
    end if;

    for v_fill_patch in select value from jsonb_array_elements(coalesce(v_item_patch->'fills','[]'::jsonb))
    loop
      if (v_fill_patch->>'id')::bigint>0 then
        select * into strict v_fill
        from public.route_machine_visit_food_fills
        where id=(v_fill_patch->>'id')::bigint and visit_item_id=v_item.id;
        v_new_product_id:=(v_fill_patch->>'product_id')::bigint;
        v_new_quantity:=(v_fill_patch->>'quantity')::integer;
        if v_fill.product_id=v_new_product_id then
          v_changes:=v_changes||jsonb_build_array(jsonb_build_object(
            'visit_item_id',v_item.id,'product_id',v_new_product_id,
            'delta',v_new_quantity-v_fill.quantity,'expiry_date',v_fill_patch->>'expiry'
          ));
        else
          v_changes:=v_changes||jsonb_build_array(
            jsonb_build_object('visit_item_id',v_item.id,'product_id',v_fill.product_id,'delta',-v_fill.quantity,'expiry_date',v_fill.expiry_date),
            jsonb_build_object('visit_item_id',v_item.id,'product_id',v_new_product_id,'delta',v_new_quantity,'expiry_date',v_fill_patch->>'expiry')
          );
        end if;
      else
        v_changes:=v_changes||jsonb_build_array(jsonb_build_object(
          'visit_item_id',v_item.id,'product_id',(v_fill_patch->>'product_id')::bigint,
          'delta',(v_fill_patch->>'quantity')::integer,'expiry_date',v_fill_patch->>'expiry'
        ));
      end if;
    end loop;
  end loop;

  for v_waste_patch in select value from jsonb_array_elements(coalesce(p_patch->'wastes','[]'::jsonb))
  loop
    select * into strict v_waste from public.route_vehicle_waste_items where id=(v_waste_patch->>'id')::bigint;
    select * into strict v_item from public.route_machine_visit_items where id=v_waste.route_machine_visit_item_id;
    if exists(select 1 from public.machine_planogram_slot_layers where planogram_slot_id=v_item.planogram_slot_id)
       and (v_waste_patch->>'quantity')::numeric is distinct from v_waste.quantity then
      raise exception 'Odpis ze složené pružiny oprav až po fyzické kontrole jednotlivých produktů.';
    end if;
  end loop;

  v_result:=public.correct_route_visit_v50(
    p_visit_id,p_expected_revision,p_expected_updated_at,p_reason,p_patch
  );

  for v_item_patch in select value from jsonb_array_elements(coalesce(p_patch->'items','[]'::jsonb))
  loop
    select * into strict v_item
    from public.route_machine_visit_items
    where id=(v_item_patch->>'id')::bigint and visit_id=p_visit_id;
    if v_item.item_kind<>'food_slot' or not exists(
      select 1 from public.machine_planogram_slot_layers where planogram_slot_id=v_item.planogram_slot_id
    ) then continue; end if;
    select coalesce(jsonb_agg(change),'[]'::jsonb) into v_item_changes
    from jsonb_array_elements(v_changes) change
    where (change->>'visit_item_id')::bigint=v_item.id and coalesce((change->>'delta')::integer,0)<>0;
    perform public.apply_route_visit_layer_fill_changes_v66(v_item.planogram_slot_id,v_item_changes,p_visit_id);
    v_after_layers:=v_after_layers||jsonb_build_array(jsonb_build_object(
      'visit_item_id',v_item.id,'planogram_slot_id',v_item.planogram_slot_id,
      'layers',(select coalesce(jsonb_agg(to_jsonb(layer) order by layer.layer_order),'[]'::jsonb)
                from public.machine_planogram_slot_layers layer where layer.planogram_slot_id=v_item.planogram_slot_id)
    ));
  end loop;

  v_audit_id:=(v_result->>'audit_id')::bigint;
  update public.route_visit_corrections
  set before_data=before_data||jsonb_build_object('slot_layers',v_before_layers),
      after_data=after_data||jsonb_build_object('slot_layers',v_after_layers)
  where id=v_audit_id;
  return v_result;
end $$;

revoke all on function public.correct_route_visit_with_layers_v66(bigint,integer,timestamptz,text,jsonb) from public,anon;
grant execute on function public.correct_route_visit_with_layers_v66(bigint,integer,timestamptz,text,jsonb) to authenticated;

commit;
notify pgrst,'reload schema';
