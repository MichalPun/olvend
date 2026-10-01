-- Připraví odstavený Luce Snack X EV 23 na nový plánogram z 1. 10. 2026.
-- Rozložení: 51 voleb, z toho horní řada obsahuje tři dvojité a tři jednoduché spirály.
-- Stroj musí být před spuštěním bez lokality a neaktivní.
-- Existující zásoba ani expirace se nemažou: změněné obsazené pozice se připraví jako úplná výměna.

begin;

insert into public.products (
  sku, name, ean, product_category, usage_type, base_unit, vat_rate,
  purchase_price, sale_price, expiry_tracking_mode, expiry_warning_days,
  requires_batch_tracking, can_be_sold_directly, active, note
)
values
  ('SIMPLY-DEBRECIN', 'Simply Debrecín', null, 'food_ready', 'direct_sale', 'ks', 12, null, 44, 'use_by', 3, true, true, true, 'Nový sortiment pro Luce Snack X EV 23 podle plánogramu 1. 10. 2026; nákupní údaje doplnit po první dodávce.'),
  ('SIMPLY-PORIZEK', 'Simply Pořízek', null, 'food_ready', 'direct_sale', 'ks', 12, null, 44, 'use_by', 3, true, true, true, 'Nový sortiment pro Luce Snack X EV 23 podle plánogramu 1. 10. 2026; nákupní údaje doplnit po první dodávce.'),
  ('SIMPLY-MLSKA', 'Simply Mlska', null, 'food_ready', 'direct_sale', 'ks', 12, null, 44, 'use_by', 3, true, true, true, 'Nový sortiment pro Luce Snack X EV 23 podle plánogramu 1. 10. 2026; nákupní údaje doplnit po první dodávce.'),
  ('HAME-KURECI-STRIPS', 'Hamé Kuřecí Strips', null, 'food_ready', 'direct_sale', 'ks', 12, null, 50, 'best_before', 14, true, true, true, 'Nový sortiment pro Luce Snack X EV 23 podle plánogramu 1. 10. 2026; nákupní údaje doplnit po první dodávce.'),
  ('SIMPLY-SVACINKA', 'Simply Svačinka', null, 'food_ready', 'direct_sale', 'ks', 12, null, 44, 'use_by', 3, true, true, true, 'Nový sortiment pro Luce Snack X EV 23 podle plánogramu 1. 10. 2026; nákupní údaje doplnit po první dodávce.'),
  ('VA-ARASIDY-PRAZ-SOL-100', 'VA Arašídy pražené solené 100g', null, 'snack_ready', 'direct_sale', 'ks', 12, null, 14, 'best_before', 30, false, true, true, 'Nový sortiment pro Luce Snack X EV 23 podle plánogramu 1. 10. 2026; nákupní údaje doplnit po první dodávce.'),
  ('BERTYCKY-TVARUZKOVE', 'Bertýčky tvarůžkové', null, 'snack_ready', 'direct_sale', 'ks', 12, null, 21, 'best_before', 14, false, true, true, 'Nový sortiment pro Luce Snack X EV 23 podle plánogramu 1. 10. 2026; nákupní údaje doplnit po první dodávce.')
on conflict (sku) do update set
  name = excluded.name,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  vat_rate = excluded.vat_rate,
  sale_price = excluded.sale_price,
  expiry_tracking_mode = excluded.expiry_tracking_mode,
  expiry_warning_days = excluded.expiry_warning_days,
  requires_batch_tracking = excluded.requires_batch_tracking,
  can_be_sold_directly = true,
  active = true,
  note = excluded.note,
  updated_at = now();

do $$
declare
  v_machine_id bigint;
  v_machine_active boolean;
  v_location_id bigint;
  v_inserted integer;
  v_active_slots integer;
  v_units_before numeric;
  v_units_after numeric;
begin
  select id, active, location_id
  into strict v_machine_id, v_machine_active, v_location_id
  from public.machines
  where id = 19
    and evidence_number = 23
    and name = 'Luce Snack X'
    and brand = 'Rheavendors'
    and status = 'removed';

  if v_machine_active is true or v_location_id is not null then
    raise exception 'EV 23 musí být před přestavbou neaktivní a bez lokality.';
  end if;

  select coalesce(sum(current_units), 0)
  into v_units_before
  from public.machine_planogram_slots
  where machine_id = v_machine_id;

  insert into public.machine_planogram_slots as current_slot (
    machine_id, slot_code, product_name, product_sku,
    price_czk, customer_price_czk, dex_price_czk,
    current_units, last_units, capacity_units, desired_units, target_units,
    fill_percent, expiry_date, telemetry_key, sort_order, active,
    product_family, product_variant, replenishment_mode,
    planned_product_name, planned_product_sku, planned_price_czk,
    pending_product_id, pending_product_sku, pending_product_name,
    pending_price_czk, pending_change_effective_date, pending_change_note,
    pending_change_mode, changeover_old_units, changeover_new_units,
    changeover_started_at, substitution_policy, allowed_substitutes,
    operator_instruction, subsidy_amount_czk, subsidy_payer,
    subsidy_billing_enabled, subsidy_note, settlement_type,
    settlement_amount_czk, settlement_partner, settlement_billing_enabled,
    settlement_note, note
  )
  select
    v_machine_id, d.slot_code, product.name, product.sku,
    d.price_czk, d.price_czk, d.price_czk,
    0, 0, d.capacity_units, d.capacity_units, d.capacity_units,
    0, null, d.slot_code, d.sort_order, true,
    d.product_family, d.product_variant, 'fixed_target',
    null, null, null,
    null, null, null,
    null, null, null,
    'sell_through', null, null,
    null, d.substitution_policy, d.allowed_substitutes,
    d.operator_instruction, 0, null,
    false, null, 'none',
    0, null, false,
    null, 'Cílový 51pozicový plánogram EV 23 podle podkladu 1. 10. 2026. Existující zásoba a expirace zůstávají zachované do fyzického osazení.'
  from (values
    ('1',  '71',  27::numeric,  6,  0, 'Pepsi', 'Cola', 'exact', null::text, null::text),
    ('2',  '67',  23::numeric,  6,  1, 'Nestea', 'Různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně SKU 67; lze použít Lemon SKU 275.'),
    ('3',  '70',  26::numeric,  6,  2, 'Kofola', 'Original', 'exact', null, null),
    ('4',  '209', 20::numeric,  6,  3, 'ZON', 'Různé druhy', 'exact', null, null),
    ('5',  '156', 24::numeric,  6,  4, 'Ice Coffee', null, 'exact', null, null),
    ('6',  '2',   32::numeric,  6,  5, 'Big Shock!', 'Exotic', 'exact', null, null),
    ('7',  '187', 22::numeric,  6,  6, 'Staropramen Cool', 'Citron', 'exact', null, null),
    ('8',  '13',  15::numeric,  6,  7, 'Hanácká kyselka', null, 'exact', null, null),
    ('9',  '71',  27::numeric,  6,  8, 'Pepsi', 'Cola', 'exact', null, null),
    ('12', '163', 19::numeric,  6,  9, 'QXE', null, 'exact', null, null),
    ('13', '163', 19::numeric,  6, 10, 'QXE', null, 'exact', null, null),
    ('14', '4',   27::numeric,  6, 11, 'Hell', 'Classic', 'exact', null, null),
    ('15', '190', 48::numeric,  6, 12, 'Red Bull', null, 'exact', null, null),
    ('16', '6',   25::numeric,  6, 13, 'Relax', 'Liči', 'exact', null, null),
    ('17', '41',  15::numeric,  6, 14, 'Capri-Sun', 'Multivitamin', 'exact', null, null),
    ('18', '259', 25::numeric,  6, 15, 'Hello', 'Perlivá', 'exact', null, null),
    ('19', '157', 19::numeric,  6, 16, 'Pepsi', '0,33 l', 'exact', null, null),
    ('20', '163', 19::numeric,  6, 17, 'QXE', null, 'exact', null, null),
    ('23', 'SIMPLY-DEBRECIN', 44::numeric, 5, 18, 'Simply', 'Debrecín', 'exact', null, 'Nový čerstvý sortiment; při vložení eviduj expiraci.'),
    ('24', 'SIMPLY-PORIZEK',  44::numeric, 5, 19, 'Simply', 'Pořízek', 'exact', null, 'Nový čerstvý sortiment; při vložení eviduj expiraci.'),
    ('25', 'SIMPLY-MLSKA',    44::numeric, 5, 20, 'Simply', 'Mlska', 'exact', null, 'Nový čerstvý sortiment; při vložení eviduj expiraci.'),
    ('26', '38',  14::numeric, 10, 21, 'Havlík', 'Originál', 'exact', null, null),
    ('27', '210', 21::numeric,  6, 22, 'Doritos', null, 'exact', null, null),
    ('28', '277', 24::numeric,  6, 23, 'DrWitt', 'Různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277.'),
    ('29', '207', 24::numeric,  6, 24, 'Bad Brambacher', 'Různé druhy', 'exact', null, null),
    ('30', 'HAME-KURECI-STRIPS', 50::numeric, 5, 25, 'Hamé', 'Kuřecí Strips', 'exact', null, 'Při vložení eviduj expiraci.'),
    ('31', 'SIMPLY-SVACINKA', 44::numeric, 5, 26, 'Simply', 'Svačinka', 'exact', null, 'Nový čerstvý sortiment; při vložení eviduj expiraci.'),
    ('34', '36',  21::numeric, 15, 27, 'Mila', null, 'exact', null, null),
    ('35', '35',  17::numeric, 15, 28, 'Sedita Horalky', 'Arašídové', 'exact', null, null),
    ('36', '33',   9::numeric, 15, 29, 'Attack', 'Lískooříšková', 'exact', null, null),
    ('37', '24',  22::numeric, 15, 30, 'Snickers', null, 'exact', null, null),
    ('38', '28',  28::numeric, 15, 31, 'Kinder Bueno', null, 'exact', null, null),
    ('39', 'SOCO-BRIGIT-90', 25::numeric, 10, 32, 'Brigit', 'Kokos', 'exact', null, null),
    ('40', '208',  5::numeric, 10, 33, 'Alaska', 'Různé druhy', 'exact', null, null),
    ('41', '143',  9::numeric, 10, 34, 'Today Donut', 'Kakaová náplň', 'exact', null, null),
    ('42', '142', 12::numeric, 10, 35, 'Racio Free Style', 'Rajče a bazalka', 'exact', null, null),
    ('45', 'SOCO-PROTEIN-VANILKA-45', 18::numeric, 10, 36, 'Proteinový suk', 'Vanilka / čokoláda', 'approved_list', 'SKU SOCO-PROTEIN-COKOLADA-45', 'Přednostně vanilka; lze použít čokoládu.'),
    ('46', 'SOCO-EXTASY-PEANUT-45', 21::numeric, 10, 37, 'Extasy', 'Peanut / Coconut', 'approved_list', 'SKU SOCO-EXTASY-COCONUT-45', 'Přednostně Peanut; lze použít Coconut.'),
    ('47', '165', 10::numeric, 10, 38, 'Knoppers', null, 'exact', null, null),
    ('48', '254', 13::numeric, 10, 39, 'Dr.Ensa', 'Kukuřice', 'exact', null, null),
    ('49', 'SOCO-RAWBAR-PEANUTS', 19::numeric, 10, 40, 'RawBar', '3 příchutě', 'approved_list', 'SKU SOCO-RAWBAR-CRANBERRY; SKU SOCO-RAWBAR-APPLE', 'Lze použít tři schválené příchutě RawBar.'),
    ('50', 'SOCO-BONGO-ORIGINAL-40', 16::numeric, 10, 41, 'Bongo', '3 příchutě', 'approved_list', 'SKU SOCO-BONGO-BANAN-40; SKU SOCO-BONGO-MATA-40', 'Lze použít tři schválené příchutě Bongo.'),
    ('51', '261', 18::numeric, 10, 42, 'Corny Big', 'Banán', 'exact', null, null),
    ('52', 'VA-ARASIDY-PRAZ-SOL-100', 14::numeric, 10, 43, 'VA', 'Arašídy pražené solené', 'exact', null, null),
    ('53', '211', 17::numeric, 10, 44, 'Nový věk', 'Chlebíčky rýžové', 'exact', null, null),
    ('57', '39',  24::numeric, 10, 45, 'Haribo', 'Goldbären', 'exact', null, null),
    ('59', '42',  15::numeric, 10, 46, '7days', 'Lískový oříšek', 'exact', null, null),
    ('61', 'BERTYCKY-TVARUZKOVE', 21::numeric, 10, 47, 'Bertýčky', 'Tvarůžkové', 'exact', null, null),
    ('62', '144', 18::numeric,  6, 48, 'Yoohoo!', 'Kakao+lískový oříšek', 'exact', null, null),
    ('63', '20',  25::numeric, 10, 49, 'Dupetky', 'Hořčice, med a cibulka', 'exact', null, null),
    ('64', '162', 13::numeric,  8, 50, 'Ovesná svačinka', 'Brusnice', 'exact', null, null)
  ) as d(
    slot_code, sku, price_czk, capacity_units, sort_order,
    product_family, product_variant, substitution_policy,
    allowed_substitutes, operator_instruction
  )
  join public.products product
    on product.sku = d.sku
   and product.active is true
  on conflict (machine_id, slot_code) do update set
    product_name = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then current_slot.product_name
      else excluded.product_name
    end,
    product_sku = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then current_slot.product_sku
      else excluded.product_sku
    end,
    price_czk = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then current_slot.price_czk
      else excluded.price_czk
    end,
    customer_price_czk = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then current_slot.customer_price_czk
      else excluded.customer_price_czk
    end,
    dex_price_czk = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then current_slot.dex_price_czk
      else excluded.dex_price_czk
    end,
    current_units = current_slot.current_units,
    last_units = current_slot.last_units,
    capacity_units = case
      when coalesce(current_slot.current_units, 0) > 0 then current_slot.capacity_units
      else excluded.capacity_units
    end,
    desired_units = case
      when coalesce(current_slot.current_units, 0) > 0 then current_slot.desired_units
      else excluded.desired_units
    end,
    target_units = case
      when coalesce(current_slot.current_units, 0) > 0 then current_slot.target_units
      else excluded.target_units
    end,
    fill_percent = case
      when coalesce(current_slot.current_units, 0) > 0 then current_slot.fill_percent
      else excluded.fill_percent
    end,
    expiry_date = case
      when coalesce(current_slot.current_units, 0) > 0 then current_slot.expiry_date
      else null
    end,
    telemetry_key = excluded.telemetry_key,
    sort_order = excluded.sort_order,
    active = true,
    product_family = case
      when coalesce(current_slot.current_units, 0) > 0
       and current_slot.product_sku is distinct from excluded.product_sku
        then current_slot.product_family
      else excluded.product_family
    end,
    product_variant = case
      when coalesce(current_slot.current_units, 0) > 0
       and current_slot.product_sku is distinct from excluded.product_sku
        then current_slot.product_variant
      else excluded.product_variant
    end,
    replenishment_mode = excluded.replenishment_mode,
    planned_product_name = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then excluded.product_name
      else null
    end,
    planned_product_sku = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then excluded.product_sku
      else null
    end,
    planned_price_czk = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then excluded.price_czk
      else null
    end,
    pending_product_id = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then (select id from public.products where sku = excluded.product_sku)
      else null
    end,
    pending_product_sku = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then excluded.product_sku
      else null
    end,
    pending_product_name = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then excluded.product_name
      else null
    end,
    pending_price_czk = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then excluded.price_czk
      else null
    end,
    pending_change_effective_date = case
      when coalesce(current_slot.current_units, 0) > 0
       and (
         current_slot.product_sku is distinct from excluded.product_sku
         or coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
       ) then current_date
      else null
    end,
    pending_change_note = case
      when coalesce(current_slot.current_units, 0) > 0
       and current_slot.product_sku is distinct from excluded.product_sku
        then 'Nový plánogram EV 23: při fyzickém osazení vrať původní kusy do vozidla a vlož cílový produkt.'
      when coalesce(current_slot.current_units, 0) > 0
       and coalesce(current_slot.customer_price_czk, current_slot.price_czk, current_slot.dex_price_czk)
            is distinct from excluded.price_czk
        then 'Nový plánogram EV 23: při fyzickém osazení změň cenu na automatu a potvrď ji v aplikaci.'
      else null
    end,
    pending_change_mode = case
      when coalesce(current_slot.current_units, 0) > 0
       and current_slot.product_sku is distinct from excluded.product_sku
        then 'full_swap'
      else 'sell_through'
    end,
    changeover_old_units = case
      when coalesce(current_slot.current_units, 0) > 0
       and current_slot.product_sku is distinct from excluded.product_sku
        then current_slot.current_units
      else null
    end,
    changeover_new_units = case
      when coalesce(current_slot.current_units, 0) > 0
       and current_slot.product_sku is distinct from excluded.product_sku
        then 0
      else null
    end,
    changeover_started_at = null,
    substitution_policy = excluded.substitution_policy,
    allowed_substitutes = excluded.allowed_substitutes,
    operator_instruction = excluded.operator_instruction,
    subsidy_amount_czk = 0,
    subsidy_payer = null,
    subsidy_billing_enabled = false,
    subsidy_note = null,
    settlement_type = 'none',
    settlement_amount_czk = 0,
    settlement_partner = null,
    settlement_billing_enabled = false,
    settlement_note = null,
    note = excluded.note,
    updated_at = now();

  get diagnostics v_inserted = row_count;
  if v_inserted <> 51 then
    raise exception 'EV 23: očekáváno 51 vložených nebo upravených pozic, získáno %.', v_inserted;
  end if;

  select count(*) into v_active_slots
  from public.machine_planogram_slots
  where machine_id = v_machine_id
    and active is true;

  if v_active_slots <> 51 then
    raise exception 'EV 23: očekáváno 51 aktivních pozic, nalezeno %.', v_active_slots;
  end if;

  select coalesce(sum(current_units), 0)
  into v_units_after
  from public.machine_planogram_slots
  where machine_id = v_machine_id;

  if v_units_after <> v_units_before then
    raise exception 'EV 23: migrace změnila evidovaný počet kusů (% → %), proto byla vrácena zpět.', v_units_before, v_units_after;
  end if;

  update public.machines
  set note = concat_ws(
        ' · ',
        nullif(trim(note), ''),
        '1. 10. 2026: připraven bezpečný 51pozicový plánogram podle schváleného podkladu; existující zásoba a expirace zachovány, změny se dokončí při fyzickém osazení.'
      )
  where id = v_machine_id;
end;
$$;

commit;

notify pgrst, 'reload schema';
