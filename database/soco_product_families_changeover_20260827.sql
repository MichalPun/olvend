begin;

-- Pilot tvoří pět nejslabších pozic každého nahrazovaného produktu podle
-- potvrzených prodejů za 30 dní k 27. 8. 2026. Silné pozice zůstávají na
-- starém sortimentu, aby doprodaly zásobu z vozidel a centrálního skladu.

-- Opraví i případné dřívější příliš široké nastavení stejného SOCO přechodu.
with target_slots(id, expected_sku) as (values
  (1596::bigint, '40'), (1520::bigint, '40'), (1864::bigint, '40'), (1268::bigint, '40'), (1741::bigint, '40'),
  (1855::bigint, '26'), (2002::bigint, '26'), (1509::bigint, '26'), (1676::bigint, '26'), (1141::bigint, '26'),
  (1339::bigint, '31'), (1865::bigint, '31'), (1780::bigint, '31'), (1229::bigint, '31'), (1597::bigint, '31'),
  (1267::bigint, '27'), (1863::bigint, '27'), (1778::bigint, '27'), (1338::bigint, '27'), (1305::bigint, '27'),
  (1869::bigint, '25'), (1783::bigint, '25'), (1342::bigint, '25'), (1273::bigint, '25'), (1745::bigint, '25')
)
update public.machine_planogram_slots slot
set
  product_family = case slot.product_sku
    when '40' then 'Margot' when '26' then '3Bit' when '31' then 'Miňonky'
    when '27' then 'Kit Kat' when '25' then 'Twix'
  end,
  product_variant = case slot.product_sku
    when '26' then 'Různé druhy' when '31' then 'Oříškové' when '27' then '4 Fingers'
    else null
  end,
  planned_product_name = null,
  planned_product_sku = null,
  planned_price_czk = null,
  substitution_policy = 'exact',
  allowed_substitutes = null,
  operator_instruction = null,
  pending_change_mode = 'sell_through',
  updated_at = now()
where slot.active is true
  and slot.product_sku in ('40', '26', '31', '27', '25')
  and slot.planned_product_sku in (
    'SOCO-BRIGIT-90', 'SOCO-BONGO-ORIGINAL-40', 'SOCO-RAWBAR-PEANUTS',
    'SOCO-EXTASY-PEANUT-45', 'SOCO-PROTEIN-VANILKA-45'
  )
  and not exists (select 1 from target_slots target where target.id = slot.id);

with target_slots(id, expected_sku) as (values
  (1596::bigint, '40'), (1520::bigint, '40'), (1864::bigint, '40'), (1268::bigint, '40'), (1741::bigint, '40'),
  (1855::bigint, '26'), (2002::bigint, '26'), (1509::bigint, '26'), (1676::bigint, '26'), (1141::bigint, '26'),
  (1339::bigint, '31'), (1865::bigint, '31'), (1780::bigint, '31'), (1229::bigint, '31'), (1597::bigint, '31'),
  (1267::bigint, '27'), (1863::bigint, '27'), (1778::bigint, '27'), (1338::bigint, '27'), (1305::bigint, '27'),
  (1869::bigint, '25'), (1783::bigint, '25'), (1342::bigint, '25'), (1273::bigint, '25'), (1745::bigint, '25')
)
update public.machine_planogram_slots slot
set
  product_family = case slot.product_sku
    when '40' then 'Brigit 90 g' when '26' then 'Bongo 40 g' when '31' then 'RawBar 40 g'
    when '27' then 'Extasy 45 g' when '25' then 'Proteinový suk 45 g'
  end,
  product_variant = case slot.product_sku
    when '40' then 'Kokos' when '26' then 'Originál' when '31' then 'Arašídová'
    when '27' then 'Arašídová' when '25' then 'Vanilka'
  end,
  planned_product_name = case slot.product_sku
    when '40' then 'Brigit kokosová tyčinka v tmavé polevě 90g'
    when '26' then 'Bongo 40 g - různé příchutě'
    when '31' then 'RawBar 40 g - různé příchutě'
    when '27' then 'Extasy 45 g - různé příchutě'
    when '25' then 'Proteinový suk 45 g - různé příchutě'
  end,
  planned_product_sku = case slot.product_sku
    when '40' then 'SOCO-BRIGIT-90' when '26' then 'SOCO-BONGO-ORIGINAL-40'
    when '31' then 'SOCO-RAWBAR-PEANUTS' when '27' then 'SOCO-EXTASY-PEANUT-45'
    when '25' then 'SOCO-PROTEIN-VANILKA-45'
  end,
  planned_price_czk = case slot.product_sku
    when '40' then 25 when '26' then 16 when '31' then 19 when '27' then 21 when '25' then 18
  end,
  substitution_policy = case when slot.product_sku = '40' then 'exact' else 'approved_list' end,
  allowed_substitutes = case slot.product_sku
    when '40' then null
    when '26' then 'Bongo originál SKU SOCO-BONGO-ORIGINAL-40; Bongo banán SKU SOCO-BONGO-BANAN-40; Bongo máta SKU SOCO-BONGO-MATA-40'
    when '31' then 'RawBar arašídy SKU SOCO-RAWBAR-PEANUTS; RawBar brusinky a mandle SKU SOCO-RAWBAR-CRANBERRY; RawBar jablko a skořice SKU SOCO-RAWBAR-APPLE'
    when '27' then 'Peanut Extasy SKU SOCO-EXTASY-PEANUT-45; Coconut Extasy SKU SOCO-EXTASY-COCONUT-45'
    when '25' then 'Proteinový suk vanilka SKU SOCO-PROTEIN-VANILKA-45; Proteinový suk čokoláda SKU SOCO-PROTEIN-COKOLADA-45'
  end,
  operator_instruction = case slot.product_sku
    when '40' then 'Při nejbližší návštěvě stáhni Margot zpět do vozidla pro doprodej na silných pozicích a slot přepni na Brigit.'
    when '26' then 'Při nejbližší návštěvě stáhni 3Bit zpět do vozidla pro doprodej na silných pozicích a doplň libovolnou dostupnou schválenou příchuť Bongo.'
    when '31' then 'Při nejbližší návštěvě stáhni Miňonky zpět do vozidla pro doprodej na silných pozicích a doplň libovolnou dostupnou schválenou příchuť RawBar.'
    when '27' then 'Při nejbližší návštěvě stáhni KitKat zpět do vozidla pro doprodej na silných pozicích a doplň libovolnou dostupnou schválenou příchuť Extasy.'
    when '25' then 'Při nejbližší návštěvě stáhni Twix zpět do vozidla pro doprodej na silných pozicích a doplň libovolnou dostupnou schválenou příchuť Proteinového suku.'
  end,
  pending_change_mode = 'full_swap',
  updated_at = now()
from target_slots target
where slot.id = target.id
  and slot.product_sku = target.expected_sku
  and slot.active is true;

do $$
declare
  v_target_slots integer;
  v_invalid integer;
  v_outside integer;
begin
  with target_slots(id) as (values
    (1596::bigint), (1520::bigint), (1864::bigint), (1268::bigint), (1741::bigint),
    (1855::bigint), (2002::bigint), (1509::bigint), (1676::bigint), (1141::bigint),
    (1339::bigint), (1865::bigint), (1780::bigint), (1229::bigint), (1597::bigint),
    (1267::bigint), (1863::bigint), (1778::bigint), (1338::bigint), (1305::bigint),
    (1869::bigint), (1783::bigint), (1342::bigint), (1273::bigint), (1745::bigint)
  )
  select count(*), count(*) filter (where
    slot.planned_product_sku is null
    or slot.product_family is null
    or slot.pending_change_mode <> 'full_swap'
    or (slot.product_sku <> '40' and slot.substitution_policy <> 'approved_list')
    or (slot.product_sku <> '40' and coalesce(slot.allowed_substitutes, '') = '')
  )
  into v_target_slots, v_invalid
  from target_slots target
  join public.machine_planogram_slots slot on slot.id = target.id and slot.active is true;

  if v_target_slots <> 25 or v_invalid <> 0 then
    raise exception 'Expected 25 valid weak SOCO pilot slots; found %, invalid %.', v_target_slots, v_invalid;
  end if;

  select count(*) into v_outside
  from public.machine_planogram_slots slot
  where slot.active is true
    and slot.product_sku in ('40', '26', '31', '27', '25')
    and slot.planned_product_sku in (
      'SOCO-BRIGIT-90', 'SOCO-BONGO-ORIGINAL-40', 'SOCO-RAWBAR-PEANUTS',
      'SOCO-EXTASY-PEANUT-45', 'SOCO-PROTEIN-VANILKA-45'
    )
    and slot.id not in (
      1596,1520,1864,1268,1741,1855,2002,1509,1676,1141,1339,1865,1780,
      1229,1597,1267,1863,1778,1338,1305,1869,1783,1342,1273,1745
    );

  if v_outside <> 0 then
    raise exception 'SOCO changeover leaked to % strong slots.', v_outside;
  end if;
end $$;

commit;

notify pgrst, 'reload schema';
