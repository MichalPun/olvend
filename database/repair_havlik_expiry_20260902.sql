begin;

-- Dodavatelský doklad #100 obsahoval u Havlíkových tyčinek překlep v roce
-- minimální trvanlivosti: 09.05.2026 místo 09.05.2027. Oprava je záměrně
-- omezena na SKU 38 a přesné chybné datum.
do $$
declare
  v_product_id bigint;
  v_batches integer;
  v_slots integer;
  v_fills integer;
  v_waste integer;
begin
  select id into strict v_product_id
  from public.products
  where sku = '38';

  update public.inventory_batches
  set best_before_date = date '2027-05-09',
      updated_at = now()
  where product_id = v_product_id
    and best_before_date = date '2026-05-09'
    and use_by_date is null;
  get diagnostics v_batches = row_count;

  update public.machine_planogram_slots
  set expiry_date = date '2027-05-09',
      updated_at = now()
  where product_sku = '38'
    and expiry_date = date '2026-05-09';
  get diagnostics v_slots = row_count;

  update public.route_machine_visit_food_fills
  set expiry_date = date '2027-05-09'
  where product_id = v_product_id
    and expiry_date = date '2026-05-09';
  get diagnostics v_fills = row_count;

  -- Kusy už fyzicky stažené z automatů ponecháváme v seznamu svozu, ale
  -- opravujeme jejich datum a jasně je označujeme jako prodejné po kontrole.
  -- Bez potvrzení fyzické přítomnosti je nesmíme automaticky připsat do auta.
  update public.route_vehicle_waste_items
  set expiry_date = date '2027-05-09',
      reason = 'other',
      note = concat_ws(' · ', nullif(note, ''), 'OPRAVA: platné do 09.05.2027; nevyhazovat, po fyzické kontrole vrátit mezi prodejné'),
      updated_at = now()
  where product_id = v_product_id
    and expiry_date = date '2026-05-09'
    and status = 'pending';
  get diagnostics v_waste = row_count;

  if v_batches <> 1 then
    raise exception 'Očekávána 1 chybná šarže Havlík, nalezeno %.', v_batches;
  end if;
  if v_slots = 0 then
    raise exception 'Nebyla nalezena žádná pozice Havlík s chybným datem.';
  end if;

  raise notice 'Havlík opraven: šarže %, pozice %, doplnění %, čekající svozy %.',
    v_batches, v_slots, v_fills, v_waste;
end
$$;

commit;
