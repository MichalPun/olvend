-- Jetinno JL300 EV125 po fyzicke kontrole:
-- * maximalni kapacita vsech surovinovych zasobniku Z1-Z7 je 2,5 kg,
-- * Matcha Z6 zustava na dnes skutecne doplnenych 2,0 kg,
-- * ostatni suroviny vcetne zrna byly v automatu uz pred navstevou: 2,2 kg.
-- Predem nasypane suroviny se dorovnaji jako pocatecni fyzicky stav EV125,
-- nikoli jako dnesni presun z vozidla.

begin;

do $$
declare
  v_machine_id bigint;
  v_machine_stock_location_id bigint;
  v_updated integer;
  v_rows jsonb;
  v_result jsonb;
begin
  select id into v_machine_id
  from public.machines
  where evidence_number = 125
    and brand = 'Jetinno'
    and model = 'JL300';

  if v_machine_id is null then
    raise exception 'Jetinno EV125 nebylo nalezeno.';
  end if;

  select id into v_machine_stock_location_id
  from public.stock_locations
  where location_type = 'machine'
    and machine_id = v_machine_id
    and active = true;

  if v_machine_stock_location_id is null then
    raise exception 'Skladove misto EV125 nebylo nalezeno.';
  end if;

  -- Vsechny fyzicke surovinove zasobniky maji maximum 2,5 kg.
  update public.machine_coffee_containers
  set capacity_quantity = 2500,
      current_quantity = case when container_code = 'Z6' then 2000 else 2200 end,
      note = concat_ws(' ', nullif(note, ''), 'Fyzicka kontrola 5. 9. 2026: kapacita 2,5 kg; vychozi naplneni ostatnich surovin 2,2 kg, Matcha po dnesnim doplneni 2,0 kg.'),
      updated_at = now()
  where machine_id = v_machine_id
    and container_code in ('Z1','Z2','Z3','Z4','Z5','Z6','Z7')
    and unit = 'g'
    and active = true;

  get diagnostics v_updated = row_count;
  if v_updated <> 7 then
    raise exception 'Ocekavano 7 surovinovych zasobniku EV125, upraveno %.', v_updated;
  end if;

  -- Z1-Z5 a Z7 byly fyzicky naplnene uz pred dnesni navstevou. Jejich
  -- skladovou zasobu dorovname na 2,2 kg bez odectu z dnesniho vozidla.
  with physical_targets as (
    select
      c.container_code,
      c.product_id,
      2.2::numeric as target_quantity,
      coalesce((
        select sum(b.quantity_on_hand)
        from public.stock_location_balances b
        where b.stock_location_id = v_machine_stock_location_id
          and b.product_id = c.product_id
      ), 0)::numeric as current_stock_quantity
    from public.machine_coffee_containers c
    where c.machine_id = v_machine_id
      and c.container_code in ('Z1','Z2','Z3','Z4','Z5','Z7')
      and c.active = true
  ), missing_stock as (
    select *
    from physical_targets
    where target_quantity - current_stock_quantity > 0.0001
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'product_id', product_id,
    'batch_id', null,
    'from_stock_location_id', null,
    'to_stock_location_id', v_machine_stock_location_id,
    'movement_type', 'adjustment',
    'quantity_base_units', target_quantity - current_stock_quantity,
    'reference_type', 'data_repair',
    'reference_id', 'ev125_initial_physical_fill_' || lower(container_code) || '_20260905',
    'note', 'Pocatecni fyzicky stav EV125 potvrzen 5. 9. 2026: ' || container_code || ' obsahoval pred navstevou 2,2 kg.'
  )), '[]'::jsonb)
  into v_rows
  from missing_stock;

  if jsonb_array_length(v_rows) > 0 then
    select public.apply_stock_movements_v13(v_rows) into v_result;
    if coalesce((v_result->>'inserted')::integer, 0) <> jsonb_array_length(v_rows) then
      raise exception 'Dorovnani pocatecniho fyzickeho stavu EV125 selhalo: %.', v_result;
    end if;
  end if;

  if exists (
    select 1
    from public.machine_coffee_containers
    where machine_id = v_machine_id
      and container_code in ('Z1','Z2','Z3','Z4','Z5','Z6','Z7')
      and active = true
      and (
        capacity_quantity <> 2500
        or current_quantity <> case when container_code = 'Z6' then 2000 else 2200 end
        or current_quantity > capacity_quantity
      )
  ) then
    raise exception 'Konecny stav zasobniku EV125 neodpovida fyzicke kontrole.';
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
