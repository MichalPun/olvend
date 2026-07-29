-- Aktuální planogram EV 5 / Europa Snack / TEXTILOMANIE, Blučina.
-- Zdroj: Planogram [5] Europa Snack-2026-07-29.xlsx.
-- Expirace se podle pokynu uživatele z Excelu nepřebírají a jsou vyčištěné.
-- Obecné varianty:
--   slot 13 Nestea -> primární Peach SKU 67, povolená náhrada Lemon SKU 275
--   slot 28 DrWitt -> primární mango+citron SKU 277, náhrady citrus 276 a liči+hruška 200
--   slot 29 Bad Brambacher -> Malina SKU 207

begin;

update public.machine_planogram_slots
set active = false
where machine_id = 3;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  3,
  d.slot_code,
  p.name,
  p.sku,
  d.price_czk,
  d.current_units,
  d.last_units,
  d.capacity_units,
  d.dex_price_czk,
  d.desired_units,
  null::date,
  d.slot_code,
  d.sort_order,
  true,
  d.product_family,
  d.product_variant,
  d.planned_product_name,
  d.product_sku,
  d.price_czk,
  d.substitution_policy,
  d.allowed_substitutes,
  d.operator_instruction,
  'Aktualizováno z planogramu EV 5 dne 2026-07-29; expirace záměrně nepřevzata.'
from (values
  ('1',  19::numeric,  2,  6,  6, 19::numeric, 4, '163',  0, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null),
  ('2',  19::numeric,  2,  6,  6, 19::numeric, 4, '163',  1, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null),
  ('3',  27::numeric,  5,  6,  6, 27::numeric, 1, '4',     2, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null),
  ('4',  48::numeric,  5,  6,  6, 48::numeric, 1, '190',   3, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null),
  ('5',  25::numeric,  6,  6,  6, 25::numeric, 0, '6',     4, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null),
  ('6',  15::numeric,  4,  6,  6, 15::numeric, 2, '41',    5, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null),
  ('7',  25::numeric,  5,  6,  6, 25::numeric, 1, '259',   6, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null),
  ('12', 33::numeric,  3,  6,  6, 33::numeric, 3, '71',   7, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null),
  ('13', 30::numeric,  4,  6,  6, 30::numeric, 2, '67',   8, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.'),
  ('14', 32::numeric,  6,  6,  6, 32::numeric, 0, '70',   9, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null),
  ('15', 24::numeric,  1,  6,  6, 24::numeric, 5, '209', 10, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null),
  ('16', 29::numeric,  5,  6,  6, 29::numeric, 1, '156', 11, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null),
  ('17', 39::numeric,  4,  6,  6, 39::numeric, 2, '2',   12, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null),
  ('18', 28::numeric,  6,  6,  6, 28::numeric, 0, '187', 13, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null),
  ('23', 55::numeric,  0,  4,  5, 55::numeric, 5, '79',  14, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, null),
  ('24', 55::numeric,  1,  4,  5, 55::numeric, 4, '154', 15, 'ATM', 'Trhané vepřové', 'ATM Trhané Vepřové', 'exact', null, null),
  ('25', 55::numeric,  4,  4,  5, 55::numeric, 1, '155', 16, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, null),
  ('26', 19::numeric,  4,  6,  6, 19::numeric, 2, '38',  17, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null),
  ('27', 25::numeric,  5,  5,  5, 25::numeric, 0, '210', 18, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null),
  ('28', 29::numeric,  4,  6,  6, 29::numeric, 2, '277', 19, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200.'),
  ('29', 29::numeric,  6,  6,  6, 29::numeric, 0, '207', 20, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null),
  ('34', 26::numeric, 14, 15, 15, 26::numeric, 1, '36',  21, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null),
  ('35', 20::numeric,  9, 10, 10, 20::numeric, 1, '35',  22, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null),
  ('36', 11::numeric, 14, 14, 15, 11::numeric, 1, '33',  23, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null),
  ('37', 26::numeric, 11, 13, 15, 26::numeric, 4, '24',  24, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null),
  ('38', 30::numeric, 10, 10, 10, 30::numeric, 0, '28',  25, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null),
  ('39', 25::numeric, 10, 10, 10, 25::numeric, 0, '40',  26, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null),
  ('40',  8::numeric, 15, 15, 15,  8::numeric, 0, '208', 27, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null),
  ('45', 26::numeric, 14, 14, 15, 26::numeric, 1, '25',  28, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null),
  ('46', 24::numeric, 15, 15, 15, 24::numeric, 0, '27',  29, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null),
  ('47', 11::numeric, 14, 17, 20, 11::numeric, 6, '165', 30, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null),
  ('48', 14::numeric, 14, 15, 15, 14::numeric, 1, '254', 31, 'Dr.Ensa', 'Barbecue', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null),
  ('49', 24::numeric, 20, 20, 20, 24::numeric, 0, '31',  32, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null),
  ('50', 30::numeric, 15, 15, 15, 30::numeric, 0, '26',  33, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null),
  ('51', 21::numeric,  9, 10, 10, 21::numeric, 1, '261', 34, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null),
  ('57', 27::numeric, 10, 10, 10, 27::numeric, 0, '39',  35, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null),
  ('59', 20::numeric,  0,  0,  2, 20::numeric, 2, '211', 36, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, null),
  ('61', 19::numeric,  2,  5,  5, 19::numeric, 3, '42',  37, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null),
  ('62', 21::numeric,  9, 10, 10, 21::numeric, 1, '144', 38, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null)
) as d(
  slot_code, price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, product_sku, sort_order,
  product_family, product_variant, planned_product_name,
  substitution_policy, allowed_substitutes, operator_instruction
)
join public.products p on p.sku = d.product_sku and p.active = true
on conflict (machine_id, slot_code) do update
set
  product_name = excluded.product_name,
  product_sku = excluded.product_sku,
  price_czk = excluded.price_czk,
  current_units = excluded.current_units,
  last_units = excluded.last_units,
  capacity_units = excluded.capacity_units,
  fill_percent = case
    when excluded.capacity_units > 0
      then round((excluded.current_units::numeric / excluded.capacity_units::numeric) * 100, 2)
    else 0
  end,
  dex_price_czk = excluded.dex_price_czk,
  desired_units = excluded.desired_units,
  expiry_date = null,
  telemetry_key = excluded.telemetry_key,
  sort_order = excluded.sort_order,
  active = true,
  product_family = excluded.product_family,
  product_variant = excluded.product_variant,
  planned_product_name = excluded.planned_product_name,
  planned_product_sku = excluded.planned_product_sku,
  planned_price_czk = excluded.planned_price_czk,
  substitution_policy = excluded.substitution_policy,
  allowed_substitutes = excluded.allowed_substitutes,
  operator_instruction = excluded.operator_instruction,
  note = excluded.note,
  updated_at = now();

commit;
