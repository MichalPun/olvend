begin;

create temporary table _utb_zlin_locations (
  code text primary key,
  name text not null,
  address text not null,
  latitude numeric not null,
  longitude numeric not null,
  food_basic integer not null,
  food_xl integer not null,
  coffee integer not null
) on commit drop;

insert into _utb_zlin_locations (
  code, name, address, latitude, longitude, food_basic, food_xl, coffee
) values
  ('U1',  'UTB U1 - Fakulta technologická',               'Vavrečkova 275, 760 01 Zlín',             49.2248230, 17.6605280, 0, 1, 1),
  ('U41', 'UTB U41 - Fakulta multimediálních komunikací',  'Univerzitní 2431, 760 01 Zlín',          49.2226480, 17.6661880, 1, 0, 1),
  ('U44', 'UTB U44 - Fakulta multimediálních komunikací',  'Univerzitní 2431, 760 01 Zlín',          49.2223960, 17.6669690, 1, 0, 1),
  ('U5',  'UTB U5 - Fakulta aplikované informatiky',       'Nad Stráněmi 4511, 760 05 Zlín',         49.2305050, 17.6571030, 0, 2, 1),
  ('U11', 'UTB U11 - Univerzitní institut',                'Nad Ovčírnou 3685, 760 01 Zlín',         49.2194570, 17.6622480, 1, 0, 1),
  ('U13R','UTB U13 - Rektorát',                            'nám. T. G. Masaryka 5555, 760 01 Zlín',  49.2225540, 17.6648980, 1, 0, 2),
  ('U13K','UTB U13 - Knihovna',                            'nám. T. G. Masaryka 5555, 760 01 Zlín',  49.2225540, 17.6648980, 1, 0, 1),
  ('U15', 'UTB U15 - Fakulta technologická',               'Vavrečkova 5669, 760 01 Zlín',           49.2253100, 17.6603980, 0, 1, 1),
  ('U16', 'UTB U16 - Fakulta multimediálních komunikací',  'tř. T. Bati 4342, 760 01 Zlín',          49.2202075, 17.6494879, 1, 0, 0),
  ('U17', 'UTB U17 - Centrum polymerních systémů',         'tř. T. Bati 5678, 760 01 Zlín',          49.2209600, 17.6521860, 1, 0, 0),
  ('U18', 'UTB U18 - Fakulta humanitních studií',          'Štefánikova 5670, 760 01 Zlín',          49.2231730, 17.6664970, 1, 1, 1),
  ('U6',  'UTB U6 - Koleje Antonínova',                    'Antonínova 4379, 760 01 Zlín',           49.2205780, 17.6532860, 2, 0, 0),
  ('HG',  'UTB HG - Hotel Garni',                          'nám. T. G. Masaryka 1335, 760 01 Zlín',  49.2213088, 17.6629348, 0, 1, 0);

do $$
begin
  if (select count(*) from _utb_zlin_locations) <> 13 then
    raise exception 'UTB import musi obsahovat presne 13 lokalit.';
  end if;

  if (select sum(food_basic + food_xl) from _utb_zlin_locations) <> 16 then
    raise exception 'UTB import musi obsahovat presne 16 potravinovych automatu.';
  end if;

  if (select sum(coffee) from _utb_zlin_locations) <> 10 then
    raise exception 'UTB import musi obsahovat presne 10 napojovych automatu.';
  end if;

  if exists (
    select 1
    from public.locations l
    join _utb_zlin_locations s on lower(trim(l.name)) = lower(trim(s.name))
    where coalesce(l.customer_name, '') <> 'Univerzita Tomáše Bati ve Zlíně'
  ) then
    raise exception 'Nektery cilovy nazev lokality uz patri jinemu zakaznikovi.';
  end if;
end
$$;

update public.locations l
set
  city = 'Zlín',
  address = s.address,
  customer_name = 'Univerzita Tomáše Bati ve Zlíně',
  active = true,
  latitude = s.latitude,
  longitude = s.longitude,
  route_note = format(
    'UTB 2026-2029 - vítězná nabídka: %s%s%s.',
    case when s.food_basic > 0 then s.food_basic || 'x potravinový základní' else '' end,
    case when s.food_basic > 0 and (s.food_xl > 0 or s.coffee > 0) then ' + ' else '' end ||
    case when s.food_xl > 0 then s.food_xl || 'x potravinový XL' else '' end,
    case when (s.food_basic > 0 or s.food_xl > 0) and s.coffee > 0 then ' + ' else '' end ||
    case when s.coffee > 0 then s.coffee || 'x nápojový' else '' end
  ),
  service_plan_note = 'Rozmístění podle Přílohy č. 1 vítězné nabídky UTB 2026-2029. Přístupový čas a servisní okno ověřit před instalací.',
  updated_at = now()
from _utb_zlin_locations s
where lower(trim(l.name)) = lower(trim(s.name));

insert into public.locations (
  name,
  city,
  address,
  customer_name,
  active,
  latitude,
  longitude,
  route_note,
  service_plan_note
)
select
  s.name,
  'Zlín',
  s.address,
  'Univerzita Tomáše Bati ve Zlíně',
  true,
  s.latitude,
  s.longitude,
  format(
    'UTB 2026-2029 - vítězná nabídka: %s%s%s.',
    case when s.food_basic > 0 then s.food_basic || 'x potravinový základní' else '' end,
    case when s.food_basic > 0 and (s.food_xl > 0 or s.coffee > 0) then ' + ' else '' end ||
    case when s.food_xl > 0 then s.food_xl || 'x potravinový XL' else '' end,
    case when (s.food_basic > 0 or s.food_xl > 0) and s.coffee > 0 then ' + ' else '' end ||
    case when s.coffee > 0 then s.coffee || 'x nápojový' else '' end
  ),
  'Rozmístění podle Přílohy č. 1 vítězné nabídky UTB 2026-2029. Přístupový čas a servisní okno ověřit před instalací.'
from _utb_zlin_locations s
where not exists (
  select 1
  from public.locations l
  where lower(trim(l.name)) = lower(trim(s.name))
);

do $$
begin
  if (
    select count(*)
    from public.locations l
    join _utb_zlin_locations s on lower(trim(l.name)) = lower(trim(s.name))
    where l.active
      and l.customer_name = 'Univerzita Tomáše Bati ve Zlíně'
  ) <> 13 then
    raise exception 'Po zalozeni neni v produkci presne 13 aktivnich lokalit UTB.';
  end if;
end
$$;

select jsonb_build_object(
  'locations', count(*),
  'food_basic', sum(s.food_basic),
  'food_xl', sum(s.food_xl),
  'food_total', sum(s.food_basic + s.food_xl),
  'coffee_total', sum(s.coffee),
  'machines_total', sum(s.food_basic + s.food_xl + s.coffee),
  'rows', jsonb_agg(
    jsonb_build_object(
      'id', l.id,
      'code', s.code,
      'name', l.name,
      'address', l.address,
      'food_basic', s.food_basic,
      'food_xl', s.food_xl,
      'coffee', s.coffee
    ) order by s.code
  )
) as result
from _utb_zlin_locations s
join public.locations l on lower(trim(l.name)) = lower(trim(s.name));

commit;
