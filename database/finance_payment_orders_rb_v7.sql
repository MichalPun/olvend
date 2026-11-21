begin;

alter table public.finance_liabilities
  add column if not exists payee_name text,
  add column if not exists bank_account text,
  add column if not exists bank_code text,
  add column if not exists variable_symbol text,
  add column if not exists constant_symbol text,
  add column if not exists specific_symbol text,
  add column if not exists payment_message text;

alter table public.finance_payment_batches
  add column if not exists title text,
  add column if not exists exported_at timestamptz,
  add column if not exists export_format text,
  add column if not exists export_file_name text,
  add column if not exists export_sha256 text;

alter table public.finance_payment_batch_items
  add column if not exists creditor_name text,
  add column if not exists creditor_bank_code text,
  add column if not exists constant_symbol text,
  add column if not exists specific_symbol text;

create or replace view public.finance_payment_candidates_v1 with (security_invoker=true) as
with invoice_orders as (
  select i.invoice_id,sum(i.amount) active_amount
  from public.finance_payment_batch_items i
  join public.finance_payment_batches b on b.id=i.batch_id
  where i.invoice_id is not null and i.source_kind='olvend'
    and i.status not in ('rejected','cancelled') and b.status<>'cancelled'
  group by i.invoice_id
), liability_orders as (
  select i.liability_id,sum(i.amount) active_amount
  from public.finance_payment_batch_items i
  join public.finance_payment_batches b on b.id=i.batch_id
  where i.liability_id is not null and i.source_kind='olvend'
    and i.status not in ('rejected','cancelled') and b.status<>'cancelled'
  group by i.liability_id
)
select 'invoice'::text target_type,i.id target_id,i.internal_number reference,
  i.supplier_name payee_name,coalesce(i.document_number,i.internal_number) description,
  i.due_date,i.currency,abs(i.total_amount) total_amount,
  greatest(coalesce(i.operational_remaining_amount,i.money_remaining_amount,abs(i.total_amount)),0) actual_remaining_amount,
  coalesce(o.active_amount,0) active_ordered_amount,
  greatest(coalesce(i.operational_remaining_amount,i.money_remaining_amount,abs(i.total_amount))-coalesce(o.active_amount,0),0) available_amount,
  coalesce(nullif(i.bank_account,''),p.creditor_account) bank_account,
  coalesce(nullif(i.bank_code,''),p.creditor_bank_code,
    nullif(substring(coalesce(i.bank_account,p.creditor_account) from '/([0-9]{4})$'),'')) bank_code,
  coalesce(nullif(i.variable_symbol,''),p.variable_symbol) variable_symbol,
  coalesce(nullif(i.constant_symbol,''),p.constant_symbol) constant_symbol,
  coalesce(nullif(i.specific_symbol,''),p.specific_symbol) specific_symbol,
  coalesce(nullif(i.payment_message,''),p.message,i.document_number) payment_message,
  i.payment_status,i.accounting_status
from public.finance_received_invoices i
left join invoice_orders o on o.invoice_id=i.id
left join lateral (
  select x.creditor_account,x.creditor_bank_code,x.variable_symbol,x.constant_symbol,x.specific_symbol,x.message
  from public.finance_payment_batch_items x where x.invoice_id=i.id
  order by x.id desc limit 1
) p on true
where i.payment_status not in ('paid','overpaid','cancelled')
union all
select 'liability'::text,l.id,l.internal_number,
  coalesce(l.payee_name,l.description),l.description,l.due_date,l.currency,abs(l.total_amount),
  greatest(l.actual_remaining_amount-l.bank_confirmed_amount,0),
  greatest(l.ordered_amount,0)+coalesce(o.active_amount,0),
  greatest(l.orderable_remaining_amount-coalesce(o.active_amount,0),0),
  coalesce(nullif(l.bank_account,''),p.creditor_account),
  coalesce(nullif(l.bank_code,''),p.creditor_bank_code,
    nullif(substring(coalesce(l.bank_account,p.creditor_account) from '/([0-9]{4})$'),'')),
  coalesce(nullif(l.variable_symbol,''),p.variable_symbol),
  coalesce(nullif(l.constant_symbol,''),p.constant_symbol),
  coalesce(nullif(l.specific_symbol,''),p.specific_symbol),
  coalesce(nullif(l.payment_message,''),p.message,l.description),
  l.payment_status,l.accounting_status
from public.finance_liabilities l
left join liability_orders o on o.liability_id=l.id
left join lateral (
  select x.creditor_account,x.creditor_bank_code,x.variable_symbol,x.constant_symbol,x.specific_symbol,x.message
  from public.finance_payment_batch_items x where x.liability_id=l.id
  order by x.id desc limit 1
) p on true
where l.payment_status not in ('paid','overpaid','cancelled');

create or replace function public.finance_digits_v1(p_value text,p_max integer default 30)
returns text language sql immutable set search_path=public,pg_temp as $$
  select left(regexp_replace(coalesce(p_value,''),'[^0-9]','','g'),p_max);
$$;

create or replace function public.finance_create_payment_batch_v2(
  p_items jsonb,
  p_debtor_account text default '6544188002/5500',
  p_title text default null
)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_item jsonb; v_batch public.finance_payment_batches; v_number text;
  v_type text; v_id bigint; v_amount numeric(18,2); v_available numeric(18,2);
  v_account text; v_bank text; v_vs text; v_ks text; v_ss text; v_date date;
  v_name text; v_message text; v_count integer:=0; v_total numeric(18,2):=0;
begin
  if not public.finance_can_manage_v1() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>500 then
    raise exception 'Vyberte 1 až 500 plateb.';
  end if;
  if p_debtor_account<>'6544188002/5500' then raise exception 'Účet plátce musí být 6544188002/5500.'; end if;

  perform pg_advisory_xact_lock(hashtext('finance-payment-batch-'||to_char(current_date,'YYYY')));
  select 'HP-'||to_char(current_date,'YYYY')||'-'||lpad((count(*)+1)::text,4,'0') into v_number
  from public.finance_payment_batches where created_at>=date_trunc('year',now());
  insert into public.finance_payment_batches(batch_number,title,debtor_account,currency,requested_execution_date,status,bank_provider,created_by)
  values(v_number,coalesce(nullif(trim(p_title),''),'Platby '||to_char(current_date,'DD.MM.YYYY')),p_debtor_account,'CZK',current_date,'draft','raiffeisenbank',auth.uid())
  returning * into v_batch;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_type:=v_item->>'target_type'; v_id:=(v_item->>'target_id')::bigint;
    v_amount:=round((v_item->>'amount')::numeric,2);
    v_account:=regexp_replace(split_part(coalesce(v_item->>'bank_account',''), '/', 1),'\s','','g');
    v_bank:=public.finance_digits_v1(coalesce(v_item->>'bank_code',split_part(coalesce(v_item->>'bank_account',''), '/', 2)),4);
    v_vs:=public.finance_digits_v1(v_item->>'variable_symbol',10);
    v_ks:=public.finance_digits_v1(v_item->>'constant_symbol',4);
    v_ss:=public.finance_digits_v1(v_item->>'specific_symbol',10);
    v_date:=coalesce(nullif(v_item->>'execution_date','')::date,current_date);
    v_name:=left(coalesce(nullif(trim(v_item->>'payee_name'),''),'Příjemce'),140);
    v_message:=left(coalesce(nullif(trim(v_item->>'message'),''),v_name),140);
    if v_amount<=0 then raise exception 'Částka musí být vyšší než nula.'; end if;
    if v_date<current_date then raise exception 'Datum splatnosti nesmí být v minulosti.'; end if;
    if v_account !~ '^[0-9]{2,10}(-[0-9]{2,10})?$' and v_account !~ '^[0-9]{1,6}-[0-9]{2,10}$' then
      raise exception 'Neplatné číslo účtu příjemce u položky %.',v_name;
    end if;
    if v_bank !~ '^[0-9]{4}$' then raise exception 'Chybí čtyřmístný kód banky u položky %.',v_name; end if;

    if v_type='invoice' then
      perform 1 from public.finance_received_invoices where id=v_id for update;
      select available_amount into v_available from public.finance_payment_candidates_v1 where target_type='invoice' and target_id=v_id;
      if v_available is null or v_amount>v_available+.01 then raise exception 'Částka překračuje zbývající částku faktury %.',v_id; end if;
      insert into public.finance_payment_batch_items(batch_id,invoice_id,amount,creditor_account,creditor_name,creditor_bank_code,
        variable_symbol,constant_symbol,specific_symbol,message,status,source_kind,requested_execution_date)
      values(v_batch.id,v_id,v_amount,v_account,v_name,v_bank,v_vs,v_ks,v_ss,v_message,'prepared','olvend',v_date);
      update public.finance_received_invoices set status='in_payment_batch',payment_status='ordered',updated_at=now() where id=v_id;
    elsif v_type='liability' then
      perform 1 from public.finance_liabilities where id=v_id for update;
      select available_amount into v_available from public.finance_payment_candidates_v1 where target_type='liability' and target_id=v_id;
      if v_available is null or v_amount>v_available+.01 then raise exception 'Částka překračuje zbývající částku závazku %.',v_id; end if;
      insert into public.finance_payment_batch_items(batch_id,liability_id,amount,creditor_account,creditor_name,creditor_bank_code,
        variable_symbol,constant_symbol,specific_symbol,message,status,source_kind,requested_execution_date)
      values(v_batch.id,v_id,v_amount,v_account,v_name,v_bank,v_vs,v_ks,v_ss,v_message,'prepared','olvend',v_date);
      update public.finance_liabilities set payment_status='ordered',updated_at=now() where id=v_id;
    else raise exception 'Neznámý typ placené položky.';
    end if;
    v_count:=v_count+1; v_total:=v_total+v_amount;
  end loop;

  update public.finance_payment_batches set payment_count=v_count,total_amount=v_total,
    requested_execution_date=(select min(requested_execution_date) from public.finance_payment_batch_items where batch_id=v_batch.id),
    status='ready' where id=v_batch.id;
  return jsonb_build_object('id',v_batch.id,'batch_number',v_number,'payment_count',v_count,'total_amount',v_total,'status','ready');
end;
$$;

create or replace function public.finance_get_payment_batch_export_v1(p_batch_id bigint)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select case when public.finance_can_manage_v1() then jsonb_build_object(
    'batch',to_jsonb(b),
    'items',coalesce((select jsonb_agg(to_jsonb(i) order by i.requested_execution_date,i.id)
      from public.finance_payment_batch_items i where i.batch_id=b.id and i.status not in ('rejected','cancelled')),'[]'::jsonb)
  ) else null end
  from public.finance_payment_batches b where b.id=p_batch_id;
$$;

create or replace function public.finance_record_payment_batch_export_v1(p_batch_id bigint,p_file_name text,p_sha256 text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_batch public.finance_payment_batches;
begin
  if not public.finance_can_manage_v1() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  if coalesce(p_file_name,'')='' or coalesce(p_sha256,'') !~ '^[0-9a-f]{64}$' then raise exception 'Neplatné údaje exportu.'; end if;
  update public.finance_payment_batches set exported_at=now(),export_format='ABO_KPC',export_file_name=p_file_name,export_sha256=p_sha256
  where id=p_batch_id and status<>'cancelled' returning * into v_batch;
  if v_batch.id is null then raise exception 'Platební dávka nebyla nalezena.'; end if;
  return jsonb_build_object('id',v_batch.id,'batch_number',v_batch.batch_number,'exported_at',v_batch.exported_at);
end;
$$;

grant select on public.finance_payment_candidates_v1 to authenticated;
revoke all on function public.finance_create_payment_batch_v2(jsonb,text,text) from public,anon;
grant execute on function public.finance_create_payment_batch_v2(jsonb,text,text) to authenticated;
revoke all on function public.finance_get_payment_batch_export_v1(bigint) from public,anon;
grant execute on function public.finance_get_payment_batch_export_v1(bigint) to authenticated;
revoke all on function public.finance_record_payment_batch_export_v1(bigint,text,text) from public,anon;
grant execute on function public.finance_record_payment_batch_export_v1(bigint,text,text) to authenticated;

comment on view public.finance_payment_candidates_v1 is 'Společný výběr faktur a ostatních závazků pro částečné i plné úhrady.';
comment on function public.finance_create_payment_batch_v2(jsonb,text,text) is 'Vytvoří kontrolovatelnou dávku s částkou, účtem, symboly a datem pro každou vybranou položku.';

notify pgrst,'reload schema';
commit;
