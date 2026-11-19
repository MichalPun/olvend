begin;

do $$
declare
  v_machine_ids bigint[];
begin
  select coalesce(array_agg(id),'{}'::bigint[]) into v_machine_ids
  from public.machines where serial_number='TEST-MIXED-SPRING-20261119';

  delete from public.route_plans
  where route_payload->>'test_key' in ('mixed-spring-real-planogram-v1','operator-full-sportisimo-v2');

  delete from public.stock_locations
  where location_type='machine' and machine_id=any(v_machine_ids)
    and not exists(select 1 from public.stock_location_balances balance where balance.stock_location_id=stock_locations.id and balance.quantity_on_hand<>0);

  delete from public.machines where id=any(v_machine_ids);
end $$;

commit;
notify pgrst,'reload schema';
