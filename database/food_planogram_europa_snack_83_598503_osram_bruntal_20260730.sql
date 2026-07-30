-- Aktuální planogram EV 83 / Europa Snack Hala 13 / OSRAM Bruntál.
-- Zdroj: Planogram [83] Europa Snack Hala 13-2026-07-30.xlsx.
-- TID 598503; expirace se přebírají pouze tam, kde jsou uvedené ve zdroji.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 63
      and evidence_number = 83
      and qr_token = 'vendsoft-83'
      and location_id = 16
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 83 / Europa Snack Hala 13 / OSRAM Bruntál nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  name = 'Europa Snack Hala 13',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Planogram 2026-07-30; EV 83; OSRAM Bruntál, hala 13. TID 598503.',
  updated_at = now()
where id = 63;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (63, 'IMA', '598503', true, 'TID 598503 pro EV 83 / Europa Snack Hala 13 / OSRAM Bruntál.'),
  (63, 'GP',  '598503', true, 'TID 598503 pro EV 83 / Europa Snack Hala 13 / OSRAM Bruntál.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 63;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  63,
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
  'Planogram EV 83 / OSRAM Bruntál / TID 598503 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  39::numeric, 5, 6,  6, 39::numeric, 1, '2',   0, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('2',  27::numeric, 6, 6,  6, 27::numeric, 0, '4',   1, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('3',  18::numeric, 6, 6,  6, 18::numeric, 0, '163', 2, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('4',  23::numeric, 6, 6,  6, 23::numeric, 0, '6',   3, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('5',  25::numeric, 6, 6,  6, 25::numeric, 0, '187', 4, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('6',  30::numeric, 6, 6,  6, 30::numeric, 0, '71',  5, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('12', 29::numeric, 3, 4,  4, 29::numeric, 1, '277', 6, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus SKU 276 nebo liči+hruška SKU 200.', null::date),
  ('13', 28::numeric, 6, 6,  6, 28::numeric, 0, '156', 7, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('14', 25::numeric, 6, 6,  6, 25::numeric, 0, '67',  8, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('15', 46::numeric, 5, 6,  6, 46::numeric, 1, '190', 9, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('16', 13::numeric, 6, 6,  6, 13::numeric, 0, '41', 10, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('17', 30::numeric, 5, 6,  6, 30::numeric, 1, '71', 11, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('23', 55::numeric, 4, 5,  5, 55::numeric, 1, '16', 12, 'ATM', 'Chlebíčkový Labužník', 'ATM - Chlebíčkový Labužník', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-07-30'::date),
  ('24', 22::numeric, 5, 5,  5, 22::numeric, 0, '211', 13, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-06-02'::date),
  ('25', 55::numeric, 2, 5,  5, 55::numeric, 3, '79', 14, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-07-30'::date),
  ('26', 18::numeric, 4, 5,  5, 18::numeric, 1, '38', 15, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null, null::date),
  ('27', 27::numeric, 5, 5,  5, 27::numeric, 0, '210', 16, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, null::date),
  ('28', 14::numeric, 4, 5,  5, 14::numeric, 1, '254', 17, 'Dr.Ensa', 'Kukuřice BBQ', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('29', 28::numeric, 5, 6,  6, 28::numeric, 1, '207', 18, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('34', 26::numeric, 5, 5,  5, 26::numeric, 0, '24', 19, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('35', 26::numeric, 5, 5,  5, 26::numeric, 0, '25', 20, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('36', 24::numeric, 4, 5,  5, 24::numeric, 1, '40', 21, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('37', 26::numeric, 9, 10, 10, 26::numeric, 1, '36', 22, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('38',  8::numeric, 3, 5,  5,  8::numeric, 2, '208', 23, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('39', 29::numeric, 5, 6,  6, 29::numeric, 1, '28', 24, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('40', 14::numeric, 8, 8, 10, 14::numeric, 2, '30', 25, 'Romanca', 'Kakaová náplň', 'Romanca Sušenka s kakaovou náplní 40g', 'exact', null, null, null::date),
  ('45', 20::numeric, 9, 10, 10, 20::numeric, 1, '35', 26, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('46', 11::numeric, 8, 10, 10, 11::numeric, 2, '33', 27, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('47', 23::numeric, 5, 5,  5, 23::numeric, 0, '31', 28, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('48', 28::numeric, 5, 5,  5, 28::numeric, 0, '26', 29, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('49', 22::numeric, 5, 5,  5, 22::numeric, 0, '27', 30, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('50', 21::numeric, 5, 5,  5, 21::numeric, 0, '261', 31, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('51', 11::numeric, 4, 4,  5, 11::numeric, 1, '165', 32, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('57', 27::numeric, 5, 5,  5, 27::numeric, 0, '20', 33, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('59', 26::numeric, 5, 5,  5, 26::numeric, 0, '39', 34, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('60', 13::numeric, 3, 5,  5, 13::numeric, 2, '142', 35, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date),
  ('61', 20::numeric, 5, 5,  5, 20::numeric, 0, '144', 36, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date)
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
  where machine_id = 63 and active = true;

  if v_count <> 37 then
    raise exception 'EV 83: očekáváno 37 aktivních pozic, nalezeno %.', v_count;
  end if;

  if v_desired <> 24 then
    raise exception 'EV 83: očekáváno celkem 24 ks k doplnění, nalezeno %.', v_desired;
  end if;

  if v_expiries <> 3 then
    raise exception 'EV 83: očekávány 3 evidované expirace, nalezeno %.', v_expiries;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 63
    and external_machine_id = '598503'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 83: očekávány 2 aktivní vazby TID 598503, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 63
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 83: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;

  select location_id into v_location_id
  from public.machines
  where id = 63;

  if v_location_id <> 16 then
    raise exception 'EV 83: automat není připojen k lokalitě OSRAM Bruntál (ID 16), ale k %.', v_location_id;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
