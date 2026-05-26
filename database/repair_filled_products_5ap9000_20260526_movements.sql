begin;

with filled_lines(product_id, quantity_base_units, source_code, source_name, source_type) as (
  values
    (1::bigint, 1::numeric, '26', '3Bit tycinka ruzne druhy', 'Cukrovinky'),
    (2::bigint, 6::numeric, '42', '7days Croissant liskovy orisek 60g', 'Cukrovinky'),
    (10::bigint, 8::numeric, '208', 'Alaska kukuricne trubicky plnene kremem 18g ruzne', 'Cukrovinky'),
    (19::bigint, 3::numeric, '33', 'Attack Oplatka liskooriskova 30g', 'Cukrovinky'),
    (49::bigint, 1::numeric, '210', 'Doritos Tortillas Chipsy nachos cheese 44g', 'Cukrovinky'),
    (50::bigint, 10::numeric, '254', 'Dr.Ensa Kukurice prazena solena s prichuti barbecue 60g', 'Cukrovinky'),
    (61::bigint, 7::numeric, '39', 'Haribo Bonbony goldbaren zele medvidci 100g', 'Cukrovinky'),
    (62::bigint, 8::numeric, '38', 'Havlik Tycinky original 90g', 'Cukrovinky'),
    (81::bigint, 8::numeric, '28', 'Kinder Bueno Oplatky 43g', 'Cukrovinky'),
    (83::bigint, 4::numeric, '27', 'Kit Kat 4 Fingers Tycinka 41,5g', 'Cukrovinky'),
    (84::bigint, 7::numeric, '165', 'Knoppers Oplatka 25g', 'Cukrovinky'),
    (92::bigint, 14::numeric, '40', 'Margot Tycinka 80g', 'Cukrovinky'),
    (93::bigint, 9::numeric, '36', 'Mila Oplatky 50g', 'Cukrovinky'),
    (94::bigint, 3::numeric, '31', 'Minonky Oplatky oriskove 50g', 'Cukrovinky'),
    (111::bigint, 1::numeric, '162', 'Ovesna svacinka Susenka s brusnicemi 36g', 'Cukrovinky'),
    (123::bigint, 14::numeric, '35', 'Sedita Horalky Oplatky arasidove 50g', 'Cukrovinky'),
    (124::bigint, 3::numeric, '213', 'Skittles Bonbony ovocne zvykaci 38g', 'Cukrovinky'),
    (125::bigint, 2::numeric, '24', 'Snickers Tycinka cokoladova 50g', 'Cukrovinky'),
    (127::bigint, 5::numeric, '139', 'Straznicke bramburky Chipsy cesnekove 60g', 'Cukrovinky'),
    (133::bigint, 1::numeric, '25', 'Twix Tycinka 50g', 'Cukrovinky'),
    (137::bigint, 2::numeric, '144', 'Yoohoo! Vafle kakao+liskovy orisek 50', 'Cukrovinky'),
    (42::bigint, 3::numeric, '43', 'Cukr Vending 1,5 kg', 'Ingredient'),
    (78::bigint, 400::numeric, '45', 'Kelimek 180 ml (100 ks)', 'Ingredient'),
    (80::bigint, 300::numeric, '53', 'Kelimek 300 ml (50 ks)', 'Ingredient'),
    (103::bigint, 2::numeric, '197', 'oVe BASE WITH PISTACHIO FLAVOUR 1000g', 'Ingredient'),
    (104::bigint, 4::numeric, '48', 'oVe COFFEE CREAMER WHITE 1 kg', 'Ingredient'),
    (105::bigint, 3::numeric, '51', 'oVe DRINK WITH CHOC WHITE FLAVOUR 1000g', 'Ingredient'),
    (106::bigint, 3::numeric, '47', 'oVe DRINK WITH COCOA ZETA 1 kg', 'Ingredient'),
    (107::bigint, 3::numeric, '5', 'oVe Elite 1 kg zrnková', 'Ingredient'),
    (108::bigint, 1::numeric, '44', 'oVe FD COFFEE SOPHIA 500g', 'Ingredient'),
    (110::bigint, 6::numeric, '46', 'oVe SMART CAPPUCCINO IRISH CREAM FLAVOUR 1000g', 'Ingredient'),
    (20::bigint, 3::numeric, '207', 'Bad Brambacher 0,5l ruzne druhy', 'Vody'),
    (27::bigint, 10::numeric, '2', 'Big Shock! Energeticky napoj Exotic 500ml plech', 'Vody'),
    (38::bigint, 1::numeric, '41', 'Capri-Sun Multivitamin ovocny napoj 200ml', 'Vody'),
    (51::bigint, 4::numeric, '200', 'DrWitt min. voda 0,55l ruzne druhy', 'Vody'),
    (63::bigint, 13::numeric, '4', 'Hell Energeticky napoj classic 250ml plech', 'Vody'),
    (66::bigint, 3::numeric, '156', 'Ice Coffee Ledova kava 350ml', 'Vody'),
    (85::bigint, 11::numeric, '70', 'Kofola Original 500ml PET', 'Vody'),
    (99::bigint, 4::numeric, '67', 'Nestea 0,5l ruzne druhy', 'Vody'),
    (112::bigint, 1::numeric, '157', 'Pepsi 0,33l plech', 'Vody'),
    (113::bigint, 10::numeric, '71', 'Pepsi Cola 500ml PET', 'Vody'),
    (118::bigint, 9::numeric, '163', 'QXE Energeticky napoj 250ml plech', 'Vody'),
    (121::bigint, 5::numeric, '6', 'Relax Limonada lici 330ml plech', 'Vody'),
    (126::bigint, 5::numeric, '187', 'Staropramen Cool citron nealkoholicky napoj z piva 500ml', 'Vody'),
    (139::bigint, 8::numeric, '209', 'ZON 500ml PET ruzne druhy', 'Vody')
),
deduplicated as (
  select fl.*
  from filled_lines fl
  where not exists (
    select 1
    from public.stock_movements_v13 sm
    where sm.reference_type = 'manual_transfer'
      and sm.reference_id = 'filled-products-5AP9000-2026-05-26-reimport'
      and sm.product_id = fl.product_id
  )
)
insert into public.stock_movements_v13 (
  product_id,
  batch_id,
  from_stock_location_id,
  to_stock_location_id,
  movement_type,
  quantity_base_units,
  unit_price,
  reference_type,
  reference_id,
  note
)
select
  product_id,
  null,
  4,
  5,
  'fill_machine',
  quantity_base_units,
  null,
  'manual_transfer',
  'filled-products-5AP9000-2026-05-26-reimport',
  'Reimport Filled Products 5AP9000 2026-05-26; stavy uz byly propsane, proto se neduplikuji. Zdroj: ' || source_type || ' / ' || source_code || ' / ' || source_name
from deduplicated;

commit;
