begin;

alter table public.finance_payment_matches
  add column if not exists note text;

create or replace function public.finance_refresh_payment_target_v1(
  p_target_kind text,
  p_target_id bigint
)
returns void
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_amount numeric(18,2):=0;
  v_last_paid date;
begin
  select coalesce(sum(m.matched_amount),0),max(t.booked_on)
    into v_amount,v_last_paid
  from public.finance_payment_matches m
  join public.finance_bank_transactions t on t.id=m.bank_transaction_id
  where m.status='confirmed'
    and ((p_target_kind='invoice' and m.invoice_id=p_target_id)
      or (p_target_kind='liability' and m.liability_id=p_target_id));

  if p_target_kind='invoice' then
    update public.finance_received_invoices i set
      bank_confirmed_amount=v_amount,
      bank_last_payment_at=v_last_paid,
      payment_evidence=case
        when v_amount>.01 and i.source_provider='money_s3' then 'mixed'
        when v_amount>.01 then 'bank'
        when i.source_provider='money_s3' then 'money_s3'
        else 'unknown'
      end,
      payment_status=case
        when abs(i.total_amount)<.01 then 'cancelled'
        when v_amount>=abs(i.total_amount)-.01 then 'paid'
        when v_amount>.01 then 'partially_paid'
        when coalesce(i.money_remaining_amount,abs(i.total_amount))<abs(i.total_amount)-.01 then 'partially_paid'
        when exists(
          select 1 from public.finance_payment_batch_items bi
          where bi.invoice_id=i.id and bi.status not in ('processed','rejected','cancelled')
        ) then 'ordered'
        else 'unpaid'
      end,
      operational_remaining_amount=greatest(abs(i.total_amount)-v_amount,0),
      paid_at=case when v_amount>=abs(i.total_amount)-.01 then v_last_paid else null end,
      status=case
        when abs(i.total_amount)<.01 then 'cancelled'
        when v_amount>=abs(i.total_amount)-.01 then 'settled'
        when exists(
          select 1 from public.finance_payment_batch_items bi
          where bi.invoice_id=i.id and bi.status not in ('processed','rejected','cancelled')
        ) then 'in_payment_batch'
        else 'ready_for_payment'
      end,
      updated_at=now()
    where i.id=p_target_id;
    if not found then raise exception 'Faktura nebyla nalezena.'; end if;
  elsif p_target_kind='liability' then
    update public.finance_liabilities l set
      bank_confirmed_amount=v_amount,
      bank_last_payment_at=v_last_paid,
      payment_status=case
        when abs(l.total_amount)<.01 then 'cancelled'
        when v_amount>=abs(l.actual_remaining_amount)-.01 then 'paid'
        when v_amount>.01 then 'partially_paid'
        when l.ordered_amount>.01 then 'ordered'
        when l.actual_remaining_amount<abs(l.total_amount)-.01 then 'partially_paid'
        else 'unpaid'
      end,
      updated_at=now()
    where l.id=p_target_id;
    if not found then raise exception 'Závazek nebyl nalezen.'; end if;
  else
    raise exception 'Neplatný typ cíle.';
  end if;
end;
$$;

create or replace function public.finance_manual_match_bank_transaction_v1(
  p_bank_transaction_id bigint,
  p_target_kind text,
  p_target_id bigint,
  p_amount numeric,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_tx public.finance_bank_transactions%rowtype;
  v_tx_available numeric(18,2);
  v_target_available numeric(18,2);
  v_existing_id bigint;
begin
  if not public.finance_can_manage_v1() then
    raise exception 'Přístup odepřen.' using errcode='42501';
  end if;
  if p_target_kind not in ('invoice','liability') then
    raise exception 'Vyberte fakturu nebo závazek.';
  end if;
  if coalesce(p_amount,0)<=0 then
    raise exception 'Částka musí být vyšší než nula.';
  end if;

  select * into v_tx
  from public.finance_bank_transactions
  where id=p_bank_transaction_id
  for update;
  if not found then raise exception 'Bankovní pohyb nebyl nalezen.'; end if;
  if v_tx.amount>=0 then raise exception 'Příchozí pohyb nelze přiřadit k přijaté faktuře ani závazku.'; end if;

  select greatest(abs(v_tx.amount)-coalesce(sum(m.matched_amount),0),0)
    into v_tx_available
  from public.finance_payment_matches m
  where m.bank_transaction_id=v_tx.id and m.status='confirmed';

  if p_target_kind='invoice' then
    select greatest(coalesce(i.operational_remaining_amount,abs(i.total_amount)-i.bank_confirmed_amount),0)
      into v_target_available
    from public.finance_received_invoices i where i.id=p_target_id for update;
    if not found then raise exception 'Faktura nebyla nalezena.'; end if;
  else
    select greatest(l.actual_remaining_amount-l.bank_confirmed_amount,0)
      into v_target_available
    from public.finance_liabilities l where l.id=p_target_id for update;
    if not found then raise exception 'Závazek nebyl nalezen.'; end if;
  end if;

  if p_amount>v_tx_available+.01 then
    raise exception 'Z pohybu zbývá přiřadit pouze % Kč.',v_tx_available;
  end if;
  if p_amount>v_target_available+.01 then
    raise exception 'Na vybraném dokladu zbývá pouze % Kč.',v_target_available;
  end if;

  if p_target_kind='invoice' then
    select id into v_existing_id from public.finance_payment_matches
    where invoice_id=p_target_id and bank_transaction_id=v_tx.id;
    if v_existing_id is not null then
      update public.finance_payment_matches set
        matched_amount=p_amount,match_method='manual',confidence=100,status='confirmed',
        confirmed_at=now(),confirmed_by=auth.uid(),note=nullif(trim(p_note),'')
      where id=v_existing_id and status='rejected';
      if not found then raise exception 'Tento pohyb už je s fakturou spárovaný.'; end if;
    else
      insert into public.finance_payment_matches(
        invoice_id,bank_transaction_id,matched_amount,match_method,confidence,status,
        confirmed_at,confirmed_by,note
      ) values(p_target_id,v_tx.id,p_amount,'manual',100,'confirmed',now(),auth.uid(),nullif(trim(p_note),''));
    end if;
  else
    select id into v_existing_id from public.finance_payment_matches
    where liability_id=p_target_id and bank_transaction_id=v_tx.id;
    if v_existing_id is not null then
      update public.finance_payment_matches set
        matched_amount=p_amount,match_method='manual',confidence=100,status='confirmed',
        confirmed_at=now(),confirmed_by=auth.uid(),note=nullif(trim(p_note),'')
      where id=v_existing_id and status='rejected';
      if not found then raise exception 'Tento pohyb už je se závazkem spárovaný.'; end if;
    else
      insert into public.finance_payment_matches(
        liability_id,bank_transaction_id,matched_amount,match_method,confidence,status,
        confirmed_at,confirmed_by,note
      ) values(p_target_id,v_tx.id,p_amount,'manual',100,'confirmed',now(),auth.uid(),nullif(trim(p_note),''));
    end if;
  end if;

  perform public.finance_refresh_payment_target_v1(p_target_kind,p_target_id);
  return jsonb_build_object(
    'bank_transaction_id',v_tx.id,'target_kind',p_target_kind,'target_id',p_target_id,
    'matched_amount',p_amount,'remaining_amount',greatest(v_tx_available-p_amount,0)
  );
end;
$$;

create or replace function public.finance_reject_manual_bank_match_v1(p_match_id bigint)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_match public.finance_payment_matches%rowtype;
  v_kind text;
  v_target_id bigint;
begin
  if not public.finance_can_manage_v1() then
    raise exception 'Přístup odepřen.' using errcode='42501';
  end if;
  select * into v_match from public.finance_payment_matches where id=p_match_id for update;
  if not found then raise exception 'Párování nebylo nalezeno.'; end if;
  if v_match.match_method<>'manual' or v_match.status<>'confirmed' then
    raise exception 'Zrušit lze pouze ručně potvrzené párování.';
  end if;
  v_kind:=case when v_match.invoice_id is not null then 'invoice' else 'liability' end;
  v_target_id:=coalesce(v_match.invoice_id,v_match.liability_id);
  update public.finance_payment_matches set
    status='rejected',confirmed_at=null,confirmed_by=null,
    note=concat_ws(' · ',nullif(note,''),'Ruční párování zrušeno '||to_char(now(),'DD.MM.YYYY HH24:MI'))
  where id=v_match.id;
  perform public.finance_refresh_payment_target_v1(v_kind,v_target_id);
  return jsonb_build_object('match_id',v_match.id,'status','rejected');
end;
$$;

create or replace view public.finance_bank_transaction_overview_v1
with (security_invoker=true) as
select
  t.*,
  coalesce(x.matched_amount,0)::numeric(18,2) as matched_amount,
  case when t.amount<0 then greatest(abs(t.amount)-coalesce(x.matched_amount,0),0) else 0 end::numeric(18,2) as remaining_to_match,
  case
    when t.amount>=0 then 'income'
    when coalesce(x.matched_amount,0)<.01 then 'review'
    when coalesce(x.matched_amount,0)<abs(t.amount)-.01 then 'partial_review'
    else 'matched'
  end as match_state,
  case
    when t.amount>=0 or coalesce(x.matched_amount,0)>=abs(t.amount)-.01 then null
    when coalesce(x.matched_amount,0)>.01 then 'Část platby zatím není přiřazena k dokladu.'
    when lower(concat_ws(' ',t.counterparty_name,t.message)) ~ '(card|karta|platba kartou|webnode|elevenlabs|profikutil)'
      then 'Karetní platba bez jednoznačně přiřazeného dokladu.'
    when coalesce(t.variable_symbol,'')='' then 'Chybí variabilní symbol a nebyla nalezena jednoznačná vazba.'
    else 'Nebyl nalezen jediný doklad se shodným VS, účtem a částkou.'
  end as review_reason,
  coalesce(x.targets,'[]'::jsonb) as matched_targets
from public.finance_bank_transactions t
left join lateral(
  select
    sum(m.matched_amount) as matched_amount,
    jsonb_agg(jsonb_build_object(
      'match_id',m.id,
      'kind',case when m.invoice_id is not null then 'invoice' else 'liability' end,
      'target_id',coalesce(m.invoice_id,m.liability_id),
      'number',coalesce(i.internal_number,l.internal_number),
      'name',coalesce(i.supplier_name,l.payee_name,l.description),
      'amount',m.matched_amount,
      'method',m.match_method,
      'note',m.note
    ) order by m.id) as targets
  from public.finance_payment_matches m
  left join public.finance_received_invoices i on i.id=m.invoice_id
  left join public.finance_liabilities l on l.id=m.liability_id
  where m.bank_transaction_id=t.id and m.status='confirmed'
) x on true;

revoke all on function public.finance_refresh_payment_target_v1(text,bigint) from public,anon,authenticated;
revoke all on function public.finance_manual_match_bank_transaction_v1(bigint,text,bigint,numeric,text) from public,anon;
revoke all on function public.finance_reject_manual_bank_match_v1(bigint) from public,anon;
grant execute on function public.finance_manual_match_bank_transaction_v1(bigint,text,bigint,numeric,text) to authenticated,service_role;
grant execute on function public.finance_reject_manual_bank_match_v1(bigint) to authenticated,service_role;
grant select on public.finance_bank_transaction_overview_v1 to authenticated;

comment on view public.finance_bank_transaction_overview_v1 is
  'Bankovní pohyby se stavem spárování, zbývající částkou a důvodem ruční kontroly.';
comment on function public.finance_manual_match_bank_transaction_v1(bigint,text,bigint,numeric,text) is
  'Bezpečně přiřadí celou nebo částečnou odchozí bankovní platbu k faktuře či závazku.';

notify pgrst,'reload schema';
commit;
