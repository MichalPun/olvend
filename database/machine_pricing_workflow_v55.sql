-- OLVEND v55: centrální cenotvorba automatu, povinné provedení v jízdě a tisk cenovek.
-- Schválení vytvoří čekající sadu. Aktivní cena se přepíše až po potvrzení
-- fyzické změny obsluhou přímo u automatu.

create extension if not exists pgcrypto;

create table if not exists public.pricing_category_margin_rules (
  id bigint generated always as identity primary key,
  machine_id bigint not null references public.machines(id) on delete cascade,
  category_key text not null,
  minimum_margin_percent numeric(6,2) not null check (minimum_margin_percent >= 0 and minimum_margin_percent < 100),
  rounding_step_czk numeric(8,2) not null default 1 check (rounding_step_czk > 0),
  updated_by_employee_id uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(machine_id, category_key)
);

create table if not exists public.machine_price_change_batches (
  id uuid primary key default gen_random_uuid(),
  batch_code text not null unique,
  machine_id bigint not null references public.machines(id) on delete cascade,
  status text not null default 'approved' check (status in ('approved','in_progress','completed','cancelled')),
  note text,
  created_by_employee_id uuid references public.employees(id) on delete set null,
  approved_by_employee_id uuid references public.employees(id) on delete set null,
  approved_at timestamptz not null default now(),
  completed_at timestamptz,
  location_operator_message_id bigint references public.location_operator_messages(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.machine_price_change_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.machine_price_change_batches(id) on delete cascade,
  machine_id bigint not null references public.machines(id) on delete cascade,
  target_type text not null check (target_type in ('food_slot','coffee_button')),
  planogram_slot_id bigint references public.machine_planogram_slots(id) on delete cascade,
  coffee_button_id bigint references public.machine_coffee_buttons(id) on delete cascade,
  slot_code text not null,
  product_id bigint references public.products(id) on delete set null,
  product_sku text,
  product_name text not null,
  category_key text not null,
  purchase_price_czk numeric(12,2),
  vat_rate numeric(6,2),
  old_price_czk numeric(10,2) not null check (old_price_czk >= 0),
  recommended_price_czk numeric(10,2) not null check (recommended_price_czk > 0),
  new_price_czk numeric(10,2) not null check (new_price_czk > 0),
  minimum_margin_percent numeric(6,2) not null,
  benchmark_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','applied','cancelled')),
  applied_visit_id bigint references public.route_machine_visits(id) on delete set null,
  applied_by_employee_id uuid references public.employees(id) on delete set null,
  applied_at timestamptz,
  label_printed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint machine_price_change_target_check check (
    (target_type = 'food_slot' and planogram_slot_id is not null and coffee_button_id is null)
    or (target_type = 'coffee_button' and coffee_button_id is not null and planogram_slot_id is null)
  )
);

create unique index if not exists machine_price_change_pending_slot_idx
  on public.machine_price_change_items(planogram_slot_id)
  where status = 'pending' and planogram_slot_id is not null;

create unique index if not exists machine_price_change_pending_button_idx
  on public.machine_price_change_items(coffee_button_id)
  where status = 'pending' and coffee_button_id is not null;

create index if not exists machine_price_change_batch_machine_idx
  on public.machine_price_change_batches(machine_id, approved_at desc);

create index if not exists machine_price_change_item_batch_idx
  on public.machine_price_change_items(batch_id, status);

create or replace function public.machine_pricing_current_employee_id_v55()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.employees
  where auth_user_id = auth.uid() and active is distinct from false
  limit 1
$$;

create or replace function public.machine_pricing_can_manage_v55()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.employees
    where auth_user_id = auth.uid()
      and active is distinct from false
      and lower(coalesce(role,'')) in ('admin','manager')
  )
$$;

create or replace function public.touch_machine_pricing_v55()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists pricing_category_margin_rules_touch_v55 on public.pricing_category_margin_rules;
create trigger pricing_category_margin_rules_touch_v55 before update on public.pricing_category_margin_rules
for each row execute function public.touch_machine_pricing_v55();

drop trigger if exists machine_price_change_batches_touch_v55 on public.machine_price_change_batches;
create trigger machine_price_change_batches_touch_v55 before update on public.machine_price_change_batches
for each row execute function public.touch_machine_pricing_v55();

alter table public.pricing_category_margin_rules enable row level security;
alter table public.machine_price_change_batches enable row level security;
alter table public.machine_price_change_items enable row level security;

revoke all on public.pricing_category_margin_rules from anon, authenticated;
revoke all on public.machine_price_change_batches from anon, authenticated;
revoke all on public.machine_price_change_items from anon, authenticated;
grant select on public.pricing_category_margin_rules, public.machine_price_change_batches, public.machine_price_change_items to authenticated;

drop policy if exists "Authenticated reads pricing rules" on public.pricing_category_margin_rules;
create policy "Authenticated reads pricing rules" on public.pricing_category_margin_rules
for select to authenticated using (public.machine_pricing_current_employee_id_v55() is not null);

drop policy if exists "Authenticated reads price batches" on public.machine_price_change_batches;
create policy "Authenticated reads price batches" on public.machine_price_change_batches
for select to authenticated using (public.machine_pricing_current_employee_id_v55() is not null);

drop policy if exists "Authenticated reads price items" on public.machine_price_change_items;
create policy "Authenticated reads price items" on public.machine_price_change_items
for select to authenticated using (public.machine_pricing_current_employee_id_v55() is not null);

create or replace function public.get_machine_pricing_context_v55(p_machine_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_result jsonb;
begin
  if public.machine_pricing_current_employee_id_v55() is null then raise exception 'Přihlášení vypršelo.'; end if;
  if not exists(select 1 from public.machines where id = p_machine_id) then raise exception 'Automat nebyl nalezen.'; end if;

  select jsonb_build_object(
    'machine', jsonb_build_object(
      'id',m.id,'name',m.name,'evidence_number',m.evidence_number,'machine_type',m.machine_type,
      'brand',m.brand,'model',m.model,'location_id',m.location_id,
      'location_name',l.name,'location_city',l.city,'location_address',l.address
    ),
    'rules', coalesce((select jsonb_agg(to_jsonb(r) order by r.category_key) from public.pricing_category_margin_rules r where r.machine_id=m.id),'[]'::jsonb),
    'products', coalesce((select jsonb_agg(x.row_data order by x.sort_order, x.slot_code) from (
      select s.sort_order, s.slot_code, jsonb_build_object(
        'target_type','food_slot','target_id',s.id,'slot_code',s.slot_code,'product_id',p.id,
        'product_sku',coalesce(s.product_sku,p.sku),'product_name',coalesce(s.product_name,p.name),
        'category_key',case when p.product_category in ('beverage_ready','snack_ready','food_ready') then p.product_category else 'other' end,
        'purchase_price_czk',p.purchase_price,
        'vat_rate',coalesce(p.vat_rate,21),'current_price_czk',coalesce(s.customer_price_czk,s.price_czk,s.dex_price_czk,0),
        'benchmark',coalesce((select jsonb_build_object(
          'minimum',min(z.price_czk),'average',round(avg(z.price_czk),2),'maximum',max(z.price_czk),'count',count(*),
          'sources',jsonb_agg(jsonb_build_object('machine_id',z.machine_id,'evidence_number',z.evidence_number,'machine_name',z.machine_name,'location_name',z.location_name,'price_czk',z.price_czk) order by z.price_czk)
        ) from (
          select os.machine_id, om.evidence_number, om.name machine_name, ol.name location_name,
                 coalesce(os.customer_price_czk,os.price_czk,os.dex_price_czk) price_czk
          from public.machine_planogram_slots os join public.machines om on om.id=os.machine_id left join public.locations ol on ol.id=om.location_id
          where os.active is distinct from false and os.machine_id<>m.id and nullif(os.product_sku,'')=nullif(s.product_sku,'')
            and coalesce(os.customer_price_czk,os.price_czk,os.dex_price_czk) is not null
          union all
          select ob.machine_id, om.evidence_number, om.name, ol.name, coalesce(ob.customer_price_czk,ob.sale_price_czk)
          from public.machine_coffee_buttons ob join public.machines om on om.id=ob.machine_id left join public.locations ol on ol.id=om.location_id
          where ob.active is distinct from false and ob.machine_id<>m.id and nullif(ob.product_sku,'')=nullif(s.product_sku,'')
            and coalesce(ob.customer_price_czk,ob.sale_price_czk) is not null
        ) z),'{}'::jsonb),
        'pending_item', (select to_jsonb(pi) from public.machine_price_change_items pi where pi.planogram_slot_id=s.id and pi.status='pending' limit 1)
      ) row_data
      from public.machine_planogram_slots s left join public.products p on p.sku=s.product_sku
      where s.machine_id=m.id and s.active is distinct from false
      union all
      select 100000+b.sort_order, b.selection_code, jsonb_build_object(
        'target_type','coffee_button','target_id',b.id,'slot_code',b.selection_code,'product_id',p.id,
        'product_sku',coalesce(b.product_sku,p.sku),'product_name',coalesce(b.product_name,p.name),
        'category_key','coffee','purchase_price_czk',coalesce((
          select round(sum(
            ri.quantity_per_vend * ip.purchase_price /
            coalesce(nullif(case
              when lower(coalesce(ip.base_unit,'')) in ('kg','l') and lower(coalesce(ri.unit,'')) in ('g','ml')
                then case when pp.units_per_package is null then 1000 when pp.units_per_package < 100 then pp.units_per_package*1000 else pp.units_per_package end
              else pp.units_per_package
            end,0),1)
          ),2)
          from public.machine_coffee_recipe_items ri
          left join public.machine_coffee_containers rc on rc.id=ri.coffee_container_id
          join public.products ip on ip.id=coalesce(ri.product_id,rc.product_id)
          left join lateral (
            select pkg.units_per_package from public.product_packages pkg
            where pkg.product_id=ip.id and pkg.active is distinct from false
            order by pkg.is_default desc,pkg.id limit 1
          ) pp on true
          where ri.coffee_button_id=b.id and ri.active is distinct from false and ip.purchase_price is not null
        ),p.purchase_price),
        'vat_rate',coalesce(p.vat_rate,12),'current_price_czk',coalesce(b.customer_price_czk,b.sale_price_czk,0),
        'benchmark',coalesce((select jsonb_build_object(
          'minimum',min(z.price_czk),'average',round(avg(z.price_czk),2),'maximum',max(z.price_czk),'count',count(*),
          'sources',jsonb_agg(jsonb_build_object('machine_id',z.machine_id,'evidence_number',z.evidence_number,'machine_name',z.machine_name,'location_name',z.location_name,'price_czk',z.price_czk) order by z.price_czk)
        ) from (
          select ob.machine_id, om.evidence_number, om.name machine_name, ol.name location_name, coalesce(ob.customer_price_czk,ob.sale_price_czk) price_czk
          from public.machine_coffee_buttons ob join public.machines om on om.id=ob.machine_id left join public.locations ol on ol.id=om.location_id
          where ob.active is distinct from false and ob.machine_id<>m.id and nullif(ob.product_sku,'')=nullif(b.product_sku,'')
            and coalesce(ob.customer_price_czk,ob.sale_price_czk) is not null
        ) z),'{}'::jsonb),
        'pending_item', (select to_jsonb(pi) from public.machine_price_change_items pi where pi.coffee_button_id=b.id and pi.status='pending' limit 1)
      )
      from public.machine_coffee_buttons b left join public.products p on p.id=b.product_id
      where b.machine_id=m.id and b.active is distinct from false
    ) x),'[]'::jsonb),
    'pending_batches', coalesce((select jsonb_agg(to_jsonb(pb) order by pb.approved_at desc) from public.machine_price_change_batches pb where pb.machine_id=m.id and pb.status in ('approved','in_progress')),'[]'::jsonb),
    'next_visit_date', (select min(rp.planning_date) from public.route_plan_stops rs join public.route_plans rp on rp.id=rs.route_plan_id where rs.machine_id=m.id and rs.status not in ('completed','skipped') and rp.planning_date>=current_date)
  ) into v_result
  from public.machines m left join public.locations l on l.id=m.location_id where m.id=p_machine_id;
  return v_result;
end;
$$;

create or replace function public.save_machine_pricing_rules_v55(p_machine_id bigint, p_rules jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_employee uuid := public.machine_pricing_current_employee_id_v55(); v_rule jsonb; v_count integer:=0;
begin
  if not public.machine_pricing_can_manage_v55() then raise exception 'Pravidla cen může měnit pouze vedoucí.'; end if;
  if jsonb_typeof(coalesce(p_rules,'[]'::jsonb))<>'array' then raise exception 'Neplatný seznam pravidel.'; end if;
  for v_rule in select * from jsonb_array_elements(p_rules) loop
    insert into public.pricing_category_margin_rules(machine_id,category_key,minimum_margin_percent,rounding_step_czk,updated_by_employee_id)
    values(p_machine_id,trim(v_rule->>'category_key'),(v_rule->>'minimum_margin_percent')::numeric,coalesce((v_rule->>'rounding_step_czk')::numeric,1),v_employee)
    on conflict(machine_id,category_key) do update set minimum_margin_percent=excluded.minimum_margin_percent,rounding_step_czk=excluded.rounding_step_czk,updated_by_employee_id=excluded.updated_by_employee_id,updated_at=now();
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('ok',true,'saved',v_count);
end;
$$;

create or replace function public.assign_machine_price_change_checks_v55(p_visit_id bigint)
returns integer language plpgsql security definer set search_path=public as $$
declare v_count integer;
begin
  insert into public.route_machine_visit_checks(visit_id,check_key,label,required,status,assigned_payload)
  select v.id,'price_change:'||i.id::text,
         format('Změnit cenu pozice %s: %s → %s Kč',i.slot_code,trim(to_char(i.old_price_czk,'FM999999990D00')),trim(to_char(i.new_price_czk,'FM999999990D00'))),
         true,'pending',jsonb_build_object('section','outside','order',5,'kind','price_change','price_change_item_id',i.id,'batch_id',i.batch_id,'target_type',i.target_type,'target_id',coalesce(i.planogram_slot_id,i.coffee_button_id),'slot_code',i.slot_code,'old_price_czk',i.old_price_czk,'new_price_czk',i.new_price_czk)
  from public.route_machine_visits v join public.machine_price_change_items i on i.machine_id=v.machine_id and i.status='pending'
  where v.id=p_visit_id and v.status not in ('completed','skipped')
  on conflict(visit_id,check_key) do nothing;
  get diagnostics v_count=row_count; return v_count;
end;
$$;

create or replace function public.machine_pricing_assign_visit_trigger_v55()
returns trigger language plpgsql security definer set search_path=public as $$
begin perform public.assign_machine_price_change_checks_v55(new.id); return new; end;
$$;

drop trigger if exists machine_pricing_assign_visit_v55 on public.route_machine_visits;
create trigger machine_pricing_assign_visit_v55 after insert on public.route_machine_visits
for each row execute function public.machine_pricing_assign_visit_trigger_v55();

create or replace function public.approve_machine_price_change_v55(p_machine_id bigint,p_items jsonb,p_rules jsonb default '[]'::jsonb,p_note text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_employee uuid:=public.machine_pricing_current_employee_id_v55(); v_batch public.machine_price_change_batches%rowtype;
  v_machine public.machines%rowtype; v_location_id bigint; v_message_id bigint; v_item jsonb; v_slot public.machine_planogram_slots%rowtype;
  v_button public.machine_coffee_buttons%rowtype; v_product public.products%rowtype; v_old numeric; v_new numeric; v_cost numeric; v_vat numeric; v_min numeric; v_margin numeric; v_category text; v_count integer:=0; v_visit record;
begin
  if not public.machine_pricing_can_manage_v55() then raise exception 'Ceny může schválit pouze vedoucí.'; end if;
  if jsonb_typeof(coalesce(p_items,'[]'::jsonb))<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Vyberte alespoň jednu změnu ceny.'; end if;
  perform public.save_machine_pricing_rules_v55(p_machine_id,coalesce(p_rules,'[]'::jsonb));
  select * into v_machine from public.machines where id=p_machine_id for update;
  if not found then raise exception 'Automat nebyl nalezen.'; end if;
  v_location_id:=v_machine.location_id;
  if v_location_id is null then raise exception 'Automat nemá přiřazenou lokalitu.'; end if;
  insert into public.machine_price_change_batches(batch_code,machine_id,status,note,created_by_employee_id,approved_by_employee_id)
  values('NC-'||to_char(clock_timestamp(),'YYYYMMDD-HH24MISS')||'-'||upper(substr(gen_random_uuid()::text,1,4)),p_machine_id,'approved',nullif(trim(coalesce(p_note,'')),''),v_employee,v_employee)
  returning * into v_batch;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_new:=(v_item->>'new_price_czk')::numeric;
    if v_item->>'target_type'='food_slot' then
      select * into v_slot from public.machine_planogram_slots where id=(v_item->>'target_id')::bigint and machine_id=p_machine_id for update;
      if not found then raise exception 'Pozice potravinového automatu nebyla nalezena.'; end if;
      if exists(select 1 from public.machine_price_change_items where planogram_slot_id=v_slot.id and status='pending') then raise exception 'Pozice % už čeká na provedení.',v_slot.slot_code; end if;
      select * into v_product from public.products where sku=v_slot.product_sku limit 1;
      v_category:=case when v_product.product_category in ('beverage_ready','snack_ready','food_ready') then v_product.product_category else 'other' end;
      select minimum_margin_percent into v_min from public.pricing_category_margin_rules where machine_id=p_machine_id and category_key=v_category;
      v_min:=coalesce(v_min,0);
      v_old:=coalesce(v_slot.customer_price_czk,v_slot.price_czk,v_slot.dex_price_czk,0); v_cost:=v_product.purchase_price; v_vat:=coalesce(v_product.vat_rate,21);
      if v_new<=0 or v_new=v_old then continue; end if;
      v_margin:=case when v_cost is null or v_new=0 then null else ((v_new/(1+v_vat/100)-v_cost)/(v_new/(1+v_vat/100)))*100 end;
      if v_margin is not null and v_margin+0.01<v_min then raise exception 'Cena pozice % nesplňuje minimální marži % %.',v_slot.slot_code,v_min,'%'; end if;
      insert into public.machine_price_change_items(batch_id,machine_id,target_type,planogram_slot_id,slot_code,product_id,product_sku,product_name,category_key,purchase_price_czk,vat_rate,old_price_czk,recommended_price_czk,new_price_czk,minimum_margin_percent,benchmark_snapshot)
      values(v_batch.id,p_machine_id,'food_slot',v_slot.id,v_slot.slot_code,v_product.id,coalesce(v_slot.product_sku,v_product.sku),v_slot.product_name,v_category,v_cost,v_vat,v_old,coalesce((v_item->>'recommended_price_czk')::numeric,v_new),v_new,v_min,coalesce(v_item->'benchmark_snapshot','{}'::jsonb));
    elsif v_item->>'target_type'='coffee_button' then
      select * into v_button from public.machine_coffee_buttons where id=(v_item->>'target_id')::bigint and machine_id=p_machine_id for update;
      if not found then raise exception 'Tlačítko kávového automatu nebylo nalezeno.'; end if;
      if exists(select 1 from public.machine_price_change_items where coffee_button_id=v_button.id and status='pending') then raise exception 'Pozice % už čeká na provedení.',v_button.selection_code; end if;
      select * into v_product from public.products where id=v_button.product_id;
      v_category:='coffee';
      select minimum_margin_percent into v_min from public.pricing_category_margin_rules where machine_id=p_machine_id and category_key=v_category;
      v_min:=coalesce(v_min,0);
      select round(sum(
        ri.quantity_per_vend * ip.purchase_price /
        coalesce(nullif(case
          when lower(coalesce(ip.base_unit,'')) in ('kg','l') and lower(coalesce(ri.unit,'')) in ('g','ml')
            then case when pp.units_per_package is null then 1000 when pp.units_per_package < 100 then pp.units_per_package*1000 else pp.units_per_package end
          else pp.units_per_package
        end,0),1)
      ),2) into v_cost
      from public.machine_coffee_recipe_items ri
      left join public.machine_coffee_containers rc on rc.id=ri.coffee_container_id
      join public.products ip on ip.id=coalesce(ri.product_id,rc.product_id)
      left join lateral (
        select pkg.units_per_package from public.product_packages pkg
        where pkg.product_id=ip.id and pkg.active is distinct from false
        order by pkg.is_default desc,pkg.id limit 1
      ) pp on true
      where ri.coffee_button_id=v_button.id and ri.active is distinct from false and ip.purchase_price is not null;
      v_cost:=coalesce(v_cost,v_product.purchase_price); v_vat:=coalesce(v_product.vat_rate,12);
      v_old:=coalesce(v_button.customer_price_czk,v_button.sale_price_czk,0);
      if v_new<=0 or v_new=v_old then continue; end if;
      v_margin:=((v_new/(1+v_vat/100)-v_cost)/(v_new/(1+v_vat/100)))*100;
      if v_margin+0.01<v_min then raise exception 'Cena pozice % nesplňuje minimální marži % %.',v_button.selection_code,v_min,'%'; end if;
      insert into public.machine_price_change_items(batch_id,machine_id,target_type,coffee_button_id,slot_code,product_id,product_sku,product_name,category_key,purchase_price_czk,vat_rate,old_price_czk,recommended_price_czk,new_price_czk,minimum_margin_percent,benchmark_snapshot)
      values(v_batch.id,p_machine_id,'coffee_button',v_button.id,v_button.selection_code,v_product.id,coalesce(v_button.product_sku,v_product.sku),v_button.product_name,v_category,v_cost,v_vat,v_old,coalesce((v_item->>'recommended_price_czk')::numeric,v_new),v_new,v_min,coalesce(v_item->'benchmark_snapshot','{}'::jsonb));
    else raise exception 'Neplatný typ cenové položky.'; end if;
    v_count:=v_count+1;
  end loop;
  if v_count=0 then raise exception 'Žádná cena se proti aktuálnímu stavu nemění.'; end if;
  insert into public.location_operator_messages(location_id,machine_id,title,message,display_mode,requires_acknowledgement,is_active,created_by_employee_id)
  values(v_location_id,p_machine_id,'Povinná změna cen · '||v_batch.batch_code,format('U automatu %s je připraveno %s změn cen. Proveďte je v průběhu návštěvy a potvrďte každou pozici.',coalesce(v_machine.name,'EV '||v_machine.evidence_number),v_count),'every_visit',false,true,v_employee)
  returning id into v_message_id;
  update public.machine_price_change_batches set location_operator_message_id=v_message_id where id=v_batch.id;
  for v_visit in select id from public.route_machine_visits where machine_id=p_machine_id and status not in ('completed','skipped') loop perform public.assign_machine_price_change_checks_v55(v_visit.id); end loop;
  return jsonb_build_object('ok',true,'batch_id',v_batch.id,'batch_code',v_batch.batch_code,'item_count',v_count,'print_url','price-label-print.html?batch='||v_batch.id::text);
exception when others then
  raise;
end;
$$;

create or replace function public.confirm_machine_price_change_v55(p_visit_id bigint,p_item_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_employee uuid:=public.machine_pricing_current_employee_id_v55(); v_visit public.route_machine_visits%rowtype; v_item public.machine_price_change_items%rowtype; v_pending integer;
begin
  if v_employee is null then raise exception 'Přihlášení vypršelo.'; end if;
  select * into v_visit from public.route_machine_visits where id=p_visit_id for update;
  if not found then raise exception 'Návštěva nebyla nalezena.'; end if;
  if v_visit.employee_id is distinct from v_employee and not public.machine_pricing_can_manage_v55() then raise exception 'Návštěva nepatří přihlášené obsluze.'; end if;
  select * into v_item from public.machine_price_change_items where id=p_item_id and machine_id=v_visit.machine_id for update;
  if not found then raise exception 'Čekající změna ceny nebyla nalezena.'; end if;
  if v_item.status='applied' then return jsonb_build_object('ok',true,'already_applied',true,'target_type',v_item.target_type,'target_id',coalesce(v_item.planogram_slot_id,v_item.coffee_button_id),'new_price_czk',v_item.new_price_czk); end if;
  if v_item.status<>'pending' then raise exception 'Tuto změnu už nelze provést.'; end if;
  if v_item.target_type='food_slot' then
    update public.machine_planogram_slots set price_czk=v_item.new_price_czk,customer_price_czk=v_item.new_price_czk,dex_price_czk=v_item.new_price_czk where id=v_item.planogram_slot_id and machine_id=v_visit.machine_id;
  else
    update public.machine_coffee_buttons set sale_price_czk=v_item.new_price_czk,customer_price_czk=v_item.new_price_czk where id=v_item.coffee_button_id and machine_id=v_visit.machine_id;
  end if;
  update public.machine_price_change_items set status='applied',applied_visit_id=p_visit_id,applied_by_employee_id=v_employee,applied_at=now() where id=v_item.id;
  update public.route_machine_visit_checks
  set status='done',completed_at=now(),operator_note=case
    when visit_id=p_visit_id then operator_note
    else concat_ws(E'\n',nullif(operator_note,''),format('Cena provedena v návštěvě #%s; tento duplicitní úkol je uzavřen automaticky.',p_visit_id))
  end
  where check_key='price_change:'||v_item.id::text;
  select count(*) into v_pending from public.machine_price_change_items where batch_id=v_item.batch_id and status='pending';
  update public.machine_price_change_batches set status=case when v_pending=0 then 'completed' else 'in_progress' end,completed_at=case when v_pending=0 then now() else null end where id=v_item.batch_id;
  if v_pending=0 then
    update public.location_operator_messages set is_active=false,closed_at=now() where id=(select location_operator_message_id from public.machine_price_change_batches where id=v_item.batch_id);
  end if;
  return jsonb_build_object('ok',true,'target_type',v_item.target_type,'target_id',coalesce(v_item.planogram_slot_id,v_item.coffee_button_id),'new_price_czk',v_item.new_price_czk,'batch_completed',v_pending=0);
end;
$$;

create or replace function public.machine_pricing_guard_visit_completion_v55()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='completed' and old.status is distinct from 'completed' and exists(select 1 from public.machine_price_change_items where machine_id=new.machine_id and status='pending') then
    raise exception 'Návštěvu nelze dokončit: u automatu čeká povinná změna ceny.';
  end if;
  return new;
end;
$$;

drop trigger if exists machine_pricing_guard_visit_completion_v55 on public.route_machine_visits;
create trigger machine_pricing_guard_visit_completion_v55 before update of status on public.route_machine_visits
for each row execute function public.machine_pricing_guard_visit_completion_v55();

create or replace function public.mark_machine_price_labels_printed_v55(p_item_ids uuid[])
returns integer language plpgsql security definer set search_path=public as $$
declare v_count integer;
begin
  if public.machine_pricing_current_employee_id_v55() is null then raise exception 'Přihlášení vypršelo.'; end if;
  update public.machine_price_change_items set label_printed_at=now() where id=any(p_item_ids);
  get diagnostics v_count=row_count; return v_count;
end;
$$;

revoke all on function public.machine_pricing_current_employee_id_v55() from public;
revoke all on function public.machine_pricing_can_manage_v55() from public;
revoke all on function public.get_machine_pricing_context_v55(bigint) from public;
revoke all on function public.save_machine_pricing_rules_v55(bigint,jsonb) from public;
revoke all on function public.assign_machine_price_change_checks_v55(bigint) from public;
revoke all on function public.approve_machine_price_change_v55(bigint,jsonb,jsonb,text) from public;
revoke all on function public.confirm_machine_price_change_v55(bigint,uuid) from public;
revoke all on function public.mark_machine_price_labels_printed_v55(uuid[]) from public;
grant execute on function public.machine_pricing_current_employee_id_v55() to authenticated;
grant execute on function public.machine_pricing_can_manage_v55() to authenticated;
grant execute on function public.get_machine_pricing_context_v55(bigint) to authenticated;
grant execute on function public.save_machine_pricing_rules_v55(bigint,jsonb) to authenticated;
grant execute on function public.assign_machine_price_change_checks_v55(bigint) to authenticated;
grant execute on function public.approve_machine_price_change_v55(bigint,jsonb,jsonb,text) to authenticated;
grant execute on function public.confirm_machine_price_change_v55(bigint,uuid) to authenticated;
grant execute on function public.mark_machine_price_labels_printed_v55(uuid[]) to authenticated;

notify pgrst,'reload schema';
