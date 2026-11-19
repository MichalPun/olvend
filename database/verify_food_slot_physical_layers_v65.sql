-- Nedestruktivni overeni tri fyzickych vrstev. Vsechny zmeny se vrati.
begin;

do $$
declare
  v_slot public.machine_planogram_slots%rowtype;
  v_products public.products[];
  v_primary text;
  v_first jsonb;
  v_repeat jsonb;
begin
  select * into v_slot from public.machine_planogram_slots
  where active is true and coalesce(capacity_units,0)>=5 and nullif(product_sku,'') is not null
  order by id limit 1 for update;
  select array_agg(product order by product.id) into v_products
  from (select p.* from public.products p where p.active is true and nullif(p.sku,'') is not null order by p.id limit 3) product;
  if v_slot.id is null or cardinality(v_products)<3 then raise exception 'Test fixture chybi.'; end if;
  v_primary:=v_products[1].sku;
  delete from public.machine_planogram_slot_layers where planogram_slot_id=v_slot.id;
  delete from public.machine_planogram_slot_layer_consumptions where planogram_slot_id=v_slot.id;
  update public.machine_planogram_slots set primary_product_id=v_products[1].id,
    primary_product_sku=v_primary,primary_product_name=v_products[1].name,
    product_sku=v_products[1].sku,product_name=v_products[1].name,current_units=5
  where id=v_slot.id;
  insert into public.machine_planogram_slot_layers(planogram_slot_id,layer_order,product_id,product_sku,product_name,quantity,source)
  values(v_slot.id,1,v_products[1].id,v_products[1].sku,v_products[1].name,1,'transaction_test'),
        (v_slot.id,2,v_products[2].id,v_products[2].sku,v_products[2].name,2,'transaction_test'),
        (v_slot.id,3,v_products[3].id,v_products[3].sku,v_products[3].name,2,'transaction_test');

  v_first:=public.consume_machine_planogram_slot_layers(v_slot.id,1,'verify-v65-first');
  v_repeat:=public.consume_machine_planogram_slot_layers(v_slot.id,1,'verify-v65-first');
  if v_first is distinct from v_repeat then raise exception 'Opakovany prodej neni idempotentni.'; end if;
  if (select current_units from public.machine_planogram_slots where id=v_slot.id)<>4 then raise exception 'Opakovany prodej odepsal zasobu dvakrat.'; end if;
  if (select product_sku from public.machine_planogram_slots where id=v_slot.id)<>v_products[2].sku then raise exception 'Predni vrstva se neprepla na druhou.'; end if;
  if (select primary_product_sku from public.machine_planogram_slots where id=v_slot.id)<>v_primary then raise exception 'Hlavni produkt se po prvnim doprodeji zmenil.'; end if;

  perform public.consume_machine_planogram_slot_layers(v_slot.id,2,'verify-v65-second');
  if (select product_sku from public.machine_planogram_slots where id=v_slot.id)<>v_products[3].sku then raise exception 'Predni vrstva se neprepla na treti.'; end if;
  perform public.consume_machine_planogram_slot_layers(v_slot.id,2,'verify-v65-third');
  if (select product_sku from public.machine_planogram_slots where id=v_slot.id)<>v_primary then raise exception 'Prazdna pozice se nevratila k hlavnimu produktu.'; end if;
  if (select primary_product_sku from public.machine_planogram_slots where id=v_slot.id)<>v_primary then raise exception 'Hlavni produkt se ztratil.'; end if;
end $$;

rollback;
