begin;

-- Money XML obsahuje u závazku kartu příjemce (název, účet a symboly).
-- Tyto údaje jsou nutné pro bezpečné vytvoření bankovního příkazu.
create or replace function public.finance_import_money_liabilities_v1(
  p_rows jsonb,p_file_name text,p_file_sha256 text,p_exported_at date,p_total_rows integer,p_is_final boolean default false
)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_row jsonb; v_total numeric(18,2); v_actual numeric(18,2); v_orderable numeric(18,2);
  v_status text; v_processed integer:=0; v_count integer; v_remaining numeric(18,2); v_ordered numeric(18,2);
begin
  if not public.finance_can_manage_v1() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>100 then raise exception 'Dávka musí obsahovat nejvýše 100 závazků.'; end if;
  if coalesce(p_file_sha256,'') !~ '^[0-9a-f]{64}$' then raise exception 'Neplatný SHA-256 otisk.'; end if;
  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_total:=coalesce((v_row->>'total_amount')::numeric,0);
    v_actual:=coalesce((v_row->>'actual_remaining_amount')::numeric,0);
    v_orderable:=coalesce((v_row->>'orderable_remaining_amount')::numeric,v_actual);
    v_status:=case when abs(v_total)<.01 then 'cancelled' when abs(v_actual)<.01 then 'paid'
      when abs(v_orderable)<abs(v_actual)-.01 then 'ordered'
      when abs(v_actual)<abs(v_total)-.01 then 'partially_paid' else 'unpaid' end;
    insert into public.finance_liabilities(
      source_provider,source_external_id,internal_number,series,series_number,description,category,
      issue_date,accounting_date,taxable_date,due_date,received_date,currency,total_amount,
      actual_remaining_amount,orderable_remaining_amount,ordered_amount,payment_status,accounting_status,
      money_payment_date,money_payment_document,payee_name,bank_account,bank_code,variable_symbol,
      constant_symbol,specific_symbol,payment_message,source_file_sha256,source_payload,imported_at,updated_at
    ) values (
      'money_s3',v_row->>'internal_number',v_row->>'internal_number',nullif(v_row->>'series',''),
      nullif(v_row->>'series_number','')::integer,coalesce(nullif(v_row->>'description',''),'Bez popisu'),
      public.finance_liability_category_v1(v_row->>'description'),nullif(v_row->>'issue_date','')::date,
      nullif(v_row->>'accounting_date','')::date,nullif(v_row->>'taxable_date','')::date,
      nullif(v_row->>'due_date','')::date,nullif(v_row->>'received_date','')::date,
      upper(coalesce(nullif(v_row->>'currency',''),'CZK')),v_total,v_actual,v_orderable,
      greatest(v_actual-v_orderable,0),v_status,'not_prepared',nullif(v_row->>'money_payment_date','')::date,
      nullif(v_row->>'money_payment_document',''),nullif(v_row->>'payee_name',''),
      nullif(v_row->>'bank_account',''),nullif(v_row->>'bank_code',''),nullif(v_row->>'variable_symbol',''),
      nullif(v_row->>'constant_symbol',''),nullif(v_row->>'specific_symbol',''),
      coalesce(nullif(v_row->>'payment_message',''),nullif(v_row->>'description','')),
      p_file_sha256,jsonb_strip_nulls(jsonb_build_object(
        'import','Money S3 závazky','source_remaining',v_actual,'source_orderable',v_orderable,
        'payee_guid',nullif(v_row->>'payee_guid','')
      )),now(),now()
    ) on conflict(source_provider,source_external_id) do update set
      internal_number=excluded.internal_number,series=excluded.series,series_number=excluded.series_number,
      description=excluded.description,category=excluded.category,issue_date=excluded.issue_date,
      accounting_date=excluded.accounting_date,taxable_date=excluded.taxable_date,due_date=excluded.due_date,
      received_date=excluded.received_date,currency=excluded.currency,total_amount=excluded.total_amount,
      actual_remaining_amount=excluded.actual_remaining_amount,orderable_remaining_amount=excluded.orderable_remaining_amount,
      ordered_amount=excluded.ordered_amount,payment_status=excluded.payment_status,
      money_payment_date=excluded.money_payment_date,money_payment_document=excluded.money_payment_document,
      payee_name=coalesce(excluded.payee_name,finance_liabilities.payee_name),
      bank_account=coalesce(excluded.bank_account,finance_liabilities.bank_account),
      bank_code=coalesce(excluded.bank_code,finance_liabilities.bank_code),
      variable_symbol=coalesce(excluded.variable_symbol,finance_liabilities.variable_symbol),
      constant_symbol=coalesce(excluded.constant_symbol,finance_liabilities.constant_symbol),
      specific_symbol=coalesce(excluded.specific_symbol,finance_liabilities.specific_symbol),
      payment_message=coalesce(excluded.payment_message,finance_liabilities.payment_message),
      source_file_sha256=excluded.source_file_sha256,
      source_payload=finance_liabilities.source_payload||excluded.source_payload,
      imported_at=now(),updated_at=now();
    v_processed:=v_processed+1;
  end loop;
  if p_is_final then
    select count(*),coalesce(sum(actual_remaining_amount),0),coalesce(sum(ordered_amount),0)
    into v_count,v_remaining,v_ordered from public.finance_liabilities where source_file_sha256=p_file_sha256;
    insert into public.finance_money_liability_imports(source_file_name,source_file_sha256,exported_at,liability_count,
      actual_remaining_amount,ordered_amount,imported_by,updated_at)
    values(p_file_name,p_file_sha256,p_exported_at,coalesce(v_count,p_total_rows),v_remaining,v_ordered,auth.uid(),now())
    on conflict(source_file_sha256) do update set source_file_name=excluded.source_file_name,exported_at=excluded.exported_at,
      liability_count=excluded.liability_count,actual_remaining_amount=excluded.actual_remaining_amount,
      ordered_amount=excluded.ordered_amount,imported_by=excluded.imported_by,updated_at=now();
  end if;
  return jsonb_build_object('processed',v_processed,'final',p_is_final);
end;
$$;

revoke all on function public.finance_import_money_liabilities_v1(jsonb,text,text,date,integer,boolean) from public,anon;
grant execute on function public.finance_import_money_liabilities_v1(jsonb,text,text,date,integer,boolean) to authenticated;

comment on function public.finance_import_money_liabilities_v1(jsonb,text,text,date,integer,boolean) is
  'Import závazků Money včetně názvu příjemce, bankovního účtu a platebních symbolů.';

notify pgrst,'reload schema';
commit;
