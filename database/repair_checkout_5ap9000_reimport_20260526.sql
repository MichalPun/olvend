begin;

with checkout_lines(product_id, quantity_base_units, source_name) as (
  values
    (92::bigint, 40::numeric, 'Margot Tycinka 80g'),
    (100::bigint, 20::numeric, 'Novy vek Chlebicky ryzove horko-kakaova poleva 60g'),
    (123::bigint, 56::numeric, 'Sedita Horalky Oplatky arasidove 50g'),
    (78::bigint, 20::numeric, 'Kelimek 180 ml (100 ks)'),
    (106::bigint, 10::numeric, 'oVe DRINK WITH COCOA ZETA 1 kg'),
    (126::bigint, 8::numeric, 'Staropramen Cool citron nealkoholicky napoj z piva 500ml plech'),
    (139::bigint, 10::numeric, 'ZON 500ml PET ruzne druhy'),
    (27::bigint, 12::numeric, 'Big Shock! Energeticky napoj Exotic 500ml plech'),
    (51::bigint, 6::numeric, 'DrWitt min. voda 0,55l ruzne druhy'),
    (63::bigint, 24::numeric, 'Hell Energeticky napoj classic 250ml plech'),
    (85::bigint, 12::numeric, 'Kofola Original 500ml PET'),
    (155::bigint, 12::numeric, 'Nestea 0,5l ruzne druhy'),
    (118::bigint, 24::numeric, 'QXE Energeticky napoj 250ml plech')
),
deduplicated as (
  select cl.*
  from checkout_lines cl
  where not exists (
    select 1
    from public.stock_movements_v13 sm
    where sm.reference_type = 'manual_transfer'
      and sm.reference_id = 'checkout-5AP9000-2026-05-26-reimport'
      and sm.product_id = cl.product_id
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
  1,
  4,
  'load_vehicle',
  quantity_base_units,
  null,
  'manual_transfer',
  'checkout-5AP9000-2026-05-26-reimport',
  'Reimport CheckOut-5AP9000-2026-05-26.xlsx po neuspesnem zapisu historie; stavy uz byly propsane, proto se neduplikuji. Zdroj: ' || source_name
from deduplicated;

commit;
