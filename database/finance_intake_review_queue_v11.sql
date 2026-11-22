begin;

drop policy if exists finance_internal_private_document_read on storage.objects;
create policy finance_internal_private_document_read on storage.objects
  for select to authenticated
  using(bucket_id='finance-private' and public.finance_can_manage_v1());

create or replace function public.finance_review_intake_document_v1(
  p_queue_id bigint,
  p_action text,
  p_invoice_id bigint default null,
  p_values jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_queue public.finance_document_intake_queue%rowtype;
  v_invoice public.finance_received_invoices%rowtype;
  v_payload jsonb;
  v_class text;
  v_document_type text;
  v_internal_number text;
  v_supplier text;
  v_document_number text;
  v_currency text;
  v_total numeric(18,2);
  v_net numeric(18,2);
  v_vat numeric(18,2);
  v_issue_date date;
  v_taxable_date date;
  v_due_date date;
  v_bank_account text;
  v_iban text;
  v_variable_symbol text;
  v_line jsonb;
  v_line_number integer := 0;
  v_line_count integer := 0;
  v_reason text;
begin
  if not public.finance_can_manage_v1() then
    raise exception 'Přístup odepřen.' using errcode='42501';
  end if;

  select * into v_queue
  from public.finance_document_intake_queue
  where id=p_queue_id
  for update;
  if not found then raise exception 'Dokument ve frontě nebyl nalezen.'; end if;

  p_action:=lower(trim(coalesce(p_action,'')));
  v_payload:=coalesce(v_queue.extracted_payload,'{}'::jsonb);

  if p_action='ignore' then
    if v_queue.invoice_id is not null then raise exception 'Přiřazený dokument už nelze ignorovat.'; end if;
    if v_queue.status not in ('needs_review','failed','queued') then raise exception 'Dokument v tomto stavu nelze ignorovat.'; end if;
    v_reason:=coalesce(nullif(trim(p_values->>'reason'),''),'Ruční rozhodnutí ve frontě kontroly');
    update public.finance_document_intake_queue set
      status='ignored',processed_at=now(),error_message=null,
      warnings=coalesce(warnings,'[]'::jsonb)||jsonb_build_array(v_reason),
      extracted_payload=v_payload||jsonb_build_object('reviewed_by',auth.uid(),'reviewed_at',now(),'review_action','ignore')
    where id=p_queue_id;
    return jsonb_build_object('queue_id',p_queue_id,'status','ignored');
  end if;

  if p_action='reopen' then
    if v_queue.invoice_id is not null then raise exception 'Přiřazený dokument už nelze vrátit do kontroly.'; end if;
    if v_queue.status not in ('ignored','failed') then raise exception 'Do kontroly lze vrátit pouze ignorovaný nebo chybný dokument.'; end if;
    update public.finance_document_intake_queue set
      status='needs_review',processing_started_at=null,processed_at=now(),error_message=null,
      extracted_payload=v_payload||jsonb_build_object('reviewed_by',auth.uid(),'reviewed_at',now(),'review_action','reopen')
    where id=p_queue_id;
    return jsonb_build_object('queue_id',p_queue_id,'status','needs_review');
  end if;

  if p_action='attach' then
    if v_queue.status<>'needs_review' or v_queue.invoice_id is not null then raise exception 'Přiřadit lze pouze nepřiřazený dokument ke kontrole.'; end if;
    select * into v_invoice from public.finance_received_invoices where id=p_invoice_id for update;
    if not found then raise exception 'Cílová faktura nebyla nalezena.'; end if;
    insert into public.finance_invoice_attachments(
      invoice_id,kind,storage_bucket,storage_path,file_name,mime_type,size_bytes,sha256,immutable,uploaded_by
    ) values (
      v_invoice.id,
      case when coalesce(v_queue.document_class,'')='reminder' or lower(v_queue.file_name)~'(upom|remind|vyzva|výzva)' then 'supporting' else 'original' end,
      'finance-private',v_queue.storage_path,v_queue.file_name,v_queue.mime_type,v_queue.size_bytes,v_queue.sha256,true,auth.uid()
    ) on conflict(invoice_id,sha256) do nothing;
    update public.finance_document_intake_queue set
      invoice_id=v_invoice.id,status='invoice_created',processed_at=now(),error_message=null,
      extracted_payload=v_payload||jsonb_build_object('matched_by','manual_review','reviewed_by',auth.uid(),'reviewed_at',now())
    where id=p_queue_id;
    insert into public.finance_invoice_events(invoice_id,event_type,note,metadata,actor_user_id)
    values(v_invoice.id,'intake_attachment_assigned','Dokument z e-mailové fronty byl ručně přiřazen.',jsonb_build_object('queue_id',p_queue_id,'file_name',v_queue.file_name),auth.uid());
    return jsonb_build_object('queue_id',p_queue_id,'status','invoice_created','invoice_id',v_invoice.id,'action','attach');
  end if;

  if p_action<>'create' then raise exception 'Neznámá akce kontroly dokumentu.'; end if;
  if v_queue.status<>'needs_review' or v_queue.invoice_id is not null then raise exception 'Nový doklad lze založit pouze z nepřiřazeného dokumentu ke kontrole.'; end if;

  v_class:=coalesce(nullif(p_values->>'document_class',''),nullif(v_queue.document_class,''),nullif(v_payload->>'document_class',''),'invoice');
  if v_class not in ('invoice','credit_note','advance_invoice') then
    raise exception 'Dokument typu % nelze založit jako přijatou fakturu. Lze jej přiřadit k existujícímu dokladu nebo ignorovat.',v_class;
  end if;
  v_document_type:=case v_class when 'credit_note' then 'credit_note' when 'advance_invoice' then 'advance_invoice' else 'invoice' end;
  v_supplier:=trim(coalesce(p_values->>'supplier_name',''));
  v_document_number:=trim(coalesce(nullif(p_values->>'document_number',''),v_payload->>'document_number',''));
  if v_supplier='' then raise exception 'Doplňte dodavatele.'; end if;
  if v_document_number='' then raise exception 'Doplňte číslo dokladu.'; end if;

  begin v_total:=coalesce(nullif(p_values->>'total_amount','')::numeric,nullif(v_payload->>'total_amount','')::numeric); exception when others then raise exception 'Celková částka nemá platný formát.'; end;
  if v_total is null or abs(v_total)<0.01 then raise exception 'Doplňte nenulovou celkovou částku.'; end if;
  begin v_net:=nullif(p_values->>'net_amount','')::numeric; exception when others then raise exception 'Částka bez DPH nemá platný formát.'; end;
  begin v_vat:=nullif(p_values->>'vat_amount','')::numeric; exception when others then raise exception 'DPH nemá platný formát.'; end;
  if v_net is null and v_vat is null then v_net:=v_total; v_vat:=0;
  elsif v_net is null then v_net:=v_total-v_vat;
  elsif v_vat is null then v_vat:=v_total-v_net;
  end if;
  if abs((v_net+v_vat)-v_total)>1 then raise exception 'Součet částky bez DPH a DPH neodpovídá celkové částce.'; end if;

  v_currency:=upper(coalesce(nullif(p_values->>'currency',''),nullif(v_payload->>'currency',''),'CZK'));
  if v_currency !~ '^[A-Z]{3}$' then raise exception 'Měna musí mít třípísmenný kód.'; end if;
  begin v_issue_date:=nullif(coalesce(nullif(p_values->>'issue_date',''),v_payload->>'issue_date'),'')::date; exception when others then raise exception 'Datum vystavení nemá platný formát.'; end;
  begin v_taxable_date:=nullif(coalesce(nullif(p_values->>'taxable_date',''),v_payload->>'taxable_date'),'')::date; exception when others then raise exception 'DUZP nemá platný formát.'; end;
  begin v_due_date:=nullif(coalesce(nullif(p_values->>'due_date',''),v_payload->>'due_date'),'')::date; exception when others then raise exception 'Datum splatnosti nemá platný formát.'; end;
  v_bank_account:=nullif(trim(coalesce(nullif(p_values->>'bank_account',''),v_payload->>'bank_account','')),'');
  v_iban:=nullif(upper(regexp_replace(coalesce(nullif(p_values->>'iban',''),v_payload->>'iban',''),'\s','','g')),'');
  v_variable_symbol:=nullif(regexp_replace(coalesce(nullif(p_values->>'variable_symbol',''),v_payload->>'variable_symbol',''),'\D','','g'),'');

  insert into public.finance_received_invoices(
    internal_number,source_provider,source_external_id,source_received_at,source_payload,
    supplier_name,supplier_company_id,supplier_tax_id,document_number,document_type,document_class,issue_date,taxable_date,due_date,
    currency,net_amount,vat_amount,total_amount,bank_account,bank_code,iban,variable_symbol,
    category,cost_center,extraction_confidence,extraction_warnings,status,payment_status,handoff_status,note
  ) values (
    null,'email','intake:'||v_queue.id,coalesce(v_queue.message_received_at,v_queue.discovered_at),
    jsonb_build_object('queue_id',v_queue.id,'sender_address',v_queue.sender_address,'subject',v_queue.subject,'extracted',v_payload),
    v_supplier,nullif(coalesce(nullif(p_values->>'supplier_company_id',''),v_payload->>'supplier_company_id'),'') ,nullif(upper(coalesce(nullif(p_values->>'supplier_tax_id',''),v_payload->>'supplier_tax_id','')),'') ,v_document_number,v_document_type,v_class,v_issue_date,v_taxable_date,v_due_date,
    v_currency,v_net,v_vat,v_total,v_bank_account,case when v_bank_account like '%/%' then split_part(v_bank_account,'/',2) end,v_iban,v_variable_symbol,
    nullif(p_values->>'category',''),nullif(p_values->>'cost_center',''),v_queue.extraction_confidence,coalesce(v_queue.warnings,'[]'::jsonb),
    'approval','unpaid','not_ready','Založeno po ruční kontrole dokumentu z fakturačního e-mailu.'
  ) returning * into v_invoice;
  v_internal_number:=v_invoice.internal_number;

  insert into public.finance_invoice_attachments(
    invoice_id,kind,storage_bucket,storage_path,file_name,mime_type,size_bytes,sha256,immutable,uploaded_by
  ) values (
    v_invoice.id,'original','finance-private',v_queue.storage_path,v_queue.file_name,v_queue.mime_type,v_queue.size_bytes,v_queue.sha256,true,auth.uid()
  );

  if jsonb_typeof(v_payload->'line_items')='array' then
    for v_line in select value from jsonb_array_elements(v_payload->'line_items') loop
      v_line_number:=v_line_number+1;
      if coalesce(trim(v_line->>'description'),'')='' then continue; end if;
      insert into public.finance_invoice_allocations(
        invoice_id,line_number,description,quantity,unit_code,unit_price,supplier_item_code,ean,
        stock_relevant,net_amount,vat_amount,total_amount,source_payload
      ) values (
        v_invoice.id,v_line_number,v_line->>'description',nullif(v_line->>'quantity','')::numeric,nullif(v_line->>'unit_code',''),
        nullif(v_line->>'unit_price','')::numeric,nullif(v_line->>'supplier_item_code',''),nullif(v_line->>'ean',''),
        true,coalesce(nullif(v_line->>'total_amount','')::numeric,0),0,coalesce(nullif(v_line->>'total_amount','')::numeric,0),
        jsonb_build_object('source','intake_review','queue_id',v_queue.id)
      );
      v_line_count:=v_line_count+1;
    end loop;
  end if;
  if v_line_count>0 and v_class='invoice' then
    update public.finance_received_invoices set stock_receipt_status='needs_mapping' where id=v_invoice.id;
  end if;

  update public.finance_document_intake_queue set
    invoice_id=v_invoice.id,status='invoice_created',document_class=v_class,processed_at=now(),error_message=null,
    extracted_payload=v_payload||jsonb_build_object('matched_by','manual_review_create','reviewed_by',auth.uid(),'reviewed_at',now(),'internal_number',v_internal_number)
  where id=p_queue_id;
  insert into public.finance_invoice_events(invoice_id,event_type,to_status,note,metadata,actor_user_id)
  values(v_invoice.id,'created_from_intake_review','approval','Doklad byl založen po ruční kontrole e-mailové přílohy.',jsonb_build_object('queue_id',p_queue_id,'file_name',v_queue.file_name,'line_count',v_line_count),auth.uid());

  return jsonb_build_object('queue_id',p_queue_id,'status','invoice_created','invoice_id',v_invoice.id,'internal_number',v_internal_number,'line_count',v_line_count,'action','create');
end;
$$;

revoke all on function public.finance_review_intake_document_v1(bigint,text,bigint,jsonb) from public,anon;
grant execute on function public.finance_review_intake_document_v1(bigint,text,bigint,jsonb) to authenticated,service_role;

comment on function public.finance_review_intake_document_v1(bigint,text,bigint,jsonb) is
  'Auditované rozhodnutí nad přílohou ve frontě: založit doklad, přiřadit, ignorovat nebo vrátit ke kontrole.';

notify pgrst,'reload schema';
commit;
