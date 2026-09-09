-- Manažerské opravy návštěv, audit a ochrana před starým mobilním zápisem.
begin;
alter table public.route_machine_visits add column if not exists correction_revision integer not null default 0;
alter table public.route_machine_visit_food_fills add column if not exists correction_sources jsonb;
create table if not exists public.route_visit_corrections (
 id bigint generated always as identity primary key,
 visit_id bigint not null references public.route_machine_visits(id),
 actor_id uuid not null references public.employees(id),
 reason text not null check(length(trim(reason))>=3),
 before_data jsonb not null, after_data jsonb not null,
 created_at timestamptz not null default now()
);
alter table public.route_visit_corrections enable row level security;
drop policy if exists route_correction_read on public.route_visit_corrections;
create policy route_correction_read on public.route_visit_corrections for select to authenticated using (
 exists(select 1 from public.employees where auth_user_id=auth.uid() and active and lower(role) in ('admin','manager'))
);
grant select on public.route_visit_corrections to authenticated;


create or replace function public.guard_corrected_route_visit_v50() returns trigger
language plpgsql security invoker set search_path=public as $$
declare v_id bigint; v_revision integer;
begin
 if current_setting('olvend.route_correction',true)='on' then
   if TG_OP='DELETE' then return old; else return new; end if;
 end if;
 if TG_TABLE_NAME='route_machine_visits' then
   if TG_OP='INSERT' then
     if new.correction_revision<>0 then raise exception 'Revizi opravy nelze nastavit z mobilu.'; end if;
     return new;
   end if;
   v_revision:=old.correction_revision;
   if TG_OP='UPDATE' and new.correction_revision is distinct from old.correction_revision then
     raise exception 'Revizi opravy lze měnit pouze přes manažerskou opravu.';
   end if;
 else
   if TG_OP='DELETE' then v_id:=old.visit_id; else v_id:=new.visit_id; end if;
   if TG_OP='UPDATE' and old.visit_id is distinct from new.visit_id then raise exception 'Položku nelze přesouvat mezi návštěvami.'; end if;
   select correction_revision into v_revision from route_machine_visits where id=v_id for share;
 end if;
 if coalesce(v_revision,0)>0 then
   raise exception 'Návštěvu opravilo vedení. Starý mobilní zápis nelze uložit; obnov trasu.';
 end if;
 if TG_OP='DELETE' then return old; else return new; end if;
end $$;
drop trigger if exists guard_corrected_visit on public.route_machine_visits;
create trigger guard_corrected_visit before insert or update or delete on public.route_machine_visits for each row execute function public.guard_corrected_route_visit_v50();
drop trigger if exists guard_corrected_items on public.route_machine_visit_items;
create trigger guard_corrected_items before insert or update or delete on public.route_machine_visit_items for each row execute function public.guard_corrected_route_visit_v50();
drop trigger if exists guard_corrected_fills on public.route_machine_visit_food_fills;
create trigger guard_corrected_fills before insert or update or delete on public.route_machine_visit_food_fills for each row execute function public.guard_corrected_route_visit_v50();

create or replace function public.guard_corrected_stock_v50() returns trigger
language plpgsql security definer set search_path=public as $$
declare visit_key bigint;
begin
 if current_setting('olvend.route_correction',true)='on' then return new; end if;
 visit_key:=substring(new.reference_id from '^route_visit_([0-9]+)_')::bigint;
 if visit_key is not null then
   perform id from route_machine_visits where id=visit_key and correction_revision>0 for share;
   if found then raise exception 'Návštěvu opravilo vedení. Starý skladový zápis z mobilu je zablokovaný; obnov trasu.'; end if;
 end if;
 return new;
end $$;
drop trigger if exists guard_corrected_stock on public.stock_movements_v13;
create trigger guard_corrected_stock before insert on public.stock_movements_v13 for each row execute function public.guard_corrected_stock_v50();

drop trigger if exists guard_corrected_cash on public.route_machine_cash_reports;
create trigger guard_corrected_cash before insert or update or delete on public.route_machine_cash_reports for each row execute function public.guard_corrected_route_visit_v50();
drop trigger if exists guard_corrected_checks on public.route_machine_visit_checks;
create trigger guard_corrected_checks before insert or update or delete on public.route_machine_visit_checks for each row execute function public.guard_corrected_route_visit_v50();

-- Inventurní rozdíl počtu před doplněním / oprava odpisu. Neznámá přebývající šarže zůstane nepřiřazená.
create or replace function public.route_correction_delta_v50(p_location bigint,p_product bigint,p_delta numeric,p_reference text,p_note text) returns void
language plpgsql security definer set search_path=public as $$
declare r record; remaining numeric:=abs(p_delta); take numeric;
begin
 if current_setting('olvend.route_correction',true) is distinct from 'on' then raise exception 'Použij formulář opravy návštěvy.'; end if;
 if p_delta>0 then
   perform apply_stock_movements_v13(jsonb_build_array(jsonb_build_object('product_id',p_product,'to_stock_location_id',p_location,'movement_type','adjustment','quantity_base_units',p_delta,'reference_type','route_correction','reference_id',p_reference,'note',p_note)));
 elsif p_delta<0 then
   for r in select * from stock_location_balances where stock_location_id=p_location and product_id=p_product and quantity_on_hand>0 order by id for update loop
     exit when remaining<=0; take:=least(remaining,r.quantity_on_hand);
     perform apply_stock_movements_v13(jsonb_build_array(jsonb_build_object('product_id',p_product,'batch_id',r.batch_id,'from_stock_location_id',p_location,'movement_type','adjustment','quantity_base_units',take,'reference_type','route_correction','reference_id',p_reference,'note',p_note)));
     remaining:=remaining-take;
   end loop;
   if remaining>.0001 then raise exception 'Oprava by vytvořila zápornou skladovou zásobu.'; end if;
 end if;
end $$;
revoke all on function public.route_correction_delta_v50(bigint,bigint,numeric,text,text) from public,anon,authenticated;

-- Jeden formulář, jedna transakce. Skladové změny jsou účetní korekce, nikoliv nové fyzické přesuny.
create or replace function public.correct_route_visit_v50(p_visit_id bigint,p_expected_revision integer,p_expected_updated_at timestamptz,p_reason text,p_patch jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v route_machine_visits%rowtype; i route_machine_visit_items%rowtype; f route_machine_visit_food_fills%rowtype;
 s machine_planogram_slots%rowtype; c machine_coffee_containers%rowtype;
 p products%rowtype; b inventory_batches%rowtype; m record; x jsonb; y jsonb;
 arrived timestamptz; ended timestamptz; skipped timestamptz; actor uuid; audit_id bigint; before_doc jsonb; after_doc jsonb; delta numeric; qty numeric; added numeric; final_qty numeric;
 vehicle_loc bigint; machine_loc bigint; original_total numeric; new_ref text; old_ref text; factor numeric:=1;
 w route_vehicle_waste_items%rowtype; before_delta numeric; sources jsonb; is_new_fill boolean; fill_seen bigint[]; change_stock boolean:=false; new_status text; cap numeric; cash numeric; seen bigint[]:='{}';
begin
 select id into actor from employees where auth_user_id=auth.uid() and active and lower(role) in ('admin','manager');
 if actor is null then raise exception 'Opravu může uložit pouze vedení.'; end if;
 if length(trim(coalesce(p_reason,'')))<3 then raise exception 'Vyplň důvod opravy.'; end if;
 if p_patch is null or jsonb_typeof(p_patch)<>'object' then raise exception 'Chybí oprava.'; end if;
 select * into strict v from route_machine_visits where id=p_visit_id for update;
 if v.correction_revision is distinct from p_expected_revision or v.updated_at is distinct from p_expected_updated_at then
   raise exception 'Zápis se mezitím změnil. Zavři opravu a otevři ji znovu.';
 end if;
 if v.status not in ('completed','skipped') then raise exception 'Operátor musí nejdřív dokončit nebo přeskočit návštěvu. Rozpracovaný zápis nelze současně opravovat.'; end if;
 perform set_config('olvend.route_correction','on',true);
 before_doc:=jsonb_build_object('waste',(select jsonb_agg(to_jsonb(t)) from route_vehicle_waste_items t where route_machine_visit_id=v.id),'visit',to_jsonb(v),'items',(select jsonb_agg(to_jsonb(t)) from route_machine_visit_items t where visit_id=v.id),'fills',(select jsonb_agg(to_jsonb(t)) from route_machine_visit_food_fills t where visit_id=v.id),'cash',(select to_jsonb(t) from route_machine_cash_reports t where visit_id=v.id));
 insert into route_visit_corrections(visit_id,actor_id,reason,before_data,after_data) values(v.id,actor,trim(p_reason),before_doc,'{}') returning id into audit_id;
 new_ref:='route_correction_'||audit_id;
 select id into vehicle_loc from stock_locations where vehicle_id=v.vehicle_id and location_type='vehicle' and active limit 1;
 select id into machine_loc from stock_locations where machine_id=v.machine_id and location_type='machine' and active limit 1;
 if jsonb_array_length(coalesce(p_patch->'items','[]'))>0 or jsonb_array_length(coalesce(p_patch->'wastes','[]'))>0 then
   if vehicle_loc is null or machine_loc is null then raise exception 'Chybí skladová karta auta nebo automatu.'; end if;
   perform id from stock_location_balances where stock_location_id in(vehicle_loc,machine_loc) order by id for update;
   if exists(select 1 from route_machine_visits newer where newer.machine_id=v.machine_id and newer.id<>v.id and coalesce(newer.arrived_at,newer.created_at)>coalesce(v.arrived_at,v.created_at) and newer.status in ('arrived','completed')) then
     raise exception 'Automat už má novější návštěvu. Skladovou opravu proveď podle aktuální fyzické kontroly.';
   end if;
 end if;
 for x in select value from jsonb_array_elements(coalesce(p_patch->'items','[]')) loop
   select * into strict i from route_machine_visit_items where id=(x->>'id')::bigint and visit_id=v.id for update;
   if i.id=any(seen) then raise exception 'Duplicitní položka opravy.'; end if; seen:=array_append(seen,i.id);
   if i.item_kind not in ('food_slot','coffee_container') then raise exception 'Tento typ položky nelze skladově opravit.'; end if;
   if exists(select 1 from inventory_audit_items ai join inventory_audits a on a.id=ai.audit_id where ai.product_id in(i.actual_product_id,i.planned_product_id) and ai.stock_location_id in(vehicle_loc,machine_loc) and a.status='closed' and a.closed_at>coalesce(i.accepted_at,v.completed_at,v.created_at)) then
     raise exception 'Po návštěvě už proběhla inventura této položky. Oprava by změnila ověřený stav.';
   end if;
   select * into strict p from products where id=coalesce(i.actual_product_id,i.planned_product_id);
   factor:=case when lower(i.unit)=lower(p.base_unit) then 1 when lower(i.unit)='g' and lower(p.base_unit)='kg' then .001 when lower(i.unit)='ml' and lower(p.base_unit)='l' then .001 else null end;
   if factor is null then raise exception 'Nepodporovaný převod jednotek % → %.',i.unit,p.base_unit; end if;
   before_delta:=coalesce((x->>'before')::numeric,i.actual_before_quantity)-coalesce(i.actual_before_quantity,0);
   if coalesce((x->>'before')::numeric,i.actual_before_quantity)<0 then raise exception 'Stav před doplněním nesmí být záporný.'; end if;
   cap:=(x->>'capacity')::numeric;
   if coalesce((x->>'before')::numeric,i.actual_before_quantity)>cap then raise exception 'Stav před doplněním přesahuje kapacitu.'; end if;
   if cap is null or cap<=0 or cap>1000000 then raise exception 'Zadej platnou kapacitu.'; end if;
   if i.item_kind='food_slot' then
     select * into strict s from machine_planogram_slots where id=i.planogram_slot_id and machine_id=v.machine_id for update;
     if before_delta<>0 then
       if s.product_sku is distinct from p.sku or coalesce(s.changeover_new_units,0)>0 or (select count(distinct product_id) from route_machine_visit_food_fills where visit_item_id=i.id)>1 or exists(select 1 from jsonb_array_elements(coalesce(x->'fills','[]')) e where (e->>'product_id')::bigint<>p.id) then raise exception 'Oprava stavu před doplněním vyžaduje jednoznačný produkt bez směsi.'; end if;
       if before_delta<>trunc(before_delta) then raise exception 'Stav pozice musí být celé kusy.'; end if;
       perform route_correction_delta_v50(machine_loc,p.id,before_delta,new_ref||'_before_'||i.id,p_reason);
     end if;
     if cap<>trunc(cap) then raise exception 'Kapacita pozice musí být celé kusy.'; end if;
     added:=0; fill_seen:='{}';
     if (select count(*) from route_machine_visit_food_fills where visit_item_id=i.id)<>(select count(*) from jsonb_array_elements(coalesce(x->'fills','[]')) t where (t->>'id')::bigint>0) then raise exception 'Seznam doplnění se změnil.'; end if;
     for y in select value from jsonb_array_elements(coalesce(x->'fills','[]')) loop
       is_new_fill:=(y->>'id')::bigint<0;
       if is_new_fill then
         f:=null; f.id:=(y->>'id')::bigint; f.visit_item_id:=i.id; f.visit_id:=v.id; f.product_id:=coalesce(i.actual_product_id,i.planned_product_id); f.quantity:=0; f.correction_sources:='[]';
       else select * into strict f from route_machine_visit_food_fills where id=(y->>'id')::bigint and visit_item_id=i.id for update; end if;
       if f.id=any(fill_seen) then raise exception 'Duplicitní doplnění.'; end if; fill_seen:=array_append(fill_seen,f.id);
       qty:=(y->>'quantity')::numeric;
       if qty is null or qty<0 or qty<>trunc(qty) or qty>10000 then raise exception 'Počet kusů musí být nezáporné celé číslo.'; end if;
       if (y->>'product_id')::bigint<>f.product_id then
         if (select count(*) from route_machine_visit_food_fills where visit_item_id=i.id)<>(case when is_new_fill then 0 else 1 end) or coalesce(i.actual_before_quantity,0)-coalesce(i.removed_quantity,0)<>0 or s.current_units<>i.final_quantity or coalesce(s.changeover_new_units,0)>0 or s.pending_product_sku is not null then
           raise exception 'Změna produktu vyžaduje pozici bez směsi původního zboží a bez následného prodeje. Nejdřív ověř skutečný obsah pozice.';
         end if;
       end if;
       select * into strict p from products where id=(y->>'product_id')::bigint and active;
       if (y->>'price')::numeric is null or (y->>'price')::numeric<0 or (y->>'price')::numeric>10000 then raise exception 'Zadej platnou cenu.'; end if;
       if exists(select 1 from inventory_audit_items ai join inventory_audits a on a.id=ai.audit_id where ai.product_id=p.id and ai.stock_location_id in(vehicle_loc,machine_loc) and a.status='closed' and a.closed_at>coalesce(i.accepted_at,v.completed_at,v.created_at)) then raise exception 'Nový produkt má novější inventuru.'; end if;
       if p.base_unit<>'ks' then raise exception 'Potravinová pozice vyžaduje produkt v kusech.'; end if;
       select * into b from inventory_batches where id=nullif(y->>'batch_id','')::bigint and product_id=p.id;
       if qty>0 and (not found or coalesce(b.best_before_date,b.use_by_date) is distinct from nullif(y->>'expiry','')::date) then raise exception 'Vyber šarži odpovídající produktu a expiraci.'; end if;
       if qty>0 and (b.best_before_date is not null or b.use_by_date is not null) and coalesce(b.best_before_date,b.use_by_date)<v.visit_date then raise exception 'Šarže byla v den návštěvy po expiraci.'; end if;
       old_ref:=f.stock_reference_id;
       sources:=f.correction_sources;
       if sources is null then
         select jsonb_agg(jsonb_build_object('product_id',product_id,'batch_id',batch_id,'quantity',quantity_base_units)) into sources from stock_movements_v13 where reference_id=old_ref and from_stock_location_id=vehicle_loc and to_stock_location_id=machine_loc and product_id=f.product_id;
       end if;
       select sum((value->>'quantity')::numeric) into original_total from jsonb_array_elements(sources);
       if coalesce(original_total,0) is distinct from f.quantity::numeric then raise exception 'Původní skladové pohyby doplnění nesouhlasí. Je nutná individuální kontrola.'; end if;
       -- Nejprve vrátíme účetní původní doplnění, pak zapíšeme skutečné. Stejné šarže se započtou netto.
       for m in
         with deltas as (
           select (value->>'product_id')::bigint product_id,(value->>'batch_id')::bigint batch_id,(value->>'quantity')::numeric q from jsonb_array_elements(sources)
           union all select p.id,b.id,-qty where qty>0
         ) select product_id,batch_id,sum(q) q from deltas group by product_id,batch_id having sum(q)<>0
       loop
         perform apply_stock_movements_v13(jsonb_build_array(jsonb_build_object('product_id',m.product_id,'batch_id',m.batch_id,'from_stock_location_id',case when m.q>0 then machine_loc else vehicle_loc end,'to_stock_location_id',case when m.q>0 then vehicle_loc else machine_loc end,'movement_type',case when m.q>0 then 'return' else 'fill_machine' end,'quantity_base_units',abs(m.q),'reference_type','route_correction','reference_id',new_ref||'_fill_'||f.id,'note',p_reason)));
       end loop;
       -- Uložení opraveného rozpisu šarží pro případnou další opravu; původní pohyby zůstávají v historii.
       if qty<>f.quantity or p.id<>f.product_id or b.id is distinct from nullif(y->>'original_batch_id','')::bigint then change_stock:=true; end if;
       if p.id<>f.product_id then
         update machine_planogram_slots set product_sku=p.sku,product_name=p.name where id=s.id;
       end if;
       if is_new_fill and qty>0 then
         insert into route_machine_visit_food_fills(visit_id,visit_item_id,machine_id,planogram_slot_id,product_id,product_sku,product_name,quantity,expiry_date,sale_price_czk,load_order,stock_reference_id,correction_sources)
         values(v.id,i.id,v.machine_id,i.planogram_slot_id,p.id,p.sku,p.name,qty,nullif(y->>'expiry','')::date,(y->>'price')::numeric,(select coalesce(max(load_order),-1)+1 from route_machine_visit_food_fills where visit_item_id=i.id),new_ref||'_new_'||i.id||'_'||abs(f.id),jsonb_build_array(jsonb_build_object('product_id',p.id,'batch_id',b.id,'quantity',qty)));
       elsif qty=0 then delete from route_machine_visit_food_fills where id=f.id;
       else update route_machine_visit_food_fills set quantity=qty,product_id=p.id,product_sku=p.sku,product_name=p.name,expiry_date=nullif(y->>'expiry','')::date,sale_price_czk=(y->>'price')::numeric,correction_sources=jsonb_build_array(jsonb_build_object('product_id',p.id,'batch_id',b.id,'quantity',qty)) where id=f.id; end if;
       added:=added+qty;
     end loop;
     delta:=added-i.actual_add_quantity+before_delta;
     if coalesce(s.changeover_new_units,0)>0 and delta<>0 then raise exception 'Pozice obsahuje směs při výměně sortimentu. Je nutné ověřit počty obou druhů.'; end if;
     final_qty:=i.final_quantity+delta;
     if final_qty<0 or final_qty>cap or s.current_units+delta<0 or s.current_units+delta>cap then raise exception 'Opravený stav je mimo kapacitu pozice.'; end if;
     update machine_planogram_slots set current_units=current_units+delta,capacity_units=cap,target_units=least(coalesce(target_units,cap),cap),desired_units=greatest(0,least(coalesce(target_units,cap),cap)-(current_units+delta)),fill_percent=round(100*(current_units+delta)/cap,2),updated_at=now() where id=s.id;
     if jsonb_array_length(x->'fills')=1 then
       update route_machine_visit_items set actual_product_id=p.id,actual_product_sku=p.sku,actual_product_name=p.name where id=i.id;
       if coalesce(s.changeover_new_units,0)=0 and (s.product_sku=p.sku or coalesce(i.actual_before_quantity,0)-coalesce(i.removed_quantity,0)=0) then
         update machine_planogram_slots set price_czk=((x->'fills'->0)->>'price')::numeric,customer_price_czk=((x->'fills'->0)->>'price')::numeric where id=s.id;
         update route_machine_visit_items set sale_price_czk=((x->'fills'->0)->>'price')::numeric where id=i.id;
       end if;
       if coalesce(i.actual_before_quantity,0)-coalesce(i.removed_quantity,0)=0 then
         update machine_planogram_slots set expiry_date=nullif((x->'fills'->0)->>'expiry','')::date,price_czk=((x->'fills'->0)->>'price')::numeric,customer_price_czk=((x->'fills'->0)->>'price')::numeric where id=s.id;
       end if;
     end if;
   else
     select * into strict c from machine_coffee_containers where id=i.coffee_container_id and machine_id=v.machine_id for update;
     old_ref:='route_visit_'||v.id||'_container_'||i.coffee_container_id;
     select coalesce(sum(case when from_stock_location_id=vehicle_loc and to_stock_location_id=machine_loc then quantity_base_units when from_stock_location_id=machine_loc and to_stock_location_id=vehicle_loc then -quantity_base_units else 0 end),0) into original_total
     from stock_movements_v13 sm where sm.product_id=p.id and (sm.reference_id=old_ref or left(sm.reference_id,length(old_ref)+1)=old_ref||'_' or exists(select 1 from route_visit_corrections a where a.visit_id=v.id and sm.reference_id='route_correction_'||a.id||'_container_'||i.id));
     if abs(original_total-i.actual_add_quantity*factor)>.0001 then raise exception 'Skladové pohyby suroviny nesouhlasí s návštěvou. Je nutná individuální kontrola.'; end if;
     added:=(x->>'added')::numeric; delta:=added-i.actual_add_quantity; final_qty:=i.final_quantity+delta+before_delta;
     if added is null or added<0 or final_qty<0 or final_qty>cap or c.current_quantity+delta+before_delta<0 or c.current_quantity+delta+before_delta>cap then raise exception 'Opravený stav je mimo kapacitu zásobníku.'; end if;
     qty:=abs(delta*factor);
     for m in select * from stock_location_balances where stock_location_id=case when delta>0 then vehicle_loc else machine_loc end and product_id=p.id and quantity_on_hand>0 order by id for update loop
       exit when qty<=0;
       original_total:=least(qty,m.quantity_on_hand);
       perform apply_stock_movements_v13(jsonb_build_array(jsonb_build_object('product_id',p.id,'batch_id',m.batch_id,'from_stock_location_id',case when delta>0 then vehicle_loc else machine_loc end,'to_stock_location_id',case when delta>0 then machine_loc else vehicle_loc end,'movement_type',case when delta>0 then 'fill_machine' else 'return' end,'quantity_base_units',original_total,'reference_type','route_correction','reference_id',new_ref||'_container_'||i.id,'note',p_reason)));
       qty:=qty-original_total;
     end loop;
     if qty>.0001 then raise exception 'Pro opravu není dostatečná evidovaná zásoba.'; end if;
     perform route_correction_delta_v50(machine_loc,p.id,before_delta*factor,new_ref||'_before_'||i.id,p_reason);
     update machine_coffee_containers set current_quantity=current_quantity+delta+before_delta,capacity_quantity=cap,updated_at=now() where id=c.id;
   end if;
   update route_machine_visit_items set actual_before_quantity=coalesce(actual_before_quantity,0)+before_delta,actual_add_quantity=added,final_quantity=final_qty,capacity_quantity=cap,operator_note=nullif(x->>'note',''),updated_at=now() where id=i.id;
 end loop;
 seen:='{}';
 for x in select value from jsonb_array_elements(coalesce(p_patch->'wastes','[]')) loop
   select * into strict w from route_vehicle_waste_items where id=(x->>'id')::bigint and route_machine_visit_id=v.id for update;
   if w.status<>'pending' then raise exception 'Odpis už byl předaný skladu; použij opravu skladového dokladu.'; end if;
   if w.id=any(seen) then raise exception 'Duplicitní řádek opravy.'; end if; seen:=array_append(seen,w.id);
   if exists(select 1 from inventory_audit_items ai join inventory_audits a on a.id=ai.audit_id where ai.product_id=w.product_id and ai.stock_location_id in(vehicle_loc,machine_loc) and a.status='closed' and a.closed_at>coalesce(v.completed_at,v.created_at)) then raise exception 'Odpis má novější inventuru.'; end if;
   qty:=(x->>'quantity')::numeric;
   if qty is null or qty<0 or qty<>trunc(qty) then raise exception 'Zadej platný počet odepsaných kusů.'; end if;
   select * into strict i from route_machine_visit_items where id=w.route_machine_visit_item_id and visit_id=v.id for update;
   if i.item_kind<>'food_slot' or w.unit<>'ks' then raise exception 'Odpis vyžaduje potravinovou pozici v kusech.'; end if;
   select * into strict s from machine_planogram_slots where id=i.planogram_slot_id and machine_id=v.machine_id for update;
   if coalesce(s.changeover_new_units,0)>0 then raise exception 'Odpis ve smíšené pozici vyžaduje fyzickou kontrolu.'; end if;
   delta:=qty-w.quantity;
   if s.current_units-delta<0 or s.current_units-delta>s.capacity_units or i.final_quantity-delta<0 or i.final_quantity-delta>i.capacity_quantity then raise exception 'Opravený odpis je mimo kapacitu pozice.'; end if;
   perform route_correction_delta_v50(machine_loc,w.product_id,-delta,new_ref||'_waste_'||w.id,p_reason);
   update machine_planogram_slots set current_units=current_units-delta,desired_units=greatest(0,coalesce(target_units,capacity_units)-(current_units-delta)),fill_percent=round(100*(current_units-delta)/nullif(capacity_units,0),2),updated_at=now() where id=s.id;
   update route_machine_visit_items set removed_quantity=removed_quantity+delta,final_quantity=final_quantity-delta,updated_at=now() where id=i.id;
   if qty=0 then delete from route_vehicle_waste_items where id=w.id;
   else update route_vehicle_waste_items set quantity=qty,reason=x->>'reason',note=concat_ws(' · ',note,'Oprava: '||p_reason),updated_at=now() where id=w.id; end if;
 end loop;
 if p_patch ? 'cash' then
   cash:=nullif(p_patch->'cash'->>'counted','')::numeric;
   if cash<0 or cash>10000000 then raise exception 'Zadej platnou částku hotovosti.'; end if;
   insert into route_machine_cash_reports(visit_id,machine_id,operator_collected_confirmed,operator_bag_label,supervisor_counted_cash_czk,supervisor_counted_by,supervisor_counted_at,note)
   values(v.id,v.machine_id,(p_patch->'cash'->>'collected')::boolean,p_patch->'cash'->>'bag',cash,actor,now(),p_patch->'cash'->>'note')
   on conflict(visit_id) do update set operator_collected_confirmed=excluded.operator_collected_confirmed,operator_bag_label=excluded.operator_bag_label,supervisor_counted_cash_czk=excluded.supervisor_counted_cash_czk,supervisor_counted_by=actor,supervisor_counted_at=now(),note=excluded.note,updated_at=now();
 end if;
 new_status:=coalesce(p_patch->>'status',v.status);
 arrived:=case when p_patch ? 'arrived_at' then nullif(p_patch->>'arrived_at','')::timestamptz else v.arrived_at end;
 ended:=case when p_patch ? 'completed_at' then nullif(p_patch->>'completed_at','')::timestamptz else v.completed_at end;
 skipped:=coalesce(v.skipped_at,v.completed_at,v.arrived_at);
 if new_status='completed' and ended is null then raise exception 'Doplň skutečný čas dokončení návštěvy.'; end if;
 if ended<arrived or ended>now()+interval '5 minutes' or arrived>now()+interval '5 minutes' then raise exception 'Zkontroluj čas příjezdu a dokončení.'; end if;
 if new_status not in ('completed','skipped') then raise exception 'Vyber dokončeno nebo přeskočeno.'; end if;
 if new_status='skipped' and v.status<>'skipped' and (exists(select 1 from route_machine_visit_items where visit_id=v.id and (actual_add_quantity<>0 or removed_quantity<>0)) or exists(select 1 from route_machine_cash_reports where visit_id=v.id and operator_collected_confirmed)) then raise exception 'Návštěva má doplnění, odpis nebo výběr peněz. Před přeskočením oprav tyto zápisy.'; end if;
 update route_machine_visits set operator_note=coalesce(p_patch->>'note',operator_note),status=new_status,skip_reason=case when new_status='skipped' then coalesce(p_patch->>'skip_reason',skip_reason,p_reason) else null end,arrived_at=arrived,completed_at=case when new_status='completed' then ended else null end,skipped_at=case when new_status='skipped' then skipped else null end,correction_revision=correction_revision+1,updated_at=now(),synced_at=now() where id=v.id;
 if new_status<>v.status or arrived is distinct from v.arrived_at or ended is distinct from v.completed_at then
   update route_plan_stops set status=case when new_status='completed' then 'done' else 'skipped' end,arrived_at=arrived,completed_at=case when new_status='completed' then ended else null end,skipped_at=case when new_status='skipped' then skipped else null end where id=v.route_plan_stop_id;
 end if;
 after_doc:=jsonb_build_object('waste',(select jsonb_agg(to_jsonb(t)) from route_vehicle_waste_items t where route_machine_visit_id=v.id),'visit',(select to_jsonb(t) from route_machine_visits t where id=v.id),'items',(select jsonb_agg(to_jsonb(t)) from route_machine_visit_items t where visit_id=v.id),'fills',(select jsonb_agg(to_jsonb(t)) from route_machine_visit_food_fills t where visit_id=v.id),'cash',(select to_jsonb(t) from route_machine_cash_reports t where visit_id=v.id));
 update route_visit_corrections set after_data=after_doc where id=audit_id;
 perform set_config('olvend.route_correction','off',true);
 return jsonb_build_object('audit_id',audit_id,'revision',v.correction_revision+1);
end $$;
revoke all on function public.correct_route_visit_v50(bigint,integer,timestamptz,text,jsonb) from public,anon;
grant execute on function public.correct_route_visit_v50(bigint,integer,timestamptz,text,jsonb) to authenticated;
commit;
notify pgrst,'reload schema';
