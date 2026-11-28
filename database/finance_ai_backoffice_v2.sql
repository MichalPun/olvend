begin;

-- OLVEND Finance AI Backoffice v2
-- One operational document, one audit trail, and deterministic actions.
-- This module deliberately does not implement MD/D, pre-accounting or tax accounting.

alter table public.finance_received_invoices
  add column if not exists processing_state text not null default 'received',
  add column if not exists category_key text,
  add column if not exists subcategory_key text,
  add column if not exists operational_summary text,
  add column if not exists document_period_from date,
  add column if not exists document_period_to date,
  add column if not exists requires_physical_receipt boolean not null default false,
  add column if not exists duplicate_of_invoice_id bigint references public.finance_received_invoices(id) on delete set null,
  add column if not exists ai_model text,
  add column if not exists ai_last_run_at timestamptz,
  add column if not exists accountant_queue_at timestamptz,
  add column if not exists accountant_taken_at timestamptz,
  add column if not exists accountant_taken_by uuid,
  add column if not exists source_queue_id bigint references public.finance_document_intake_queue(id) on delete set null;

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname='finance_received_invoices_processing_state_chk'
      and conrelid='public.finance_received_invoices'::regclass
  ) then
    alter table public.finance_received_invoices add constraint finance_received_invoices_processing_state_chk
      check(processing_state in (
        'received','extracting','needs_review','waiting_answer','ready_to_execute',
        'waiting_delivery','waiting_approval','executing','accountant_ready',
        'accountant_taken','accountant_returned','completed','failed','cancelled'
      ));
  end if;
end $$;

-- Existing v1 invoices already belonged to the legacy payment workflow. Do not
-- present them as fresh AI intake; their payment and due-date state stays intact.
update public.finance_received_invoices
set processing_state=case when status='cancelled' or payment_status='cancelled' then 'cancelled' else 'completed' end,
    operational_summary=coalesce(operational_summary,'Historický doklad převzatý z původní evidence Finance.'),
    updated_at=now()
where processing_state='received' and source_queue_id is null and ai_last_run_at is null;

create index if not exists finance_received_processing_idx
  on public.finance_received_invoices(processing_state,source_received_at desc);
create index if not exists finance_received_category_idx
  on public.finance_received_invoices(category_key,taxable_date desc);
create index if not exists finance_received_queue_idx
  on public.finance_received_invoices(source_queue_id);

create table if not exists public.finance_categories_v2 (
  category_key text primary key,
  parent_key text references public.finance_categories_v2(category_key) on delete restrict,
  label text not null,
  description text,
  default_action_type text not null default 'record_cost',
  requires_operational_target boolean not null default false,
  requires_physical_receipt boolean not null default false,
  sort_order integer not null default 100,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.finance_categories_v2(category_key,parent_key,label,description,default_action_type,requires_operational_target,requires_physical_receipt,sort_order)
values
  ('goods',null,'Zboží a suroviny','Zásoby přijímané na sklad.','stock_receipt',true,true,10),
  ('goods_resale','goods','Zboží k prodeji','Balíčkové a kusové zboží pro automaty.','stock_receipt',true,true,11),
  ('ingredients','goods','Suroviny','Káva, mléko, čokoláda, cukr a další suroviny.','stock_receipt',true,true,12),
  ('consumables','goods','Spotřební materiál','Kelímky, víčka, míchátka a provozní spotřeba.','stock_receipt',true,true,13),
  ('spare_parts','goods','Náhradní díly','Díly přijímané na technický sklad.','stock_receipt',true,true,14),
  ('fleet',null,'Vozidla','Provoz a údržba vozového parku.','vehicle_expense',true,false,20),
  ('fuel','fleet','PHM','Tankování, palivové karty a dobíjení.','vehicle_expense',true,false,21),
  ('vehicle_service','fleet','Servis vozidel','Opravy, pneumatiky, STK a údržba.','vehicle_expense',true,false,22),
  ('vehicle_insurance','fleet','Pojištění vozidel','Povinné a havarijní pojištění.','vehicle_expense',true,false,23),
  ('premises',null,'Provozovny','Náklady spojené s provozovnami a lokalitami.','record_cost',true,false,30),
  ('rent','premises','Nájem','Nájemné a související služby.','record_cost',true,false,31),
  ('energy','premises','Energie','Elektřina, plyn, voda a teplo.','record_cost',true,false,32),
  ('machine_service',null,'Servis a technika','Servis automatů a technické práce.','service_link',true,false,40),
  ('software',null,'Software a předplatné','Licence, SaaS a pravidelná předplatná.','record_cost',false,false,50),
  ('telecom',null,'Telekomunikace','Telefony, data a internet.','record_cost',false,false,51),
  ('insurance',null,'Pojištění','Pojištění mimo vozidla.','record_cost',false,false,52),
  ('bank_fees',null,'Bankovní a finanční služby','Poplatky a platební služby.','record_cost',false,false,53),
  ('office',null,'Kancelář a administrativa','Kancelářské a správní náklady.','record_cost',false,false,60),
  ('marketing',null,'Marketing','Reklama, grafika a propagace.','record_cost',false,false,61),
  ('professional_services',null,'Odborné služby','Právní, poradenské a další služby.','record_cost',false,false,62),
  ('other',null,'Ostatní','Doklad, který nelze bezpečně zařadit jinam.','record_cost',false,false,999)
on conflict(category_key) do update set
  parent_key=excluded.parent_key,label=excluded.label,description=excluded.description,
  default_action_type=excluded.default_action_type,
  requires_operational_target=excluded.requires_operational_target,
  requires_physical_receipt=excluded.requires_physical_receipt,
  sort_order=excluded.sort_order,active=true,updated_at=now();

create table if not exists public.finance_invoice_lines_v2 (
  id bigint generated by default as identity primary key,
  invoice_id bigint not null references public.finance_received_invoices(id) on delete cascade,
  line_number integer not null check(line_number>0),
  source_line_id text,
  supplier_item_code text,
  ean text,
  description text not null,
  quantity numeric(18,6) not null default 0,
  unit_code text,
  unit_price_net numeric(18,6),
  net_amount numeric(18,2) not null default 0,
  vat_rate numeric(7,3),
  vat_amount numeric(18,2) not null default 0,
  total_amount numeric(18,2) not null default 0,
  category_key text references public.finance_categories_v2(category_key) on delete set null,
  product_id bigint references public.products(id) on delete set null,
  supplier_mapping_id bigint references public.supplier_product_mappings(id) on delete set null,
  base_units_per_invoice_unit numeric(18,6) not null default 1 check(base_units_per_invoice_unit>0),
  target_stock_location_id bigint references public.stock_locations(id) on delete set null,
  lot_code text,
  best_before_date date,
  use_by_date date,
  confidence numeric(5,2) check(confidence between 0 and 100),
  warnings jsonb not null default '[]'::jsonb,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(invoice_id,line_number)
);

create index if not exists finance_invoice_lines_invoice_idx on public.finance_invoice_lines_v2(invoice_id,line_number);
create index if not exists finance_invoice_lines_product_idx on public.finance_invoice_lines_v2(product_id);

create table if not exists public.finance_document_links_v2 (
  id bigint generated by default as identity primary key,
  invoice_id bigint not null references public.finance_received_invoices(id) on delete cascade,
  line_id bigint references public.finance_invoice_lines_v2(id) on delete cascade,
  link_type text not null check(link_type in (
    'purchase_order','stock_receipt','warehouse','vehicle','machine','location',
    'technical_job','service_request','employee','contract','budget_entry','other'
  )),
  link_id text not null,
  label text,
  confidence numeric(5,2) check(confidence between 0 and 100),
  source text not null default 'ai' check(source in ('ai','rule','manual','system')),
  confirmed_at timestamptz,
  confirmed_by uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(invoice_id,line_id,link_type,link_id)
);

create table if not exists public.finance_ai_rules_v2 (
  id bigint generated by default as identity primary key,
  name text not null,
  scope text not null check(scope in ('supplier','document','line','supplier_line','recurring','global')),
  priority integer not null default 100,
  matcher jsonb not null,
  outcome jsonb not null,
  auto_execute boolean not null default false,
  active boolean not null default true,
  verified_at timestamptz,
  verified_by uuid,
  learned_from_question_id bigint,
  hit_count bigint not null default 0,
  last_hit_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists finance_ai_rules_scope_idx on public.finance_ai_rules_v2(active,scope,priority);
create index if not exists finance_ai_rules_matcher_gin on public.finance_ai_rules_v2 using gin(matcher);

create table if not exists public.finance_ai_questions_v2 (
  id bigint generated by default as identity primary key,
  invoice_id bigint not null references public.finance_received_invoices(id) on delete cascade,
  line_id bigint references public.finance_invoice_lines_v2(id) on delete cascade,
  question_key text not null,
  question text not null,
  explanation text,
  answer_type text not null default 'choice' check(answer_type in ('choice','entity','text','number','date','boolean')),
  options jsonb not null default '[]'::jsonb,
  suggested_answer jsonb,
  answer jsonb,
  status text not null default 'open' check(status in ('open','answered','dismissed','superseded')),
  blocking boolean not null default true,
  rule_matcher jsonb,
  rule_outcome jsonb,
  answered_at timestamptz,
  answered_by uuid,
  created_at timestamptz not null default now(),
  unique(invoice_id,line_id,question_key,status)
);

create index if not exists finance_ai_questions_open_idx on public.finance_ai_questions_v2(status,created_at) where status='open';

alter table public.finance_ai_rules_v2
  drop constraint if exists finance_ai_rules_v2_learned_from_question_id_fkey;
alter table public.finance_ai_rules_v2
  add constraint finance_ai_rules_v2_learned_from_question_id_fkey
  foreign key(learned_from_question_id) references public.finance_ai_questions_v2(id) on delete set null;

create table if not exists public.finance_ai_actions_v2 (
  id bigint generated by default as identity primary key,
  invoice_id bigint not null references public.finance_received_invoices(id) on delete cascade,
  line_id bigint references public.finance_invoice_lines_v2(id) on delete cascade,
  action_type text not null check(action_type in (
    'stock_receipt','vehicle_expense','record_cost','service_link','location_link',
    'machine_link','purchase_match','accountant_handoff','no_action'
  )),
  status text not null default 'proposed' check(status in (
    'proposed','waiting_input','waiting_delivery','ready','executing','completed','skipped','failed','cancelled'
  )),
  title text not null,
  description text,
  payload jsonb not null default '{}'::jsonb,
  result jsonb not null default '{}'::jsonb,
  requires_confirmation boolean not null default true,
  idempotency_key text not null unique,
  error_message text,
  executed_at timestamptz,
  executed_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists finance_ai_actions_invoice_idx on public.finance_ai_actions_v2(invoice_id,status);
create index if not exists finance_ai_actions_ready_idx on public.finance_ai_actions_v2(status,created_at)
  where status in ('ready','waiting_delivery','failed');

create table if not exists public.finance_ai_runs_v2 (
  id bigint generated by default as identity primary key,
  queue_id bigint references public.finance_document_intake_queue(id) on delete set null,
  invoice_id bigint references public.finance_received_invoices(id) on delete set null,
  model text not null,
  status text not null default 'running' check(status in ('running','completed','failed')),
  provider_request_id text,
  input_tokens bigint,
  output_tokens bigint,
  total_tokens bigint,
  estimated_cost_usd numeric(14,6),
  latency_ms integer,
  attempt_count integer not null default 1,
  error_message text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists finance_ai_runs_status_idx on public.finance_ai_runs_v2(status,started_at desc);
create index if not exists finance_ai_runs_invoice_idx on public.finance_ai_runs_v2(invoice_id,started_at desc);

create table if not exists public.finance_ai_settings_v2 (
  id boolean primary key default true check(id),
  automatic_email_intake boolean not null default false,
  confidence_auto_process numeric(5,2) not null default 95 check(confidence_auto_process between 0 and 100),
  confidence_ask numeric(5,2) not null default 80 check(confidence_ask between 0 and 100),
  maximum_attempts integer not null default 3 check(maximum_attempts between 1 and 8),
  monthly_budget_usd numeric(12,2),
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.finance_ai_settings_v2
  add column if not exists finance_mail_account_id uuid references public.mail_accounts(id) on delete set null,
  add column if not exists finance_mail_folder text not null default 'INBOX',
  add column if not exists email_sync_interval_minutes integer not null default 10,
  add column if not exists email_scan_limit integer not null default 50,
  add column if not exists email_last_sync_at timestamptz,
  add column if not exists email_last_error text;
do $$ begin
  if not exists(select 1 from pg_constraint where conname='finance_ai_settings_email_interval_chk') then
    alter table public.finance_ai_settings_v2 add constraint finance_ai_settings_email_interval_chk check(email_sync_interval_minutes between 2 and 1440);
  end if;
  if not exists(select 1 from pg_constraint where conname='finance_ai_settings_email_limit_chk') then
    alter table public.finance_ai_settings_v2 add constraint finance_ai_settings_email_limit_chk check(email_scan_limit between 1 and 100);
  end if;
end $$;
insert into public.finance_ai_settings_v2(id) values(true) on conflict(id) do nothing;

create table if not exists public.finance_accountant_queue_v2 (
  id bigint generated by default as identity primary key,
  invoice_id bigint not null unique references public.finance_received_invoices(id) on delete restrict,
  status text not null default 'ready' check(status in ('ready','taken','returned','completed','cancelled')),
  operational_summary text,
  checklist jsonb not null default '{}'::jsonb,
  ready_at timestamptz not null default now(),
  taken_at timestamptz,
  taken_by uuid,
  returned_at timestamptz,
  return_reason text,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists finance_accountant_queue_status_idx on public.finance_accountant_queue_v2(status,ready_at);

create table if not exists public.finance_recurring_commitments_v2 (
  id bigint generated by default as identity primary key,
  name text not null,
  commitment_type text not null check(commitment_type in (
    'loan_installment','leasing','rent','insurance','subscription','energy_advance',
    'service_contract','tax','other'
  )),
  supplier_name text,
  supplier_company_id text,
  contract_reference text,
  category_key text references public.finance_categories_v2(category_key) on delete set null,
  amount numeric(18,2) not null check(amount>0),
  currency text not null default 'CZK' check(currency ~ '^[A-Z]{3}$'),
  amount_kind text not null default 'gross' check(amount_kind in ('gross','net','estimate')),
  frequency text not null check(frequency in ('monthly','quarterly','semiannual','annual','custom_months')),
  every_n_months integer not null default 1 check(every_n_months between 1 and 60),
  due_day integer check(due_day between 1 and 31),
  starts_on date not null,
  ends_on date,
  next_due_on date not null,
  materialize_days_ahead integer not null default 120 check(materialize_days_ahead between 1 and 730),
  requires_document boolean not null default true,
  auto_match_document boolean not null default true,
  requires_approval boolean not null default true,
  operational_target jsonb not null default '{}'::jsonb,
  payment_details jsonb not null default '{}'::jsonb,
  note text,
  active boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(ends_on is null or ends_on>=starts_on)
);

create index if not exists finance_recurring_commitments_due_idx
  on public.finance_recurring_commitments_v2(active,next_due_on);

create table if not exists public.finance_expected_obligations_v2 (
  id bigint generated by default as identity primary key,
  commitment_id bigint not null references public.finance_recurring_commitments_v2(id) on delete restrict,
  due_date date not null,
  expected_amount numeric(18,2) not null check(expected_amount>0),
  currency text not null default 'CZK' check(currency ~ '^[A-Z]{3}$'),
  status text not null default 'expected' check(status in ('expected','document_missing','matched','confirmed','paid','skipped','cancelled')),
  invoice_id bigint references public.finance_received_invoices(id) on delete set null,
  matched_at timestamptz,
  match_confidence numeric(5,2) check(match_confidence between 0 and 100),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(commitment_id,due_date)
);

create index if not exists finance_expected_obligations_due_idx
  on public.finance_expected_obligations_v2(status,due_date);
create index if not exists finance_expected_obligations_invoice_idx
  on public.finance_expected_obligations_v2(invoice_id);

create or replace function public.finance_operational_manage_v2()
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(auth.role(),'')='service_role'
    or exists(
      select 1 from public.employees e
      where e.auth_user_id=auth.uid() and e.active is distinct from false
        and lower(coalesce(e.role,'')) ~ '(admin|manager|manaž|manaz|vedouc|majitel|finance)'
    );
$$;

create or replace function public.finance_materialize_recurring_v2(p_until date default (current_date+120))
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.finance_recurring_commitments_v2; v_due date; v_step integer; v_inserted integer:=0; v_last date;
begin
  if not public.finance_operational_manage_v2() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  if p_until>current_date+730 then raise exception 'Výhled může být nejvýše 730 dnů.'; end if;
  update public.finance_expected_obligations_v2 o
  set status='document_missing',updated_at=now()
  from public.finance_recurring_commitments_v2 c
  where c.id=o.commitment_id and c.active and c.requires_document
    and o.status='expected' and o.invoice_id is null and o.due_date<current_date;
  for v in select * from public.finance_recurring_commitments_v2 where active and next_due_on<=p_until loop
    v_step:=case v.frequency when 'monthly' then 1 when 'quarterly' then 3 when 'semiannual' then 6 when 'annual' then 12 else v.every_n_months end;
    v_due:=v.next_due_on;
    while v_due<=p_until and (v.ends_on is null or v_due<=v.ends_on) loop
      insert into public.finance_expected_obligations_v2(commitment_id,due_date,expected_amount,currency,status,note)
      values(v.id,v_due,v.amount,v.currency,case when v.requires_document and v_due<current_date then 'document_missing' else 'expected' end,v.note)
      on conflict(commitment_id,due_date) do nothing;
      if found then v_inserted:=v_inserted+1; end if;
      v_last:=v_due;
      v_due:=(v_due+make_interval(months=>v_step))::date;
      if v.due_day is not null then
        v_due:=make_date(extract(year from v_due)::integer,extract(month from v_due)::integer,
          least(v.due_day,extract(day from (date_trunc('month',v_due)+interval '1 month - 1 day'))::integer));
      end if;
    end loop;
    if v_last is not null then
      update public.finance_recurring_commitments_v2 set next_due_on=(v_last+make_interval(months=>v_step))::date,updated_at=now() where id=v.id;
    end if;
  end loop;
  return jsonb_build_object('ok',true,'inserted',v_inserted,'until',p_until);
end; $$;

create or replace function public.finance_match_expected_obligation_v2(p_invoice_id bigint,p_obligation_id bigint,p_confidence numeric default 100)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_invoice public.finance_received_invoices; v_obligation public.finance_expected_obligations_v2;
begin
  if not public.finance_operational_manage_v2() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  select * into v_invoice from public.finance_received_invoices where id=p_invoice_id;
  select * into v_obligation from public.finance_expected_obligations_v2 where id=p_obligation_id for update;
  if v_invoice.id is null or v_obligation.id is null then raise exception 'Doklad nebo očekávaný závazek neexistuje.'; end if;
  if v_obligation.status in ('paid','skipped','cancelled') then raise exception 'Tento závazek už nelze spárovat.'; end if;
  if v_obligation.invoice_id is not null and v_obligation.invoice_id<>p_invoice_id then raise exception 'Závazek už je spárovaný s jiným dokladem.'; end if;
  update public.finance_expected_obligations_v2 set status='matched',invoice_id=p_invoice_id,matched_at=now(),match_confidence=least(100,greatest(0,p_confidence)),updated_at=now()
  where id=p_obligation_id;
  insert into public.finance_document_links_v2(invoice_id,link_type,link_id,label,confidence,source,confirmed_at,confirmed_by,metadata)
  select p_invoice_id,'contract',commitment_id::text,c.name,least(100,greatest(0,p_confidence)),'manual',now(),auth.uid(),jsonb_build_object('expected_obligation_id',p_obligation_id,'due_date',v_obligation.due_date)
  from public.finance_recurring_commitments_v2 c where c.id=v_obligation.commitment_id
  on conflict do nothing;
  insert into public.finance_invoice_events(invoice_id,event_type,note,metadata,actor_user_id)
  values(p_invoice_id,'recurring_obligation_matched','Doklad spárován s pravidelným závazkem.',jsonb_build_object('obligation_id',p_obligation_id),auth.uid());
  return jsonb_build_object('ok',true,'invoice_id',p_invoice_id,'obligation_id',p_obligation_id);
end; $$;

create unique index if not exists finance_stock_receipt_idempotency_uidx
  on public.stock_movements_v13(reference_type,reference_id)
  where reference_type='finance_invoice_receipt';

create or replace function public.finance_recalculate_state_v2(p_invoice_id bigint)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare v_state text; v_open integer; v_stock integer; v_ready integer; v_failed integer;
begin
  select count(*) into v_open from public.finance_ai_questions_v2
  where invoice_id=p_invoice_id and status='open' and blocking;
  select
    count(*) filter(where action_type='stock_receipt' and status not in ('completed','skipped','cancelled')),
    count(*) filter(where status in ('ready','proposed')),
    count(*) filter(where status='failed')
  into v_stock,v_ready,v_failed
  from public.finance_ai_actions_v2 where invoice_id=p_invoice_id;

  v_state:=case
    when v_failed>0 then 'needs_review'
    when v_open>0 then 'waiting_answer'
    when v_stock>0 then 'waiting_delivery'
    when v_ready>0 then 'ready_to_execute'
    else 'accountant_ready' end;

  update public.finance_received_invoices
  set processing_state=v_state,
      accountant_queue_at=case when v_state='accountant_ready' then coalesce(accountant_queue_at,now()) else accountant_queue_at end,
      handoff_status=case when v_state='accountant_ready' then 'ready' else handoff_status end,
      status=case when v_state='accountant_ready' then 'handoff_ready' else status end,
      updated_at=now()
  where id=p_invoice_id;

  if v_state='accountant_ready' then
    insert into public.finance_accountant_queue_v2(invoice_id,operational_summary,checklist)
    select id,operational_summary,jsonb_build_object(
      'questions_closed',true,
      'actions_completed',true,
      'original_attached',exists(select 1 from public.finance_invoice_attachments a where a.invoice_id=p_invoice_id)
    ) from public.finance_received_invoices where id=p_invoice_id
    on conflict(invoice_id) do update set
      status=case when public.finance_accountant_queue_v2.status='returned' then 'ready' else public.finance_accountant_queue_v2.status end,
      operational_summary=excluded.operational_summary,checklist=excluded.checklist,
      ready_at=case when public.finance_accountant_queue_v2.status='returned' then now() else public.finance_accountant_queue_v2.ready_at end,
      updated_at=now();
  end if;
  return v_state;
end; $$;

create or replace function public.finance_answer_question_v2(
  p_question_id bigint,
  p_answer jsonb,
  p_remember boolean default true
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_q public.finance_ai_questions_v2; v_rule_id bigint; v_state text; v_value text;
  v_product_id bigint; v_stock_location_id bigint; v_vehicle_id bigint; v_supplier_id bigint;
  v_line public.finance_invoice_lines_v2; v_invoice public.finance_received_invoices; v_outcome jsonb;
begin
  if not public.finance_operational_manage_v2() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  select * into v_q from public.finance_ai_questions_v2 where id=p_question_id for update;
  if v_q.id is null then raise exception 'Otázka neexistuje.'; end if;
  if v_q.status<>'open' then raise exception 'Otázka už byla vyřešena.'; end if;
  if p_answer is null or p_answer='null'::jsonb then raise exception 'Odpověď je povinná.'; end if;

  update public.finance_ai_questions_v2 set answer=p_answer,status='answered',answered_at=now(),answered_by=auth.uid()
  where id=v_q.id;

  v_value:=coalesce(p_answer->>'value',p_answer->>'id',trim(both '"' from p_answer::text));
  select * into v_invoice from public.finance_received_invoices where id=v_q.invoice_id;

  if v_q.question_key='document_number' then
    if nullif(v_value,'') is null then raise exception 'Číslo dokladu nesmí být prázdné.'; end if;
    update public.finance_received_invoices set document_number=v_value,updated_at=now() where id=v_q.invoice_id;

  elsif v_q.question_key='document_category' then
    update public.finance_received_invoices i set
      category_key=v_value,
      category=coalesce((select c.label from public.finance_categories_v2 c where c.category_key=v_value),v_value),
      updated_at=now()
    where i.id=v_q.invoice_id;
    update public.finance_ai_actions_v2 set payload=jsonb_set(payload,'{category_key}',to_jsonb(v_value),true),updated_at=now()
    where invoice_id=v_q.invoice_id and status not in ('completed','cancelled');

  elsif v_q.question_key like 'line_product_%' then
    v_product_id:=nullif(v_value,'')::bigint;
    select * into v_line from public.finance_invoice_lines_v2 where id=v_q.line_id and invoice_id=v_q.invoice_id;
    if v_product_id is null or v_line.id is null then raise exception 'Vybraná skladová položka není platná.'; end if;
    update public.finance_invoice_lines_v2 set product_id=v_product_id,confidence=100,updated_at=now() where id=v_line.id;
    select ps.id into v_supplier_id from public.purchase_suppliers ps
    where (v_invoice.supplier_company_id is not null and ps.company_id=v_invoice.supplier_company_id)
       or public.olvend_contact_norm(ps.name)=public.olvend_contact_norm(v_invoice.supplier_name)
    order by case when ps.company_id=v_invoice.supplier_company_id then 0 else 1 end limit 1;
    if v_supplier_id is not null and coalesce(v_line.supplier_item_code,v_line.ean) is not null then
      insert into public.supplier_product_mappings(
        supplier_id,product_id,supplier_item_code,ean,supplier_item_name,invoice_unit_code,
        base_units_per_invoice_unit,last_unit_price,last_seen_at,active
      ) values(
        v_supplier_id,v_product_id,coalesce(v_line.supplier_item_code,'EAN:'||v_line.ean),v_line.ean,
        v_line.description,v_line.unit_code,v_line.base_units_per_invoice_unit,v_line.unit_price_net,now(),true
      ) on conflict(supplier_id,supplier_item_code) do update set
        product_id=excluded.product_id,ean=excluded.ean,supplier_item_name=excluded.supplier_item_name,
        invoice_unit_code=excluded.invoice_unit_code,last_unit_price=excluded.last_unit_price,last_seen_at=now(),active=true;
    end if;

  elsif v_q.question_key='receipt_warehouse' then
    v_stock_location_id:=nullif(v_value,'')::bigint;
    update public.finance_invoice_lines_v2 set target_stock_location_id=v_stock_location_id,updated_at=now() where invoice_id=v_q.invoice_id;

  elsif v_q.question_key='vehicle_target' then
    v_vehicle_id:=nullif(v_value,'')::bigint;
    update public.finance_ai_actions_v2 set
      payload=jsonb_set(payload,'{vehicle_id}',to_jsonb(v_vehicle_id),true),status='ready',updated_at=now()
    where invoice_id=v_q.invoice_id and action_type='vehicle_expense' and status<>'completed';

  elsif v_q.question_key='service_target' then
    update public.finance_ai_actions_v2 set
      payload=jsonb_set(payload,'{machine_id}',to_jsonb(nullif(v_value,'')::bigint),true),status='ready',updated_at=now()
    where invoice_id=v_q.invoice_id and action_type='service_link' and status<>'completed';

  elsif v_q.question_key='location_target' then
    update public.finance_ai_actions_v2 set
      payload=jsonb_set(payload,'{location_id}',to_jsonb(nullif(v_value,'')::bigint),true),status='ready',updated_at=now()
    where invoice_id=v_q.invoice_id and action_type='record_cost' and status<>'completed';

  elsif v_q.question_key='duplicate' and lower(v_value) in ('true','ano','yes','1') then
    update public.finance_ai_actions_v2 set status='cancelled',updated_at=now()
    where invoice_id=v_q.invoice_id and status not in ('completed','cancelled');
    update public.finance_received_invoices set processing_state='cancelled',status='cancelled',payment_status='cancelled',updated_at=now()
    where id=v_q.invoice_id;
  end if;

  -- Rebuild stock-receipt payload after product or warehouse answers.
  if v_q.question_key like 'line_product_%' or v_q.question_key='receipt_warehouse' then
    if v_q.question_key='receipt_warehouse' then
      v_stock_location_id:=nullif(v_value,'')::bigint;
    else
      select target_stock_location_id into v_stock_location_id
      from public.finance_invoice_lines_v2 where invoice_id=v_q.invoice_id and target_stock_location_id is not null order by line_number limit 1;
    end if;
    update public.finance_ai_actions_v2 a set
      payload=jsonb_set(
        jsonb_set(a.payload,'{stock_location_id}',coalesce(to_jsonb(v_stock_location_id),'null'::jsonb),true),
        '{lines}',
        coalesce((select jsonb_agg(jsonb_build_object(
          'line_id',l.id,'line_number',l.line_number,'product_id',l.product_id,
          'stock_location_id',coalesce(l.target_stock_location_id,v_stock_location_id),
          'quantity_base_units',l.quantity*l.base_units_per_invoice_unit,
          'unit_cost',case when l.unit_price_net is null then null else l.unit_price_net/l.base_units_per_invoice_unit end,
          'lot_code',l.lot_code,'best_before_date',l.best_before_date,'use_by_date',l.use_by_date
        ) order by l.line_number) from public.finance_invoice_lines_v2 l where l.invoice_id=v_q.invoice_id),'[]'::jsonb),true
      ),
      status=case when exists(select 1 from public.finance_invoice_lines_v2 l where l.invoice_id=v_q.invoice_id and (l.product_id is null or coalesce(l.target_stock_location_id,v_stock_location_id) is null)) then 'waiting_input' else 'waiting_delivery' end,
      updated_at=now()
    where a.invoice_id=v_q.invoice_id and a.action_type='stock_receipt' and a.status<>'completed';
  end if;

  if p_remember and v_q.rule_matcher is not null and v_q.rule_outcome is not null then
    v_outcome:=v_q.rule_outcome;
    if v_outcome @> '{"category_key":"$answer"}'::jsonb then v_outcome:=jsonb_set(v_outcome,'{category_key}',to_jsonb(v_value)); end if;
    if v_outcome @> '{"product_id":"$answer"}'::jsonb then v_outcome:=jsonb_set(v_outcome,'{product_id}',to_jsonb(v_value)); end if;
    if v_outcome @> '{"stock_location_id":"$answer"}'::jsonb then v_outcome:=jsonb_set(v_outcome,'{stock_location_id}',to_jsonb(v_value)); end if;
    if v_outcome @> '{"vehicle_id":"$answer"}'::jsonb then v_outcome:=jsonb_set(v_outcome,'{vehicle_id}',to_jsonb(v_value)); end if;
    if v_outcome @> '{"machine_id":"$answer"}'::jsonb then v_outcome:=jsonb_set(v_outcome,'{machine_id}',to_jsonb(v_value)); end if;
    if v_outcome @> '{"location_id":"$answer"}'::jsonb then v_outcome:=jsonb_set(v_outcome,'{location_id}',to_jsonb(v_value)); end if;
    if not exists(select 1 from jsonb_each_text(v_q.rule_matcher) x where nullif(x.value,'') is not null) then
      v_outcome:=null;
    end if;
    if v_outcome is not null then
    insert into public.finance_ai_rules_v2(name,scope,priority,matcher,outcome,verified_at,verified_by,learned_from_question_id)
    values('Naučeno z odpovědi #'||v_q.id,case when v_q.line_id is null then 'supplier' else 'supplier_line' end,50,v_q.rule_matcher,v_outcome,now(),auth.uid(),v_q.id)
    returning id into v_rule_id;
    end if;
  end if;

  insert into public.finance_invoice_events(invoice_id,event_type,note,metadata,actor_user_id)
  values(v_q.invoice_id,'ai_question_answered',v_q.question,jsonb_build_object('question_id',v_q.id,'answer',p_answer,'remembered_rule_id',v_rule_id),auth.uid());
  if v_q.question_key='duplicate' and lower(v_value) in ('true','ano','yes','1') then v_state:='cancelled';
  else v_state:=public.finance_recalculate_state_v2(v_q.invoice_id); end if;
  return jsonb_build_object('ok',true,'invoice_id',v_q.invoice_id,'state',v_state,'rule_id',v_rule_id);
end; $$;

create or replace function public.finance_execute_action_v2(
  p_action_id bigint,
  p_confirmed boolean default false,
  p_note text default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_action public.finance_ai_actions_v2;
  v_invoice public.finance_received_invoices;
  v_line jsonb; v_product_id bigint; v_location_id bigint; v_qty numeric; v_price numeric;
  v_batch_id bigint; v_movement_id bigint; v_expense_id bigint; v_existing bigint; v_state text; v_purchase_order_id bigint;
  v_result jsonb:='{}'::jsonb; v_line_results jsonb:='[]'::jsonb;
begin
  if not public.finance_operational_manage_v2() then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  select * into v_action from public.finance_ai_actions_v2 where id=p_action_id for update;
  if v_action.id is null then raise exception 'Akce neexistuje.'; end if;
  if v_action.status='completed' then return jsonb_build_object('ok',true,'already_completed',true,'result',v_action.result); end if;
  if v_action.status not in ('proposed','ready','waiting_delivery','failed') then raise exception 'Akci v tomto stavu nelze provést.'; end if;
  if v_action.requires_confirmation and not p_confirmed then raise exception 'Akce vyžaduje potvrzení.'; end if;
  select * into v_invoice from public.finance_received_invoices where id=v_action.invoice_id;

  update public.finance_ai_actions_v2 set status='executing',error_message=null,updated_at=now() where id=v_action.id;
  update public.finance_received_invoices set processing_state='executing',updated_at=now() where id=v_invoice.id;

  if v_action.action_type='stock_receipt' then
    if jsonb_typeof(v_action.payload->'lines')<>'array' or jsonb_array_length(v_action.payload->'lines')=0 then
      raise exception 'Příjem nemá připravené položky.';
    end if;
    if nullif(v_action.payload->>'supplier_id','') is not null then
      select id into v_purchase_order_id from public.purchase_orders
      where supplier_id=(v_action.payload->>'supplier_id')::bigint and invoice_number=v_invoice.document_number and status<>'cancelled'
      order by id desc limit 1;
      if v_purchase_order_id is null then
        insert into public.purchase_orders(
          supplier_id,order_scope,status,order_date,delivery_date,document_type,due_date,
          invoice_number,received_at,received_stock_location_id,note
        ) values(
          (v_action.payload->>'supplier_id')::bigint,'general','received',coalesce(v_invoice.issue_date,current_date),current_date,
          'invoice',v_invoice.due_date,v_invoice.document_number,now(),nullif(v_action.payload->>'stock_location_id','')::bigint,
          '[finance-ai:'||v_invoice.id||'] Automatický příjem z '||v_invoice.internal_number
        ) returning id into v_purchase_order_id;
      end if;
      insert into public.finance_document_links_v2(invoice_id,link_type,link_id,label,source,confirmed_at,confirmed_by)
      values(v_invoice.id,'purchase_order',v_purchase_order_id::text,'Přijatý nákupní doklad','system',now(),auth.uid()) on conflict do nothing;
    end if;

    for v_line in select value from jsonb_array_elements(v_action.payload->'lines') loop
      v_product_id:=nullif(v_line->>'product_id','')::bigint;
      v_location_id:=coalesce(nullif(v_line->>'stock_location_id','')::bigint,nullif(v_action.payload->>'stock_location_id','')::bigint);
      v_qty:=coalesce(nullif(v_line->>'quantity_base_units','')::numeric,0);
      v_price:=nullif(v_line->>'unit_cost','')::numeric;
      if v_product_id is null or v_location_id is null or v_qty<=0 then raise exception 'Položka příjmu není úplná.'; end if;

      v_batch_id:=null;
      select id into v_existing from public.stock_movements_v13
      where reference_type='finance_invoice_receipt'
        and reference_id=v_invoice.id::text||':'||coalesce(v_line->>'line_id',v_line->>'line_number') limit 1;
      if v_existing is null then
        if coalesce(v_line->>'lot_code','')<>'' or coalesce(v_line->>'best_before_date','')<>'' or coalesce(v_line->>'use_by_date','')<>'' then
          insert into public.inventory_batches(product_id,lot_code,best_before_date,use_by_date,received_at,supplier_name,note)
          values(v_product_id,nullif(v_line->>'lot_code',''),nullif(v_line->>'best_before_date','')::date,
            nullif(v_line->>'use_by_date','')::date,now(),v_invoice.supplier_name,'Příjem z '||v_invoice.internal_number)
          returning id into v_batch_id;
        end if;
        insert into public.stock_movements_v13(
          product_id,batch_id,to_stock_location_id,movement_type,quantity_base_units,unit_price,
          reference_type,reference_id,note,created_by
        ) values(
          v_product_id,v_batch_id,v_location_id,'receipt',v_qty,v_price,
          'finance_invoice_receipt',v_invoice.id::text||':'||coalesce(v_line->>'line_id',v_line->>'line_number'),
          coalesce(p_note,'Automatický příjem z '||v_invoice.internal_number),auth.uid()
        ) returning id into v_movement_id;

        update public.stock_location_balances set quantity_on_hand=quantity_on_hand+v_qty,updated_at=now()
        where stock_location_id=v_location_id and product_id=v_product_id and batch_id is not distinct from v_batch_id;
        if not found then
          insert into public.stock_location_balances(stock_location_id,product_id,batch_id,quantity_on_hand)
          values(v_location_id,v_product_id,v_batch_id,v_qty);
        end if;
        if v_price is not null and v_price>0 then update public.products set purchase_price=v_price,updated_at=now() where id=v_product_id; end if;
      else
        v_movement_id:=v_existing;
        select batch_id into v_batch_id from public.stock_movements_v13 where id=v_existing;
      end if;
      v_line_results:=v_line_results||jsonb_build_array(jsonb_build_object('line_id',v_line->>'line_id','movement_id',v_movement_id,'batch_id',v_batch_id));
    end loop;
    if v_purchase_order_id is not null then
      insert into public.purchase_order_items(purchase_order_id,product_id,ordered_quantity,received_quantity,unit_cost,note)
      select v_purchase_order_id,(x->>'product_id')::bigint,sum((x->>'quantity_base_units')::numeric),sum((x->>'quantity_base_units')::numeric),
        case when sum((x->>'quantity_base_units')::numeric)>0 then sum((x->>'quantity_base_units')::numeric*coalesce(nullif(x->>'unit_cost','')::numeric,0))/sum((x->>'quantity_base_units')::numeric) else null end,
        'Přijato z '||v_invoice.internal_number
      from jsonb_array_elements(v_action.payload->'lines') x group by (x->>'product_id')::bigint
      on conflict(purchase_order_id,product_id) do update set
        ordered_quantity=excluded.ordered_quantity,received_quantity=excluded.received_quantity,
        unit_cost=coalesce(excluded.unit_cost,public.purchase_order_items.unit_cost),note=excluded.note,updated_at=now();
    end if;
    v_result:=jsonb_build_object('stock_movements',v_line_results,'purchase_order_id',v_purchase_order_id,'confirmed_note',p_note);

  elsif v_action.action_type='vehicle_expense' then
    if nullif(v_action.payload->>'vehicle_id','') is null then raise exception 'Chybí vozidlo.'; end if;
    insert into public.vehicle_expenses(vehicle_id,expense_date,category,amount,vendor,note)
    values((v_action.payload->>'vehicle_id')::bigint,coalesce(v_invoice.taxable_date,v_invoice.issue_date,current_date),
      coalesce(nullif(v_action.payload->>'vehicle_category',''),'other'),v_invoice.total_amount,v_invoice.supplier_name,
      coalesce(p_note,v_invoice.internal_number||' · '||coalesce(v_invoice.operational_summary,''))) returning id into v_expense_id;
    insert into public.finance_document_links_v2(invoice_id,link_type,link_id,label,source,confirmed_at,confirmed_by)
    values(v_invoice.id,'vehicle',v_action.payload->>'vehicle_id',v_action.payload->>'vehicle_label','system',now(),auth.uid())
    on conflict do nothing;
    v_result:=jsonb_build_object('vehicle_expense_id',v_expense_id);

  elsif v_action.action_type='record_cost' then
    insert into public.budget_expense_entries(expense_date,category_key,description,amount,vat_mode,source,note,created_by)
    values(coalesce(v_invoice.taxable_date,v_invoice.issue_date,current_date),coalesce(v_invoice.category_key,'other'),
      v_invoice.supplier_name||' · '||v_invoice.document_number,v_invoice.net_amount,'without_vat','import',
      coalesce(p_note,v_invoice.operational_summary),auth.uid()) returning id into v_expense_id;
    insert into public.finance_document_links_v2(invoice_id,link_type,link_id,label,source,confirmed_at,confirmed_by)
    values(v_invoice.id,'budget_entry',v_expense_id::text,'Provozní náklad','system',now(),auth.uid()) on conflict do nothing;
    if nullif(v_action.payload->>'location_id','') is not null then
      insert into public.finance_document_links_v2(invoice_id,link_type,link_id,label,source,confirmed_at,confirmed_by,metadata)
      values(v_invoice.id,'location',v_action.payload->>'location_id',coalesce(v_action.payload->>'location_label','Provozovna nebo lokalita'),'system',now(),auth.uid(),v_action.payload)
      on conflict do nothing;
    end if;
    v_result:=jsonb_build_object('budget_expense_id',v_expense_id);

  elsif v_action.action_type in ('service_link','machine_link') then
    if nullif(v_action.payload->>'machine_id','') is null then raise exception 'Chybí automat.'; end if;
    insert into public.finance_document_links_v2(invoice_id,link_type,link_id,label,source,confirmed_at,confirmed_by,metadata)
    values(v_invoice.id,'machine',v_action.payload->>'machine_id',coalesce(v_action.payload->>'machine_label','Servisní náklad automatu'),'system',now(),auth.uid(),v_action.payload)
    on conflict do nothing;
    v_result:=jsonb_build_object('machine_id',v_action.payload->>'machine_id','linked',true);

  elsif v_action.action_type='location_link' then
    if nullif(v_action.payload->>'location_id','') is null then raise exception 'Chybí provozovna nebo lokalita.'; end if;
    insert into public.finance_document_links_v2(invoice_id,link_type,link_id,label,source,confirmed_at,confirmed_by,metadata)
    values(v_invoice.id,'location',v_action.payload->>'location_id',coalesce(v_action.payload->>'location_label','Provozní náklad lokality'),'system',now(),auth.uid(),v_action.payload)
    on conflict do nothing;
    v_result:=jsonb_build_object('location_id',v_action.payload->>'location_id','linked',true);

  else
    v_result:=jsonb_build_object('linked',true,'payload',v_action.payload);
  end if;

  update public.finance_ai_actions_v2 set status='completed',result=v_result,executed_at=now(),executed_by=auth.uid(),updated_at=now()
  where id=v_action.id;
  insert into public.finance_invoice_events(invoice_id,event_type,note,metadata,actor_user_id)
  values(v_invoice.id,'operational_action_completed',v_action.title,jsonb_build_object('action_id',v_action.id,'action_type',v_action.action_type,'result',v_result),auth.uid());
  v_state:=public.finance_recalculate_state_v2(v_invoice.id);
  return jsonb_build_object('ok',true,'action_id',v_action.id,'state',v_state,'result',v_result);
exception when others then
  if v_action.id is not null then
    update public.finance_ai_actions_v2 set status='failed',error_message=sqlerrm,updated_at=now() where id=v_action.id;
    update public.finance_received_invoices set processing_state='needs_review',updated_at=now() where id=v_action.invoice_id;
  end if;
  return jsonb_build_object('ok',false,'action_id',v_action.id,'state','needs_review','error',sqlerrm);
end; $$;

create or replace function public.finance_accountant_take_v2(p_invoice_id bigint)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if public.finance_portal_scope_v1() is null then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  update public.finance_accountant_queue_v2 set status='taken',taken_at=now(),taken_by=auth.uid(),updated_at=now()
  where invoice_id=p_invoice_id and status='ready';
  if not found then raise exception 'Doklad není připraven k převzetí.'; end if;
  update public.finance_received_invoices set processing_state='accountant_taken',accountant_taken_at=now(),accountant_taken_by=auth.uid(),handoff_status='accepted',updated_at=now()
  where id=p_invoice_id;
  insert into public.finance_invoice_events(invoice_id,event_type,note,actor_user_id)
  values(p_invoice_id,'accountant_taken','Doklad převzala účetní.',auth.uid());
  return jsonb_build_object('ok',true,'invoice_id',p_invoice_id,'status','taken');
end; $$;

create or replace function public.finance_accountant_return_v2(p_invoice_id bigint,p_reason text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if public.finance_portal_scope_v1() is null then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'Důvod vrácení je povinný.'; end if;
  update public.finance_accountant_queue_v2 set status='returned',returned_at=now(),return_reason=trim(p_reason),updated_at=now()
  where invoice_id=p_invoice_id and status in ('ready','taken');
  if not found then raise exception 'Doklad nelze vrátit.'; end if;
  update public.finance_received_invoices set processing_state='accountant_returned',handoff_status='returned',accountant_note=trim(p_reason),updated_at=now()
  where id=p_invoice_id;
  insert into public.finance_ai_questions_v2(invoice_id,question_key,question,explanation,answer_type,blocking)
  values(p_invoice_id,'accountant_return_'||extract(epoch from now())::bigint,'Účetní vrátila doklad: '||trim(p_reason),'Doplňte nebo opravte podklad a vraťte ho účetní.','text',true);
  insert into public.finance_invoice_events(invoice_id,event_type,note,actor_user_id)
  values(p_invoice_id,'accountant_returned',trim(p_reason),auth.uid());
  return jsonb_build_object('ok',true,'invoice_id',p_invoice_id,'status','returned');
end; $$;

create or replace function public.finance_accountant_complete_v2(p_invoice_id bigint,p_note text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if public.finance_portal_scope_v1() is null then raise exception 'Přístup odepřen.' using errcode='42501'; end if;
  update public.finance_accountant_queue_v2 set status='completed',completed_at=now(),updated_at=now()
  where invoice_id=p_invoice_id and status in ('ready','taken');
  if not found then raise exception 'Doklad nelze dokončit.'; end if;
  update public.finance_received_invoices set processing_state='completed',handoff_status='accepted',status='exported',accountant_note=coalesce(nullif(trim(p_note),''),accountant_note),updated_at=now()
  where id=p_invoice_id;
  insert into public.finance_invoice_events(invoice_id,event_type,note,actor_user_id)
  values(p_invoice_id,'accountant_completed',coalesce(nullif(trim(p_note),''),'Účetní dokončila zpracování dokladu.'),auth.uid());
  return jsonb_build_object('ok',true,'invoice_id',p_invoice_id,'status','completed');
end; $$;

create or replace view public.finance_workbench_v2 with (security_invoker=true) as
select i.*,
  coalesce(e.name||' '||e.surname,'Bez přiřazení') owner,
  a.file_name attachment_name,a.storage_path attachment_path,a.mime_type attachment_mime_type,
  coalesce(q.open_questions,0) open_questions,
  coalesce(x.pending_actions,0) pending_actions,
  coalesce(x.failed_actions,0) failed_actions,
  coalesce(l.line_count,0) line_count,
  aq.status accountant_queue_status,
  aq.return_reason accountant_return_reason
from public.finance_received_invoices i
left join public.employees e on e.id=i.owner_employee_id
left join lateral(
  select ia.file_name,ia.storage_path,ia.mime_type from public.finance_invoice_attachments ia
  where ia.invoice_id=i.id and ia.kind='original' order by ia.id limit 1
) a on true
left join lateral(select count(*) open_questions from public.finance_ai_questions_v2 z where z.invoice_id=i.id and z.status='open') q on true
left join lateral(select count(*) filter(where z.status not in ('completed','skipped','cancelled')) pending_actions,count(*) filter(where z.status='failed') failed_actions from public.finance_ai_actions_v2 z where z.invoice_id=i.id) x on true
left join lateral(select count(*) line_count from public.finance_invoice_lines_v2 z where z.invoice_id=i.id) l on true
left join public.finance_accountant_queue_v2 aq on aq.invoice_id=i.id;

create or replace view public.finance_accountant_workbench_v2 with (security_invoker=true) as
select q.id queue_id,q.status queue_status,q.ready_at,q.taken_at,q.return_reason,q.completed_at,
  i.id invoice_id,i.internal_number,i.supplier_name,i.supplier_company_id,i.document_number,
  i.issue_date,i.taxable_date,i.due_date,i.currency,i.net_amount,i.vat_amount,i.total_amount,
  i.category,i.category_key,i.operational_summary,i.payment_status,i.paid_at,i.accountant_note,
  a.file_name attachment_name,a.storage_path attachment_path,a.mime_type attachment_mime_type,
  coalesce((select count(*) from public.finance_invoice_lines_v2 l where l.invoice_id=i.id),0) line_count
from public.finance_accountant_queue_v2 q
join public.finance_received_invoices i on i.id=q.invoice_id
left join lateral(select x.file_name,x.storage_path,x.mime_type from public.finance_invoice_attachments x where x.invoice_id=i.id and x.kind='original' order by x.id limit 1)a on true;

create or replace function public.get_finance_backoffice_dashboard_v2(p_month date default current_date)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select case when public.finance_operational_manage_v2() then jsonb_build_object(
    'received',count(*) filter(where processing_state in ('received','extracting')),
    'needs_answer',count(*) filter(where processing_state in ('needs_review','waiting_answer','accountant_returned')),
    'waiting_delivery',count(*) filter(where processing_state='waiting_delivery'),
    'waiting_approval',count(*) filter(where processing_state in ('ready_to_execute','waiting_approval')),
    'accountant_ready',count(*) filter(where processing_state='accountant_ready'),
    'accountant_taken',count(*) filter(where processing_state='accountant_taken'),
    'failed',count(*) filter(where processing_state='failed'),
    'month_net',coalesce(sum(net_amount) filter(where coalesce(taxable_date,issue_date)>=date_trunc('month',p_month)::date and coalesce(taxable_date,issue_date)<(date_trunc('month',p_month)+interval '1 month')::date),0),
    'open_amount',coalesce(sum(total_amount) filter(where payment_status not in ('paid','cancelled')),0),
    'overdue_amount',coalesce(sum(total_amount) filter(where payment_status not in ('paid','cancelled') and due_date<current_date),0),
    'expected_30d_amount',coalesce((select sum(expected_amount) from public.finance_expected_obligations_v2 where status in ('expected','document_missing','matched','confirmed') and due_date between current_date and current_date+30),0),
    'missing_documents',coalesce((select count(*) from public.finance_expected_obligations_v2 where status='document_missing'),0),
    'categories',coalesce((select jsonb_agg(jsonb_build_object('category_key',z.category_key,'label',c.label,'net_amount',z.net_amount,'document_count',z.document_count) order by z.net_amount desc)
      from (select category_key,sum(net_amount) net_amount,count(*) document_count from public.finance_received_invoices
        where coalesce(taxable_date,issue_date)>=date_trunc('month',p_month)::date and coalesce(taxable_date,issue_date)<(date_trunc('month',p_month)+interval '1 month')::date group by category_key) z
      left join public.finance_categories_v2 c on c.category_key=z.category_key),'[]'::jsonb)
  ) else null end from public.finance_received_invoices;
$$;

alter table public.finance_categories_v2 enable row level security;
alter table public.finance_invoice_lines_v2 enable row level security;
alter table public.finance_document_links_v2 enable row level security;
alter table public.finance_ai_rules_v2 enable row level security;
alter table public.finance_ai_questions_v2 enable row level security;
alter table public.finance_ai_actions_v2 enable row level security;
alter table public.finance_ai_runs_v2 enable row level security;
alter table public.finance_ai_settings_v2 enable row level security;
alter table public.finance_accountant_queue_v2 enable row level security;
alter table public.finance_recurring_commitments_v2 enable row level security;
alter table public.finance_expected_obligations_v2 enable row level security;

do $$ declare t text; begin
  foreach t in array array['finance_categories_v2','finance_invoice_lines_v2','finance_document_links_v2','finance_ai_rules_v2','finance_ai_questions_v2','finance_ai_actions_v2','finance_ai_runs_v2','finance_ai_settings_v2','finance_accountant_queue_v2','finance_recurring_commitments_v2','finance_expected_obligations_v2'] loop
    execute format('drop policy if exists %I on public.%I','finance_internal_'||t,t);
    execute format('create policy %I on public.%I for all to authenticated using(public.finance_operational_manage_v2()) with check(public.finance_operational_manage_v2())','finance_internal_'||t,t);
  end loop;
end $$;

drop policy if exists finance_accountant_invoice_read_v2 on public.finance_received_invoices;
create policy finance_accountant_invoice_read_v2 on public.finance_received_invoices for select to authenticated
using(public.finance_portal_scope_v1()='accountant' and handoff_status in ('ready','packaged','accepted','returned'));
drop policy if exists finance_accountant_attachment_read_v2 on public.finance_invoice_attachments;
create policy finance_accountant_attachment_read_v2 on public.finance_invoice_attachments for select to authenticated
using(public.finance_portal_scope_v1()='accountant' and exists(select 1 from public.finance_received_invoices i where i.id=invoice_id and i.handoff_status in ('ready','packaged','accepted','returned')));
drop policy if exists finance_accountant_lines_read_v2 on public.finance_invoice_lines_v2;
create policy finance_accountant_lines_read_v2 on public.finance_invoice_lines_v2 for select to authenticated
using(public.finance_portal_scope_v1()='accountant' and exists(select 1 from public.finance_received_invoices i where i.id=invoice_id and i.handoff_status in ('ready','packaged','accepted','returned')));
drop policy if exists finance_accountant_queue_read_v2 on public.finance_accountant_queue_v2;
create policy finance_accountant_queue_read_v2 on public.finance_accountant_queue_v2 for select to authenticated
using(public.finance_portal_scope_v1()='accountant');

drop policy if exists finance_private_read_v2 on storage.objects;
create policy finance_private_read_v2 on storage.objects for select to authenticated
using(bucket_id='finance-private' and public.finance_portal_scope_v1() is not null);
drop policy if exists finance_private_insert_v2 on storage.objects;
create policy finance_private_insert_v2 on storage.objects for insert to authenticated
with check(bucket_id='finance-private' and public.finance_operational_manage_v2());
drop policy if exists finance_private_update_v2 on storage.objects;
create policy finance_private_update_v2 on storage.objects for update to authenticated
using(bucket_id='finance-private' and public.finance_operational_manage_v2())
with check(bucket_id='finance-private' and public.finance_operational_manage_v2());

grant select,insert,update,delete on table
  public.finance_categories_v2,public.finance_invoice_lines_v2,public.finance_document_links_v2,
  public.finance_ai_rules_v2,public.finance_ai_questions_v2,public.finance_ai_actions_v2,
  public.finance_ai_runs_v2,public.finance_ai_settings_v2,public.finance_accountant_queue_v2,
  public.finance_recurring_commitments_v2,public.finance_expected_obligations_v2
to authenticated,service_role;
grant select on table public.finance_workbench_v2,public.finance_accountant_workbench_v2 to authenticated,service_role;
do $$ declare s record; begin
  for s in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='S' and c.relname like 'finance_%_v2_id_seq'
  loop execute format('grant usage,select on sequence %I.%I to authenticated,service_role',s.nspname,s.relname); end loop;
end $$;

revoke all on function public.finance_answer_question_v2(bigint,jsonb,boolean) from public,anon;
revoke all on function public.finance_execute_action_v2(bigint,boolean,text) from public,anon;
revoke all on function public.finance_accountant_take_v2(bigint) from public,anon;
revoke all on function public.finance_accountant_return_v2(bigint,text) from public,anon;
revoke all on function public.finance_accountant_complete_v2(bigint,text) from public,anon;
revoke all on function public.get_finance_backoffice_dashboard_v2(date) from public,anon;
revoke all on function public.finance_materialize_recurring_v2(date) from public,anon;
revoke all on function public.finance_match_expected_obligation_v2(bigint,bigint,numeric) from public,anon;
revoke all on function public.finance_recalculate_state_v2(bigint) from public,anon;
revoke all on function public.finance_operational_manage_v2() from public,anon;
grant execute on function public.finance_answer_question_v2(bigint,jsonb,boolean) to authenticated,service_role;
grant execute on function public.finance_execute_action_v2(bigint,boolean,text) to authenticated,service_role;
grant execute on function public.finance_accountant_take_v2(bigint) to authenticated,service_role;
grant execute on function public.finance_accountant_return_v2(bigint,text) to authenticated,service_role;
grant execute on function public.finance_accountant_complete_v2(bigint,text) to authenticated,service_role;
grant execute on function public.get_finance_backoffice_dashboard_v2(date) to authenticated,service_role;
grant execute on function public.finance_materialize_recurring_v2(date) to authenticated,service_role;
grant execute on function public.finance_match_expected_obligation_v2(bigint,bigint,numeric) to authenticated,service_role;
revoke execute on function public.finance_recalculate_state_v2(bigint) from authenticated;
grant execute on function public.finance_recalculate_state_v2(bigint) to service_role;
grant execute on function public.finance_operational_manage_v2() to authenticated,service_role;

comment on table public.finance_ai_rules_v2 is 'Dohledatelná firemní paměť: odpovědi a ověřená provozní pravidla, nikoli účetní předkontace.';
comment on table public.finance_ai_actions_v2 is 'Deterministický plán provozních kroků. AI navrhuje, databázová funkce kontroluje a provádí.';
comment on table public.finance_ai_runs_v2 is 'Produkční telemetrie AI běhů: model, tokeny, latence, pokusy, náklad a chyba.';
comment on table public.finance_accountant_queue_v2 is 'Fronta kompletních provozně zpracovaných dokladů pro účetní.';
comment on table public.finance_recurring_commitments_v2 is 'Smluvní a pravidelně opakované závazky včetně splátek, nájmů, leasingů a předplatných.';
comment on table public.finance_expected_obligations_v2 is 'Jednotlivé očekávané splatnosti vytvořené z pravidelných závazků; mohou čekat na doklad nebo se s ním spárovat.';

commit;
