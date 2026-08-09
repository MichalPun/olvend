-- Planogram [103] rhFS1 touch 21,5-2026-07-28.xlsx
-- Machine DB id 83, evidence 103, TID 587375, BVK Hády location_id 15.
-- All selections are 250 ml. New product SKUs 283-297 are created;
-- existing correct Espresso Macchiatto 250 ml SKU 256 is reused.
-- Recipe formula: gram ingredients = round(source 180 ml quantity * 250/180, 1);
-- cup is exactly 1 x SKU 255. Z1 uses Barbera Tris SKU 201 instead of legacy Elite SKU 5.

begin;

insert into public.products (
  name,sku,ean,product_category,usage_type,base_unit,vat_rate,
  purchase_price,sale_price,shelf_life_days,expiry_tracking_mode,
  expiry_warning_days,requires_batch_tracking,active,note,
  can_be_sold_directly,can_be_used_in_recipe,
  can_be_consumed_internally,can_be_used_in_service
)
select
  d.new_name,d.new_sku,null,s.product_category,s.usage_type,s.base_unit,
  s.vat_rate,s.purchase_price,d.sale_price,s.shelf_life_days,
  s.expiry_tracking_mode,s.expiry_warning_days,s.requires_batch_tracking,true,
  'Nová 250ml varianta pro rhFS1 touch / automat 103. Receptura 180 ml × 250/180, gramáže zaokrouhleny na 0,1 g; kelímek SKU 255.',
  s.can_be_sold_directly,s.can_be_used_in_recipe,
  s.can_be_consumed_internally,s.can_be_used_in_service
from (values
  ('224','283','Espresso 250 ml',18::numeric),
  ('226','284','Espresso Lungo 250 ml',18),
  ('227','285','Espresso Lungo bílé 250 ml',18),
  ('241','286','Latte Macchiato (E) 250 ml',18),
  ('221','287','Cappuccino (E) 250 ml',18),
  ('244','288','Moccaccino (E) 250 ml',18),
  ('257','289','Pistáciové Latté (E) 250 ml',18),
  ('239','290','Černá káva 250 ml',16),
  ('215','291','Bílá káva 250 ml',16),
  ('233','292','Kakaový nápoj 250 ml',16),
  ('230','293','Irish Cream 250 ml',16),
  ('247','294','OLMIKA Cappuccino 250 ml',16),
  ('234','295','Kakaový nápoj Cream 250 ml',16),
  ('248','296','Pistácie 250 ml',16),
  ('258','297','Pistáciová káva 250 ml',16)
) d(source_sku,new_sku,new_name,sale_price)
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
  where r.machine_type='product_catalog'
    and p.sku in ('283','284','285','286','287','288','289','290',
                  '291','292','293','294','295','296','297')
);

delete from public.recipes r
using public.products p
where r.selection_code='product:'||p.id::text
  and r.machine_type='product_catalog'
  and p.sku in ('283','284','285','286','287','288','289','290',
                '291','292','293','294','295','296','297');

insert into public.recipes (
  machine_id,machine_type,selection_code,name,sale_price,active,note
)
select null,'product_catalog','product:'||p.id::text,p.name,d.sale_price,true,
       '250 ml: zdrojová 180ml receptura × 250/180; g na 0,1; kelímek SKU 255.'
from (values
  ('283',18::numeric),('284',18),('285',18),('286',18),('287',18),
  ('288',18),('289',18),('290',16),('291',16),('292',16),
  ('293',16),('294',16),('295',16),('296',16),('297',16)
) d(sku,sale_price)
join public.products p on p.sku=d.sku;

insert into public.recipe_items (recipe_id,product_id,quantity,unit)
select
  nr.id,
  case when ip.sku in ('45','53') then cup.id else ri.product_id end,
  case
    when ip.sku in ('45','53') then 1
    when ri.unit='g' then round(ri.quantity * 250::numeric / 180::numeric,1)
    else ri.quantity
  end,
  ri.unit
from (values
  ('224','283'),('226','284'),('227','285'),('241','286'),('221','287'),
  ('244','288'),('257','289'),('239','290'),('215','291'),('233','292'),
  ('230','293'),('247','294'),('234','295'),('248','296'),('258','297')
) d(source_sku,new_sku)
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
  v_machine_id bigint := 83;
begin
  update public.machines
  set location_id=15,machine_type='Coffee',brand='Rheavendors',
      name='rhFS1 touch 21,5',sales_tracking_mode='telemetry',
      note=concat_ws(' ',nullif(note,''),
        'Planogram 2026-07-28; BVK Hády; TID 587375; všech 16 nápojů 250 ml; nové katalogové položky a přepočtené receptury.')
  where id=v_machine_id;

  insert into public.machine_external_links
    (machine_id,provider,external_machine_id,telemetry_enabled,note)
  values
    (v_machine_id,'IMA','587375',true,'TID 587375 pro automat 103 / BVK Hády.'),
    (v_machine_id,'GP','587375',true,'TID 587375 pro automat 103 / BVK Hády.')
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
           else 'Import planogramu 103 / 2026-07-28.' end
  from (values
    ('Z1','201',2000::numeric,1760::numeric,'g',1000::numeric,1),
    ('Z2','43',3000,2831,'g',1500,2),('Z3','48',3000,2778,'g',1000,3),
    ('Z4','47',3000,2790,'g',1000,4),('Z5','44',1500,1473,'g',500,5),
    ('Z6','46',3000,2802,'g',1000,6),('Z7','197',3000,2866,'g',1000,7),
    ('Z8','255',400,392,'ks',100,8),('Z9','183',100,100,'ks',100,9)
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
         0,d.grid_column,d.grid_row,d.sort_order,true,
         '250ml položka a přepočtená 250ml receptura; planogram 103 / 2026-07-28.'
  from (values
    ('1','283',18::numeric,1,4,1),('2','284',18,1,3,2),
    ('3','256',18,1,2,3),('4','285',18,1,1,4),
    ('5','286',18,2,4,5),('6','287',18,2,3,6),
    ('7','288',18,2,2,7),('8','289',18,2,1,8),
    ('9','290',16,3,4,9),('10','291',16,3,3,10),
    ('11','292',16,3,2,11),('12','293',16,3,1,12),
    ('13','294',16,4,4,13),('14','295',16,4,3,14),
    ('15','296',16,4,2,15),('16','297',16,4,1,16)
  ) d(code,sku,price,grid_column,grid_row,sort_order)
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
         'rhFS1 touch 250 ml slot; planogram 103 / TID 587375.'
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
  select pr.provider,v_machine_id,s.id,b.selection_code,0,now()
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
