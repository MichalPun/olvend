begin;

-- Bezpečnostní uzávěra po přípravě tras 75 a 76 na 28. 8. 2026.
-- SOCO změny se nesmějí aktivovat bez nové konkrétní trasy, nového pick-listu
-- a cílového automatu pro každý stažený kus starého sortimentu.
update public.machine_planogram_slots slot
set
  product_family = case slot.product_sku
    when '40' then 'Margot'
    when '26' then '3Bit'
    when '31' then 'Miňonky'
    when '27' then 'Kit Kat'
    when '25' then 'Twix'
  end,
  product_variant = case slot.product_sku
    when '26' then 'Různé druhy'
    when '31' then 'Oříškové'
    when '27' then '4 Fingers'
    else null
  end,
  planned_product_name = null,
  planned_product_sku = null,
  planned_price_czk = null,
  pending_product_id = null,
  pending_product_name = null,
  pending_product_sku = null,
  pending_price_czk = null,
  pending_change_effective_date = null,
  pending_change_note = null,
  pending_change_mode = 'sell_through',
  substitution_policy = 'exact',
  allowed_substitutes = null,
  operator_instruction = null,
  updated_at = now()
where slot.active is true
  and slot.product_sku in ('40', '26', '31', '27', '25')
  and (
    slot.planned_product_sku like 'SOCO-%'
    or slot.pending_product_sku like 'SOCO-%'
  );

do $$
declare
  v_active_changes integer;
begin
  select count(*) into v_active_changes
  from public.machine_planogram_slots slot
  where slot.active is true
    and slot.product_sku in ('40', '26', '31', '27', '25')
    and (
      slot.planned_product_sku like 'SOCO-%'
      or slot.pending_product_sku like 'SOCO-%'
      or slot.pending_change_mode = 'full_swap'
    );

  if v_active_changes <> 0 then
    raise exception 'SOCO changeover is still active on % slots; routes 75/76 must remain unchanged.', v_active_changes;
  end if;
end $$;

commit;

notify pgrst, 'reload schema';
