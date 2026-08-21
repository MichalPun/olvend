-- Potvrzení fyzicky doloženého odpisu z fotografie po Davidově trase 20. 8. 2026.
-- Fotografie obsahuje 2x Kuřecí stripsy a 4x Debrecínská. Sporné odpisy
-- ze Sportisima EV 90 nejsou součástí této operace.

begin;

do $$
declare
  v_result jsonb;
begin
  if not exists (
    select 1
    from public.route_vehicle_waste_items
    where id = 61
      and route_plan_id = 62
      and route_machine_visit_id = 348
      and product_id = 14
      and quantity = 2
      and reason = 'expired'
      and status = 'pending'
  ) then
    raise exception 'Odpis 2x Kuřecí stripsy už není v očekávaném stavu.';
  end if;

  if not exists (
    select 1
    from public.route_vehicle_waste_items
    where id = 58
      and route_plan_id = 62
      and route_machine_visit_id = 344
      and product_id = 17
      and quantity = 4
      and reason = 'expired'
      and status = 'pending'
  ) then
    raise exception 'Odpis 4x Debrecínská už není v očekávaném stavu.';
  end if;

  v_result := public.confirm_route_vehicle_waste_unload_v29(array[58, 61]::bigint[], null);

  if coalesce((v_result ->> 'unloaded_count')::integer, 0) <> 2 then
    raise exception 'Nebyly potvrzeny oba fyzicky doložené řádky odpisu.';
  end if;

  if exists (
    select 1
    from public.route_vehicle_waste_items
    where id in (58, 61)
      and status <> 'unloaded'
  ) then
    raise exception 'Některý fyzicky doložený odpis nezůstal uzavřený.';
  end if;

  if exists (
    select 1
    from public.route_vehicle_waste_items
    where id in (59, 60)
      and status <> 'pending'
  ) then
    raise exception 'Sporné odpisy Sportisimo EV 90 byly neočekávaně změněny.';
  end if;
end
$$;

commit;
