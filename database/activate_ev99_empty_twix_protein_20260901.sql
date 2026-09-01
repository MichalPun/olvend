begin;

do $$
declare
  v_product_id bigint;
  v_changed integer;
begin
  select id into strict v_product_id
  from public.products
  where sku = 'SOCO-PROTEIN-VANILKA-45'
    and active is true;

  update public.machine_planogram_slots
  set pending_product_id = v_product_id,
      pending_product_sku = 'SOCO-PROTEIN-VANILKA-45',
      pending_product_name = 'Proteinový suk s vanilkovou příchutí 45g',
      pending_price_czk = 18,
      planned_product_sku = 'SOCO-PROTEIN-VANILKA-45',
      planned_product_name = 'Proteinový suk s vanilkovou příchutí 45g',
      planned_price_czk = 18,
      pending_change_mode = 'full_swap',
      pending_change_effective_date = date '2026-09-02',
      pending_change_note = 'EV 99 Sportisimo: Twix je fyzicky i evidenčně vyprodaný; prázdnou pozici 23 ihned změnit na schválený Proteinový suk.',
      changeover_old_units = 0,
      changeover_new_units = 0,
      operator_instruction = 'Pozice 23 je prázdná. Vlož Proteinový suk s vanilkovou příchutí 45g a potvrď změnu produktu.',
      updated_at = now()
  where id = 1965
    and machine_id = 79
    and slot_code = '23'
    and product_sku = '25'
    and current_units = 0
    and pending_product_sku is null;

  get diagnostics v_changed = row_count;
  if v_changed <> 1 then
    raise exception 'EV 99 / pozice 23 už neodpovídá bezpečné výchozí podmínce prázdného Twixu.';
  end if;
end
$$;

commit;

select
  id,
  machine_id,
  slot_code,
  product_sku,
  current_units,
  pending_product_sku,
  pending_product_name,
  pending_change_mode,
  pending_change_effective_date
from public.machine_planogram_slots
where id = 1965;
