-- Storno chybné opravy: fyzická informace o smíšené pozici patřila Kaňákovi,
-- nikoli HANÁK EV23. Vrací HANÁK pozici 31 i zásoby do stavu před opravou.

begin;

do $$
declare
  v_reference constant text := 'revert-hanak-mixed-misattribution-20261116';
  v_result jsonb;
  v_changed integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(v_reference,0));

  if exists(
    select 1 from public.stock_movements_v13
    where reference_type='data_repair' and reference_id like v_reference || '%'
  ) then
    raise notice 'Storno chybného přiřazení už bylo provedeno.';
    return;
  end if;

  if not exists(
    select 1 from public.machine_planogram_slots
    where id=1402 and machine_id=19 and slot_code='31' and current_units=5
      and product_sku='HAME-KURECI-STRIPS' and planned_product_sku='SIMPLY-NUGET'
      and changeover_old_units=2 and changeover_new_units=3
  ) then raise exception 'HANÁK pozice 31 už není v chybně zapsaném smíšeném stavu.'; end if;

  select public.apply_stock_movements_v13(jsonb_build_array(
    jsonb_build_object(
      'product_id',239,'batch_id',961,
      'from_stock_location_id',null,'to_stock_location_id',47,
      'movement_type','adjustment','quantity_base_units',1,
      'reference_type','data_repair','reference_id',v_reference || '-strips',
      'note','Storno: údaj 2× Strips + 3× Nuget patřil Kaňákovi, nikoli HANÁK EV23.'
    ),
    jsonb_build_object(
      'product_id',266,'batch_id',954,
      'from_stock_location_id',null,'to_stock_location_id',47,
      'movement_type','adjustment','quantity_base_units',1,
      'reference_type','data_repair','reference_id',v_reference || '-nuget',
      'note','Storno: údaj 2× Strips + 3× Nuget patřil Kaňákovi, nikoli HANÁK EV23.'
    )
  )) into v_result;
  if coalesce((v_result->>'inserted')::integer,0)<>2 then
    raise exception 'Storno skladových pohybů HANÁK nebylo kompletní: %',v_result;
  end if;

  update public.machine_planogram_slots
  set current_units=4,
      desired_units=1,
      fill_percent=80,
      product_sku='HAME-KURECI-STRIPS',
      product_name='Hamé Kuřecí Strips 224g',
      planned_product_sku=null,
      planned_product_name=null,
      changeover_old_units=null,
      changeover_new_units=null,
      changeover_started_at=null,
      note=concat_ws(' · ',replace(coalesce(note,''),'Fyzická kontrola 16. 11. 2026: pozice 31 vpředu 2× Kuřecí Strips, za nimi 3× Nuget.',''),'Storno 16. 11. 2026: smíšená pozice patřila Kaňákovi, nikoli HANÁK EV23.'),
      updated_at=now()
  where id=1402;
  get diagnostics v_changed=row_count;
  if v_changed<>1 then raise exception 'Pozici HANÁK 31 se nepodařilo vrátit.'; end if;
end
$$;

commit;

select jsonb_build_object(
  'slot31',(select jsonb_build_object('current',current_units,'sku',product_sku,'planned',planned_product_sku,'capacity',capacity_units) from public.machine_planogram_slots where id=1402),
  'strips_balance',(select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=47 and product_id=239),
  'nuget_balance',(select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=47 and product_id=266)
) verification;
