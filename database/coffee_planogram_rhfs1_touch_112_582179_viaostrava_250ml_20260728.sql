-- Planogram [112] rhFS1 touch 21,5-2026-07-28.xlsx
-- Evidence 112, TID 582179, ViaPharma Ostrava location_id 50.
-- All drinks are 250 ml. Reuses SKUs 283-297/256 created for machine 103.
-- Adds SKU 298 (Irská káva 250 ml) and SKU 299 (Malinová Matcha káva I 250 ml).

begin;

insert into public.products (
  name,sku,product_category,usage_type,base_unit,vat_rate,purchase_price,
  sale_price,shelf_life_days,expiry_tracking_mode,expiry_warning_days,
  requires_batch_tracking,active,note,can_be_sold_directly,
  can_be_used_in_recipe,can_be_consumed_internally,can_be_used_in_service
)
select d.new_name,d.new_sku,s.product_category,s.usage_type,s.base_unit,
       s.vat_rate,s.purchase_price,d.price,s.shelf_life_days,
       s.expiry_tracking_mode,s.expiry_warning_days,s.requires_batch_tracking,
       true,d.note,s.can_be_sold_directly,s.can_be_used_in_recipe,
       s.can_be_consumed_internally,s.can_be_used_in_service
from (values
  ('231','298','Irská káva 250 ml',12::numeric,
   '250 ml: zdroj SKU 231 / 180 ml; gramáže × 250/180; kelímek SKU 255.'),
  ('268','299','Malinová Matcha káva I 250 ml',7::numeric,
   '250 ml: zdroj SKU 268 / 300 ml; gramáže × 250/300; kelímek SKU 255.')
) d(source_sku,new_sku,new_name,price,note)
join public.products s on s.sku=d.source_sku
on conflict (sku) do update set
  name=excluded.name,product_category=excluded.product_category,
  usage_type=excluded.usage_type,base_unit=excluded.base_unit,
  vat_rate=excluded.vat_rate,sale_price=excluded.sale_price,active=true,
  can_be_sold_directly=excluded.can_be_sold_directly,
  can_be_used_in_recipe=excluded.can_be_used_in_recipe,
  note=excluded.note,updated_at=now();

delete from public.recipe_items
where recipe_id in (
  select r.id from public.recipes r
  join public.products p on r.selection_code='product:'||p.id::text
  where r.machine_type='product_catalog' and p.sku in ('298','299')
);
delete from public.recipes r
using public.products p
where r.selection_code='product:'||p.id::text
  and r.machine_type='product_catalog' and p.sku in ('298','299');

insert into public.recipes (
  machine_id,machine_type,selection_code,name,sale_price,active,note
)
select null,'product_catalog','product:'||p.id::text,p.name,d.price,true,d.note
from (values
  ('298',12::numeric,'250 ml přepočet z 180 ml × 250/180.'),
  ('299',7::numeric,'250 ml přepočet z 300 ml × 250/300.')
) d(sku,price,note)
join public.products p on p.sku=d.sku;

insert into public.recipe_items (recipe_id,product_id,quantity,unit)
select nr.id,
       case when ip.sku in ('45','53') then cup.id else ri.product_id end,
       case
         when ip.sku in ('45','53') then 1
         when ri.unit='g' then round(ri.quantity*d.factor,1)
         else ri.quantity
       end,
       ri.unit
from (values
  ('231','298',250::numeric/180::numeric),
  ('268','299',250::numeric/300::numeric)
) d(source_sku,new_sku,factor)
join public.products sp on sp.sku=d.source_sku
join public.products np on np.sku=d.new_sku
join public.recipes nr
  on nr.machine_type='product_catalog'
 and nr.selection_code='product:'||np.id::text
join lateral (
  select r.* from public.recipes r
  where r.machine_type='product_catalog'
    and r.selection_code='product:'||sp.id::text
  order by r.id desc limit 1
) sr on true
join public.recipe_items ri on ri.recipe_id=sr.id
join public.products ip on ip.id=ri.product_id
cross join lateral (select id from public.products where sku='255') cup;

do $$
declare
  v_machine_id bigint := 103;
  v_source_machine_id bigint := 83;
begin
  update public.machines
  set location_id=50,name='rhFS1 touch 21,5',machine_type='Coffee',
      brand='Rheavendors',model='rhFS1 touch 21,5',status='ok',active=true,
      note=concat_ws(' ',nullif(note,''),
        'Planogram 2026-07-28; ViaOstrava; TID 582179; všech 20 nápojů 250 ml.'),
      sales_tracking_mode='telemetry',updated_at=now()
  where id=v_machine_id and evidence_number=112;

  insert into public.machine_external_links
    (machine_id,provider,external_machine_id,telemetry_enabled,note)
  values
    (v_machine_id,'IMA','582179',true,'TID 582179 pro automat 112 / ViaOstrava.'),
    (v_machine_id,'GP','582179',true,'TID 582179 pro automat 112 / ViaOstrava.')
  on conflict (provider,external_machine_id) do update
  set machine_id=excluded.machine_id,telemetry_enabled=true,note=excluded.note,updated_at=now();

  update public.machine_coffee_containers set active=false where machine_id=v_machine_id;
  update public.machine_coffee_buttons set active=false where machine_id=v_machine_id;
  update public.machine_planogram_slots set active=false where machine_id=v_machine_id;

  insert into public.machine_coffee_containers (
    machine_id,container_code,product_id,product_sku,product_name,
    capacity_quantity,current_quantity,unit,refill_package_quantity,
    refill_package_unit,min_refill_quantity,sort_order,active,note
  )
  select v_machine_id,d.code,p.id,p.sku,p.name,d.capacity,d.current,d.unit,
         d.package,d.unit,d.package,d.sort_order,true,
         case when d.code='Z1'
           then 'Export SKU 5 Elite; dle pravidla nahrazeno Barbera Tris SKU 201.'
           else 'Import planogramu 112 / 2026-07-28.' end
  from (values
    ('Z1','201',2000::numeric,1800::numeric,'g',1000::numeric,1),
    ('Z2','43',3000,2898,'g',1500,2),('Z3','48',3000,2797,'g',1000,3),
    ('Z4','47',3000,2951,'g',1000,4),('Z5','44',1500,1491,'g',500,5),
    ('Z6','46',3000,2941,'g',1000,6),('Z7','197',3000,2955,'g',1000,7),
    ('Z8','255',400,386,'ks',100,8),('Z9','88',100,100,'ks',100,9),
    ('Z10','262',3000,2930,'g',1000,10)
  ) d(code,sku,capacity,current,unit,package,sort_order)
  join public.products p on p.sku=d.sku
  on conflict (machine_id,container_code) do update set
    product_id=excluded.product_id,product_sku=excluded.product_sku,
    product_name=excluded.product_name,capacity_quantity=excluded.capacity_quantity,
    current_quantity=excluded.current_quantity,unit=excluded.unit,
    refill_package_quantity=excluded.refill_package_quantity,
    refill_package_unit=excluded.refill_package_unit,
    min_refill_quantity=excluded.min_refill_quantity,sort_order=excluded.sort_order,
    active=true,note=excluded.note,updated_at=now();

  insert into public.machine_coffee_buttons (
    machine_id,selection_code,product_id,product_sku,product_name,
    sale_price_czk,customer_price_czk,settlement_type,settlement_amount_czk,
    settlement_partner,settlement_billing_enabled,settlement_note,
    planned_product_name,planned_product_sku,planned_price_czk,
    substitution_policy,allowed_substitutes,operator_instruction,
    last_counter,grid_column,grid_row_from_bottom,sort_order,active,note
  )
  select v_machine_id,d.code,p.id,p.sku,p.name,d.price,d.price,
         'none',0,null,false,null,null,null,null,'exact',null,null,
         41,d.grid_column,d.grid_row,d.sort_order,true,d.note
  from (values
    ('1','283',12::numeric,1,4,1,'250 ml; původně SKU 224.'),
    ('2','284',12,1,3,2,'250 ml; původně SKU 226.'),
    ('3','256',12,1,2,3,'Správná katalogová 250ml položka.'),
    ('4','285',12,1,1,4,'250 ml; původně SKU 227.'),
    ('5','286',12,2,4,5,'250 ml; původně SKU 241.'),
    ('6','287',12,2,3,6,'250 ml; původně SKU 221.'),
    ('7','288',12,2,2,7,'250 ml; původně SKU 244.'),
    ('8','289',12,2,1,8,'250 ml; původně SKU 257.'),
    ('9','290',10,3,4,9,'250 ml; původně SKU 239.'),
    ('10','291',10,3,3,10,'250 ml; původně SKU 215.'),
    ('11','292',10,3,2,11,'250 ml; původně SKU 233.'),
    ('12','293',10,3,1,12,'250 ml; původně SKU 230.'),
    ('13','294',10,4,4,13,'250 ml; původně SKU 247.'),
    ('14','295',10,4,3,14,'250 ml; původně SKU 234.'),
    ('15','296',10,4,2,15,'250 ml; původně SKU 248.'),
    ('16','297',10,4,1,16,'250 ml; původně SKU 258.'),
    ('17','298',12,5,4,17,'Nová Irská káva 250 ml; původně SKU 231.'),
    ('18','266',7,5,3,18,'Název je autoritativní: Matcha Latte Malina 250 ml.'),
    ('19','265',10,5,2,19,'Název je autoritativní: Espresso Matcha Latte Malina 250 ml.'),
    ('20','299',7,5,1,20,'Nová Malinová Matcha káva I 250 ml; zdroj SKU 268 / 300 ml.')
  ) d(code,sku,price,grid_column,grid_row,sort_order,note)
  join public.products p on p.sku=d.sku
  on conflict (machine_id,selection_code) do update set
    product_id=excluded.product_id,product_sku=excluded.product_sku,
    product_name=excluded.product_name,sale_price_czk=excluded.sale_price_czk,
    customer_price_czk=excluded.customer_price_czk,
    settlement_type=excluded.settlement_type,
    settlement_amount_czk=excluded.settlement_amount_czk,
    settlement_partner=excluded.settlement_partner,
    settlement_billing_enabled=excluded.settlement_billing_enabled,
    settlement_note=excluded.settlement_note,
    planned_product_name=excluded.planned_product_name,
    planned_product_sku=excluded.planned_product_sku,
    planned_price_czk=excluded.planned_price_czk,
    substitution_policy=excluded.substitution_policy,
    allowed_substitutes=excluded.allowed_substitutes,
    operator_instruction=excluded.operator_instruction,last_counter=excluded.last_counter,
    grid_column=excluded.grid_column,grid_row_from_bottom=excluded.grid_row_from_bottom,
    sort_order=excluded.sort_order,active=true,note=excluded.note,updated_at=now();

  delete from public.machine_coffee_recipe_items where machine_id=v_machine_id;
  insert into public.machine_coffee_recipe_items (
    machine_id,coffee_button_id,coffee_container_id,product_id,
    container_code,ingredient_name,quantity_per_vend,unit,sort_order,active
  )
  select v_machine_id,b.id,c.id,c.product_id,c.container_code,c.product_name,
         ri.quantity,ri.unit,ri.id,true
  from public.machine_coffee_buttons b
  join lateral (
    select r.* from public.recipes r
    where r.machine_type='product_catalog'
      and r.selection_code='product:'||b.product_id::text
    order by (r.sale_price=b.sale_price_czk) desc nulls last,r.id desc limit 1
  ) r on true
  join public.recipe_items ri on ri.recipe_id=r.id
  join public.machine_coffee_containers c
    on c.machine_id=v_machine_id and c.product_id=ri.product_id and c.active
  where b.machine_id=v_machine_id and b.active;

  insert into public.machine_planogram_slots (
    machine_id,slot_code,product_name,product_sku,price_czk,dex_price_czk,
    active,sort_order,telemetry_key,customer_price_czk,settlement_type,
    settlement_amount_czk,settlement_partner,settlement_billing_enabled,
    settlement_note,planned_product_name,planned_product_sku,planned_price_czk,
    substitution_policy,allowed_substitutes,operator_instruction,note
  )
  select v_machine_id,selection_code,product_name,product_sku,
         sale_price_czk,sale_price_czk,true,sort_order,selection_code,
         customer_price_czk,settlement_type,settlement_amount_czk,
         settlement_partner,settlement_billing_enabled,settlement_note,
         planned_product_name,planned_product_sku,planned_price_czk,
         substitution_policy,allowed_substitutes,operator_instruction,
         'rhFS1 touch 250 ml slot; planogram 112 / TID 582179 / ViaOstrava.'
  from public.machine_coffee_buttons where machine_id=v_machine_id and active
  on conflict (machine_id,slot_code) do update set
    product_name=excluded.product_name,product_sku=excluded.product_sku,
    price_czk=excluded.price_czk,dex_price_czk=excluded.dex_price_czk,
    active=true,sort_order=excluded.sort_order,telemetry_key=excluded.telemetry_key,
    customer_price_czk=excluded.customer_price_czk,
    settlement_type=excluded.settlement_type,
    settlement_amount_czk=excluded.settlement_amount_czk,
    settlement_partner=excluded.settlement_partner,
    settlement_billing_enabled=excluded.settlement_billing_enabled,
    settlement_note=excluded.settlement_note,
    planned_product_name=excluded.planned_product_name,
    planned_product_sku=excluded.planned_product_sku,
    planned_price_czk=excluded.planned_price_czk,
    substitution_policy=excluded.substitution_policy,
    allowed_substitutes=excluded.allowed_substitutes,
    operator_instruction=excluded.operator_instruction,note=excluded.note,updated_at=now();

  insert into public.telemetry_planogram_counters (
    provider,machine_id,planogram_slot_id,selection_code,last_total_count,last_event_at
  )
  select pr.provider,v_machine_id,s.id,b.selection_code,41,now()
  from public.machine_coffee_buttons b
  join public.machine_planogram_slots s
    on s.machine_id=v_machine_id and s.slot_code=b.selection_code
  cross join (values ('IMA'),('GP')) pr(provider)
  where b.machine_id=v_machine_id and b.active
  on conflict (provider,machine_id,planogram_slot_id,selection_code) do update
  set last_total_count=excluded.last_total_count,last_event_at=excluded.last_event_at,
      updated_at=now();
end $$;

commit;
