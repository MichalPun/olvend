begin;

do $$
declare
  v_invoice_id bigint;
begin
  select id into v_invoice_id
  from public.finance_received_invoices
  where internal_number='FP260573' and document_number='26002070'
  for update;
  if v_invoice_id is null then raise exception 'Faktura FP260573 / 26002070 nebyla nalezena.'; end if;

  insert into public.finance_invoice_allocations(
    invoice_id,line_number,description,quantity,unit_code,unit_price,supplier_item_code,vat_rate,
    product_id,stock_relevant,mapping_confidence,net_amount,vat_amount,total_amount,source_payload
  ) values
    (v_invoice_id,1,'DARKOFF VEN White choco vending 1 Kg',72,'kg',200,'980',12,null,true,null,14400,1728,16128,
      jsonb_build_object('source','money_s3_text_row','source_unit_code','ks','queue_id',35,'recovered_by','finance_simandl_fp260573_items_v14')),
    (v_invoice_id,2,'DARKOFF VEN Choco drink 15 1 Kg',72,'kg',200,'983',12,null,true,null,14400,1728,16128,
      jsonb_build_object('source','money_s3_text_row','source_unit_code','ks','queue_id',35,'recovered_by','finance_simandl_fp260573_items_v14')),
    (v_invoice_id,3,'DARKOFF VEN. Čaj LEMON 1 Kg',45,'kg',200,'652/A',12,null,true,null,9000,1080,10080,
      jsonb_build_object('source','money_s3_text_row','source_unit_code','ks','queue_id',35,'recovered_by','finance_simandl_fp260573_items_v14'))
  on conflict(invoice_id,line_number) do update set
    description=excluded.description,quantity=excluded.quantity,unit_code=excluded.unit_code,unit_price=excluded.unit_price,
    supplier_item_code=excluded.supplier_item_code,vat_rate=excluded.vat_rate,stock_relevant=true,
    net_amount=excluded.net_amount,vat_amount=excluded.vat_amount,total_amount=excluded.total_amount,
    source_payload=excluded.source_payload;

  if (select round(sum(net_amount),2) from public.finance_invoice_allocations where invoice_id=v_invoice_id)<>37800
    or (select round(sum(vat_amount),2) from public.finance_invoice_allocations where invoice_id=v_invoice_id)<>4536
    or (select round(sum(total_amount),2) from public.finance_invoice_allocations where invoice_id=v_invoice_id)<>42336 then
    raise exception 'Kontrolní součty položek FP260573 nesouhlasí s fakturou.';
  end if;

  update public.finance_received_invoices
  set stock_receipt_status='needs_mapping',updated_at=now()
  where id=v_invoice_id and stock_receipt_status not in ('ordered','received');

  if not exists(
    select 1 from public.finance_invoice_events
    where invoice_id=v_invoice_id and event_type='line_items_recovered' and metadata->>'migration'='finance_simandl_fp260573_items_v14'
  ) then
    insert into public.finance_invoice_events(invoice_id,event_type,note,metadata)
    values(v_invoice_id,'line_items_recovered','Tři položky byly bezpečně obnoveny z textové vrstvy PDF Money S3.',
      jsonb_build_object('migration','finance_simandl_fp260573_items_v14','line_count',3,'net_total',37800,'vat_total',4536,'gross_total',42336));
  end if;

  update public.finance_document_intake_queue
  set extracted_payload=jsonb_set(extracted_payload,'{line_items}',jsonb_build_array(
    jsonb_build_object('description','DARKOFF VEN White choco vending 1 Kg','supplier_item_code','980','unit_code','kg','source_unit_code','ks','quantity',72,'unit_price',200,'vat_rate',12,'net_amount',14400,'vat_amount',1728,'total_amount',16128,'source','money_s3_text_row'),
    jsonb_build_object('description','DARKOFF VEN Choco drink 15 1 Kg','supplier_item_code','983','unit_code','kg','source_unit_code','ks','quantity',72,'unit_price',200,'vat_rate',12,'net_amount',14400,'vat_amount',1728,'total_amount',16128,'source','money_s3_text_row'),
    jsonb_build_object('description','DARKOFF VEN. Čaj LEMON 1 Kg','supplier_item_code','652/A','unit_code','kg','source_unit_code','ks','quantity',45,'unit_price',200,'vat_rate',12,'net_amount',9000,'vat_amount',1080,'total_amount',10080,'source','money_s3_text_row')
  ),true),processed_at=now()
  where invoice_id=v_invoice_id;
end;
$$;

commit;
