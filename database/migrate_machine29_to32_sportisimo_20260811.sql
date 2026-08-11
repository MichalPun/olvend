-- Přesun provozních stavů z EV 29 na EV 32 ve Sportisimu.
-- EV 32 si ponechává Matcha Malina v Z7; bílá čokoláda z EV 29 se nepřenáší.

do $$
declare
  v_source_machine_id bigint := 24;
  v_target_machine_id bigint := 27;
  v_warehouse_location_id bigint := 1;
  v_target_stock_location_id bigint;
  v_matcha_product_id bigint := 143;
  v_state_already_migrated boolean;
begin
  if not exists (
    select 1
    from public.machines m
    where m.id = v_source_machine_id
      and m.evidence_number = '29'
      and m.location_id = 58
  ) then
    raise exception 'Zdrojový automat EV 29 neodpovídá očekávanému stroji ve Sportisimu.';
  end if;

  if not exists (
    select 1
    from public.machines m
    where m.id = v_target_machine_id
      and m.evidence_number = '32'
      and m.location_id = 58
  ) then
    raise exception 'Cílový automat EV 32 neodpovídá očekávanému stroji ve Sportisimu.';
  end if;

  if not exists (
    select 1
    from public.products p
    where p.id = v_matcha_product_id
      and p.sku = '262'
      and lower(p.name) like '%matcha%malina%'
  ) then
    raise exception 'Produkt Matcha Malina neodpovídá očekávanému produktu SKU 262.';
  end if;

  select sl.id
  into v_target_stock_location_id
  from public.stock_locations sl
  where sl.location_type = 'machine'
    and sl.machine_id = v_target_machine_id
  order by sl.active desc, sl.id
  limit 1;

  if v_target_stock_location_id is null then
    insert into public.stock_locations (
      location_type,
      name,
      machine_id,
      active,
      note
    ) values (
      'machine',
      'Automat EV 32 · Sportisimo',
      v_target_machine_id,
      true,
      'Vytvořeno při zprovoznění automatu EV 32 dne 11. 8. 2026.'
    )
    returning id into v_target_stock_location_id;
  end if;

  select coalesce(m.note, '') like '%MIGRACE_EV29_EV32_20260811%'
  into v_state_already_migrated
  from public.machines m
  where m.id = v_target_machine_id;

  -- Přenos fyzických stavů. Z7 je záměrně vynechána, protože na EV 32 je Matcha.
  update public.machine_coffee_containers target
  set
    capacity_quantity = source.capacity_quantity,
    current_quantity = source.current_quantity,
    refill_package_quantity = source.refill_package_quantity,
    refill_package_unit = source.refill_package_unit,
    min_refill_quantity = source.min_refill_quantity,
    note = concat_ws(
      ' · ',
      nullif(target.note, ''),
      'Stav a kapacita převedeny z EV 29 při zprovoznění ve Sportisimu 11. 8. 2026'
    ),
    updated_at = now()
  from public.machine_coffee_containers source
  where source.machine_id = v_source_machine_id
    and target.machine_id = v_target_machine_id
    and source.active = true
    and target.active = true
    and source.container_code = target.container_code
    and source.container_code in ('Z1', 'Z2', 'Z3', 'Z4', 'Z5', 'Z6', 'Z8', 'Z9', 'Z10')
    and source.product_id = target.product_id
    and not v_state_already_migrated;

  -- Po přesunu nesmí stejné fyzické množství zůstat současně i na EV 29.
  update public.machine_coffee_containers source
  set
    current_quantity = 0,
    note = concat_ws(
      ' · ',
      nullif(source.note, ''),
      'Fyzický stav převeden na EV 32 ve Sportisimu 11. 8. 2026'
    ),
    updated_at = now()
  where source.machine_id = v_source_machine_id
    and source.active = true
    and source.container_code in ('Z1', 'Z2', 'Z3', 'Z4', 'Z5', 'Z6', 'Z8', 'Z9', 'Z10')
    and not v_state_already_migrated;

  -- Tři kilogramy Matcha Malina jsou jediný nový fyzický výdej z Blučiny.
  if not exists (
    select 1
    from public.stock_movements_v13 sm
    where sm.reference_type = 'data_repair'
      and sm.reference_id = 'machine-32-matcha-3kg-20260811'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', v_matcha_product_id,
          'batch_id', null,
          'from_stock_location_id', v_warehouse_location_id,
          'to_stock_location_id', v_target_stock_location_id,
          'movement_type', 'fill_machine',
          'quantity_base_units', 3,
          'reference_type', 'data_repair',
          'reference_id', 'machine-32-matcha-3kg-20260811',
          'note', 'Výdej 3 kg Matcha Malina ze skladu BLUČINA do automatu EV 32 ve Sportisimu.'
        )
      )
    );

    update public.machine_coffee_containers
    set
      current_quantity = 3000,
      note = concat_ws(' · ', nullif(note, ''), 'Naplněno 3 kg Matcha Malina ze skladu BLUČINA 11. 8. 2026'),
      updated_at = now()
    where machine_id = v_target_machine_id
      and active = true
      and container_code = 'Z7'
      and product_id = v_matcha_product_id;
  end if;

  -- Partnerský prodej musí být shodný s ostatním Sportisimem, včetně sazeb partnera.
  update public.machine_coffee_buttons target
  set
    customer_price_czk = source.customer_price_czk,
    sale_price_czk = source.sale_price_czk,
    settlement_type = source.settlement_type,
    settlement_amount_czk = source.settlement_amount_czk,
    settlement_partner = source.settlement_partner,
    settlement_billing_enabled = source.settlement_billing_enabled,
    settlement_note = source.settlement_note,
    updated_at = now()
  from public.machine_coffee_buttons source
  where source.machine_id = v_source_machine_id
    and target.machine_id = v_target_machine_id
    and source.active = true
    and target.active = true
    and source.selection_code = target.selection_code;

  -- Platební terminál GP/TID 596507 se přesouvá z EV 29 na EV 32.
  update public.machine_external_links
  set
    machine_id = v_target_machine_id,
    note = 'TID 596507 přiřazen automatu EV 32 ve Sportisimu dne 11. 8. 2026.',
    updated_at = now()
  where machine_id = v_source_machine_id
    and provider = 'GP'
    and external_machine_id = '596507';

  update public.machines
  set
    note = case
      when coalesce(note, '') like '%MIGRACE_EV29_EV32_20260811%'
        then note
      else concat_ws(' · ', nullif(note, ''), 'Partnerský prodej SPORTISIMO · zákaznická cena 0 Kč · TID 596507 · MIGRACE_EV29_EV32_20260811')
    end,
    updated_at = now()
  where id = v_target_machine_id;
end
$$;

-- Ověření po nasazení.
select
  m.evidence_number,
  c.container_code,
  c.product_name,
  c.current_quantity,
  c.capacity_quantity,
  c.unit
from public.machines m
join public.machine_coffee_containers c on c.machine_id = m.id and c.active = true
where m.id in (24, 27)
order by m.id, c.sort_order;

select
  m.evidence_number,
  count(*) filter (where b.customer_price_czk = 0) as zero_price_buttons,
  count(*) filter (where b.settlement_partner = 'SPORTISIMO s.r.o.') as sportisimo_buttons,
  min(b.settlement_amount_czk) as min_partner_rate,
  max(b.settlement_amount_czk) as max_partner_rate
from public.machines m
join public.machine_coffee_buttons b on b.machine_id = m.id and b.active = true
where m.id = 27
group by m.evidence_number;

select
  m.evidence_number,
  l.provider,
  l.external_machine_id,
  l.telemetry_enabled
from public.machine_external_links l
join public.machines m on m.id = l.machine_id
where l.external_machine_id = '596507'
order by l.provider;
