-- Oprava návštěv EV 132 a EV 133 z 26. 10. 2026.
-- Čtyři nedotčené zásobníky byly chybně hromadně potvrzené jako prázdné.
begin;

select set_config('request.jwt.claim.sub', 'abad3293-29a0-4668-97c5-0c6fa08ece0f', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare
  v_visit public.route_machine_visits%rowtype;
begin
  select * into strict v_visit from public.route_machine_visits where id = 1496 for update;
  if v_visit.correction_revision = 0 then
    perform public.correct_route_visit_v50(
      1496,
      0,
      v_visit.updated_at,
      'Oprava chybného hromadného nulového stavu; vedením nastaven odhad 50 % kapacity.',
      jsonb_build_object('items', jsonb_build_array(
        jsonb_build_object('id',42182,'before',1250,'added',0,'capacity',2500,'note','Manažerská oprava: odhad 50 % kapacity po chybném automatickém vynulování.'),
        jsonb_build_object('id',42183,'before',1250,'added',0,'capacity',2500,'note','Manažerská oprava: odhad 50 % kapacity po chybném automatickém vynulování.'),
        jsonb_build_object('id',42184,'before',1250,'added',0,'capacity',2500,'note','Manažerská oprava: odhad 50 % kapacity po chybném automatickém vynulování.'),
        jsonb_build_object('id',42185,'before',225,'added',0,'capacity',450,'note','Manažerská oprava: odhad 50 % kapacity po chybném automatickém vynulování.')
      ))
    );
  end if;

  select * into strict v_visit from public.route_machine_visits where id = 1497 for update;
  if v_visit.correction_revision = 0 then
    perform public.correct_route_visit_v50(
      1497,
      0,
      v_visit.updated_at,
      'Oprava chybného hromadného nulového stavu; vedením nastaven odhad 50 % kapacity.',
      jsonb_build_object('items', jsonb_build_array(
        jsonb_build_object('id',42228,'before',1250,'added',0,'capacity',2500,'note','Manažerská oprava: odhad 50 % kapacity po chybném automatickém vynulování.'),
        jsonb_build_object('id',42229,'before',1250,'added',0,'capacity',2500,'note','Manažerská oprava: odhad 50 % kapacity po chybném automatickém vynulování.'),
        jsonb_build_object('id',42230,'before',1250,'added',0,'capacity',2500,'note','Manažerská oprava: odhad 50 % kapacity po chybném automatickém vynulování.'),
        jsonb_build_object('id',42231,'before',225,'added',0,'capacity',450,'note','Manažerská oprava: odhad 50 % kapacity po chybném automatickém vynulování.')
      ))
    );
  end if;
end
$$;

-- Jde o výslovný manažerský odhad aktuálního stavu, proto po auditované
-- opravě historických položek nastavíme právě 50 % i jako současný stav.
update public.machine_coffee_containers
   set current_quantity = capacity_quantity / 2,
       physical_counted_at = now(),
       physical_count_source = 'management_estimate_50_percent',
       updated_at = now()
 where id in (786,787,789,791,794,795,797,799)
   and (
     (machine_id = 131 and exists(select 1 from public.route_machine_visits where id=1497 and correction_revision=1))
     or (machine_id = 132 and exists(select 1 from public.route_machine_visits where id=1496 and correction_revision=1))
   );

update public.machines
   set stock_initialized_at = coalesce(stock_initialized_at, now()),
       updated_at = now()
 where id in (131,132);

commit;

