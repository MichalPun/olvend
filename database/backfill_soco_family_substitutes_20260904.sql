-- Legacy mobile builds read approved substitutes directly from this field.
-- Keep all active RawBar and Extasy variants usable within their own family.
update public.machine_planogram_slots
set allowed_substitutes = case
  when product_sku like 'SOCO-RAWBAR-%' then
    'SKU SOCO-RAWBAR-PEANUTS, SKU SOCO-RAWBAR-CRANBERRY, SKU SOCO-RAWBAR-APPLE'
  when product_sku like 'SOCO-EXTASY-%' then
    'SKU SOCO-EXTASY-PEANUT-45, SKU SOCO-EXTASY-COCONUT-45'
  else allowed_substitutes
end,
updated_at = now()
where active is true
  and (product_sku like 'SOCO-RAWBAR-%' or product_sku like 'SOCO-EXTASY-%');

do $$
begin
  if exists (
    select 1
    from public.machine_planogram_slots
    where active is true
      and (product_sku like 'SOCO-RAWBAR-%' or product_sku like 'SOCO-EXTASY-%')
      and coalesce(allowed_substitutes, '') not like '%SKU SOCO-%'
  ) then
    raise exception 'SOCO family substitute backfill is incomplete.';
  end if;
end $$;
