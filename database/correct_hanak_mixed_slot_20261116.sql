-- HANÁK EV23: fyzicky potvrzené pořadí pozice 31 je vpředu 2x Kuřecí
-- Strips a za nimi 3x Nuget. Oprava současně srovná dvě zbylé nealokované
-- položky v celkové zásobě automatu.

begin;

do $$
declare
  v_reference constant text := 'repair-hanak-slot31-mixed-2strips-3nuget-20261116';
  v_result jsonb;
  v_changed integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(v_reference,0));

  if exists(
    select 1 from public.stock_movements_v13
    where reference_type='data_repair' and reference_id like v_reference || '%'
  ) then
    raise notice 'Oprava smíšené pozice HANÁK už byla provedena.';
    return;
  end if;

  perform 1 from public.machine_planogram_slots where id=1402 for update;
  perform 1 from public.stock_location_balances
    where stock_location_id=47 and product_id in(239,266) for update;

  if not exists(
    select 1 from public.machine_planogram_slots
    where id=1402 and machine_id=19 and slot_code='31'
      and product_sku='HAME-KURECI-STRIPS' and current_units=4 and capacity_units=5
  ) then raise exception 'Pozice HANÁK 31 už není v očekávaném stavu 4/5 Strips.'; end if;

  if coalesce((select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=47 and product_id=239),0)<>3
     or coalesce((select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=47 and product_id=266),0)<>9
  then raise exception 'Celková evidence Strips/Nuget v HANÁK se od kontroly změnila.'; end if;

  select public.apply_stock_movements_v13(jsonb_build_array(
    jsonb_build_object(
      'product_id',239,'batch_id',961,
      'from_stock_location_id',47,'to_stock_location_id',null,
      'movement_type','adjustment','quantity_base_units',1,
      'reference_type','data_repair','reference_id',v_reference || '-strips',
      'note','Fyzická kontrola HANÁK EV23 pozice 31: celkem jsou v automatu 2 ks Strips; odstraněn 1 nealokovaný kus evidence.'
    ),
    jsonb_build_object(
      'product_id',266,'batch_id',954,
      'from_stock_location_id',47,'to_stock_location_id',null,
      'movement_type','adjustment','quantity_base_units',1,
      'reference_type','data_repair','reference_id',v_reference || '-nuget',
      'note','Fyzická kontrola HANÁK EV23: celkem je v automatu 8 ks Nuget; odstraněn 1 nealokovaný kus evidence.'
    )
  )) into v_result;
  if coalesce((v_result->>'inserted')::integer,0)<>2 then
    raise exception 'Skladová oprava smíšené pozice nebyla kompletní: %',v_result;
  end if;

  update public.machine_planogram_slots
  set current_units=5,
      desired_units=0,
      target_units=5,
      fill_percent=100,
      product_sku='HAME-KURECI-STRIPS',
      product_name='Hamé Kuřecí Strips 224g',
      planned_product_sku='SIMPLY-NUGET',
      planned_product_name='Simply Fresh Nuget 185g',
      changeover_old_units=2,
      changeover_new_units=3,
      changeover_started_at=coalesce(changeover_started_at,now()),
      note=concat_ws(' · ',nullif(note,''),'Fyzická kontrola 16. 11. 2026: pozice 31 vpředu 2× Kuřecí Strips, za nimi 3× Nuget.'),
      updated_at=now()
  where id=1402;
  get diagnostics v_changed=row_count;
  if v_changed<>1 then raise exception 'Smíšenou pozici HANÁK se nepodařilo uložit.'; end if;

  if coalesce((select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=47 and product_id=239),0)<>2
     or coalesce((select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=47 and product_id=266),0)<>8
  then raise exception 'Konečná evidence HANÁK neodpovídá Strips 2 / Nuget 8.'; end if;
end
$$;

commit;

select jsonb_build_object(
  'slot31',(
    select jsonb_build_object(
      'total',current_units,'front_sku',product_sku,'front_quantity',changeover_old_units,
      'rear_sku',planned_product_sku,'rear_quantity',changeover_new_units,'capacity',capacity_units
    ) from public.machine_planogram_slots where id=1402
  ),
  'machine_strips',(select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=47 and product_id=239),
  'machine_nuget',(select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=47 and product_id=266)
) verification;
