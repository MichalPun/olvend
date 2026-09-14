begin;
create table if not exists public.telemetry_transition_audit_20260914 (
  repair_key text primary key, created_at timestamptz not null default now(), snapshot jsonb not null
);
alter table public.telemetry_transition_audit_20260914 enable row level security;
do $$
declare n integer; q numeric; amt numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended('hlucin-434625',0));
 if exists(select 1 from telemetry_transition_audit_20260914 where repair_key='hlucin-434625') then raise exception 'Already repaired'; end if;
 if not exists(select 1 from telemetry_dex_ingests where id=434625 and device_id='602224') then raise exception 'Wrong ingest'; end if;
 perform 1 from telemetry_sales_events where machine_id=66 and ingest_id=434625 for update;
 select count(*),sum(quantity),sum(unpaid_dispense_quantity*unit_price_czk) into n,q,amt from telemetry_sales_events where machine_id=66 and ingest_id=434625;
 if n<>4 or q<>253 or amt<>2228 then raise exception 'Unexpected event totals'; end if;
 perform 1 from machine_coffee_containers where id in(446,447,448,452,454,455) for update;
 if not exists(select 1 from machine_coffee_containers where id=452 and current_quantity=0 and updated_at='2026-09-14 11:31:55.979113+00') then raise exception 'Irish changed after inspection'; end if;
 if not exists(select 1 from route_machine_visit_items where id=13332 and coffee_container_id=452 and final_quantity=2182) then raise exception 'Missing Irish baseline'; end if;
 if exists(select 1 from telemetry_coffee_recipe_depletions d join telemetry_sales_events s on s.id=d.sale_event_id where d.coffee_container_id=452 and s.source_event_at>'2026-09-01 05:55:58+00' and s.ingest_id<>434625) then raise exception 'Other Irish consumption'; end if;
 if (select count(*) from stock_movements_v13 where id between 104996 and 105003)<>8 then raise exception 'Stock audit changed'; end if;
 if exists(select product_id from stock_movements_v13 where id between 104996 and 105003 group by product_id having sum(case when to_stock_location_id=43 then quantity_base_units else -quantity_base_units end)<>0) then raise exception 'Reconstruction is not balanced'; end if;
 insert into telemetry_transition_audit_20260914(repair_key,snapshot) select 'hlucin-434625',jsonb_build_object(
 'sales',(select jsonb_agg(to_jsonb(s)) from telemetry_sales_events s where machine_id=66 and ingest_id=434625),
 'coffee_depletions',(select jsonb_agg(to_jsonb(d)) from telemetry_coffee_recipe_depletions d where sale_event_id in(529685,529686,529687,529688)),
 'stock_depletions',(select jsonb_agg(to_jsonb(d)) from telemetry_stock_depletions d where sale_event_id in(529685,529686,529687,529688)),
 'movements',(select jsonb_agg(to_jsonb(m)) from stock_movements_v13 m where id between 104996 and 105003),
 'containers',(select jsonb_agg(to_jsonb(c)) from machine_coffee_containers c where machine_id=66),
 'counters',(select jsonb_agg(to_jsonb(c)) from telemetry_planogram_counters c where machine_id=66));
 -- Positive remaining quantities prove these deductions were not clamped at zero.
 if exists(select 1 from machine_coffee_containers where id in(446,447,448,454,455) and current_quantity<=0) then raise exception 'Cannot reverse clamped deduction'; end if;
 update machine_coffee_containers c set current_quantity=c.current_quantity+d.q,updated_at=now()
 from(select coffee_container_id,sum(quantity) q from telemetry_coffee_recipe_depletions where sale_event_id in(529685,529686,529687,529688) and coffee_container_id<>452 group by coffee_container_id)d
 where c.id=d.coffee_container_id and c.machine_id=66;
 -- Irish was clamped: restore the last recorded physical fill, not the 5.768kg theoretical deduction.
 update machine_coffee_containers set current_quantity=2182,updated_at=now() where id=452 and machine_id=66;
 -- These paired reconstruction entries had zero net stock effect.
 delete from stock_movements_v13 where id between 104996 and 105003 and reference_type in('telemetry_stock_reconstruction','telemetry_sale_reconstruction');
 delete from telemetry_sales_events where machine_id=66 and ingest_id=434625 and id in(529685,529686,529687,529688);
end $$;
commit;
select count(*) remaining_false_events from telemetry_sales_events where machine_id=66 and ingest_id=434625;
