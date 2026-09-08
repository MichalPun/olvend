begin;

select pg_advisory_xact_lock(hashtext('import_havlicek_locations_remove_slavicin_20260908'));

create temporary table _havlicek_locations (
  name text primary key,
  city text not null,
  address text,
  customer_name text not null,
  source_location_ids text not null,
  source_machine_ids text not null,
  planned_setup text not null,
  placement_note text not null,
  address_source text,
  latitude numeric,
  longitude numeric
) on commit drop;

insert into _havlicek_locations (
  name,
  city,
  address,
  customer_name,
  source_location_ids,
  source_machine_ids,
  planned_setup,
  placement_note,
  address_source,
  latitude,
  longitude
) values
  (
    'Aquapark Uherské Hradiště',
    'Uherské Hradiště',
    'Sportovní 1214, 686 01 Uherské Hradiště',
    'Aquapark Uherské Hradiště, příspěvková organizace',
    '47332, 47333',
    '40255, 51390',
    '1× kávový + 1× potravinový automat',
    'Vestibul; kávový automat DESIGN a potravinový automat FAS.',
    'https://www.aquapark-uh.cz/kontakt',
    null,
    null
  ),
  (
    'AWL-Techniek CZ Napajedla',
    'Napajedla',
    'Kvítkovická 1670, 763 61 Napajedla',
    'AWL-Techniek CZ s.r.o.',
    '45622, 42875, 45623',
    '32580, 34754, 21366',
    '2× kávový + 1× potravinový automat',
    'Hala, nová hala a hala FAS.',
    'https://awl.nl/cs',
    null,
    null
  ),
  (
    'DOZP Kunovice – Cihlářská',
    'Kunovice',
    'Cihlářská 526, 686 04 Kunovice',
    'Sociální služby Uherské Hradiště, příspěvková organizace',
    '59531, 59319',
    '48776, 38872',
    '1× kávový + 1× potravinový automat',
    'Vstupní chodba; kávový a potravinový automat.',
    'https://www.ssluh.cz/c-dzp-kunovice-cihlarska/kontakty.htm',
    null,
    null
  ),
  (
    'HANÁK NÁBYTEK Kojetín',
    'Kojetín',
    'Popůvky 72, 752 01 Kojetín',
    'HANÁK NÁBYTEK, a.s.',
    '55693, 55691, 55692',
    '51092, 51129, 49933',
    '2× kávový + 1× potravinový automat',
    'Jídelna, výroba a jídelna FAS.',
    'https://www.hanak-nabytek.cz/hanak/kontakt',
    null,
    null
  ),
  (
    'Konzervatoř P. J. Vejvanovského Kroměříž',
    'Kroměříž',
    'Pilařova 7/1, 767 01 Kroměříž',
    'Konzervatoř P. J. Vejvanovského Kroměříž',
    '37530',
    '35206',
    '1× kávový automat',
    'Vestibul v přízemí.',
    'https://www.konzkm.cz/kontakty/',
    null,
    null
  ),
  (
    'MORAVSKÁ MODELÁRNA Uničov',
    'Uničov',
    'Brníčko 1032, 783 91 Uničov',
    'MORAVSKÁ MODELÁRNA, a.s.',
    '55825',
    '33472',
    '1× kávový automat',
    'Chodba v přízemí.',
    'https://www.mmodel.cz',
    null,
    null
  ),
  (
    'Regionální centrum Olomouc',
    'Olomouc',
    'Jeremenkova 1191/40b, 779 00 Olomouc',
    'Regionální centrum Olomouc s.r.o.',
    '60620, 60621',
    '42546, 51050',
    '1× kávový + 1× potravinový automat',
    'Chodba v 1. patře; kávový automat DESIGN a potravinový automat FAS.',
    'https://rco.cz/',
    null,
    null
  ),
  (
    'Renostav Zábřeh na Moravě',
    'Jedlí',
    'Jedlí 109, 789 01 Jedlí',
    'R E N O S T A V, spol. s r.o.',
    '39752',
    '32759',
    '1× kávový automat',
    'Kuchyňka v provozovně Jedlí.',
    'https://www.renostav.cz/menu/kontakt',
    null,
    null
  ),
  (
    'ROUČKA SLÉVÁRNA Lutín',
    'Lutín',
    'Jana Sigmunda 79, 783 50 Lutín',
    'ROUČKA SLÉVÁRNA, a.s.',
    '39322, 55770',
    '29231, 26264',
    '1× kávový + 1× potravinový automat',
    'Chodba závodu; kávový a potravinový automat.',
    'https://www.roucka-slevarna.cz/kontakt',
    49.5579078,
    17.1399728
  ),
  (
    'SPŠ elektrotechnická Havířov',
    'Havířov',
    'Makarenkova 513/1, 736 01 Havířov',
    'Střední průmyslová škola elektrotechnická, Havířov, příspěvková organizace',
    '56577',
    '29777',
    '1× kávový automat',
    'Chodba v přízemí.',
    'https://spsehavirov.cz/kontakty/',
    null,
    null
  ),
  (
    'SPŠ stavební Lipník nad Bečvou',
    'Lipník nad Bečvou',
    'Komenského sady 257, 751 31 Lipník nad Bečvou',
    'Střední průmyslová škola stavební, Lipník nad Bečvou',
    '56327',
    '40241',
    '1× kávový automat',
    'Chodba v 1. patře.',
    'https://www.spsslipnik.cz/kontakty',
    null,
    null
  ),
  (
    'ZLIN AERO Otrokovice',
    'Otrokovice',
    'Letiště 1887, 765 02 Otrokovice',
    'ZLIN AERO a.s.',
    '58727',
    '31040',
    '1× kávový automat',
    'Hala v přízemí.',
    null,
    49.1955207,
    17.5216656
  ),
  (
    'AWL-Techniek CZ Hulín',
    'Hulín',
    null,
    'AWL-Techniek CZ s.r.o.',
    '60997',
    '22604',
    '1× potravinový automat',
    'Hala v přízemí FAS. Přesnou adresu je nutné doplnit.',
    null,
    null,
    null
  );

do $$
declare
  v_duplicate_matches integer;
  v_slavicin_links integer;
begin
  if (select count(*) from _havlicek_locations) <> 13 then
    raise exception 'Import musí obsahovat přesně 13 fyzických lokalit.';
  end if;

  select count(*)
  into v_duplicate_matches
  from _havlicek_locations source
  cross join lateral (
    select count(*) as match_count
    from public.locations location
    where public.olvend_contact_norm(coalesce(location.name, '')) = public.olvend_contact_norm(source.name)
       or (
         source.address is not null
         and public.olvend_contact_norm(coalesce(location.address, '')) = public.olvend_contact_norm(source.address)
       )
  ) matched
  where matched.match_count > 1;

  if v_duplicate_matches <> 0 then
    raise exception 'Import byl zastaven: některá zdrojová lokalita odpovídá více záznamům v OLVENDu.';
  end if;

  select
    (select count(*) from public.location_financial_rules x where x.location_id = 106)
    + (select count(*) from public.location_operator_messages x where x.location_id = 106)
    + (select count(*) from public.machine_transfers x where x.from_location_id = 106 or x.to_location_id = 106)
    + (select count(*) from public.machines x where x.location_id = 106)
    + (select count(*) from public.partner_billing_profiles x where x.location_id = 106)
    + (select count(*) from public.partner_settlement_reports x where x.location_id = 106)
    + (select count(*) from public.route_cash_reports x where x.location_id = 106)
    + (select count(*) from public.route_plan_stops x where x.location_id = 106)
    + (select count(*) from public.route_template_stops x where x.location_id = 106)
    + (select count(*) from public.service_requests x where x.location_id = 106)
    + (select count(*) from public.technical_jobs x where x.location_id = 106 or x.source_location_id = 106 or x.target_location_id = 106)
  into v_slavicin_links;

  if exists (
    select 1
    from public.locations
    where id = 106
      and name = 'EKOFILTR Slavičín'
      and city = 'Slavičín'
  ) then
    if v_slavicin_links <> 0 then
      raise exception 'Slavičín má % provozních vazeb mimo administrativní přiřazení rajónu; odstranění bylo zastaveno.', v_slavicin_links;
    end if;
  elsif exists (
    select 1
    from public.locations
    where city ilike '%Slavičín%'
       or name ilike '%Slavičín%'
  ) then
    raise exception 'V OLVENDu existuje jiný záznam Slavičína; automatické odstranění bylo zastaveno.';
  end if;
end
$$;

update public.locations location
set
  name = source.name,
  city = source.city,
  address = coalesce(source.address, location.address),
  customer_name = source.customer_name,
  active = true,
  route_note = case
    when coalesce(location.route_note, '') ilike '%Leoš Havlíček na OLMIKA.xlsx%'
      then location.route_note
    else concat_ws(
      E'\n',
      nullif(trim(location.route_note), ''),
      format(
        'Zdroj: Leoš Havlíček na OLMIKA.xlsx. VendSoft místa: %s. Původní automaty: %s. Plánované převzetí: %s. %s',
        source.source_location_ids,
        source.source_machine_ids,
        source.planned_setup,
        source.placement_note
      )
    )
  end,
  service_plan_note = case
    when coalesce(location.service_plan_note, '') ilike '%bez přiřazeného automatu%'
      then location.service_plan_note
    else concat_ws(
      E'\n',
      nullif(trim(location.service_plan_note), ''),
      'Přebíraná lokalita je zatím bez přiřazeného automatu. Typy a počty v provozní poznámce jsou pouze podklad ze zdrojového souboru. Automat, servisní frekvenci, přístup a servisní okno založit nebo potvrdit samostatně.'
    )
  end,
  latitude = coalesce(location.latitude, source.latitude),
  longitude = coalesce(location.longitude, source.longitude),
  route_access_source = coalesce(location.route_access_source, source.address_source),
  route_access_status = case
    when location.route_access_status = 'confirmed' then location.route_access_status
    else 'needs_confirmation'
  end,
  updated_at = now()
from _havlicek_locations source
where public.olvend_contact_norm(coalesce(location.name, '')) = public.olvend_contact_norm(source.name)
   or (
     source.address is not null
     and public.olvend_contact_norm(coalesce(location.address, '')) = public.olvend_contact_norm(source.address)
   );

insert into public.locations (
  name,
  city,
  address,
  customer_name,
  active,
  route_note,
  service_plan_note,
  latitude,
  longitude,
  route_access_source,
  route_access_status
)
select
  source.name,
  source.city,
  source.address,
  source.customer_name,
  true,
  format(
    'Zdroj: Leoš Havlíček na OLMIKA.xlsx. VendSoft místa: %s. Původní automaty: %s. Plánované převzetí: %s. %s',
    source.source_location_ids,
    source.source_machine_ids,
    source.planned_setup,
    source.placement_note
  ),
  'Přebíraná lokalita je zatím bez přiřazeného automatu. Typy a počty v provozní poznámce jsou pouze podklad ze zdrojového souboru. Automat, servisní frekvenci, přístup a servisní okno založit nebo potvrdit samostatně.',
  source.latitude,
  source.longitude,
  source.address_source,
  'needs_confirmation'
from _havlicek_locations source
where not exists (
  select 1
  from public.locations location
  where public.olvend_contact_norm(coalesce(location.name, '')) = public.olvend_contact_norm(source.name)
     or (
       source.address is not null
       and public.olvend_contact_norm(coalesce(location.address, '')) = public.olvend_contact_norm(source.address)
     )
);

delete from public.locations
where id = 106
  and name = 'EKOFILTR Slavičín'
  and city = 'Slavičín';

do $$
begin
  if (
    select count(*)
    from _havlicek_locations source
    join public.locations location
      on public.olvend_contact_norm(coalesce(location.name, '')) = public.olvend_contact_norm(source.name)
    where location.active
  ) <> 13 then
    raise exception 'Po importu není aktivních přesně 13 očekávaných lokalit.';
  end if;

  if exists (
    select 1
    from public.locations
    where id = 106
       or public.olvend_contact_norm(coalesce(name, '')) = public.olvend_contact_norm('EKOFILTR Slavičín')
  ) then
    raise exception 'Lokalita EKOFILTR Slavičín po odstranění stále existuje.';
  end if;
end
$$;

select jsonb_build_object(
  'expected_locations', count(*),
  'with_address', count(*) filter (where location.address is not null),
  'with_coordinates', count(*) filter (where location.latitude is not null and location.longitude is not null),
  'without_coordinates', count(*) filter (where location.latitude is null or location.longitude is null),
  'locations', jsonb_agg(
    jsonb_build_object(
      'id', location.id,
      'name', location.name,
      'city', location.city,
      'address', location.address,
      'coordinates', case
        when location.latitude is not null and location.longitude is not null
          then jsonb_build_array(location.latitude, location.longitude)
        else null
      end
    )
    order by location.name
  )
) as result
from _havlicek_locations source
join public.locations location
  on public.olvend_contact_norm(coalesce(location.name, '')) = public.olvend_contact_norm(source.name)
where location.active;

commit;
