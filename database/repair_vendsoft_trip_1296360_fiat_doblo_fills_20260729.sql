-- Dodatečné zaúčtování doplnění z VendSoft cesty 1296360.
-- Datum: 29. 7. 2026, operátorka Kristýna Dvořáková.
-- Zdroj: Fiat Doblo 5AP9000 (stock_location_id 4).
-- Fiat smí podle výslovného pokynu přejít do záporného stavu.
-- Zapisuje přesná množství z výsledků cesty, včetně případného překročení
-- nominální kapacity zásobníku.

do $$
declare
  v_row record;
  v_machine_id bigint;
  v_machine_location_id bigint;
  v_container_id bigint;
  v_product_id bigint;
  v_reference_id text;
begin
  for v_row in
    select *
    from (values
      ('27',  'Z1',  1000::numeric, 1.0::numeric, '1 bal. Barbera Tris (VendSoft Elite)'),
      ('27',  'Z7',  1000::numeric, 1.0::numeric, '1 bal. Lemon'),
      ('27',  'Z8',   200::numeric, 200::numeric, '2 bal. kelímků 180 ml po 100 ks'),

      ('29',  'Z1',  1000::numeric, 1.0::numeric, '1 bal. Barbera Tris (VendSoft Elite)'),
      ('29',  'Z2',  1500::numeric, 1.5::numeric, '1 bal. cukru 1,5 kg'),
      ('29',  'Z3',  3000::numeric, 3.0::numeric, '3 bal. creameru'),
      ('29',  'Z4',  2000::numeric, 2.0::numeric, '2 bal. kakaa'),
      ('29',  'Z5',   500::numeric, 0.5::numeric, '1 bal. Sophia 500 g'),
      ('29',  'Z6',  1000::numeric, 1.0::numeric, '1 bal. Irish Cream'),
      ('29',  'Z8',   300::numeric, 300::numeric, '3 bal. kelímků 180 ml po 100 ks'),

      ('98',  'Z1',   500::numeric, 0.5::numeric, '1 bal. Sophia 500 g'),
      ('98',  'Z2',  1500::numeric, 1.5::numeric, '1 bal. cukru 1,5 kg'),
      ('98',  'Z3',  1000::numeric, 1.0::numeric, '1 bal. creameru'),
      ('98',  'Z4',  1000::numeric, 1.0::numeric, '1 bal. kakaa'),
      ('98',  'Z6',  1000::numeric, 1.0::numeric, '1 bal. pistácie'),
      ('98',  'Z8',  1000::numeric, 1.0::numeric, '1 bal. Lemon'),

      ('107', 'Z1',   500::numeric, 0.5::numeric, '1 bal. Sophia 500 g'),
      ('107', 'Z3',  1000::numeric, 1.0::numeric, '1 bal. creameru'),
      ('107', 'Z7',  1000::numeric, 1.0::numeric, '1 bal. Irish Cream'),
      ('107', 'Z8',  1000::numeric, 1.0::numeric, '1 bal. Lemon'),

      ('112', 'Z3',  1000::numeric, 1.0::numeric, '1 bal. creameru'),
      ('112', 'Z8',   200::numeric, 200::numeric, '2 bal. kelímků 250 ml po 100 ks')
    ) as x(evidence_number, container_code, container_add_quantity, stock_base_quantity, description)
  loop
    select m.id
      into strict v_machine_id
    from public.machines m
    where m.evidence_number::text = v_row.evidence_number;

    select c.id, c.product_id
      into strict v_container_id, v_product_id
    from public.machine_coffee_containers c
    where c.machine_id = v_machine_id
      and c.container_code = v_row.container_code
      and c.active = true;

    select sl.id
      into v_machine_location_id
    from public.stock_locations sl
    where sl.location_type = 'machine'
      and sl.machine_id = v_machine_id
    order by sl.id
    limit 1;

    if v_machine_location_id is null then
      insert into public.stock_locations (
        location_type, name, machine_id, active, note
      )
      values (
        'machine',
        'Automat EV ' || v_row.evidence_number,
        v_machine_id,
        true,
        'Vytvořeno při dodatečném zaúčtování VendSoft cesty 1296360.'
      )
      returning id into v_machine_location_id;
    end if;

    v_reference_id := 'vendsoft-trip-1296360-ev-' || v_row.evidence_number
      || '-' || lower(v_row.container_code);

    if not exists (
      select 1
      from public.stock_movements_v13 sm
      where sm.reference_type = 'manual_transfer'
        and sm.reference_id = v_reference_id
    ) then
      perform public.apply_stock_movements_v13(
        jsonb_build_array(
          jsonb_build_object(
            'product_id', v_product_id,
            'batch_id', null,
            'from_stock_location_id', 4,
            'to_stock_location_id', v_machine_location_id,
            'movement_type', 'fill_machine',
            'quantity_base_units', v_row.stock_base_quantity,
            'reference_type', 'manual_transfer',
            'reference_id', v_reference_id,
            'allow_negative_source', true,
            'note', 'VendSoft trip 1296360 · 2026-07-29 · Kristýna Dvořáková · EV '
              || v_row.evidence_number || ' · ' || v_row.container_code || ' · '
              || v_row.description
          )
        )
      );

      update public.machine_coffee_containers
      set current_quantity = round((coalesce(current_quantity, 0) + v_row.container_add_quantity)::numeric, 3),
          note = concat_ws(
            ' ',
            nullif(note, ''),
            'Dodatečně přičteno z VendSoft cesty 1296360 dne 2026-07-29: '
              || v_row.description || '.'
          ),
          updated_at = now()
      where id = v_container_id;
    end if;
  end loop;
end
$$;
