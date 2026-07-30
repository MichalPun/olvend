-- Aktuální planogram EV 100 / ARIA L EVO / RIGUM, s.r.o.
-- Zdroj: Planogram [100] ARIA L EVO-2026-07-30.xlsx.
-- TID 582176; expirace se přebírají pouze tam, kde jsou uvedené ve zdroji.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 80
      and evidence_number = 100
      and qr_token = 'vendsoft-100'
      and location_id = 23
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 100 / ARIA L EVO / RIGUM nebyl nalezen na očekávaném DB záznamu.';
  end if;

  if not exists (
    select 1
    from public.locations
    where id = 23
      and name = 'RIGUM, s.r.o.'
      and city = 'Dubňany'
      and active = true
  ) then
    raise exception 'Aktivní lokalita RIGUM, s.r.o. (ID 23) nebyla nalezena.';
  end if;
end
$$;

update public.machines
set
  name = 'ARIA L EVO',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Planogram 2026-07-30; EV 100; RIGUM, s.r.o., Dubňany. TID 582176.',
  updated_at = now()
where id = 80;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (80, 'IMA', '582176', true, 'TID 582176 pro EV 100 / ARIA L EVO / RIGUM.'),
  (80, 'GP',  '582176', true, 'TID 582176 pro EV 100 / ARIA L EVO / RIGUM.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 80;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  80,
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
  'Planogram EV 100 / RIGUM / TID 582176 aktualizován ze souboru 2026-07-30.'
from (values
  ('12', 27::numeric,  7,  7,  7, 27::numeric, 0, '39',   0, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('14', 20::numeric,  4,  7,  7, 20::numeric, 3, '42',   1, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('16', 19::numeric,  0,  0,  7, 19::numeric, 7, '139',  2, 'Strážnické brambůrky', 'Česnekové', 'Strážnické brambůrky Chipsy česnekové 60g', 'exact', null, null, null::date),
  ('18', 21::numeric,  7,  7,  7, 21::numeric, 0, '144',  3, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date),
  ('21', 26::numeric,  9, 10, 10, 26::numeric, 1, '25',   4, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('22', 24::numeric, 10, 10, 10, 24::numeric, 0, '27',   5, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('23', 11::numeric, 10, 10, 10, 11::numeric, 0, '165',  6, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('24', 14::numeric,  3,  7,  7, 14::numeric, 4, '254',  7, 'Dr.Ensa', 'Kukuřice BBQ', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('25', 24::numeric,  9, 10, 10, 24::numeric, 1, '31',   8, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('26', 30::numeric, 10, 10, 10, 30::numeric, 0, '26',   9, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('27', 21::numeric, 13, 13, 13, 21::numeric, 0, '261', 10, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('28', 30::numeric,  7,  7,  7, 18::numeric, 0, '279', 11, 'JoJo', 'Arašídy v cukru', 'Jojo Arašídky v cukru dražé 60g', 'exact', null, 'Cena v automatu 30 Kč; DEX cena ve zdroji 18 Kč.', null::date),
  ('31', 26::numeric, 13, 13, 13, 26::numeric, 0, '36',  12, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('32', 20::numeric,  9, 10, 10, 20::numeric, 1, '35',  13, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('33', 11::numeric, 13, 13, 13, 11::numeric, 0, '33',  14, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('34', 26::numeric, 13, 15, 15, 26::numeric, 2, '24',  15, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('35', 30::numeric, 15, 15, 15, 30::numeric, 0, '28',  16, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('36', 25::numeric, 10, 10, 10, 25::numeric, 0, '40',  17, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('37',  8::numeric,  9, 10, 10,  8::numeric, 1, '208', 18, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('38', 10::numeric,  8, 10, 10, 10::numeric, 2, '143', 19, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('41', 55::numeric,  4,  6,  6, 55::numeric, 2, '154', 20, 'ATM', 'Trhané vepřové', 'ATM Trhané Vepřové', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-04'::date),
  ('42', 55::numeric,  5,  6,  6, 55::numeric, 1, '155', 21, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-04'::date),
  ('43', 55::numeric,  2,  6,  6, 55::numeric, 4, '17',  22, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('44', 19::numeric,  4,  5,  6, 19::numeric, 2, '38',  23, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-02-05'::date),
  ('45', 25::numeric,  5,  5,  5, 25::numeric, 0, '210', 24, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-02-05'::date),
  ('46', 29::numeric,  5,  6,  6, 29::numeric, 1, '277', 25, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus SKU 276 nebo liči+hruška SKU 200.', null::date),
  ('47', 29::numeric,  3,  6,  6, 29::numeric, 3, '207', 26, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('48', 55::numeric,  4,  5,  6, 50::numeric, 2, '278', 27, 'ATM', 'Masové koule', 'ATM - Masové koule', 'exact', null, 'Cena v automatu 55 Kč; DEX cena ve zdroji 50 Kč. Zkontroluj expiraci zásoby; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('51', 33::numeric,  6,  6,  6, 33::numeric, 0, '71',  28, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('52', 30::numeric,  5,  6,  6, 30::numeric, 1, '67',  29, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('53', 32::numeric,  4,  6,  6, 32::numeric, 2, '70',  30, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('54', 24::numeric,  5,  5,  6, 24::numeric, 1, '209', 31, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('55', 29::numeric,  0,  5,  6, 29::numeric, 6, '156', 32, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('56', 39::numeric,  0,  6,  6, 39::numeric, 6, '2',   33, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('57', 28::numeric,  5,  6,  6, 28::numeric, 1, '187', 34, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('58', 20::numeric,  4,  6,  6, 20::numeric, 2, '13',  35, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null, null::date),
  ('61', 19::numeric,  2,  6,  6, 19::numeric, 4, '163', 36, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('62', 19::numeric,  4,  6,  6, 19::numeric, 2, '163', 37, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('63', 27::numeric,  4,  6,  6, 27::numeric, 2, '4',   38, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('64', 48::numeric,  4,  6,  6, 48::numeric, 2, '190', 39, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('65', 25::numeric,  6,  6,  6, 25::numeric, 0, '6',   40, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('66', 15::numeric,  6,  6,  6, 15::numeric, 0, '41',  41, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('67', 23::numeric,  4,  6,  6, 23::numeric, 2, '157', 42, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('68', 25::numeric,  1,  6,  6, 25::numeric, 5, '259', 43, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date)
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
  v_links integer;
  v_bad_capacity integer;
  v_location_id bigint;
  v_desired integer;
  v_expiries integer;
begin
  select count(*), coalesce(sum(desired_units), 0), count(expiry_date)
  into v_count, v_desired, v_expiries
  from public.machine_planogram_slots
  where machine_id = 80 and active = true;

  if v_count <> 44 then
    raise exception 'EV 100: očekáváno 44 aktivních pozic, nalezeno %.', v_count;
  end if;

  if v_desired <> 73 then
    raise exception 'EV 100: očekáváno celkem 73 ks k doplnění, nalezeno %.', v_desired;
  end if;

  if v_expiries <> 6 then
    raise exception 'EV 100: očekáváno 6 evidovaných expirací, nalezeno %.', v_expiries;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 80
    and external_machine_id = '582176'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 100: očekávány 2 aktivní vazby TID 582176, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 80
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 100: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;

  select location_id into v_location_id
  from public.machines
  where id = 80;

  if v_location_id <> 23 then
    raise exception 'EV 100: automat není připojen k lokalitě RIGUM (ID 23), ale k %.', v_location_id;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
