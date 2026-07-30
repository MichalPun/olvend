-- Aktuální planogram EV 3 / Europa Snack / Břeclav - Domov seniorů.
-- Zdroj: Planogram [3] Europa Snack-2026-07-30.xlsx.
-- TID 582177; expirace se přebírají přesně ze zdrojového souboru.
-- Obecné varianty:
--   slot 13 Nestea -> primární Peach SKU 67, povolená náhrada Lemon SKU 275
--   slot 28 DrWitt -> primární mango+citron SKU 277, náhrady citrus 276 a liči+hruška 200
--   slot 29 Bad Brambacher -> Malina SKU 207

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 2
      and qr_token = 'vendsoft-3'
      and location_id = 18
  ) then
    raise exception 'EV 3 / Břeclav - Domov seniorů nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (2, 'IMA', '582177', true, 'TID 582177 pro EV 3 / Europa Snack / Břeclav - Domov seniorů.'),
  (2, 'GP',  '582177', true, 'TID 582177 pro EV 3 / Europa Snack / Břeclav - Domov seniorů.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 2;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  2,
  d.slot_code,
  p.name,
  p.sku,
  d.price_czk,
  d.current_units,
  d.last_units,
  d.capacity_units,
  d.dex_price_czk,
  d.desired_units,
  least(d.capacity_units, d.current_units + d.desired_units),
  d.expiry_date,
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
  'Planogram EV 3 / Břeclav - Domov seniorů / TID 582177 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  19::numeric,  5,  6,  6, 19::numeric, 1, '163',  0, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('2',  19::numeric,  6,  6,  6, 19::numeric, 0, '163',  1, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('3',  27::numeric,  4,  6,  6, 27::numeric, 2, '4',    2, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('4',  48::numeric,  6,  6,  6, 48::numeric, 0, '190',  3, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('5',  25::numeric,  5,  6,  6, 25::numeric, 1, '6',    4, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('6',  15::numeric,  5,  6,  6, 15::numeric, 1, '41',   5, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('7',  23::numeric,  5,  6,  6, 23::numeric, 1, '157',  6, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('12', 33::numeric,  4,  6,  6, 33::numeric, 2, '71',   7, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('13', 30::numeric,  3,  6,  6, 30::numeric, 3, '67',   8, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('14', 32::numeric,  0,  6,  6, 32::numeric, 6, '70',   9, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('15', 24::numeric,  0,  6,  6, 24::numeric, 6, '209', 10, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('16', 29::numeric,  4,  6,  6, 29::numeric, 2, '156', 11, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('17', 39::numeric,  5,  5,  5, 39::numeric, 0, '2',   12, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('18', 28::numeric,  3,  5,  5, 28::numeric, 2, '187', 13, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('23', 55::numeric,  3,  3,  5, 55::numeric, 2, '79',  14, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, null, '2026-08-04'::date),
  ('24', 55::numeric,  3,  3,  4, 55::numeric, 1, '17',  15, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, null, '2026-08-03'::date),
  ('25', 55::numeric,  4,  4,  4, 55::numeric, 0, '155', 16, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, null, '2026-08-04'::date),
  ('26', 19::numeric,  0,  1,  5, 19::numeric, 5, '38',  17, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null, null::date),
  ('27', 25::numeric,  5,  5,  5, 25::numeric, 0, '210', 18, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, null::date),
  ('28', 29::numeric,  6,  6,  6, 29::numeric, 0, '277', 19, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200.', null::date),
  ('29', 29::numeric,  5,  6,  6, 29::numeric, 1, '207', 20, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('34', 26::numeric,  4,  5,  5, 26::numeric, 1, '36',  21, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('35', 20::numeric, 13, 15, 15, 20::numeric, 2, '35',  22, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('36', 11::numeric, 18, 20, 20, 11::numeric, 2, '33',  23, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('37', 26::numeric, 15, 15, 15, 26::numeric, 0, '24',  24, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('38', 30::numeric, 18, 20, 20, 30::numeric, 2, '28',  25, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('39', 25::numeric, 15, 15, 15, 25::numeric, 0, '40',  26, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('40',  8::numeric, 11, 15, 15,  8::numeric, 4, '208', 27, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('45', 26::numeric, 15, 15, 15, 26::numeric, 0, '25',  28, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('46', 24::numeric, 14, 15, 15, 24::numeric, 1, '27',  29, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('47', 11::numeric, 15, 15, 15, 11::numeric, 0, '165', 30, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('48', 14::numeric, 14, 15, 15, 14::numeric, 1, '254', 31, 'Dr.Ensa', 'Barbecue', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('49', 24::numeric, 15, 15, 15, 24::numeric, 0, '31',  32, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('50', 30::numeric, 20, 20, 20, 30::numeric, 0, '26',  33, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('51', 21::numeric,  0,  5, 15, 21::numeric,15, '213', 34, 'Skittles', 'Ovocné', 'Skittles Bonbóny ovocné žvýkací 38g', 'exact', null, null, null::date),
  ('57', 27::numeric,  4,  8,  8, 27::numeric, 4, '39',  35, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('59', 20::numeric,  9, 10, 10, 20::numeric, 1, '42',  36, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('61', 28::numeric,  1,  1, 10, 28::numeric, 9, '20',  37, 'Dupetky', 'Hořčice+med+cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('62', 20::numeric,  6,  8,  8, 21::numeric, 2, '144', 38, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date)
) as d(
  slot_code, price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, product_sku, sort_order,
  product_family, product_variant, planned_product_name,
  substitution_policy, allowed_substitutes, operator_instruction, expiry_date
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
  target_units = excluded.target_units,
  fill_percent = case
    when excluded.capacity_units > 0
      then round((excluded.current_units::numeric / excluded.capacity_units::numeric) * 100, 2)
    else 0
  end,
  dex_price_czk = excluded.dex_price_czk,
  desired_units = excluded.desired_units,
  expiry_date = excluded.expiry_date,
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

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.machine_planogram_slots
  where machine_id = 2 and active = true;

  if v_count <> 39 then
    raise exception 'EV 3: očekáváno 39 aktivních pozic, nalezeno %.', v_count;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
