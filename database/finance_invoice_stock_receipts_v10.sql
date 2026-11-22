begin;

-- Finance může připravit příjemku i v instalaci, kde starší volitelný patch
-- přijatých dokladů ještě nebyl spuštěný.
alter table public.purchase_orders
  add column if not exists document_type text not null default 'invoice',
  add column if not exists due_date date;

alter table public.purchase_suppliers
  add column if not exists company_id text,
  add column if not exists tax_id text;

alter table public.finance_document_intake_queue
  add column if not exists document_class text;

alter table public.finance_received_invoices
  add column if not exists document_class text not null default 'invoice',
  add column if not exists stock_receipt_status text not null default 'not_applicable',
  add column if not exists purchase_order_id bigint references public.purchase_orders(id) on delete restrict;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='finance_received_invoices_document_class_check') then
    alter table public.finance_received_invoices add constraint finance_received_invoices_document_class_check
      check(document_class in ('invoice','credit_note','advance_invoice','delivery_note','reminder','payment_schedule','accounting_report','contract','other'));
  end if;
  if not exists(select 1 from pg_constraint where conname='finance_received_invoices_stock_receipt_status_check') then
    alter table public.finance_received_invoices add constraint finance_received_invoices_stock_receipt_status_check
      check(stock_receipt_status in ('not_applicable','needs_mapping','ready','ordered','received','blocked'));
  end if;
end $$;

create unique index if not exists finance_received_invoices_purchase_order_uidx
  on public.finance_received_invoices(purchase_order_id) where purchase_order_id is not null;

alter table public.finance_invoice_allocations
  add column if not exists quantity numeric(18,3),
  add column if not exists unit_code text,
  add column if not exists unit_price numeric(18,4),
  add column if not exists supplier_item_code text,
  add column if not exists ean text,
  add column if not exists product_id bigint references public.products(id) on delete restrict,
  add column if not exists stock_quantity_base_units numeric(18,3),
  add column if not exists stock_relevant boolean not null default false,
  add column if not exists mapping_confidence numeric(5,2),
  add column if not exists source_payload jsonb not null default '{}'::jsonb;

create index if not exists finance_invoice_allocations_product_idx
  on public.finance_invoice_allocations(product_id) where product_id is not null;

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
  if v_invoice.document_class not in ('invoice','delivery_note') then
    raise exception 'Dokument typu % nesmí založit skladovou příjemku.',v_invoice.document_class;
  end if;
  if v_invoice.purchase_order_id is not null then
    return jsonb_build_object('purchase_order_id',v_invoice.purchase_order_id,'status',v_invoice.stock_receipt_status,'existing',true);
  end if;
  if v_invoice.stock_receipt_status<>'ready' then
    raise exception 'Skladové položky ještě nejsou všechny bezpečně rozpoznané a spárované.';
  end if;
  select * into v_location from public.stock_locations where id=p_stock_location_id and active and location_type='warehouse';
  if not found then raise exception 'Vyberte aktivní skladové místo.'; end if;
  select count(*) into v_item_count from public.finance_invoice_allocations
    where invoice_id=p_invoice_id and stock_relevant and product_id is not null and coalesce(stock_quantity_base_units,quantity,0)>0;
  if v_item_count=0 then raise exception 'Faktura nemá žádné bezpečně spárované skladové položky.'; end if;
  if exists(select 1 from public.finance_invoice_allocations where invoice_id=p_invoice_id and stock_relevant and (product_id is null or coalesce(stock_quantity_base_units,quantity,0)<=0)) then
    raise exception 'Nejdřív spárujte všechny skladové položky s kartami zásob.';
  end if;

  select id into v_supplier_id from public.purchase_suppliers where lower(trim(name))=lower(trim(v_invoice.supplier_name)) limit 1;
  if v_supplier_id is null then
    insert into public.purchase_suppliers(name,company_id,tax_id,note)
    values(v_invoice.supplier_name,v_invoice.supplier_company_id,v_invoice.supplier_tax_id,'Založeno z přijaté faktury Finance.')
    returning id into v_supplier_id;
  end if;

  insert into public.purchase_orders(
    supplier_id,order_scope,status,document_type,order_date,delivery_date,due_date,
    invoice_number,received_stock_location_id,note
  ) values (
    v_supplier_id,'general','ordered','invoice',coalesce(v_invoice.issue_date,current_date),
    coalesce(v_invoice.received_date,v_invoice.issue_date,current_date),v_invoice.due_date,
    v_invoice.document_number,p_stock_location_id,
    format('[finance_invoice:%s] Automaticky připravená příjemka z přijaté faktury %s.',v_invoice.id,v_invoice.internal_number)
  ) returning id into v_order_id;

  insert into public.purchase_order_items(purchase_order_id,product_id,ordered_quantity,received_quantity,unit_cost,note)
  select v_order_id,a.product_id,sum(coalesce(a.stock_quantity_base_units,a.quantity)),0,
    case when sum(coalesce(a.stock_quantity_base_units,a.quantity))>0 then round((sum(coalesce(a.net_amount,a.quantity*a.unit_price))/sum(coalesce(a.stock_quantity_base_units,a.quantity)))::numeric,4) end,
    string_agg(coalesce(a.description,'Položka faktury'),E'\n' order by a.line_number)
  from public.finance_invoice_allocations a
  where a.invoice_id=p_invoice_id and a.stock_relevant and a.product_id is not null and coalesce(a.stock_quantity_base_units,a.quantity,0)>0
  group by a.product_id;

  update public.finance_received_invoices set purchase_order_id=v_order_id,stock_receipt_status='ordered',updated_at=now() where id=p_invoice_id;
  return jsonb_build_object('purchase_order_id',v_order_id,'status','ordered','item_count',v_item_count,'existing',false);
end;
$$;

create or replace function public.finance_confirm_stock_receipt_v1(p_invoice_id bigint)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_invoice public.finance_received_invoices;
  v_order public.purchase_orders;
  v_movements jsonb;
  v_result jsonb;
begin
  if not public.finance_can_manage_v1() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtext('finance-stock-receipt-'||p_invoice_id::text));
  select * into v_invoice from public.finance_received_invoices where id=p_invoice_id for update;
  if not found or v_invoice.purchase_order_id is null then raise exception 'Nejdřív připravte skladovou příjemku.'; end if;
  select * into v_order from public.purchase_orders where id=v_invoice.purchase_order_id for update;
  if v_order.status='received' then return jsonb_build_object('purchase_order_id',v_order.id,'status','received','existing',true); end if;
  if v_order.status<>'ordered' then raise exception 'Příjemka není ve stavu čekajícím na příjem.'; end if;
  if exists(
    select 1 from public.purchase_order_items i join public.products p on p.id=i.product_id
    where i.purchase_order_id=v_order.id and (p.requires_batch_tracking or p.expiry_tracking_mode<>'none')
  ) then raise exception 'Příjemka obsahuje zboží se šarží nebo expirací. Potvrďte ji ve Skladových příjmech.'; end if;
  if exists(select 1 from public.stock_movements_v13 where reference_type='finance_invoice' and reference_id=p_invoice_id::text) then
    raise exception 'Skladový pohyb k této faktuře už existuje.';
  end if;
  select jsonb_agg(jsonb_build_object(
    'product_id',i.product_id,'to_stock_location_id',v_order.received_stock_location_id,
    'movement_type','receipt','quantity_base_units',i.ordered_quantity,'unit_price',i.unit_cost,
    'reference_type','finance_invoice','reference_id',p_invoice_id::text,
    'note',format('Příjem z faktury %s · příjemka %s',v_invoice.internal_number,v_order.id)
  )) into v_movements from public.purchase_order_items i where i.purchase_order_id=v_order.id and i.ordered_quantity>0;
  if v_movements is null then raise exception 'Příjemka nemá žádné položky.'; end if;
  v_result:=public.apply_stock_movements_v13(v_movements);
  update public.purchase_order_items set received_quantity=ordered_quantity,updated_at=now() where purchase_order_id=v_order.id;
  update public.purchase_orders set status='received',received_at=now(),updated_at=now() where id=v_order.id;
  update public.finance_received_invoices set stock_receipt_status='received',updated_at=now() where id=p_invoice_id;
  return jsonb_build_object('purchase_order_id',v_order.id,'status','received','movement_result',v_result,'existing',false);
end;
$$;

revoke all on function public.finance_prepare_purchase_receipt_v1(bigint,bigint) from public,anon;
grant execute on function public.finance_prepare_purchase_receipt_v1(bigint,bigint) to authenticated,service_role;
revoke all on function public.finance_confirm_stock_receipt_v1(bigint) from public,anon;
grant execute on function public.finance_confirm_stock_receipt_v1(bigint) to authenticated,service_role;

comment on function public.finance_prepare_purchase_receipt_v1(bigint,bigint) is
  'Z položek přijaté faktury připraví skladovou příjemku; upomínky ani neskladové dokumenty ji založit nesmějí.';
comment on function public.finance_confirm_stock_receipt_v1(bigint) is
  'Atomicky potvrdí příjem položek bez povinné šarže/expirace a navýší sklad právě jednou.';

notify pgrst,'reload schema';
commit;
