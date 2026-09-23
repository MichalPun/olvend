begin;
-- Extend existing waste handover without changing grants, RLS or the invoker security model.
alter table public.route_vehicle_waste_items add column if not exists source_warehouse_id bigint references public.warehouses(id) on delete restrict;
alter table public.route_vehicle_waste_items alter column vehicle_id drop not null;
alter table public.route_vehicle_waste_items add constraint route_waste_source_required check (vehicle_id is not null or source_warehouse_id is not null);
create index if not exists route_waste_direct_pending on public.route_vehicle_waste_items(employee_id, source_warehouse_id) where vehicle_id is null and status = 'pending';
do $$
declare definition text;
begin
 select pg_get_functiondef('public.confirm_route_vehicle_waste_unload_v29(bigint[],uuid)'::regprocedure) into definition;
 if position('count(distinct vehicle_id)' in definition) = 0 then
  raise exception 'Unexpected waste handover definition; review before migration';
 end if;
 definition := replace(definition, 'count(distinct vehicle_id)', 'count(distinct case when vehicle_id is not null then ''vehicle:'' || vehicle_id::text else ''warehouse:'' || source_warehouse_id::text || '':employee:'' || employee_id::text end)');
 definition := replace(definition, 'patřit jednomu vozidlu.', 'patřit jednomu vozidlu nebo jednomu operátorovi a skladu.');
 execute definition;
end $$;
commit;
notify pgrst, 'reload schema';
