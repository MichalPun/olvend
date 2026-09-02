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

-- U pozic, na kterých už je fyzicky/evidenčně nový SOCO produkt, opraví rodinu.
-- Cenu nikdy nepotvrdí za operátorku: pokud evidence ještě neodpovídá cílové ceně,
-- nechá stejný produkt jako price-only plán, který mobil uzavře až po fyzické změně ceny.
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
    planned_product_sku = case
      when slot.price_czk is not distinct from replacement.sale_price
       and coalesce(slot.customer_price_czk, slot.price_czk) is not distinct from replacement.sale_price
       and coalesce(slot.dex_price_czk, slot.price_czk) is not distinct from replacement.sale_price
        then null
      else replacement.sku
    end,
    planned_product_name = case
      when slot.price_czk is not distinct from replacement.sale_price
       and coalesce(slot.customer_price_czk, slot.price_czk) is not distinct from replacement.sale_price
       and coalesce(slot.dex_price_czk, slot.price_czk) is not distinct from replacement.sale_price
        then null
      else replacement.name
    end,
    planned_price_czk = case
      when slot.price_czk is not distinct from replacement.sale_price
       and coalesce(slot.customer_price_czk, slot.price_czk) is not distinct from replacement.sale_price
       and coalesce(slot.dex_price_czk, slot.price_czk) is not distinct from replacement.sale_price
        then null
      else replacement.sale_price
    end,
    operator_instruction = case
      when slot.price_czk is not distinct from replacement.sale_price
       and coalesce(slot.customer_price_czk, slot.price_czk) is not distinct from replacement.sale_price
       and coalesce(slot.dex_price_czk, slot.price_czk) is not distinct from replacement.sale_price
        then null
      else format('Ověř cenu pozice na automatu a změň ji z %s Kč na %s Kč. Potvrď až po fyzickém provedení.', coalesce(slot.customer_price_czk, slot.price_czk), replacement.sale_price)
    end,
    changeover_old_units = null,
    changeover_new_units = null,
    changeover_started_at = null,
    updated_at = now()
from replacement
where slot.active is true
  and slot.product_sku = replacement.sku
  and slot.pending_product_sku is null
  and (slot.planned_product_sku is null or slot.planned_product_sku = slot.product_sku);

do $$
declare
  v_stale_self_plan integer;
  v_unprotected_price integer;
  v_unprotected_change integer;
begin
  select count(*) into v_stale_self_plan
  from public.machine_planogram_slots slot
  join public.products product on product.sku = slot.product_sku
  where slot.active is true
    and slot.product_sku like 'SOCO-%'
    and slot.planned_product_sku = slot.product_sku
    and slot.pending_product_sku is null
    and slot.price_czk is not distinct from product.sale_price
    and coalesce(slot.customer_price_czk, slot.price_czk) is not distinct from product.sale_price
    and coalesce(slot.dex_price_czk, slot.price_czk) is not distinct from product.sale_price;

  select count(*) into v_unprotected_price
  from public.machine_planogram_slots slot
  join public.products product on product.sku = slot.product_sku
  where slot.active is true
    and slot.product_sku like 'SOCO-%'
    and slot.pending_product_sku is null
    and (
      slot.price_czk is distinct from product.sale_price
      or coalesce(slot.customer_price_czk, slot.price_czk) is distinct from product.sale_price
      or coalesce(slot.dex_price_czk, slot.price_czk) is distinct from product.sale_price
    )
    and not (
      slot.planned_product_sku = slot.product_sku
      and slot.planned_price_czk is not distinct from product.sale_price
      and nullif(slot.operator_instruction, '') is not null
    );

  select count(*) into v_unprotected_change
  from public.machine_planogram_slots slot
  where slot.active is true
    and slot.product_sku not like 'SOCO-%'
    and slot.planned_product_sku like 'SOCO-%'
    and slot.pending_product_sku is null;

  if v_stale_self_plan <> 0 or v_unprotected_price <> 0 or v_unprotected_change <> 0 then
    raise exception 'SOCO cleanup failed: % stale self-plans, % unprotected prices, % unprotected changes.', v_stale_self_plan, v_unprotected_price, v_unprotected_change;
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
