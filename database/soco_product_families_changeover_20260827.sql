begin;

-- Staré tyčinky se doprodají. Po jejich vyprodání se slot přepne na novou
-- rodinu SOCO; konkrétní příchuť může operátorka zvolit ze schváleného seznamu.
update public.machine_planogram_slots
set
  product_family = case product_sku
    when '40' then 'Brigit 90 g'
    when '26' then 'Bongo 40 g'
    when '31' then 'RawBar 40 g'
    when '27' then 'Extasy 45 g'
    when '25' then 'Proteinový suk 45 g'
  end,
  product_variant = case product_sku
    when '40' then 'Kokos'
    when '26' then 'Originál'
    when '31' then 'Arašídová'
    when '27' then 'Arašídová'
    when '25' then 'Vanilka'
  end,
  planned_product_name = case product_sku
    when '40' then 'Brigit kokosová tyčinka v tmavé polevě 90g'
    when '26' then 'Bongo 40 g - různé příchutě'
    when '31' then 'RawBar 40 g - různé příchutě'
    when '27' then 'Extasy 45 g - různé příchutě'
    when '25' then 'Proteinový suk 45 g - různé příchutě'
  end,
  planned_product_sku = case product_sku
    when '40' then 'SOCO-BRIGIT-90'
    when '26' then 'SOCO-BONGO-ORIGINAL-40'
    when '31' then 'SOCO-RAWBAR-PEANUTS'
    when '27' then 'SOCO-EXTASY-PEANUT-45'
    when '25' then 'SOCO-PROTEIN-VANILKA-45'
  end,
  planned_price_czk = case product_sku
    when '40' then 25
    when '26' then 16
    when '31' then 19
    when '27' then 21
    when '25' then 18
  end,
  substitution_policy = case when product_sku = '40' then 'exact' else 'approved_list' end,
  allowed_substitutes = case product_sku
    when '40' then null
    when '26' then 'Bongo originál SKU SOCO-BONGO-ORIGINAL-40; Bongo banán SKU SOCO-BONGO-BANAN-40; Bongo máta SKU SOCO-BONGO-MATA-40'
    when '31' then 'RawBar arašídy SKU SOCO-RAWBAR-PEANUTS; RawBar brusinky a mandle SKU SOCO-RAWBAR-CRANBERRY; RawBar jablko a skořice SKU SOCO-RAWBAR-APPLE'
    when '27' then 'Peanut Extasy SKU SOCO-EXTASY-PEANUT-45; Coconut Extasy SKU SOCO-EXTASY-COCONUT-45'
    when '25' then 'Proteinový suk vanilka SKU SOCO-PROTEIN-VANILKA-45; Proteinový suk čokoláda SKU SOCO-PROTEIN-COKOLADA-45'
  end,
  operator_instruction = case product_sku
    when '40' then 'Po doprodání Margot přejdi na Brigit.'
    when '26' then 'Po doprodání 3Bit doplň libovolnou dostupnou schválenou příchuť Bongo.'
    when '31' then 'Po doprodání Miňonek doplň libovolnou dostupnou schválenou příchuť RawBar.'
    when '27' then 'Po doprodání KitKat doplň libovolnou dostupnou schválenou příchuť Extasy.'
    when '25' then 'Po doprodání Twix doplň libovolnou dostupnou schválenou příchuť Proteinového suku.'
  end,
  pending_change_mode = 'sell_through',
  updated_at = now()
where active is true
  and product_sku in ('40', '26', '31', '27', '25');

do $$
declare
  v_slots integer;
  v_invalid integer;
begin
  select count(*) into v_slots
  from public.machine_planogram_slots
  where active is true and product_sku in ('40', '26', '31', '27', '25');

  if v_slots = 0 then
    raise exception 'No active old-product planogram slots found.';
  end if;

  select count(*) into v_invalid
  from public.machine_planogram_slots
  where active is true
    and product_sku in ('40', '26', '31', '27', '25')
    and (
      planned_product_sku is null
      or product_family is null
      or pending_change_mode <> 'sell_through'
      or (product_sku <> '40' and substitution_policy <> 'approved_list')
      or (product_sku <> '40' and coalesce(allowed_substitutes, '') = '')
    );

  if v_invalid <> 0 then
    raise exception 'Invalid SOCO family changeover on % active slots.', v_invalid;
  end if;
end $$;

commit;

notify pgrst, 'reload schema';
