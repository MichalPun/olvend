begin;

alter table public.finance_invoice_allocations
  add column if not exists stock_quantity_base_units numeric(18,3);

create or replace function public.finance_map_invoice_line_v1(
  p_allocation_id bigint,
  p_product_id bigint,
  p_remember_for_supplier boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_line public.finance_invoice_allocations%rowtype;
  v_invoice public.finance_received_invoices%rowtype;
  v_product public.products%rowtype;
  v_invoice_unit text;
  v_base_unit text;
  v_stock_quantity numeric(18,3);
  v_supplier_id bigint;
  v_stock_status text;
begin
  if not public.finance_can_manage_v1() then
    raise exception 'Přístup odepřen.' using errcode='42501';
  end if;

  select * into v_line
  from public.finance_invoice_allocations
  where id=p_allocation_id
  for update;
  if not found then raise exception 'Položka faktury nebyla nalezena.'; end if;

  select * into v_invoice
  from public.finance_received_invoices
  where id=v_line.invoice_id
  for update;
  if v_invoice.stock_receipt_status in ('ordered','received') then
    raise exception 'Položky už nelze měnit, protože příjemka byla připravena nebo potvrzena.';
  end if;
  if not v_line.stock_relevant then
    raise exception 'Tato položka není označena jako skladová.';
  end if;

  select * into v_product
  from public.products
  where id=p_product_id and active
  for share;
  if not found then raise exception 'Vybraná skladová karta není aktivní.'; end if;

  v_invoice_unit:=lower(trim(coalesce(v_line.unit_code,'')));
  v_base_unit:=lower(trim(coalesce(v_product.base_unit,'')));
  v_stock_quantity:=case
    when v_invoice_unit=v_base_unit then v_line.quantity
    when v_invoice_unit='kg' and v_base_unit='g' then v_line.quantity*1000
    when v_invoice_unit='g' and v_base_unit='kg' then v_line.quantity/1000
    when v_invoice_unit='l' and v_base_unit='ml' then v_line.quantity*1000
    when v_invoice_unit='ml' and v_base_unit='l' then v_line.quantity/1000
    else null
  end;
  if coalesce(v_stock_quantity,0)<=0 then
    raise exception 'Jednotku % z faktury nelze bezpečně převést na skladovou jednotku %.',coalesce(nullif(v_invoice_unit,''),'—'),coalesce(nullif(v_base_unit,''),'—');
  end if;

  update public.finance_invoice_allocations
  set product_id=v_product.id,
      stock_quantity_base_units=round(v_stock_quantity,3),
      mapping_confidence=100,
      source_payload=coalesce(source_payload,'{}'::jsonb)||jsonb_build_object(
        'mapping_method','manual',
        'mapped_by',auth.uid(),
        'mapped_at',now(),
        'stock_base_unit',v_product.base_unit,
        'stock_quantity_base_units',round(v_stock_quantity,3)
      )
  where id=v_line.id;

  if p_remember_for_supplier and nullif(trim(v_line.supplier_item_code),'') is not null then
    select id into v_supplier_id
    from public.purchase_suppliers
    where (nullif(v_invoice.supplier_company_id,'') is not null and company_id=v_invoice.supplier_company_id)
       or lower(trim(name))=lower(trim(v_invoice.supplier_name))
    order by case when company_id=v_invoice.supplier_company_id then 0 else 1 end,id
    limit 1;

    if v_supplier_id is null then
      insert into public.purchase_suppliers(name,company_id,tax_id,note)
      values(v_invoice.supplier_name,v_invoice.supplier_company_id,v_invoice.supplier_tax_id,'Založeno při ručním párování přijaté faktury ve Finance.')
      on conflict(name) do update set
        company_id=coalesce(public.purchase_suppliers.company_id,excluded.company_id),
        tax_id=coalesce(public.purchase_suppliers.tax_id,excluded.tax_id),
        active=true
      returning id into v_supplier_id;
    end if;

    insert into public.supplier_product_mappings(
      supplier_id,product_id,supplier_item_code,ean,supplier_item_name,invoice_unit_code,
      base_units_per_invoice_unit,last_unit_price,last_seen_at,active
    ) values (
      v_supplier_id,v_product.id,trim(v_line.supplier_item_code),nullif(trim(v_line.ean),''),v_line.description,
      v_line.unit_code,round(v_stock_quantity/nullif(v_line.quantity,0),6),v_line.unit_price,now(),true
    )
    on conflict(supplier_id,supplier_item_code) do update set
      product_id=excluded.product_id,
      ean=coalesce(excluded.ean,public.supplier_product_mappings.ean),
      supplier_item_name=excluded.supplier_item_name,
      invoice_unit_code=excluded.invoice_unit_code,
      base_units_per_invoice_unit=excluded.base_units_per_invoice_unit,
      last_unit_price=excluded.last_unit_price,
      last_seen_at=excluded.last_seen_at,
      active=true;
  end if;

  v_stock_status:=case
    when exists(
      select 1 from public.finance_invoice_allocations
      where invoice_id=v_invoice.id and stock_relevant
        and (product_id is null or coalesce(stock_quantity_base_units,0)<=0)
    ) then 'needs_mapping'
    else 'ready'
  end;

  update public.finance_received_invoices
  set stock_receipt_status=v_stock_status,updated_at=now()
  where id=v_invoice.id;

  insert into public.finance_invoice_events(invoice_id,event_type,note,metadata,actor_user_id)
  values(
    v_invoice.id,'stock_line_mapped',
    format('Položka %s byla spárována se skladovou kartou %s.',v_line.line_number,v_product.name),
    jsonb_build_object('allocation_id',v_line.id,'line_number',v_line.line_number,'product_id',v_product.id,'stock_quantity',round(v_stock_quantity,3),'stock_unit',v_product.base_unit,'remembered',p_remember_for_supplier),
    auth.uid()
  );

  return jsonb_build_object(
    'invoice_id',v_invoice.id,
    'allocation_id',v_line.id,
    'product_id',v_product.id,
    'product_name',v_product.name,
    'stock_quantity',round(v_stock_quantity,3),
    'stock_unit',v_product.base_unit,
    'stock_receipt_status',v_stock_status
  );
end;
$$;

create or replace function public.finance_create_and_map_invoice_product_v1(
  p_allocation_id bigint,
  p_name text,
  p_sku text default null,
  p_base_unit text default 'kg',
  p_product_category text default 'ingredient'
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_product_id bigint;
  v_usage_type text;
  v_result jsonb;
begin
  if not public.finance_can_manage_v1() then
    raise exception 'Přístup odepřen.' using errcode='42501';
  end if;
  p_name:=trim(coalesce(p_name,''));
  p_sku:=nullif(trim(coalesce(p_sku,'')),'');
  p_base_unit:=lower(trim(coalesce(p_base_unit,'')));
  p_product_category:=lower(trim(coalesce(p_product_category,'')));
  if p_name='' then raise exception 'Doplňte název skladové karty.'; end if;
  if p_base_unit not in ('ks','kg','g','l','ml') then raise exception 'Nepodporovaná skladová jednotka.'; end if;
  if p_product_category not in ('beverage_ready','snack_ready','food_ready','ingredient','consumable','service_material','spare_part') then
    raise exception 'Nepodporovaný typ skladové karty.';
  end if;
  if p_sku is not null and exists(select 1 from public.products where lower(sku)=lower(p_sku)) then
    raise exception 'Skladová karta se SKU % už existuje. Vyberte ji v seznamu.',p_sku;
  end if;

  v_usage_type:=case
    when p_product_category in ('beverage_ready','snack_ready','food_ready') then 'direct_sale'
    when p_product_category='ingredient' then 'recipe_consumption'
    when p_product_category='consumable' then 'internal_consumption'
    else 'service_use'
  end;

  insert into public.products(
    name,sku,product_category,usage_type,base_unit,
    can_be_sold_directly,can_be_used_in_recipe,can_be_consumed_internally,can_be_used_in_service,
    active,note
  ) values (
    p_name,p_sku,p_product_category,v_usage_type,p_base_unit,
    p_product_category in ('beverage_ready','snack_ready','food_ready'),
    p_product_category='ingredient',
    p_product_category='consumable',
    p_product_category in ('service_material','spare_part'),
    true,'Skladová karta založená při párování položky přijaté faktury.'
  ) returning id into v_product_id;

  v_result:=public.finance_map_invoice_line_v1(p_allocation_id,v_product_id,true);
  return v_result||jsonb_build_object('created',true);
end;
$$;

-- Příjemka musí používat množství v základní jednotce vybrané skladové karty.
create or replace function public.finance_prepare_purchase_receipt_v1(p_invoice_id bigint,p_stock_location_id bigint)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_invoice public.finance_received_invoices;
  v_supplier_id bigint;
  v_order_id bigint;
  v_location public.stock_locations;
  v_item_count integer;
begin
  if not public.finance_can_manage_v1() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  select * into v_invoice from public.finance_received_invoices where id=p_invoice_id for update;
  if not found then raise exception 'Faktura nebyla nalezena.'; end if;
  if v_invoice.document_class not in ('invoice','delivery_note') then raise exception 'Dokument typu % nesmí založit skladovou příjemku.',v_invoice.document_class; end if;
  if v_invoice.purchase_order_id is not null then return jsonb_build_object('purchase_order_id',v_invoice.purchase_order_id,'status',v_invoice.stock_receipt_status,'existing',true); end if;
  if v_invoice.stock_receipt_status<>'ready' then raise exception 'Skladové položky ještě nejsou všechny bezpečně rozpoznané a spárované.'; end if;
  select * into v_location from public.stock_locations where id=p_stock_location_id and active and location_type='warehouse';
  if not found then raise exception 'Vyberte aktivní skladové místo.'; end if;
  select count(*) into v_item_count from public.finance_invoice_allocations where invoice_id=p_invoice_id and stock_relevant and product_id is not null and coalesce(stock_quantity_base_units,0)>0;
  if v_item_count=0 then raise exception 'Faktura nemá žádné bezpečně spárované skladové položky.'; end if;
  if exists(select 1 from public.finance_invoice_allocations where invoice_id=p_invoice_id and stock_relevant and (product_id is null or coalesce(stock_quantity_base_units,0)<=0)) then raise exception 'Nejdřív spárujte všechny skladové položky s kartami zásob.'; end if;

  select id into v_supplier_id from public.purchase_suppliers where lower(trim(name))=lower(trim(v_invoice.supplier_name)) limit 1;
  if v_supplier_id is null then
    insert into public.purchase_suppliers(name,company_id,tax_id,note)
    values(v_invoice.supplier_name,v_invoice.supplier_company_id,v_invoice.supplier_tax_id,'Založeno z přijaté faktury Finance.')
    returning id into v_supplier_id;
  end if;

  insert into public.purchase_orders(supplier_id,order_scope,status,document_type,order_date,delivery_date,due_date,invoice_number,received_stock_location_id,note)
  values(v_supplier_id,'general','ordered','invoice',coalesce(v_invoice.issue_date,current_date),coalesce(v_invoice.received_date,v_invoice.issue_date,current_date),v_invoice.due_date,v_invoice.document_number,p_stock_location_id,format('[finance_invoice:%s] Automaticky připravená příjemka z přijaté faktury %s.',v_invoice.id,v_invoice.internal_number))
  returning id into v_order_id;

  insert into public.purchase_order_items(purchase_order_id,product_id,ordered_quantity,received_quantity,unit_cost,note)
  select v_order_id,a.product_id,sum(a.stock_quantity_base_units),0,
    case when sum(a.stock_quantity_base_units)>0 then round((sum(coalesce(a.net_amount,a.quantity*a.unit_price))/sum(a.stock_quantity_base_units))::numeric,4) end,
    string_agg(coalesce(a.description,'Položka faktury'),E'\n' order by a.line_number)
  from public.finance_invoice_allocations a
  where a.invoice_id=p_invoice_id and a.stock_relevant and a.product_id is not null and coalesce(a.stock_quantity_base_units,0)>0
  group by a.product_id;

  update public.finance_received_invoices set purchase_order_id=v_order_id,stock_receipt_status='ordered',updated_at=now() where id=p_invoice_id;
  return jsonb_build_object('purchase_order_id',v_order_id,'status','ordered','item_count',v_item_count,'existing',false);
end;
$$;

revoke all on function public.finance_map_invoice_line_v1(bigint,bigint,boolean) from public,anon;
grant execute on function public.finance_map_invoice_line_v1(bigint,bigint,boolean) to authenticated,service_role;
revoke all on function public.finance_create_and_map_invoice_product_v1(bigint,text,text,text,text) from public,anon;
grant execute on function public.finance_create_and_map_invoice_product_v1(bigint,text,text,text,text) to authenticated,service_role;

comment on function public.finance_map_invoice_line_v1(bigint,bigint,boolean) is
  'Bezpečně spáruje vytěžený řádek přijaté faktury se skladovou kartou, přepočte základní jednotku a volitelně si zapamatuje dodavatelský kód.';
comment on function public.finance_create_and_map_invoice_product_v1(bigint,text,text,text,text) is
  'Založí novou skladovou kartu z řádku přijaté faktury a ve stejné transakci ji spáruje.';

notify pgrst,'reload schema';
commit;
