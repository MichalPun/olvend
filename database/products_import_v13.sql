-- Generated from tmp/products-import-preview.csv
-- Imports products as master data only, without stock balances.
-- Safe to run repeatedly: upsert by sku.

begin;

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  '3Bit tyčinka různé druhy',
  '26',
  '7622210416407',
  'snack_ready',
  'direct_sale',
  'ks',
  28.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 3-3. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  '7days Croissant lískový oříšek 60g',
  '42',
  '7622201390648',
  'snack_ready',
  'direct_sale',
  'ks',
  18.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 1-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Aiello Crema 0,25 kg',
  '196',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  198.0,
  true,
  'Zdrojový typ: Zrnková káva. Poslední dodavatel: Caffé Aiello S.r.l..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Aiello Home Espresso 0,5 kg',
  '195',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  405.0,
  true,
  'Zdrojový typ: Zrnková káva. Poslední dodavatel: Caffé Aiello S.r.l..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Aiello Ricetta Blue 1 kg',
  '192',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  804.0,
  true,
  'Zdrojový typ: Zrnková káva. Poslední dodavatel: Caffé Aiello S.r.l..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Aiello Ricetta Orange 1 kg',
  '191',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  804.0,
  true,
  'Zdrojový typ: Zrnková káva. Poslední dodavatel: Caffé Aiello S.r.l..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Aiello Ricetta Silver 1 kg',
  '193',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  776.0,
  true,
  'Zdrojový typ: Zrnková káva. Poslední dodavatel: Caffé Aiello S.r.l..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Aiello Strong 1 kg, zrnková',
  '66',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  790.0,
  true,
  'Zdrojový typ: Zrnková káva. Poslední dodavatel: Caffé Aiello S.r.l..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Aiello Sublime 1 kg',
  '194',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  804.0,
  true,
  'Zdrojový typ: Zrnková káva. Poslední dodavatel: Caffé Aiello S.r.l..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Alaska kukuřičné trubičky plněné krémem 18g různé druhy',
  '208',
  '8588005524056',
  'snack_ready',
  'direct_sale',
  'ks',
  8.0,
  true,
  'Zdrojový typ: Cukrovinky. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ATM - Belgická bageta',
  '79',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Crocodille ČR, spol. s.r.o.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ATM - Chlebíčkový Labužník',
  '16',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  51.0,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Crocodille ČR, spol. s.r.o.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ATM - Golf',
  '15',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  50.0,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Crocodille ČR, spol. s.r.o.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ATM - Kuřecí stripsy',
  '17',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  56.0,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Crocodille ČR, spol. s.r.o.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ATM - Masové koule',
  '81',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Crocodille ČR, spol. s.r.o.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ATM - Sýrový Mlsoun',
  '18',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  52.0,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Crocodille ČR, spol. s.r.o.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ATM Debrecínská bageta',
  '155',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  55.0,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Crocodille ČR, spol. s.r.o.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ATM Trhané Vepřové',
  '154',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  55.0,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Crocodille ČR, spol. s.r.o.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Attack Oplatka lískooříšková 30g',
  '33',
  '18584004024105',
  'snack_ready',
  'direct_sale',
  'ks',
  11.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 2-4. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Bad Brambacher 0,5l různé druhy',
  '207',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  28.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: M. Poslední dodavatel: Bohemia water s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Barbera 1870 1 kg',
  '202',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  555.0,
  true,
  'Zdrojový typ: Zrnková káva.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Barbera Aromagic kapsle 25 ks',
  '205',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  199.0,
  true,
  'Zdrojový typ: Zrnková káva.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Barbera Classica 1 kg',
  '204',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  775.0,
  true,
  'Zdrojový typ: Zrnková káva.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Barbera Hesperia 1 kg',
  '203',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  641.0,
  true,
  'Zdrojový typ: Zrnková káva.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Barbera Intensa 50 ks',
  '206',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  441.0,
  true,
  'Zdrojový typ: Zrnková káva.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Barbera Tris 1 kg',
  '201',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  501.0,
  true,
  'Zdrojový typ: Zrnková káva.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Big Shock! Energetický nápoj Exotic 500ml plech',
  '2',
  '8594033172497',
  'beverage_ready',
  'direct_sale',
  'ks',
  34.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: K 5. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Báječné České Polotučné trvanlivé mléko 1,5% 1l',
  '137',
  '8593803224398',
  'snack_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 5, J 5. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Bílá krémová 180 ml NEW',
  '217',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Bílá krémová 300 ml NEW',
  '218',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Bílá káva 180 ml NEW',
  '215',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Bílá káva 300 ml NEW',
  '216',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Cafe+Co 180 ml NEW',
  '219',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Cafe+Co 300 ml NEW',
  '220',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'CAPPUCCINO (E) 180 ml NEW',
  '221',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Cappuccino 180 ml I NEW',
  '222',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Cappuccino 300 ml NEW',
  '223',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Capri-Sun Multivitamin ovocný nápoj 200ml',
  '41',
  '4000177407523',
  'beverage_ready',
  'direct_sale',
  'ks',
  13.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: K 3-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Corny Big Tyčinka banány v mléčné čokoládě 50g',
  '261',
  '4011800548506',
  'snack_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Cukrovinky. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Creamio Slaný karamel PREMIUM 1 kg',
  '50',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: B. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Creamio Topping 0,7 kg',
  '52',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: B. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Cukr Vending 1,5 kg',
  '43',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: C. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'CÁBŮ Jihočeská bez majonézy 150g',
  '176',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  46.0,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Lahůdky u Cábů s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'CÁBŮ Královská bageta 160g',
  '172',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Lahůdky u Cábů s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'CÁBŮ Mexický nářez 180g',
  '179',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Lahůdky u Cábů s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'CÁBŮ Poctivé kuřátko 230g',
  '185',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Lahůdky u Cábů s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'CÁBŮ Sýrová pochoutka 140g',
  '186',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Lahůdky u Cábů s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'CÁBŮ Školní bagetka šunková 110g',
  '177',
  null,
  'food_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Bageta. Poslední dodavatel: Lahůdky u Cábů s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Doritos Tortillas Chipsy nachos cheese 44g',
  '210',
  '5900259138293',
  'snack_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Cukrovinky. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g',
  '254',
  '8586018180863',
  'snack_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Cukrovinky. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'DrWitt min. voda 0,55l různé druhy',
  '200',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  29.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: K 4. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Dupetky Snack pečený hořčice+med+cibulka 70g',
  '20',
  '5949040204427',
  'snack_ready',
  'direct_sale',
  'ks',
  26.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 1-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Ensa Arašídy loupané pražené solené 100g',
  '37',
  '8586012827450',
  'snack_ready',
  'direct_sale',
  'ks',
  16.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 1-4. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Espresso Bílé NEW',
  '225',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Espresso Lungo 180 ml NEW',
  '226',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Espresso Lungo bílé 180 ml NEW',
  '227',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Espresso Macchiatto',
  '256',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Espresso NEW',
  '224',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ESPRESSO S KAKAOVÝM NÁPOJEM NEW',
  '228',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET',
  '13',
  '8594004583130',
  'beverage_ready',
  'direct_sale',
  'ks',
  18.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: N. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Haribo Bonbóny goldbären želé medvídci 100g',
  '39',
  '9002975301558',
  'snack_ready',
  'direct_sale',
  'ks',
  26.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 3-3. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Havlík Tyčinky originál 90g',
  '38',
  '8594012320123',
  'snack_ready',
  'direct_sale',
  'ks',
  18.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 3-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Hell Energetický nápoj classic 250ml plech',
  '4',
  '5999884034414',
  'beverage_ready',
  'direct_sale',
  'ks',
  30.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: I 4. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Hello Perlivé malinový perlivý nápoj 330ml plech',
  '259',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Vody. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'HUHTAMAKI PLAST VÍČKO 150 + 180ml (10 tyčí)',
  '183',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Ice Coffee Ledová káva 350ml',
  '156',
  '8594067380837',
  'beverage_ready',
  'direct_sale',
  'ks',
  27.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: J 4-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Irish Cappuccino 300 ml NEW',
  '229',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Irish Cream 180 ml NEW',
  '230',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Irská káva 180 ml NEW',
  '231',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'IsoFruit Izotonický nápoj grep 500ml plech',
  '260',
  '8594057829773',
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Vody. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kakaový nápoj 180 ml NEW',
  '233',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kakaový nápoj 300 ml NEW',
  '232',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kakaový nápoj Cream 180 ml NEW',
  '234',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kakaový nápoj Cream 300 ml NEW',
  '235',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'KAKAOVÝ NÁPOJ DE LUXE 180 ml NEW',
  '236',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'KAKAOVÝ NÁPOJ DE LUXE 300 ml NEW',
  '237',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kakaový nápoj Mild 180 ml NEW',
  '238',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kelímek 180 ml (100 ks)',
  '45',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: H. Poslední dodavatel: Papergroup srl.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kelímek 250 ml (100 ks)',
  '255',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kelímek 300 ml (50 ks)',
  '53',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: CH. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kinder Bueno Oplatky 43g',
  '28',
  '8000500073698',
  'snack_ready',
  'direct_sale',
  'ks',
  27.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 3-4. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kinder čokoláda T4',
  '146',
  '8000500033784',
  'snack_ready',
  'direct_sale',
  'ks',
  25.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 2-5. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kit Kat 4 Fingers Tyčinka 41,5g',
  '27',
  '7613035357754',
  'snack_ready',
  'direct_sale',
  'ks',
  22.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 3-5. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Knoppers Oplatka 25g',
  '165',
  '40144382',
  'snack_ready',
  'direct_sale',
  'ks',
  12.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 2-3. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kofola Original 500ml PET',
  '70',
  '8595231200111',
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: N. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kubík 0,3l různé druhy',
  '69',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  24.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: K 6-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Kubík Waterrr Cool XXL jahoda ovocný nápoj 330ml plech',
  '189',
  '8595646209693',
  'beverage_ready',
  'direct_sale',
  'ks',
  18.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: J 3-5. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'LATTE MACCHIATO (E) 180 ml NEW',
  '241',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'LATTE MACCHIATO 180 ml NEW',
  '242',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'LATTE MACCHIATO 300 ml NEW',
  '243',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Mamis Caffé Amabile 1 kg, zrnková',
  '164',
  '8056420685695',
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Zrnková káva.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Margot Tyčinka 80g',
  '40',
  '8593893788398',
  'snack_ready',
  'direct_sale',
  'ks',
  23.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 1-3. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Mila Oplatky 50g',
  '36',
  '58584004030005',
  'snack_ready',
  'direct_sale',
  'ks',
  24.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 2-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Miňonky Oplatky oříškové 50g',
  '31',
  '8593894809764',
  'snack_ready',
  'direct_sale',
  'ks',
  22.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 2-3. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'MOCCACCINO (E) 180 ml NEW',
  '244',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'MOCCACCINO 180 ml NEW',
  '245',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'MOCCACCINO 300 ml NEW',
  '246',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Monster 0,5l různé druhy',
  '1',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  45.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: N. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Nestea 0,5l různé druhy',
  '67',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  26.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: K 2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g',
  '211',
  '8595573401344',
  'snack_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Cukrovinky. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Nutella Tyčinka B-Ready 44g',
  '32',
  '08000500262849',
  'snack_ready',
  'direct_sale',
  'ks',
  29.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: K 1-4. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'OLMIKA Cappuccino 180 ml NEW',
  '247',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'oVe BASE WITH PISTACHIO FLAVOUR 1000g',
  '197',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: B. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'oVe COFFEE CREAMER WHITE 1 kg',
  '48',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: F. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'oVe DRINK WITH CHOC WHITE FLAVOUR 1000g',
  '51',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: B. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'oVe DRINK WITH COCOA ZETA 1 kg',
  '47',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: D. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'oVe Elite 1 kg zrnková',
  '5',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  399.0,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: G. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'oVe FD COFFEE SOPHIA 500g',
  '44',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: A. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'oVe FRESH DRINK LEMON 1 kg',
  '49',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: B. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'oVe SMART CAPPUCCINO IRISH CREAM FLAVOUR 1000g',
  '46',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: E. Poslední dodavatel: SIMANDL, spol. s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Ovesná svačinka Sušenka s brusnicemi 36g',
  '162',
  '8594064474584',
  'snack_ready',
  'direct_sale',
  'ks',
  12.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 2-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Pepsi 0,33l plech',
  '157',
  '5900497312240',
  'beverage_ready',
  'direct_sale',
  'ks',
  20.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: K 6-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Pepsi Cola 500ml PET',
  '71',
  '8594004632487',
  'beverage_ready',
  'direct_sale',
  'ks',
  32.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: N. Poslední dodavatel: Makro Cash Carry ČR s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Pistácie 180 ml NEW',
  '248',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Pistácie 300 ml NEW',
  '249',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Pistáciová káva',
  '258',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Pistáciové Latté (E)',
  '257',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'QXE Energetický nápoj 250ml plech',
  '163',
  '5900535013733',
  'beverage_ready',
  'direct_sale',
  'ks',
  18.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: L. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Racio Free Style Chlebíčky rajče a bazalka 25g',
  '142',
  '8594000097587',
  'snack_ready',
  'direct_sale',
  'ks',
  16.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 3-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Red Bull 0,25l',
  '190',
  '9002490200091',
  'beverage_ready',
  'direct_sale',
  'ks',
  47.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: J 4-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Relax Limonáda liči 330ml plech',
  '6',
  '8595646203813',
  'beverage_ready',
  'direct_sale',
  'ks',
  24.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: K 3-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Romanca Sušenka s kakaovou náplní 40g',
  '30',
  '8584004150166',
  'snack_ready',
  'direct_sale',
  'ks',
  14.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 2-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Sedita Horalky Oplatky arašídové 50g',
  '35',
  '68584004040100',
  'snack_ready',
  'direct_sale',
  'ks',
  20.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 2-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Skittles Bonbóny ovocné žvýkací 38g',
  '213',
  '4009900456630',
  'snack_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Cukrovinky. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Snickers Tyčinka čokoládová 50g',
  '24',
  '5900951311512',
  'snack_ready',
  'direct_sale',
  'ks',
  26.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 2-5. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech',
  '187',
  '8593868004447',
  'beverage_ready',
  'direct_sale',
  'ks',
  25.0,
  true,
  'Zdrojový typ: Vody. Zdrojová sekce: K 3-3. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Strážnické brambůrky Chipsy česnekové 60g',
  '139',
  '8594014630022',
  'snack_ready',
  'direct_sale',
  'ks',
  18.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 1-1. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Studentská pečeť Oplatka s arašídovou náplní v mléčné čokoládě 31g',
  '166',
  '8445290662545',
  'snack_ready',
  'direct_sale',
  'ks',
  15.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: K 1-3. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Tea 180 ml NEW',
  '250',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Tea 300 ml NEW',
  '251',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Telemetrie prodej káva NEW',
  '252',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Today Donut Dezert s kakaovou náplní v polevě 50g',
  '143',
  '8693029603189',
  'snack_ready',
  'direct_sale',
  'ks',
  12.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 3-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Twix Tyčinka 50g',
  '25',
  '5900951313608',
  'snack_ready',
  'direct_sale',
  'ks',
  26.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 2-4. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Voda',
  '214',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Vídeňská Melange 180 ml NEW',
  '253',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'VÍČKO HUHTAMAKI PLAST ČERNÉ 300ml',
  '88',
  null,
  'ingredient',
  'recipe_consumption',
  'g',
  null,
  true,
  'Zdrojový typ: Ingredient. Zdrojová sekce: CH. Poslední dodavatel: Provendia s.r.o..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Yoohoo! Vafle kakao+lískový oříšek 50',
  '144',
  '5205422270375',
  'snack_ready',
  'direct_sale',
  'ks',
  19.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: I 3-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Zlaté Polomáčené Sušenky hořké 100g',
  '19',
  '8593894001175',
  'snack_ready',
  'direct_sale',
  'ks',
  30.0,
  true,
  'Zdrojový typ: Cukrovinky. Zdrojová sekce: J 1-2. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'ZON 500ml PET různé druhy',
  '209',
  '8594006245067',
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Vody. Poslední dodavatel: JIP východočeská, a.s..'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Černá káva 180 ml NEW',
  '239',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  'Černá káva 300 ml NEW',
  '240',
  null,
  'beverage_ready',
  'direct_sale',
  'ks',
  null,
  true,
  'Zdrojový typ: Teplé nápoje.'
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();

commit;
