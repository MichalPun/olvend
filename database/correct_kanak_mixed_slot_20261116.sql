-- Karel Kaňák EV135: při příjezdu bylo v čerstvé pozici 5 kusů v pořadí
-- vpředu 2x Strips, za nimi 3x Nuget. Dva Strips byly odepsány jako prošlé,
-- takže aktuálně zůstávají 3x Nuget. Množství i skladové pohyby už sedí;
-- opravujeme identitu zbývajícího produktu v pozici a audit návštěvy.

begin;

do $$
declare
  v_changed integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('repair-kanak-mixed-slot-20261116',0));
  perform 1 from public.machine_planogram_slots where id=2989 for update;
  perform 1 from public.route_machine_visit_items where id=52533 for update;
  perform 1 from public.route_vehicle_waste_items where id=338 for update;

  if not exists(
    select 1 from public.machine_planogram_slots
    where id=2989 and machine_id=135 and slot_code='48'
      and product_sku='HAME-KURECI-STRIPS' and current_units=3 and capacity_units=5
  ) then raise exception 'Pozice Kaňák už není v očekávaném chybném stavu 3 ks Strips.'; end if;

  if coalesce((select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=108 and product_id=239),0)<>0
     or coalesce((select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id=108 and product_id=266),0)<>3
  then raise exception 'Skladová evidence Kaňák už neodpovídá 0 Strips / 3 Nuget.'; end if;

  update public.machine_planogram_slots
  set product_sku='SIMPLY-NUGET',
      product_name='Simply Fresh Nuget 185g',
      current_units=3,
      target_units=5,
      desired_units=2,
      fill_percent=60,
      expiry_date=null,
      planned_product_sku=null,
      planned_product_name=null,
      planned_price_czk=null,
      changeover_old_units=null,
      changeover_new_units=null,
      changeover_started_at=null,
      note=concat_ws(' · ',nullif(note,''),'Fyzická skutečnost 16. 11. 2026: při příjezdu vpředu 2× prošlé Strips, za nimi 3× Nuget; Strips odepsány, aktuálně zůstávají 3× Nuget.'),
      updated_at=now()
  where id=2989;
  get diagnostics v_changed=row_count;
  if v_changed<>1 then raise exception 'Pozici Kaňák se nepodařilo opravit.'; end if;

  update public.route_machine_visit_items
  set actual_product_id=266,
      actual_product_sku='SIMPLY-NUGET',
      actual_product_name='Simply Fresh Nuget 185g',
      issue_type='substitution',
      substitution_reason='Při příjezdu dva druhy v jedné pružině; přední 2× Strips odepsány jako prošlé, vzadu zůstaly 3× Nuget.',
      operator_note='Obsah při příjezdu: vpředu 2× Hamé Kuřecí Strips, za nimi 3× Simply Fresh Nuget · Odpis: 2 ks Strips · expired · Konečný stav: 3 ks Nuget · Přesné datum expirace Strips nebylo potvrzeno.',
      updated_at=now()
  where id=52533 and visit_id=1853 and planogram_slot_id=2989
    and actual_before_quantity=5 and removed_quantity=2 and final_quantity=3;
  get diagnostics v_changed=row_count;
  if v_changed<>1 then raise exception 'Audit návštěvy Kaňák se nepodařilo opravit.'; end if;

  update public.route_vehicle_waste_items
  set expiry_date=null,
      note='Pozice 48 · při příjezdu vpředu před 3 ks Nuget · fyzicky potvrzeno jako prošlé, přesné datum nepotvrzeno',
      updated_at=now()
  where id=338 and route_machine_visit_item_id=52533 and product_id=239 and quantity=2 and reason='expired';
  get diagnostics v_changed=row_count;
  if v_changed<>1 then raise exception 'Odpis prošlých Strips u Kaňáka se nepodařilo upřesnit.'; end if;
end
$$;

commit;

select jsonb_build_object(
  'slot',(select jsonb_build_object('code',slot_code,'sku',product_sku,'quantity',current_units,'capacity',capacity_units) from public.machine_planogram_slots where id=2989),
  'visit',(select jsonb_build_object('before',actual_before_quantity,'removed',removed_quantity,'final',final_quantity,'actual_sku',actual_product_sku) from public.route_machine_visit_items where id=52533),
  'waste',(select jsonb_build_object('sku',product_sku,'quantity',quantity,'reason',reason,'expiry',expiry_date) from public.route_vehicle_waste_items where id=338)
) verification;
