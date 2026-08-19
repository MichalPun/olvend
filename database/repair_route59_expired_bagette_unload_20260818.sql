begin;

do $$
declare
  v_pending_count integer;
  v_pending_quantity numeric;
  v_wrong_labusnik_count integer;
begin
  select count(*), coalesce(sum(quantity), 0)
    into v_pending_count, v_pending_quantity
  from public.route_vehicle_waste_items
  where route_plan_id = 59
    and status = 'pending'
    and reason = 'expired';

  if v_pending_count <> 7 or v_pending_quantity <> 12 then
    raise exception 'Neočekávaný stav odpisů trasy 59: % řádků / % ks.', v_pending_count, v_pending_quantity;
  end if;

  select count(*)
    into v_wrong_labusnik_count
  from public.route_vehicle_waste_items
  where id = 42
    and route_plan_id = 59
    and status = 'pending'
    and product_sku = '16'
    and quantity = 1
    and expiry_date = date '2026-08-25';

  if v_wrong_labusnik_count <> 1 then
    raise exception 'Chybný řádek Labužníku už neodpovídá ověřenému stavu.';
  end if;
end
$$;

-- Na fotografii je jeden Labužník s expirací 18. 8.; druhý záznam byl
-- omylem označen jako prošlý, přestože měl expiraci až 25. 8.
delete from public.route_vehicle_waste_items
where id = 42
  and route_plan_id = 59
  and status = 'pending';

-- Fyzicky svezené zboží na fotografii má expiraci 18. 8. 2026.
update public.route_vehicle_waste_items
set expiry_date = date '2026-08-18', updated_at = now()
where id = any(array[41, 43, 44, 45, 46, 47]::bigint[])
  and route_plan_id = 59
  and status = 'pending';

do $$
declare
  v_count integer;
  v_quantity numeric;
  v_result jsonb;
begin
  select count(*), coalesce(sum(quantity), 0)
    into v_count, v_quantity
  from public.route_vehicle_waste_items
  where id = any(array[41, 43, 44, 45, 46, 47]::bigint[])
    and route_plan_id = 59
    and status = 'pending';

  if v_count <> 6 or v_quantity <> 11 then
    raise exception 'Ověřený svoz před uzavřením nesedí: % řádků / % ks.', v_count, v_quantity;
  end if;

  select public.confirm_route_vehicle_waste_unload_v29(
    array[41, 43, 44, 45, 46, 47]::bigint[],
    (select id from public.employees where name ilike '%Michaela Nerudov%' limit 1)
  ) into v_result;

  if coalesce((v_result ->> 'unloaded_count')::integer, 0) <> 6 then
    raise exception 'Potvrzení vykládky neuzavřelo všech šest řádků.';
  end if;
end
$$;

commit;
