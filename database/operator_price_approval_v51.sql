-- OLVEND v51: neblokující změna ceny operátorem se schválením vedoucího.
-- Fyzická cena může být dočasně vyšší než doporučená. Trasa ani návštěva se
-- čekáním na rozhodnutí nikdy neblokuje.

create extension if not exists pgcrypto;

create table if not exists public.operator_price_change_approvers (
  employee_id uuid primary key references public.employees(id) on delete cascade,
  priority integer not null default 100,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.operator_price_change_approvers(employee_id, priority, active)
select id, 10, true
from public.employees
where lower(email) = 'puncochar.m@olmika.cz'
on conflict (employee_id) do update
set priority = excluded.priority,
    active = true;

create table if not exists public.operator_price_change_requests (
  id uuid primary key default gen_random_uuid(),
  client_request_key text not null unique,
  route_machine_visit_id bigint not null references public.route_machine_visits(id) on delete cascade,
  route_plan_id bigint references public.route_plans(id) on delete set null,
  route_plan_stop_id bigint references public.route_plan_stops(id) on delete set null,
  machine_id bigint not null references public.machines(id) on delete cascade,
  location_id bigint not null references public.locations(id) on delete cascade,
  planogram_slot_id bigint not null references public.machine_planogram_slots(id) on delete cascade,
  operator_employee_id uuid not null references public.employees(id) on delete restrict,
  approver_employee_id uuid not null references public.employees(id) on delete restrict,
  product_sku text,
  product_name text not null,
  slot_code text not null,
  recommended_price_czk numeric(10,2) not null check (recommended_price_czk >= 0),
  previous_customer_price_czk numeric(10,2),
  proposed_price_czk numeric(10,2) not null check (proposed_price_czk > 0),
  purchase_price_czk numeric(12,2),
  vat_rate numeric(6,2),
  operator_note text,
  comparison_snapshot jsonb not null default '{}'::jsonb,
  economics_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (
    status in ('pending','approved','rejected','reverted','cancelled')
  ),
  approval_token_hash text not null unique,
  requested_at timestamptz not null default now(),
  email_sent_at timestamptz,
  email_delivery_id text,
  mail_error text,
  decided_at timestamptz,
  decision_note text,
  operator_message_id bigint references public.location_operator_messages(id) on delete set null,
  reverted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint operator_price_change_only_increase check (proposed_price_czk > recommended_price_czk)
);

create unique index if not exists operator_price_change_one_pending_slot_idx
  on public.operator_price_change_requests(planogram_slot_id)
  where status = 'pending';

create index if not exists operator_price_change_operator_idx
  on public.operator_price_change_requests(operator_employee_id, requested_at desc);

create index if not exists operator_price_change_approver_idx
  on public.operator_price_change_requests(approver_employee_id, status, requested_at desc);

create or replace function public.touch_operator_price_change_request_v51()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists operator_price_change_request_touch_v51
  on public.operator_price_change_requests;
create trigger operator_price_change_request_touch_v51
before update on public.operator_price_change_requests
for each row execute function public.touch_operator_price_change_request_v51();

alter table public.operator_price_change_approvers enable row level security;
alter table public.operator_price_change_requests enable row level security;
revoke all on public.operator_price_change_approvers from anon, authenticated;
revoke all on public.operator_price_change_requests from anon, authenticated;

drop policy if exists "Operator reads own price requests" on public.operator_price_change_requests;
create policy "Operator reads own price requests"
on public.operator_price_change_requests
for select to authenticated
using (
  operator_employee_id = (
    select e.id from public.employees e
    where e.auth_user_id = auth.uid() and e.active is distinct from false
    limit 1
  )
  or approver_employee_id = (
    select e.id from public.employees e
    where e.auth_user_id = auth.uid() and e.active is distinct from false
    limit 1
  )
  or exists (
    select 1 from public.employees e
    where e.auth_user_id = auth.uid()
      and e.active is distinct from false
      and lower(coalesce(e.role,'')) in ('admin','manager')
  )
);

create or replace function public.create_operator_price_change_request_v51(
  p_client_request_key text,
  p_visit_id bigint,
  p_slot_id bigint,
  p_operator_employee_id uuid,
  p_new_price numeric,
  p_note text,
  p_token_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.operator_price_change_requests%rowtype;
  v_visit public.route_machine_visits%rowtype;
  v_slot public.machine_planogram_slots%rowtype;
  v_machine public.machines%rowtype;
  v_location public.locations%rowtype;
  v_operator public.employees%rowtype;
  v_approver public.employees%rowtype;
  v_product public.products%rowtype;
  v_request public.operator_price_change_requests%rowtype;
  v_recommended numeric(10,2);
  v_proposed numeric(10,2);
  v_prices jsonb := '[]'::jsonb;
  v_min numeric;
  v_max numeric;
  v_avg numeric;
  v_median numeric;
  v_sales_units numeric := 0;
  v_sales_revenue numeric := 0;
  v_sales_avg numeric;
  v_comparison jsonb;
  v_economics jsonb;
begin
  if coalesce(auth.role(),'') <> 'service_role'
     and current_user not in ('postgres','supabase_admin') then
    raise exception 'Tuto operaci smí provést pouze schvalovací služba.';
  end if;

  if nullif(trim(coalesce(p_client_request_key,'')),'') is null then
    raise exception 'Chybí identifikátor požadavku.';
  end if;

  select * into v_existing
  from public.operator_price_change_requests
  where client_request_key = trim(p_client_request_key);
  if found then
    -- A retry after a mail outage must create a fresh working link.  The
    -- original price request stays idempotent; only its one-time token rotates.
    if v_existing.status = 'pending' and v_existing.email_sent_at is null then
      update public.operator_price_change_requests
      set approval_token_hash = p_token_hash,
          mail_error = null,
          updated_at = now()
      where id = v_existing.id
      returning * into v_existing;
    end if;
    select * into v_operator from public.employees where id = v_existing.operator_employee_id;
    select * into v_approver from public.employees where id = v_existing.approver_employee_id;
    select * into v_machine from public.machines where id = v_existing.machine_id;
    select * into v_location from public.locations where id = v_existing.location_id;
    return jsonb_build_object(
      'ok', true,
      'request_id', v_existing.id,
      'status', v_existing.status,
      'already_exists', true,
      'approver_id', v_existing.approver_employee_id,
      'approver_name', trim(concat_ws(' ',v_approver.name,v_approver.surname)),
      'approver_email', v_approver.email,
      'operator_name', trim(concat_ws(' ',v_operator.name,v_operator.surname)),
      'location_name', v_location.name,
      'machine_name', v_machine.name,
      'evidence_number', v_machine.evidence_number,
      'slot_code', v_existing.slot_code,
      'product_sku', v_existing.product_sku,
      'product_name', v_existing.product_name,
      'recommended_price_czk', v_existing.recommended_price_czk,
      'previous_customer_price_czk', v_existing.previous_customer_price_czk,
      'proposed_price_czk', v_existing.proposed_price_czk,
      'operator_note', v_existing.operator_note,
      'email_sent_at', v_existing.email_sent_at,
      'comparison_snapshot', v_existing.comparison_snapshot,
      'economics_snapshot', v_existing.economics_snapshot
    );
  end if;

  select * into v_visit
  from public.route_machine_visits
  where id = p_visit_id
  for update;
  if not found then raise exception 'Návštěva automatu nebyla nalezena.'; end if;
  if v_visit.employee_id is distinct from p_operator_employee_id then
    raise exception 'Návštěva nepatří přihlášenému operátorovi.';
  end if;
  if v_visit.status = 'skipped' then
    raise exception 'U nejeté návštěvy nelze měnit cenu.';
  end if;

  select * into v_slot
  from public.machine_planogram_slots
  where id = p_slot_id and active
  for update;
  if not found or v_slot.machine_id <> v_visit.machine_id then
    raise exception 'Pozice nepatří k navštívenému automatu.';
  end if;

  select * into v_operator from public.employees
  where id = p_operator_employee_id and active is distinct from false;
  if not found then raise exception 'Aktivní operátor nebyl nalezen.'; end if;

  select e.* into v_approver
  from public.operator_price_change_approvers a
  join public.employees e on e.id = a.employee_id
  where a.active and e.active is distinct from false and nullif(trim(e.email),'') is not null
  order by a.priority, a.created_at
  limit 1;
  if not found then raise exception 'Není nastavený aktivní schvalovatel cen.'; end if;

  select * into v_machine from public.machines where id = v_slot.machine_id;
  select * into v_location from public.locations where id = v_machine.location_id;
  select * into v_product from public.products where sku = v_slot.product_sku order by active desc, id desc limit 1;

  v_recommended := round(coalesce(v_slot.price_czk, v_slot.customer_price_czk, 0)::numeric, 2);
  v_proposed := round(coalesce(p_new_price, 0)::numeric, 2);
  if v_recommended <= 0 then raise exception 'Pozice nemá platnou doporučenou cenu.'; end if;
  if v_proposed <= v_recommended then
    raise exception 'Operátor smí navrhnout pouze cenu vyšší než doporučených % Kč.', v_recommended;
  end if;
  if v_proposed > 999 then raise exception 'Navržená cena je mimo povolený rozsah.'; end if;
  if exists (
    select 1 from public.operator_price_change_requests r
    where r.planogram_slot_id = v_slot.id and r.status = 'pending'
  ) then
    raise exception 'U této pozice už jedna změna ceny čeká na schválení.';
  end if;

  select
    coalesce(jsonb_agg(jsonb_build_object(
      'location', x.location_name,
      'evidence_number', x.evidence_number,
      'slot_code', x.slot_code,
      'price_czk', x.sale_price
    ) order by x.sale_price, x.location_name, x.evidence_number, x.slot_code), '[]'::jsonb),
    min(x.sale_price), max(x.sale_price), round(avg(x.sale_price),2),
    percentile_cont(0.5) within group(order by x.sale_price)
  into v_prices, v_min, v_max, v_avg, v_median
  from (
    select l.name as location_name, m.evidence_number, s.slot_code,
           coalesce(s.customer_price_czk, s.price_czk) as sale_price
    from public.machine_planogram_slots s
    join public.machines m on m.id = s.machine_id
    join public.locations l on l.id = m.location_id
    where s.active
      and s.id <> v_slot.id
      and s.product_sku is not distinct from v_slot.product_sku
      and coalesce(s.customer_price_czk, s.price_czk) is not null
      and coalesce(s.customer_price_czk, s.price_czk) > 0
  ) x;

  select coalesce(sum(e.quantity),0), coalesce(sum(e.total_amount_czk),0),
         round(sum(e.total_amount_czk) / nullif(sum(e.quantity),0),2)
  into v_sales_units, v_sales_revenue, v_sales_avg
  from public.telemetry_sales_events e
  where e.product_sku is not distinct from v_slot.product_sku
    and e.source_event_at >= now() - interval '30 days';

  v_comparison := jsonb_build_object(
    'prices_elsewhere', v_prices,
    'location_count', jsonb_array_length(v_prices),
    'min_price_czk', v_min,
    'max_price_czk', v_max,
    'average_price_czk', v_avg,
    'median_price_czk', v_median,
    'sales_30d_units', v_sales_units,
    'sales_30d_revenue_czk', v_sales_revenue,
    'sales_30d_average_price_czk', v_sales_avg
  );

  v_economics := jsonb_build_object(
    'purchase_price_czk', v_product.purchase_price,
    'vat_rate', v_product.vat_rate,
    'recommended_price_czk', v_recommended,
    'proposed_price_czk', v_proposed,
    'recommended_spread_czk', case when v_product.purchase_price is null then null else round(v_recommended - v_product.purchase_price,2) end,
    'recommended_margin_percent', case when v_product.purchase_price is null or v_recommended = 0 then null else round((v_recommended - v_product.purchase_price) / v_recommended * 100,1) end,
    'proposed_spread_czk', case when v_product.purchase_price is null then null else round(v_proposed - v_product.purchase_price,2) end,
    'proposed_margin_percent', case when v_product.purchase_price is null or v_proposed = 0 then null else round((v_proposed - v_product.purchase_price) / v_proposed * 100,1) end,
    'net_price_after_vat_czk', case when v_product.vat_rate is null then null else round(v_proposed / (1 + v_product.vat_rate / 100),2) end,
    'estimated_30d_revenue_change_czk', round(v_sales_units * (v_proposed - v_recommended),2)
  );

  insert into public.operator_price_change_requests(
    client_request_key, route_machine_visit_id, route_plan_id, route_plan_stop_id,
    machine_id, location_id, planogram_slot_id, operator_employee_id, approver_employee_id,
    product_sku, product_name, slot_code, recommended_price_czk,
    previous_customer_price_czk, proposed_price_czk, purchase_price_czk, vat_rate,
    operator_note, comparison_snapshot, economics_snapshot, approval_token_hash
  ) values (
    trim(p_client_request_key), v_visit.id, v_visit.route_plan_id, v_visit.route_plan_stop_id,
    v_slot.machine_id, v_location.id, v_slot.id, v_operator.id, v_approver.id,
    v_slot.product_sku, coalesce(v_slot.product_name, v_product.name, 'Produkt'), v_slot.slot_code,
    v_recommended, v_slot.customer_price_czk, v_proposed, v_product.purchase_price, v_product.vat_rate,
    nullif(trim(coalesce(p_note,'')),''), v_comparison, v_economics, p_token_hash
  ) returning * into v_request;

  -- Doporučená cena zůstává v price_czk. customer_price_czk a dex_price_czk
  -- popisují cenu, kterou operátor právě fyzicky nastavil.
  update public.machine_planogram_slots
  set customer_price_czk = v_proposed,
      dex_price_czk = v_proposed,
      note = concat_ws(E'\n', nullif(note,''),
        format('Cena %s Kč fyzicky nastavena operátorem %s; žádost %s čeká na schválení.',
          v_proposed, trim(concat_ws(' ',v_operator.name,v_operator.surname)), v_request.id))
  where id = v_slot.id;

  return jsonb_build_object(
    'ok', true,
    'request_id', v_request.id,
    'status', v_request.status,
    'already_exists', false,
    'approver_id', v_approver.id,
    'approver_name', trim(concat_ws(' ',v_approver.name,v_approver.surname)),
    'approver_email', v_approver.email,
    'operator_name', trim(concat_ws(' ',v_operator.name,v_operator.surname)),
    'location_name', v_location.name,
    'machine_name', v_machine.name,
    'evidence_number', v_machine.evidence_number,
    'slot_code', v_slot.slot_code,
    'product_sku', v_slot.product_sku,
    'product_name', coalesce(v_slot.product_name,v_product.name,'Produkt'),
    'recommended_price_czk', v_recommended,
    'previous_customer_price_czk', v_slot.customer_price_czk,
    'proposed_price_czk', v_proposed,
    'operator_note', nullif(trim(coalesce(p_note,'')),''),
    'comparison_snapshot', v_comparison,
    'economics_snapshot', v_economics
  );
end;
$$;

revoke all on function public.create_operator_price_change_request_v51(text,bigint,bigint,uuid,numeric,text,text)
  from public, anon, authenticated;
grant execute on function public.create_operator_price_change_request_v51(text,bigint,bigint,uuid,numeric,text,text)
  to service_role;

create or replace function public.decide_operator_price_change_v51(
  p_token text,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.operator_price_change_requests%rowtype;
  v_slot public.machine_planogram_slots%rowtype;
  v_message_id bigint;
  v_marker text;
begin
  if coalesce(auth.role(),'') <> 'service_role'
     and current_user not in ('postgres','supabase_admin') then
    raise exception 'Tuto operaci smí provést pouze schvalovací služba.';
  end if;
  if p_decision not in ('approve','reject') then raise exception 'Neplatné rozhodnutí.'; end if;

  select * into v_request
  from public.operator_price_change_requests
  where approval_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;
  if not found then raise exception 'Schvalovací odkaz není platný.'; end if;
  if v_request.status <> 'pending' then
    return jsonb_build_object('ok',true,'status',v_request.status,'already_decided',true,'request_id',v_request.id);
  end if;

  select * into v_slot from public.machine_planogram_slots
  where id = v_request.planogram_slot_id for update;
  if not found then raise exception 'Pozice už není dostupná.'; end if;
  v_marker := '[CENA:' || v_request.id::text || ']';

  if p_decision = 'approve' then
    update public.machine_planogram_slots
    set price_czk = v_request.proposed_price_czk,
        customer_price_czk = v_request.proposed_price_czk,
        dex_price_czk = v_request.proposed_price_czk,
        pending_price_czk = null,
        pending_change_note = null,
        operator_instruction = case
          when operator_instruction like v_marker || '%' then null
          else operator_instruction
        end
    where id = v_slot.id;

    update public.operator_price_change_requests
    set status='approved', decided_at=now(), decision_note='Vyšší cena byla schválena.'
    where id=v_request.id;
    return jsonb_build_object('ok',true,'status','approved','request_id',v_request.id,
      'price_czk',v_request.proposed_price_czk);
  end if;

  insert into public.location_operator_messages(
    location_id, machine_id, title, message, display_mode,
    requires_acknowledgement, is_active, created_by_employee_id
  ) values (
    v_request.location_id,
    v_request.machine_id,
    'Vrátit cenu pozice ' || v_request.slot_code,
    format('Cena %s na pozici %s (%s) nebyla schválena. Při příští návštěvě ji fyzicky vraťte na doporučených %s Kč a potvrďte změnu v aplikaci.',
      v_request.proposed_price_czk, v_request.slot_code, v_request.product_name, v_request.recommended_price_czk),
    'next_visit', true, true, v_request.approver_employee_id
  ) returning id into v_message_id;

  update public.machine_planogram_slots
  set pending_price_czk = v_request.recommended_price_czk,
      pending_change_mode = 'sell_through',
      pending_change_effective_date = current_date + 1,
      pending_change_note = v_marker || ' Vyšší cena nebyla schválena; vraťte ji na doporučenou cenu.',
      operator_instruction = v_marker || ' Při příští návštěvě vraťte cenu na ' || v_request.recommended_price_czk || ' Kč.'
  where id = v_slot.id;

  update public.operator_price_change_requests
  set status='rejected', decided_at=now(), decision_note='Vyšší cena byla zamítnuta; čeká se na fyzické vrácení ceny.',
      operator_message_id=v_message_id
  where id=v_request.id;

  return jsonb_build_object('ok',true,'status','rejected','request_id',v_request.id,
    'return_price_czk',v_request.recommended_price_czk,'operator_message_id',v_message_id);
end;
$$;

revoke all on function public.decide_operator_price_change_v51(text,text)
  from public, anon, authenticated;
grant execute on function public.decide_operator_price_change_v51(text,text)
  to service_role;

create or replace function public.close_rejected_operator_price_change_v51()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.operator_price_change_requests%rowtype;
  v_marker text;
begin
  select * into v_request
  from public.operator_price_change_requests r
  where r.planogram_slot_id = new.id
    and r.status = 'rejected'
    and new.customer_price_czk is not distinct from r.recommended_price_czk
  order by r.decided_at desc
  limit 1
  for update;
  if not found then return new; end if;

  update public.operator_price_change_requests
  set status='reverted', reverted_at=now(), decision_note='Zamítnutá cena byla při návštěvě fyzicky vrácena.'
  where id=v_request.id;

  if v_request.operator_message_id is not null then
    update public.location_operator_messages
    set is_active=false, closed_at=coalesce(closed_at,now())
    where id=v_request.operator_message_id;
  end if;

  v_marker := '[CENA:' || v_request.id::text || ']';
  if new.operator_instruction like v_marker || '%' then new.operator_instruction := null; end if;
  if new.pending_change_note like v_marker || '%' then
    new.pending_change_note := null;
    new.pending_change_effective_date := null;
  end if;
  if new.pending_price_czk is not distinct from v_request.recommended_price_czk then new.pending_price_czk := null; end if;
  return new;
end;
$$;

drop trigger if exists machine_planogram_slot_close_rejected_price_v51
  on public.machine_planogram_slots;
create trigger machine_planogram_slot_close_rejected_price_v51
before update of customer_price_czk on public.machine_planogram_slots
for each row execute function public.close_rejected_operator_price_change_v51();

comment on table public.operator_price_change_requests is
  'Neblokující žádosti operátorů o schválení vyšší fyzicky nastavené prodejní ceny.';
comment on column public.operator_price_change_requests.comparison_snapshot is
  'Ceny stejného SKU na ostatních místech a prodeje za posledních 30 dní v okamžiku žádosti.';
comment on column public.operator_price_change_requests.economics_snapshot is
  'Nákupní cena, DPH, rozpětí a orientační marže v okamžiku žádosti.';
