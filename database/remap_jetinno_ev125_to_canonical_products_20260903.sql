-- Oprava katalogu Jetinno JL300 ES7C, ev. c. 125.
--
-- Cile:
--   1. napojove volby navazat na existujici kanonicke produktove karty,
--   2. zalozit pouze ctyri skutecne chybejici 250ml varianty,
--   3. zachovat strojove receptury Jetinno beze zmeny (55 radku),
--   4. doplnit fyzicky zasobnik kelimku 250 ml a navazat na nej vsechny receptury,
--   5. odstranit nepouzite docasne karty JETINNO-JL300-*.

begin;

do $$
declare
  v_machine_id bigint;
  v_temp_ids bigint[];
  v_missing integer;
  v_count integer;
  v_ref record;
begin
  select id into v_machine_id
  from public.machines
  where evidence_number = 125
    and lower(concat_ws(' ', brand, model, name)) like '%jetinno%'
    and lower(concat_ws(' ', brand, model, name)) like '%jl300%';

  if v_machine_id is null then
    raise exception 'Jetinno JL300 s evidencnim cislem 125 nebyl nalezen.';
  end if;

  select array_agg(id order by sku), count(*)
  into v_temp_ids, v_count
  from public.products
  where sku like 'JETINNO-JL300-%';

  if v_count <> 18 then
    raise exception 'Bezpecnostni kontrola: ocekavano 18 docasnych Jetinno karet, nalezeno %.', v_count;
  end if;

  if (select count(*) from public.machine_coffee_buttons where machine_id = v_machine_id and active) <> 18 then
    raise exception 'Bezpecnostni kontrola: EV125 nema presne 18 aktivnich voleb.';
  end if;

  if (select count(*) from public.machine_coffee_buttons where machine_id = v_machine_id and active and product_id = any(v_temp_ids)) <> 18 then
    raise exception 'Bezpecnostni kontrola: aktivni volby EV125 nejsou vsechny navazane na docasne karty.';
  end if;

  if (select count(*) from public.machine_coffee_recipe_items where machine_id = v_machine_id and active) <> 55 then
    raise exception 'Bezpecnostni kontrola: pred zmenou musi mit EV125 presne 55 recepturovych radku.';
  end if;

  -- Kanonicke karty, ktere uz v katalogu existuji.
  select count(*) into v_missing
  from (values
    ('283'),('284'),('290'),('291'),('287'),('286'),('288'),
    ('298'),('293'),('294'),('266'),('265'),('292'),('295'),('255')
  ) required(sku)
  left join public.products p on p.sku = required.sku and p.active = true
  where p.id is null;

  if v_missing <> 0 then
    raise exception 'Chybi % povinnych kanonickych produktovych karet.', v_missing;
  end if;

  if exists (select 1 from public.products where sku in ('304','305','306','307')) then
    raise exception 'SKU 304-307 jiz nejsou volna; migrace nebyla provedena.';
  end if;

  -- Pouze varianty, ktere v katalogu ve velikosti 250 ml chybi.
  insert into public.products (
    name, sku, product_category, usage_type, base_unit, vat_rate,
    purchase_price, sale_price, expiry_tracking_mode, expiry_warning_days,
    requires_batch_tracking, can_be_sold_directly, can_be_used_in_recipe,
    can_be_consumed_internally, can_be_used_in_service, active, note
  ) values
    ('Cafe+Co 250 ml',                         '304', 'beverage_ready', 'direct_sale', 'ks', 12, null, 10, 'none', 0, false, true, false, false, false, true, 'Kanonicka napojova karta 250 ml; zalozeno pro Jetinno JL300 dne 2026-09-03.'),
    ('Matcha Latte Malina DeLuxe 250 ml',      '305', 'beverage_ready', 'direct_sale', 'ks', 12, null, 10, 'none', 0, false, true, false, false, false, true, 'Kanonicka napojova karta 250 ml; zalozeno pro Jetinno JL300 dne 2026-09-03.'),
    ('KAKAOVY NAPOJ DeLuxe 250 ml',            '306', 'beverage_ready', 'direct_sale', 'ks', 12, null, 10, 'none', 0, false, true, false, false, false, true, 'Kanonicka napojova karta 250 ml; zalozeno pro Jetinno JL300 dne 2026-09-03.'),
    ('Bila cokolada 250 ml',                   '307', 'beverage_ready', 'direct_sale', 'ks', 12, null,  7, 'none', 0, false, true, false, false, false, true, 'Kanonicka napojova karta 250 ml; zalozeno pro Jetinno JL300 dne 2026-09-03.');

  -- Diakritiku zapiseme explicitne; ASCII hodnoty vyse pouze zjednodusuji prenos SQL souboru.
  update public.products set name = 'KAKAOVÝ NÁPOJ DeLuxe 250 ml' where sku = '306';
  update public.products set name = 'Bílá čokoláda 250 ml' where sku = '307';

  insert into public.recipes (machine_id, machine_type, selection_code, name, sale_price, active, note)
  select null, 'product_catalog', 'product:' || p.id::text, p.name, p.sale_price, true,
         'Plna vychozi gramaz pro variantu 250 ml; kalibrace vody a sneku probiha na konkretnim stroji.'
  from public.products p
  where p.sku in ('304','305','306','307');

  insert into public.recipe_items (recipe_id, product_id, quantity, unit)
  select recipe.id, ingredient.id, source.quantity, source.unit
  from (values
    ('304','201',14::numeric,'g'), ('304','51',17,'g'),   ('304','255',1,'ks'),
    ('305','262',35,'g'),          ('305','48',13,'g'),   ('305','255',1,'ks'),
    ('306','47',27.5,'g'),         ('306','51',12.5,'g'), ('306','255',1,'ks'),
    ('307','51',33,'g'),                                    ('307','255',1,'ks')
  ) source(drink_sku, ingredient_sku, quantity, unit)
  join public.products drink on drink.sku = source.drink_sku
  join public.recipes recipe
    on recipe.machine_type = 'product_catalog'
   and recipe.selection_code = 'product:' || drink.id::text
  join public.products ingredient on ingredient.sku = source.ingredient_sku;

  -- Fyzicky zasobnik automaticky vydavanych kelimku (stejny model evidence jako u ostatnich kavovaru).
  if exists (
    select 1 from public.machine_coffee_containers
    where machine_id = v_machine_id and (container_code = 'Z8' or product_sku = '255')
  ) then
    raise exception 'EV125 uz obsahuje zasobnik Z8 nebo produkt 255; rucni kontrola je nutna.';
  end if;

  insert into public.machine_coffee_containers (
    machine_id, container_code, product_id, product_sku, product_name,
    capacity_quantity, current_quantity, unit, refill_package_quantity,
    refill_package_unit, min_refill_quantity, sort_order, active, note
  )
  select v_machine_id, 'Z8', p.id, p.sku, p.name,
         250, 0, 'ks', 50, 'ks', 50, 8, true,
         'Jetinno JL300 ES7C · zasobnik automaticky vydavanych kelimku 250 ml · vychozi stav 0 ks.'
  from public.products p
  where p.sku = '255';

  update public.machine_coffee_recipe_items item
  set coffee_container_id = container.id,
      container_code = container.container_code,
      ingredient_name = container.product_name
  from public.machine_coffee_containers container,
       public.products cup
  where item.machine_id = v_machine_id
    and item.active = true
    and cup.sku = '255'
    and item.product_id = cup.id
    and container.machine_id = v_machine_id
    and container.product_id = cup.id
    and container.container_code = 'Z8'
    and container.active = true;

  get diagnostics v_count = row_count;
  if v_count <> 18 then
    raise exception 'Navazani kelimku na Z8 selhalo: ocekavano 18 radku, upraveno %.', v_count;
  end if;

  -- Prevod tlacitek na katalogove karty. Strojove receptury zustavaji nedotcene.
  update public.machine_coffee_buttons button
  set product_id = product.id,
      product_sku = product.sku,
      product_name = product.name,
      planned_product_name = product.name,
      planned_product_sku = product.sku,
      planned_price_czk = mapping.price,
      substitution_policy = 'exact',
      note = 'Jetinno JL300 · nabidka 3 × 6 · 8 oz / D80 · kanonicka produktova karta, strojova receptura zachovana.'
  from (values
    ('1','283',10::numeric), ('2','284',10), ('3','290',10), ('4','291',10),
    ('5','287',10), ('6','286',10), ('7','288',10), ('8','304',10),
    ('9','298',10), ('10','293',7), ('11','294',7), ('12','266',7),
    ('13','305',10), ('14','265',10), ('15','292',7), ('16','295',7),
    ('17','306',10), ('18','307',7)
  ) mapping(selection_code, sku, price)
  join public.products product on product.sku = mapping.sku and product.active = true
  where button.machine_id = v_machine_id
    and button.selection_code = mapping.selection_code
    and button.active = true;

  get diagnostics v_count = row_count;
  if v_count <> 18 then
    raise exception 'Prevod tlacitek selhal: ocekavano 18 radku, upraveno %.', v_count;
  end if;

  -- Ceny jsou vlastnosti konkretniho stroje, ne globalni ceny katalogovych karet.
  update public.machine_coffee_buttons button
  set sale_price_czk = mapping.price,
      customer_price_czk = mapping.price
  from (values
    ('1',10::numeric),('2',10),('3',10),('4',10),('5',10),('6',10),('7',10),('8',10),('9',10),
    ('10',7),('11',7),('12',7),('13',10),('14',10),('15',7),('16',7),('17',10),('18',7)
  ) mapping(selection_code, price)
  where button.machine_id = v_machine_id and button.selection_code = mapping.selection_code and button.active = true;

  update public.machine_planogram_slots slot
  set product_name = button.product_name,
      product_sku = button.product_sku,
      price_czk = button.sale_price_czk,
      dex_price_czk = button.sale_price_czk,
      customer_price_czk = button.customer_price_czk,
      planned_product_name = button.product_name,
      planned_product_sku = button.product_sku,
      planned_price_czk = button.sale_price_czk,
      substitution_policy = 'exact',
      note = 'Zrcadlovy slot Jetinno JL300 · ev. 125 · kanonicka produktova karta.'
  from public.machine_coffee_buttons button
  where slot.machine_id = v_machine_id
    and button.machine_id = v_machine_id
    and slot.slot_code = button.selection_code
    and slot.active = true
    and button.active = true;

  get diagnostics v_count = row_count;
  if v_count <> 18 then
    raise exception 'Aktualizace zrcadlovych slotu selhala: ocekavano 18 radku, upraveno %.', v_count;
  end if;

  -- Presna kontrola vsech surovin, gramazi, jednotek a kelimku po premapovani.
  if exists (
    with expected(selection_code, ingredient_sku, quantity, unit) as (values
      ('1','201',14::numeric,'g'), ('1','43',4.2,'g'), ('1','255',1,'ks'),
      ('2','201',14,'g'), ('2','43',8.3,'g'), ('2','255',1,'ks'),
      ('3','201',14,'g'), ('3','255',1,'ks'),
      ('4','201',14,'g'), ('4','48',11.7,'g'), ('4','43',8.3,'g'), ('4','255',1,'ks'),
      ('5','201',14,'g'), ('5','48',11.8,'g'), ('5','47',4.4,'g'), ('5','43',5.3,'g'), ('5','255',1,'ks'),
      ('6','201',14,'g'), ('6','48',27.8,'g'), ('6','43',8.9,'g'), ('6','255',1,'ks'),
      ('7','201',14,'g'), ('7','48',11.7,'g'), ('7','47',17.8,'g'), ('7','43',2.8,'g'), ('7','255',1,'ks'),
      ('8','201',14,'g'), ('8','51',17,'g'), ('8','255',1,'ks'),
      ('9','201',14,'g'), ('9','46',25,'g'), ('9','255',1,'ks'),
      ('10','46',30.6,'g'), ('10','255',1,'ks'),
      ('11','46',30.6,'g'), ('11','47',13.9,'g'), ('11','255',1,'ks'),
      ('12','262',35,'g'), ('12','255',1,'ks'),
      ('13','262',35,'g'), ('13','48',13,'g'), ('13','255',1,'ks'),
      ('14','201',10,'g'), ('14','262',35,'g'), ('14','255',1,'ks'),
      ('15','47',36.1,'g'), ('15','255',1,'ks'),
      ('16','47',23.6,'g'), ('16','48',9.7,'g'), ('16','255',1,'ks'),
      ('17','47',27.5,'g'), ('17','51',12.5,'g'), ('17','255',1,'ks'),
      ('18','51',33,'g'), ('18','255',1,'ks')
    ), actual as (
      select button.selection_code, ingredient.sku, item.quantity_per_vend, item.unit
      from public.machine_coffee_recipe_items item
      join public.machine_coffee_buttons button on button.id = item.coffee_button_id
      join public.products ingredient on ingredient.id = item.product_id
      where item.machine_id = v_machine_id and item.active = true and button.active = true
    )
    select 1 from (
      (select * from expected except all select * from actual)
      union all
      (select * from actual except all select * from expected)
    ) difference
  ) then
    raise exception 'Kontrola receptur selhala: skutecne suroviny nebo gramaze se lisi od schvaleneho zadani.';
  end if;

  if (select count(*) from public.machine_coffee_recipe_items where machine_id = v_machine_id and active) <> 55 then
    raise exception 'Kontrola receptur selhala: po zmene neni presne 55 radku.';
  end if;

  if exists (
    select 1
    from public.machine_coffee_recipe_items item
    left join public.machine_coffee_containers container on container.id = item.coffee_container_id
    where item.machine_id = v_machine_id and item.active = true
      and (container.id is null or container.machine_id <> v_machine_id or container.product_id is distinct from item.product_id)
  ) then
    raise exception 'Kontrola receptur selhala: nektera surovina nebo kelimek neni navazan na spravny zasobnik.';
  end if;

  if (select count(*) from public.machine_coffee_containers where machine_id = v_machine_id and active) <> 8 then
    raise exception 'Kontrola zasobniku selhala: ocekavano 7 surovinovych + 1 kelimkovy zasobnik.';
  end if;

  if (select count(*) from public.machine_coffee_recipe_items item join public.products p on p.id=item.product_id where item.machine_id=v_machine_id and item.active and p.sku='255' and item.container_code='Z8' and item.quantity_per_vend=1 and item.unit='ks') <> 18 then
    raise exception 'Kontrola kelimku selhala: vsech 18 napoju musi spotrebovat 1 ks ze Z8.';
  end if;

  if (select count(*) from public.machine_coffee_buttons where machine_id=v_machine_id and active and sale_price_czk=10) <> 12
     or (select count(*) from public.machine_coffee_buttons where machine_id=v_machine_id and active and sale_price_czk=7) <> 6 then
    raise exception 'Kontrola cen selhala: ocekavano 12 voleb za 10 Kc a 6 voleb za 7 Kc.';
  end if;

  -- Docasne globalni recepty jiz nejsou potreba.
  delete from public.recipe_items item
  using public.recipes recipe
  where item.recipe_id = recipe.id
    and recipe.machine_type = 'product_catalog'
    and recipe.selection_code = any(
      select 'product:' || unnest(v_temp_ids)::text
    );

  delete from public.recipes
  where machine_type = 'product_catalog'
    and selection_code = any(
      select 'product:' || unnest(v_temp_ids)::text
    );

  -- Pred smazanim overime uplne vsechny FK vazby na docasne produktove karty.
  for v_ref in
    select ns.nspname as schema_name, cls.relname as table_name, att.attname as column_name
    from pg_constraint con
    join pg_class cls on cls.oid = con.conrelid
    join pg_namespace ns on ns.oid = cls.relnamespace
    join pg_attribute att on att.attrelid = con.conrelid and att.attnum = con.conkey[1]
    where con.contype = 'f'
      and con.confrelid = 'public.products'::regclass
      and array_length(con.conkey,1) = 1
  loop
    execute format('select count(*) from %I.%I where %I = any($1)', v_ref.schema_name, v_ref.table_name, v_ref.column_name)
      into v_count using v_temp_ids;
    if v_count <> 0 then
      raise exception 'Docasne karty stale pouziva %.% (sloupec %, zaznamu %).', v_ref.schema_name, v_ref.table_name, v_ref.column_name, v_count;
    end if;
  end loop;

  delete from public.products where id = any(v_temp_ids);
  get diagnostics v_count = row_count;
  if v_count <> 18 then
    raise exception 'Odstraneni docasnych karet selhalo: ocekavano 18, smazano %.', v_count;
  end if;

  if exists (select 1 from public.products where sku like 'JETINNO-JL300-%') then
    raise exception 'Po dokonceni zustaly v katalogu docasne Jetinno SKU.';
  end if;
end $$;

commit;

select
  m.evidence_number,
  count(distinct c.id) filter (where c.active) as active_containers,
  count(distinct b.id) filter (where b.active) as active_buttons,
  count(distinct ri.id) filter (where ri.active) as active_recipe_items,
  count(distinct b.id) filter (where b.active and b.sale_price_czk = 10) as drinks_10_czk,
  count(distinct b.id) filter (where b.active and b.sale_price_czk = 7) as drinks_7_czk
from public.machines m
left join public.machine_coffee_containers c on c.machine_id = m.id
left join public.machine_coffee_buttons b on b.machine_id = m.id
left join public.machine_coffee_recipe_items ri on ri.machine_id = m.id
where m.evidence_number = 125
group by m.evidence_number;
