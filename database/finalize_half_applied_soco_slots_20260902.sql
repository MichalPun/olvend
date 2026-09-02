begin;

-- Znovu aktivuje rozpracované změny, kde zůstal starý aktuální produkt a nový
-- produkt pouze v planned_*. Protože ceny jsou různé, změna musí být full-swap:
-- staré prodejné kusy se vrátí do stejného auta a nová cena se potvrdí až s novým SKU.
with replacement as (
  select id, sku, name, sale_price
  from public.products
  where active is true
    and sku like 'SOCO-%'
), current_product as (
  select sku, sale_price
  from public.products
  where active is true
)
update public.machine_planogram_slots slot
set pending_product_id = replacement.id,
    pending_product_sku = replacement.sku,
    pending_product_name = replacement.name,
    pending_price_czk = replacement.sale_price,
    pending_change_effective_date = current_date,
    pending_change_mode = 'full_swap',
    pending_change_note = 'Obnovení nedokončené změny sortimentu: staré kusy vrať do stejného auta, vlož nový produkt a potvrď novou cenu přímo na automatu.',
    operator_instruction = 'Kompletní výměna: vyndej zbývající staré prodejné kusy do svého auta, vlož nový produkt a potvrď změnu ceny.',
    substitution_policy = 'exact',
    allowed_substitutes = replacement.sku,
    price_czk = current_product.sale_price,
    customer_price_czk = current_product.sale_price,
    dex_price_czk = current_product.sale_price,
    changeover_old_units = greatest(0, coalesce(slot.changeover_old_units, slot.current_units, 0)),
    changeover_new_units = greatest(0, coalesce(slot.changeover_new_units, 0)),
    updated_at = now()
from replacement, current_product
where slot.active is true
  and current_product.sku = slot.product_sku
  and slot.product_sku not like 'SOCO-%'
  and slot.planned_product_sku = replacement.sku
  and slot.pending_product_sku is null;

-- Dokončí pouze pozice, na kterých už je jako aktuální produkt fyzicky/evidenčně
-- zapsaný nový SOCO sortiment. Rozpracovaného doprodeje starého SKU se nedotýká.
with replacement as (
  select
    product.id,
    product.sku,
    product.name,
    product.sale_price,
    case
      when product.sku = 'SOCO-BRIGIT-90' then 'Brigit'
      when product.sku like 'SOCO-BONGO-%' then 'Bongo'
      when product.sku like 'SOCO-RAWBAR-%' then 'RawBar'
      when product.sku like 'SOCO-EXTASY-%' then 'Extasy'
      when product.sku like 'SOCO-PROTEIN-%' then 'Proteinový suk'
    end as family,
    case
      when product.sku = 'SOCO-BONGO-ORIGINAL-40' then 'Original'
      when product.sku = 'SOCO-BONGO-BANAN-40' then 'Banán'
      when product.sku = 'SOCO-BONGO-MATA-40' then 'Máta'
      when product.sku = 'SOCO-RAWBAR-PEANUTS' then 'Arašídy'
      when product.sku = 'SOCO-RAWBAR-CRANBERRY' then 'Brusinky a mandle'
      when product.sku = 'SOCO-RAWBAR-APPLE' then 'Jablko a skořice'
      when product.sku = 'SOCO-EXTASY-PEANUT-45' then 'Arašídové máslo'
      when product.sku = 'SOCO-EXTASY-COCONUT-45' then 'Kokos'
      when product.sku = 'SOCO-PROTEIN-VANILKA-45' then 'Vanilka'
      when product.sku = 'SOCO-PROTEIN-COKOLADA-45' then 'Čokoláda'
    end as variant
  from public.products product
  where product.active is true
    and product.sku like 'SOCO-%'
)
update public.machine_planogram_slots slot
set product_name = replacement.name,
    product_family = replacement.family,
    product_variant = replacement.variant,
    price_czk = replacement.sale_price,
    customer_price_czk = replacement.sale_price,
    dex_price_czk = replacement.sale_price,
    planned_product_sku = case
      when slot.planned_product_sku = slot.product_sku then null
      else slot.planned_product_sku
    end,
    planned_product_name = case
      when slot.planned_product_sku = slot.product_sku then null
      else slot.planned_product_name
    end,
    planned_price_czk = case
      when slot.planned_product_sku = slot.product_sku then null
      else slot.planned_price_czk
    end,
    changeover_old_units = case
      when slot.planned_product_sku = slot.product_sku then null
      else slot.changeover_old_units
    end,
    changeover_new_units = case
      when slot.planned_product_sku = slot.product_sku then null
      else slot.changeover_new_units
    end,
    changeover_started_at = case
      when slot.planned_product_sku = slot.product_sku then null
      else slot.changeover_started_at
    end,
    updated_at = now()
from replacement
where slot.active is true
  and slot.product_sku = replacement.sku
  and slot.pending_product_sku is null;

do $$
declare
  v_half_applied integer;
  v_wrong_price integer;
  v_unprotected_change integer;
begin
  select count(*) into v_half_applied
  from public.machine_planogram_slots slot
  where slot.active is true
    and slot.product_sku like 'SOCO-%'
    and slot.planned_product_sku = slot.product_sku
    and slot.pending_product_sku is null;

  select count(*) into v_wrong_price
  from public.machine_planogram_slots slot
  join public.products product on product.sku = slot.product_sku
  where slot.active is true
    and slot.product_sku like 'SOCO-%'
    and slot.pending_product_sku is null
    and (
      slot.price_czk is distinct from product.sale_price
      or slot.customer_price_czk is distinct from product.sale_price
      or slot.dex_price_czk is distinct from product.sale_price
    );

  select count(*) into v_unprotected_change
  from public.machine_planogram_slots slot
  where slot.active is true
    and slot.product_sku not like 'SOCO-%'
    and slot.planned_product_sku like 'SOCO-%'
    and slot.pending_product_sku is null;

  if v_half_applied <> 0 or v_wrong_price <> 0 or v_unprotected_change <> 0 then
    raise exception 'SOCO cleanup failed: % self-planned slots, % wrong-price slots, % unprotected changes.', v_half_applied, v_wrong_price, v_unprotected_change;
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
