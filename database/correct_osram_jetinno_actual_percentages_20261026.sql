-- Upřesnění stavů podle dodatečné zprávy operátora.
-- Zpráva označuje stroje 133/134; OSRAM má v OLVENDu dvojici EV 132/133,
-- proto jsou hodnoty spárované ve stejném pořadí (133 -> EV132, 134 -> EV133).
begin;

select set_config('request.jwt.claim.sub', 'abad3293-29a0-4668-97c5-0c6fa08ece0f', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare
  v_visit public.route_machine_visits%rowtype;
begin
  -- EV 132 (ve zprávě první stroj „133“): smetana 20 %, čokoláda 95 %,
  -- matcha 30 %, kelímky 60 %.
  select * into strict v_visit from public.route_machine_visits where id = 1497 for update;
  if v_visit.correction_revision = 1 then
    perform public.correct_route_visit_v50(
      1497,
      1,
      v_visit.updated_at,
      'Upřesnění podle dodatečně zaslaných fyzických stavů operátora.',
      jsonb_build_object('items', jsonb_build_array(
        jsonb_build_object('id',42228,'before',500,'added',0,'capacity',2500,'note','Dodatečně potvrzený stav: smetana 20 %.'),
        jsonb_build_object('id',42229,'before',2375,'added',0,'capacity',2500,'note','Dodatečně potvrzený stav: čokoláda 95 %.'),
        jsonb_build_object('id',42230,'before',750,'added',0,'capacity',2500,'note','Dodatečně potvrzený stav: matcha 30 %.'),
        jsonb_build_object('id',42231,'before',270,'added',0,'capacity',450,'note','Dodatečně potvrzený stav: kelímky 60 %.')
      ))
    );
  end if;

  -- EV 133 (ve zprávě druhý stroj „134“): smetana 25 %, ostatní stejně.
  select * into strict v_visit from public.route_machine_visits where id = 1496 for update;
  if v_visit.correction_revision = 1 then
    perform public.correct_route_visit_v50(
      1496,
      1,
      v_visit.updated_at,
      'Upřesnění podle dodatečně zaslaných fyzických stavů operátora.',
      jsonb_build_object('items', jsonb_build_array(
        jsonb_build_object('id',42182,'before',625,'added',0,'capacity',2500,'note','Dodatečně potvrzený stav: smetana 25 %.'),
        jsonb_build_object('id',42183,'before',2375,'added',0,'capacity',2500,'note','Dodatečně potvrzený stav: čokoláda 95 %.'),
        jsonb_build_object('id',42184,'before',750,'added',0,'capacity',2500,'note','Dodatečně potvrzený stav: matcha 30 %.'),
        jsonb_build_object('id',42185,'before',270,'added',0,'capacity',450,'note','Dodatečně potvrzený stav: kelímky 60 %.')
      ))
    );
  end if;
end
$$;

update public.machine_coffee_containers
   set current_quantity = case id
         when 786 then 500 when 787 then 2375 when 789 then 750 when 791 then 270
         when 794 then 625 when 795 then 2375 when 797 then 750 when 799 then 270
       end,
       physical_counted_at = now(),
       physical_count_source = 'operator_follow_up_percent',
       updated_at = now()
 where id in (786,787,789,791,794,795,797,799)
   and physical_count_source = 'management_estimate_50_percent';

commit;

