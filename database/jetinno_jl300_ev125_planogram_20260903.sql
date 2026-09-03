-- OLVEND planogram pro nový Jetinno JL300 ES7C, ev. č. 125.
-- 7 zásobníků, 18 voleb v rozložení 3 sloupce × 6 řad.
-- Ceny: zrnková káva 10 Kč; instantní 7 Kč; De Luxe 10 Kč.

begin;

do $$
declare
  v_machine_id bigint;
  v_missing integer;
  v_existing integer;
begin
  select id into v_machine_id
  from public.machines
  where evidence_number = 125
    and lower(concat_ws(' ', brand, model, name)) like '%jetinno%'
    and lower(concat_ws(' ', brand, model, name)) like '%jl300%';

  if v_machine_id is null then
    raise exception 'Jetinno JL300 s evidenčním číslem 125 nebyl nalezen.';
  end if;

  select count(*) into v_missing
  from (values ('201'),('43'),('48'),('47'),('46'),('262'),('51'),('255')) required(sku)
  left join public.products p on p.sku = required.sku and p.active = true
  where p.id is null;

  if v_missing <> 0 then
    raise exception 'Chybí % povinných skladových produktů pro Jetinno JL300.', v_missing;
  end if;

  select
    (select count(*) from public.machine_coffee_containers where machine_id = v_machine_id)
    + (select count(*) from public.machine_coffee_buttons where machine_id = v_machine_id)
    + (select count(*) from public.machine_coffee_recipe_items where machine_id = v_machine_id)
    + (select count(*) from public.machine_planogram_slots where machine_id = v_machine_id)
    + (select count(*) from public.products where sku like 'JETINNO-JL300-%')
  into v_existing;

  if v_existing <> 0 then
    raise exception 'Bezpečnostní kontrola: EV 125 nebo vyhrazená Jetinno SKU již obsahují % záznamů. Import nebyl proveden.', v_existing;
  end if;

  insert into public.products (
    name, sku, product_category, usage_type, base_unit, vat_rate,
    purchase_price, sale_price, expiry_tracking_mode, expiry_warning_days,
    requires_batch_tracking, can_be_sold_directly, can_be_used_in_recipe,
    can_be_consumed_internally, can_be_used_in_service, active, note
  )
  select
    d.name, d.sku, 'beverage_ready', 'direct_sale', 'ks', 12,
    null, d.price, 'none', 0, false, true, false, false, false, true,
    'Jetinno JL300 ES7C · ev. 125 · nabídka 8 oz / D80 · založeno 2026-09-03.'
  from (values
    ('JETINNO-JL300-01','Espresso Doppio',10::numeric),
    ('JETINNO-JL300-02','Lungo',10),
    ('JETINNO-JL300-03','Černá káva',10),
    ('JETINNO-JL300-04','Bílá káva',10),
    ('JETINNO-JL300-05','Cappuccino',10),
    ('JETINNO-JL300-06','Latte Macchiato',10),
    ('JETINNO-JL300-07','Moccaccino',10),
    ('JETINNO-JL300-08','Cafe+Co',10),
    ('JETINNO-JL300-09','Irská káva',10),
    ('JETINNO-JL300-10','Irish Cream',7),
    ('JETINNO-JL300-11','OLMIKA Cappuccino',7),
    ('JETINNO-JL300-12','Matcha Malina',7),
    ('JETINNO-JL300-13','Matcha Malina De Luxe',10),
    ('JETINNO-JL300-14','Espresso Matcha Malina',10),
    ('JETINNO-JL300-15','Horká čokoláda',7),
    ('JETINNO-JL300-16','Čokoláda Cream',7),
    ('JETINNO-JL300-17','Čokoláda De Luxe',10),
    ('JETINNO-JL300-18','Bílá čokoláda',7)
  ) d(sku,name,price);

  insert into public.recipes (machine_id, machine_type, selection_code, name, sale_price, active, note)
  select
    null, 'product_catalog', 'product:' || p.id::text, p.name, p.sale_price, true,
    'Jetinno JL300 ES7C · výchozí plná gramáž; kalibrace vody a šneků proběhne na pilotním stroji.'
  from public.products p
  where p.sku like 'JETINNO-JL300-%';

  insert into public.recipe_items (recipe_id, product_id, quantity, unit)
  select r.id, ingredient.id, d.quantity, d.unit
  from (values
    ('JETINNO-JL300-01','201',14::numeric,'g'), ('JETINNO-JL300-01','43',4.2,'g'), ('JETINNO-JL300-01','255',1,'ks'),
    ('JETINNO-JL300-02','201',14,'g'), ('JETINNO-JL300-02','43',8.3,'g'), ('JETINNO-JL300-02','255',1,'ks'),
    ('JETINNO-JL300-03','201',14,'g'), ('JETINNO-JL300-03','255',1,'ks'),
    ('JETINNO-JL300-04','201',14,'g'), ('JETINNO-JL300-04','48',11.7,'g'), ('JETINNO-JL300-04','43',8.3,'g'), ('JETINNO-JL300-04','255',1,'ks'),
    ('JETINNO-JL300-05','201',14,'g'), ('JETINNO-JL300-05','48',11.8,'g'), ('JETINNO-JL300-05','47',4.4,'g'), ('JETINNO-JL300-05','43',5.3,'g'), ('JETINNO-JL300-05','255',1,'ks'),
    ('JETINNO-JL300-06','201',14,'g'), ('JETINNO-JL300-06','48',27.8,'g'), ('JETINNO-JL300-06','43',8.9,'g'), ('JETINNO-JL300-06','255',1,'ks'),
    ('JETINNO-JL300-07','201',14,'g'), ('JETINNO-JL300-07','48',11.7,'g'), ('JETINNO-JL300-07','47',17.8,'g'), ('JETINNO-JL300-07','43',2.8,'g'), ('JETINNO-JL300-07','255',1,'ks'),
    ('JETINNO-JL300-08','201',14,'g'), ('JETINNO-JL300-08','51',17,'g'), ('JETINNO-JL300-08','255',1,'ks'),
    ('JETINNO-JL300-09','201',14,'g'), ('JETINNO-JL300-09','46',25,'g'), ('JETINNO-JL300-09','255',1,'ks'),
    ('JETINNO-JL300-10','46',30.6,'g'), ('JETINNO-JL300-10','255',1,'ks'),
    ('JETINNO-JL300-11','46',30.6,'g'), ('JETINNO-JL300-11','47',13.9,'g'), ('JETINNO-JL300-11','255',1,'ks'),
    ('JETINNO-JL300-12','262',35,'g'), ('JETINNO-JL300-12','255',1,'ks'),
    ('JETINNO-JL300-13','262',35,'g'), ('JETINNO-JL300-13','48',13,'g'), ('JETINNO-JL300-13','255',1,'ks'),
    ('JETINNO-JL300-14','201',10,'g'), ('JETINNO-JL300-14','262',35,'g'), ('JETINNO-JL300-14','255',1,'ks'),
    ('JETINNO-JL300-15','47',36.1,'g'), ('JETINNO-JL300-15','255',1,'ks'),
    ('JETINNO-JL300-16','47',23.6,'g'), ('JETINNO-JL300-16','48',9.7,'g'), ('JETINNO-JL300-16','255',1,'ks'),
    ('JETINNO-JL300-17','47',27.5,'g'), ('JETINNO-JL300-17','51',12.5,'g'), ('JETINNO-JL300-17','255',1,'ks'),
    ('JETINNO-JL300-18','51',33,'g'), ('JETINNO-JL300-18','255',1,'ks')
  ) d(drink_sku,ingredient_sku,quantity,unit)
  join public.products drink on drink.sku = d.drink_sku
  join public.recipes r on r.machine_type = 'product_catalog' and r.selection_code = 'product:' || drink.id::text
  join public.products ingredient on ingredient.sku = d.ingredient_sku;

  insert into public.machine_coffee_containers (
    machine_id, container_code, product_id, product_sku, product_name,
    capacity_quantity, current_quantity, unit, refill_package_quantity,
    refill_package_unit, min_refill_quantity, sort_order, active, note
  )
  select
    v_machine_id, d.code, p.id, p.sku, p.name,
    d.capacity, 0, 'g', d.package_quantity, 'g', d.package_quantity,
    d.sort_order, true,
    'Jetinno JL300 ES7C · výchozí stav 0 g před prvním fyzickým naplněním.'
  from (values
    ('Z1','201',1500::numeric,1000::numeric,1),
    ('Z2','43',3000,1500,2),
    ('Z3','48',3000,1000,3),
    ('Z4','47',3000,1000,4),
    ('Z5','46',3000,1000,5),
    ('Z6','262',3000,1000,6),
    ('Z7','51',3000,1000,7)
  ) d(code,sku,capacity,package_quantity,sort_order)
  join public.products p on p.sku = d.sku;

  insert into public.machine_coffee_buttons (
    machine_id, selection_code, product_id, product_sku, product_name,
    sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk,
    settlement_billing_enabled, substitution_policy, last_counter,
    grid_column, grid_row_from_bottom, sort_order, active, note
  )
  select
    v_machine_id, d.selection_code, p.id, p.sku, p.name,
    d.price, d.price, 'none', 0, false, 'exact', null,
    d.grid_column, d.grid_row_from_bottom, d.sort_order, true,
    'Jetinno JL300 · nabídka 3 × 6 · 8 oz / D80.'
  from (values
    ('1','JETINNO-JL300-01',10::numeric,1,6,1),
    ('2','JETINNO-JL300-02',10,2,6,2),
    ('3','JETINNO-JL300-03',10,3,6,3),
    ('4','JETINNO-JL300-04',10,1,5,4),
    ('5','JETINNO-JL300-05',10,2,5,5),
    ('6','JETINNO-JL300-06',10,3,5,6),
    ('7','JETINNO-JL300-07',10,1,4,7),
    ('8','JETINNO-JL300-08',10,2,4,8),
    ('9','JETINNO-JL300-09',10,3,4,9),
    ('10','JETINNO-JL300-10',7,1,3,10),
    ('11','JETINNO-JL300-11',7,2,3,11),
    ('12','JETINNO-JL300-12',7,3,3,12),
    ('13','JETINNO-JL300-13',10,1,2,13),
    ('14','JETINNO-JL300-14',10,2,2,14),
    ('15','JETINNO-JL300-15',7,3,2,15),
    ('16','JETINNO-JL300-16',7,1,1,16),
    ('17','JETINNO-JL300-17',10,2,1,17),
    ('18','JETINNO-JL300-18',7,3,1,18)
  ) d(selection_code,sku,price,grid_column,grid_row_from_bottom,sort_order)
  join public.products p on p.sku = d.sku;

  insert into public.machine_coffee_recipe_items (
    machine_id, coffee_button_id, coffee_container_id, product_id,
    container_code, ingredient_name, quantity_per_vend, unit, sort_order, active
  )
  select
    v_machine_id, button.id, container.id, item.product_id,
    coalesce(container.container_code, case when ingredient.sku = '255' then 'CUP' end),
    ingredient.name, item.quantity, item.unit,
    row_number() over (partition by button.id order by item.id), true
  from public.machine_coffee_buttons button
  join public.products drink on drink.id = button.product_id
  join public.recipes recipe on recipe.machine_type = 'product_catalog' and recipe.selection_code = 'product:' || drink.id::text
  join public.recipe_items item on item.recipe_id = recipe.id
  join public.products ingredient on ingredient.id = item.product_id
  left join public.machine_coffee_containers container
    on container.machine_id = v_machine_id and container.product_id = item.product_id and container.active = true
  where button.machine_id = v_machine_id and button.active = true;

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    capacity_units, current_units, fill_percent, active, sort_order, telemetry_key,
    customer_price_czk, settlement_type, settlement_amount_czk,
    settlement_billing_enabled, substitution_policy, note
  )
  select
    v_machine_id, selection_code, product_name, product_sku,
    sale_price_czk, sale_price_czk, null, null, null, active, sort_order,
    selection_code, customer_price_czk, 'none', 0, false, 'exact',
    'Zrcadlový slot Jetinno JL300 · ev. 125.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id and active = true;

  if (select count(*) from public.machine_coffee_containers where machine_id = v_machine_id and active) <> 7 then
    raise exception 'Kontrola planogramu selhala: očekáváno 7 aktivních zásobníků.';
  end if;

  if (select count(*) from public.machine_coffee_buttons where machine_id = v_machine_id and active) <> 18 then
    raise exception 'Kontrola planogramu selhala: očekáváno 18 aktivních nápojů.';
  end if;

  if (select count(*) from public.machine_coffee_recipe_items where machine_id = v_machine_id and active) <> 55 then
    raise exception 'Kontrola receptur selhala: očekáváno 55 vazeb surovin a kelímků.';
  end if;
end $$;

commit;

select
  m.id,
  m.evidence_number,
  m.name,
  count(distinct c.id) filter (where c.active) as active_containers,
  count(distinct b.id) filter (where b.active) as active_buttons,
  count(distinct r.id) filter (where r.active) as active_recipe_items
from public.machines m
left join public.machine_coffee_containers c on c.machine_id = m.id
left join public.machine_coffee_buttons b on b.machine_id = m.id
left join public.machine_coffee_recipe_items r on r.machine_id = m.id
where m.evidence_number = 125
group by m.id, m.evidence_number, m.name;
