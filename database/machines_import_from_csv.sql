-- Generated from imports/machines-import-ready.csv
-- Safe to run repeatedly: upsert by qr_token

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Lasspektrum' and coalesce(city, '') = 'Brno' and coalesce(address, '') = 'Tovární 850' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  '20171300613',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 1; lokalita ''Brno_Lasspektrum POTRAVINY''. Telemetry ID: 592146. Zdrojová lokalita: Brno_Lasspektrum POTRAVINY.',
  'vendsoft-1'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Domov seniorů' and coalesce(city, '') = 'Břeclav' and coalesce(address, '') = 'Na Pešině 2842/13' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 3; lokalita ''Břeclav_Domov seniorů hl. budova POTRAVINY''. Telemetry ID: 582177. Zdrojová lokalita: Břeclav_Domov seniorů hl. budova POTRAVINY.',
  'vendsoft-3'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 5; lokalita ''-''. Telemetry ID: 597850.',
  'vendsoft-5'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'REMANTE GROUP s.r.o.' and coalesce(city, '') = 'Otice' and coalesce(address, '') = 'K Rybníčkům 13' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 6; lokalita ''REMANTE GROUP s.r.o. POTRAVINY''. Telemetry ID: 597851. Zdrojová lokalita: REMANTE GROUP s.r.o. POTRAVINY.',
  'vendsoft-6'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Apex' and coalesce(city, '') = 'Pohořelice' and coalesce(address, '') = 'Vídeňská 1513' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 7; lokalita ''Pohořelice_Apex POTRAVINY''. Telemetry ID: 582173. Zdrojová lokalita: Pohořelice_Apex POTRAVINY.',
  'vendsoft-7'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'AZ Klima' and coalesce(city, '') = 'Milovice' and coalesce(address, '') = 'Milovice 156' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 9; lokalita ''Milovice_AZ Klima POTRAVINY''. Telemetry ID: 597849. Zdrojová lokalita: Milovice_AZ Klima POTRAVINY.',
  'vendsoft-9'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'ETA BETA (PRODÁNO 30.3.2026)',
  'Snack',
  'Rheavendors',
  null,
  null,
  'removed',
  false,
  'Import z VendSoft exportu; původní kód 10; lokalita ''-''.',
  'vendsoft-10'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'ViaPharma' and coalesce(city, '') = 'Podolí u Brna' order by id limit 1),
  'Europa Snack SIDE',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 11; lokalita ''Brno_ViaPharma POTRAVINY''. Zdrojová lokalita: Brno_ViaPharma POTRAVINY.',
  'vendsoft-11'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Microtechnic' and coalesce(city, '') = 'Modřice' and coalesce(address, '') = 'Evropská 884' order by id limit 1),
  'Europa Snack SIDE',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 12; lokalita ''Microtechnic POTRAVINY''. Telemetry ID: 592145. Zdrojová lokalita: Microtechnic POTRAVINY.',
  'vendsoft-12'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Domov seniorů vedlejší budova' and coalesce(city, '') = 'Břeclav' and coalesce(address, '') = 'Seniorů 1' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 13; lokalita ''Břeclav_Domov seniorů vedlejší budova''. Zdrojová lokalita: Břeclav_Domov seniorů vedlejší budova.',
  'vendsoft-13'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 14; lokalita ''-''.',
  'vendsoft-14'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 15; lokalita ''-''.',
  'vendsoft-15'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'BVK Pisárky' and coalesce(city, '') = 'Brno' and coalesce(address, '') = 'Pisárecká 555/1a' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 16; lokalita ''Brno_BVK Pisárky B jídelna''. Telemetry ID: 602221. Zdrojová lokalita: Brno_BVK Pisárky B jídelna.',
  'vendsoft-16'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Lasspektrum' and coalesce(city, '') = 'Brno' and coalesce(address, '') = 'Tovární 850' order by id limit 1),
  'Luce X1 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20100200215',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 17; lokalita ''Brno_Lasspektrum KÁVA''. Telemetry ID: 596512. Zdrojová lokalita: Brno_Lasspektrum KÁVA.',
  'vendsoft-17'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'VOŠ' and coalesce(city, '') = 'Jihlava' and coalesce(address, '') = 'Srázná 21' order by id limit 1),
  'Luce X1 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20140301220',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 18; lokalita ''Jihlava_VOŠ''. Telemetry ID: 604306. Zdrojová lokalita: Jihlava_VOŠ.',
  'vendsoft-18'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 19; lokalita ''-''. Telemetry ID: 592143.',
  'vendsoft-19'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Střední škola vedl.budova' and coalesce(city, '') = 'Bohumín' and coalesce(address, '') = 'Čáslavská 420' order by id limit 1),
  'Luce X1 I (7)',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 20; lokalita ''Bohumín_Střední škola - vedl.budova''. Telemetry ID: 587382. Zdrojová lokalita: Bohumín_Střední škola - vedl.budova.',
  'vendsoft-20'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'ViaPharma' and coalesce(city, '') = 'Podolí u Brna' order by id limit 1),
  'Luce X1 I (7)',
  'Coffee',
  'Rheavendors',
  null,
  '20093600077',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 22; lokalita ''Brno_ViaPharma KÁVA''. Telemetry ID: 597848. Zdrojová lokalita: Brno_ViaPharma KÁVA.',
  'vendsoft-22'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Hotel Kovák' and coalesce(city, '') = 'Slezská Ostrava-Kunčice' and coalesce(address, '') = 'Vratimovská 142' order by id limit 1),
  'Luce Snack X',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 23; lokalita ''Ostrava_Hotel Kovák - POTRAVINY''. Telemetry ID: 582171. Zdrojová lokalita: Ostrava_Hotel Kovák - POTRAVINY.',
  'vendsoft-23'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Bianchi Aria L',
  'Snack',
  'Bianchi',
  null,
  '16732298',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 24; lokalita ''-''.',
  'vendsoft-24'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E Carimali',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 25; lokalita ''-''.',
  'vendsoft-25'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportisimo' and coalesce(city, '') = 'Slezská Ostrava-Hrušov' and coalesce(address, '') = 'Žižkova' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 27; lokalita ''Ostrava_Sportisimo KÁVA''. Telemetry ID: 596509. Zdrojová lokalita: Ostrava_Sportisimo KÁVA.',
  'vendsoft-27'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'BVK Pisárky' and coalesce(city, '') = 'Brno' and coalesce(address, '') = 'Pisárecká 555/1a' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 28; lokalita ''Brno_BVK Pisárky hl. budova KÁVA''. Telemetry ID: 602228. Zdrojová lokalita: Brno_BVK Pisárky hl. budova KÁVA.',
  'vendsoft-28'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportisimo' and coalesce(city, '') = 'Slezská Ostrava-Hrušov' and coalesce(address, '') = 'Žižkova' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 29; lokalita ''Ostrava_Sportisimo KÁVA''. Telemetry ID: 596507. Zdrojová lokalita: Ostrava_Sportisimo KÁVA.',
  'vendsoft-29'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E chlazení',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 30; lokalita ''-''.',
  'vendsoft-30'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Domov seniorů' and coalesce(city, '') = 'Hustopeče u Brna' and coalesce(address, '') = 'Hybešova 1497/7' order by id limit 1),
  'Luce X1 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 31; lokalita ''Hustopeče_Domov seniorů''. Telemetry ID: 592149. Zdrojová lokalita: Hustopeče_Domov seniorů.',
  'vendsoft-31'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Domov seniorů' and coalesce(city, '') = 'Břeclav' and coalesce(address, '') = 'Na Pešině 2842/13' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 32; lokalita ''Břeclav_Domov seniorů hl.budova KÁVA''. Telemetry ID: 582178. Zdrojová lokalita: Břeclav_Domov seniorů hl.budova KÁVA.',
  'vendsoft-32'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E Carimali',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 34; lokalita ''-''.',
  'vendsoft-34'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'SŠ Zdravotnická' and coalesce(city, '') = 'Břeclav' and coalesce(address, '') = 'Slovácká 322/1a' order by id limit 1),
  'Zero Full Touch I',
  'Coffee',
  'Rheavendors',
  null,
  '20182805713',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 35; lokalita ''Břeclav_SŠ Zdravotnická''. Telemetry ID: 596504. Zdrojová lokalita: Břeclav_SŠ Zdravotnická.',
  'vendsoft-35'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Apex' and coalesce(city, '') = 'Pohořelice' and coalesce(address, '') = 'Vídeňská 1513' order by id limit 1),
  'Luce X1 E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 36; lokalita ''Pohořelice_Apex KÁVA''. Telemetry ID: 602225. Zdrojová lokalita: Pohořelice_Apex KÁVA.',
  'vendsoft-36'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Microtechnic' and coalesce(city, '') = 'Modřice' and coalesce(address, '') = 'Evropská 884' order by id limit 1),
  'Luce X1 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 37; lokalita ''Microtechnic KÁVA''. Zdrojová lokalita: Microtechnic KÁVA.',
  'vendsoft-37'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'BVK ČOV Modřice' and coalesce(city, '') = 'Modřice' and coalesce(address, '') = 'Svratecká 989' order by id limit 1),
  'Luce X1 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 38; lokalita ''Brno_BVK ČOV Modřice''. Telemetry ID: 602222. Zdrojová lokalita: Brno_BVK ČOV Modřice.',
  'vendsoft-38'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Hotel Kovák' and coalesce(city, '') = 'Slezská Ostrava-Kunčice' and coalesce(address, '') = 'Vratimovská 142' order by id limit 1),
  'Luce X1 I',
  'Coffee',
  'Rheavendors',
  null,
  '20121402250',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 39; lokalita ''Ostrava_Hotel Kovák - KÁVA''. Zdrojová lokalita: Ostrava_Hotel Kovák - KÁVA.',
  'vendsoft-39'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E Carimali',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 40; lokalita ''-''.',
  'vendsoft-40'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Paramont' and coalesce(city, '') = 'Velké Meziříčí' and coalesce(address, '') = 'Třebíčská 194' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 41; lokalita ''Velké Meziříčí_Paramont''. Zdrojová lokalita: Velké Meziříčí_Paramont.',
  'vendsoft-41'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'SWR' and coalesce(city, '') = 'Jamné' and coalesce(address, '') = 'Jamné 48' order by id limit 1),
  'Luce X1 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 42; lokalita ''Jamné_SWR''. Telemetry ID: 596506. Zdrojová lokalita: Jamné_SWR.',
  'vendsoft-42'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'ViaPharma' and coalesce(city, '') = 'Podolí u Brna' order by id limit 1),
  'Luce X1 I (7)',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 43; lokalita ''Brno_ViaPharma KÁVA''. Telemetry ID: 587376. Zdrojová lokalita: Brno_ViaPharma KÁVA.',
  'vendsoft-43'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'VO Vrtal' and coalesce(city, '') = 'Jihlava' and coalesce(address, '') = 'Znojemská 5433' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 44; lokalita ''Jihlava_VO Vrtal''. Zdrojová lokalita: Jihlava_VO Vrtal.',
  'vendsoft-44'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Střední škola hl. budova' and coalesce(city, '') = 'Bohumín' and coalesce(address, '') = 'Husova 283' order by id limit 1),
  'Luce X1 E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 45; lokalita ''Bohumín_Střední škola - hl. budova''. Telemetry ID: 592151. Zdrojová lokalita: Bohumín_Střední škola - hl. budova.',
  'vendsoft-45'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'VOŠ' and coalesce(city, '') = 'Jihlava' and coalesce(address, '') = 'Srázná 21' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 47; lokalita ''Jihlava_VOŠ''. Zdrojová lokalita: Jihlava_VOŠ.',
  'vendsoft-47'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 50; lokalita ''-''.',
  'vendsoft-50'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'bazén' and coalesce(city, '') = 'Hrušovany nad Jevišovkou' and coalesce(address, '') = 'Nádražní 438' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 51; lokalita ''Hrušovany nad Jevišovkou_bazén''. Zdrojová lokalita: Hrušovany nad Jevišovkou_bazén.',
  'vendsoft-51'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 52; lokalita ''-''.',
  'vendsoft-52'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 53; lokalita ''-''.',
  'vendsoft-53'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Dendro' and coalesce(city, '') = 'Znojmo' and coalesce(address, '') = 'Dr. M. Horákové 861' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 54; lokalita ''Znojmo_Dendro''. Zdrojová lokalita: Znojmo_Dendro.',
  'vendsoft-54'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Vinařství' and coalesce(city, '') = 'Mutěnice' and coalesce(address, '') = 'Údolní 1174' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 55; lokalita ''Mutěnice_Vinařství''. Zdrojová lokalita: Mutěnice_Vinařství.',
  'vendsoft-55'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'SPEED' and coalesce(city, '') = 'Kyjov' and coalesce(address, '') = 'Svatoborská 427/89' order by id limit 1),
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 56; lokalita ''Kyjov_SPEED''. Zdrojová lokalita: Kyjov_SPEED.',
  'vendsoft-56'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sonepar' and coalesce(city, '') = 'Jihlava' and coalesce(address, '') = 'Heroltická 5449/19' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 58; lokalita ''Jihlava_Sonepar''. Telemetry ID: 596505. Zdrojová lokalita: Jihlava_Sonepar.',
  'vendsoft-58'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'NTS' and coalesce(city, '') = 'Brno - Slatina' and coalesce(address, '') = 'Tuřanka 1313' order by id limit 1),
  'FAS 1050',
  'Snack',
  'FAS',
  null,
  '201047026',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 65; lokalita ''Brno_NTS''. Telemetry ID: 596503. Zdrojová lokalita: Brno_NTS.',
  'vendsoft-65'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'ViaPharma_POTRAVINY' and coalesce(city, '') = 'Ostrava' and coalesce(address, '') = '17. listopadu' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20143605855',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 67; lokalita ''Ostrava_ViaPharma KÁVA''. Telemetry ID: 592144. Zdrojová lokalita: Ostrava_ViaPharma KÁVA.',
  'vendsoft-67'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Zimní stadion' and coalesce(city, '') = 'Brno' and coalesce(address, '') = 'Úvoz 1012' order by id limit 1),
  'FAS 1050',
  'Snack',
  'FAS',
  null,
  '37053-10',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 71; lokalita ''Brno_Zimní stadion''. Telemetry ID: 582170. Zdrojová lokalita: Brno_Zimní stadion.',
  'vendsoft-71'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'TEXTILOMÁNIE' and coalesce(city, '') = 'Opatovice' and coalesce(address, '') = 'Velké dráhy 74e' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  '20161800575',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 72; lokalita ''Opatovice_TEXTILOMÁNIE POTRAVINY''. Telemetry ID: 582175. Zdrojová lokalita: Opatovice_TEXTILOMÁNIE POTRAVINY.',
  'vendsoft-72'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'TEXTILOMÁNIE' and coalesce(city, '') = 'Opatovice' and coalesce(address, '') = 'Velké dráhy 74e' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 73; lokalita ''Opatovice_TEXTILOMÁNIE KÁVA''. Telemetry ID: 602224. Zdrojová lokalita: Opatovice_TEXTILOMÁNIE KÁVA.',
  'vendsoft-73'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'ViaPharma_POTRAVINY' and coalesce(city, '') = 'Ostrava' and coalesce(address, '') = '17. listopadu' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 74; lokalita ''Ostrava_ViaPharma_POTRAVINY''. Telemetry ID: 587379. Zdrojová lokalita: Ostrava_ViaPharma_POTRAVINY.',
  'vendsoft-74'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce Zero 1',
  'Coffee',
  'Rheavendors',
  null,
  '20173606000',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 75; lokalita ''-''.',
  'vendsoft-75'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'OSRAM Česká republika s.r.o.' and coalesce(city, '') = 'Bruntál' and coalesce(address, '') = 'Zahradní 1442/46' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20135103632',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 76; lokalita ''OSRAM Česká republika s.r.o. KÁVA''. Telemetry ID: 598500. Zdrojová lokalita: OSRAM Česká republika s.r.o. KÁVA.',
  'vendsoft-76'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'OSRAM Česká republika s.r.o.' and coalesce(city, '') = 'Bruntál' and coalesce(address, '') = 'Zahradní 1442/46' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20140801115',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 77; lokalita ''OSRAM Česká republika s.r.o. KÁVA''. Telemetry ID: 598501. Zdrojová lokalita: OSRAM Česká republika s.r.o. KÁVA.',
  'vendsoft-77'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Vitar' and coalesce(city, '') = 'Tišnov' and coalesce(address, '') = 'Železné 113' order by id limit 1),
  'Bianchi Aria',
  'Snack',
  'Bianchi',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 78; lokalita ''Tišnov_Vitar POTRAVINY''. Telemetry ID: 587377. Zdrojová lokalita: Tišnov_Vitar POTRAVINY.',
  'vendsoft-78'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'ViaPharma' and coalesce(city, '') = 'Podolí u Brna' order by id limit 1),
  'FAS 1050',
  'Snack',
  'FAS',
  null,
  '202514186',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 79; lokalita ''Brno_ViaPharma POTRAVINY''. Telemetry ID: 604313. Zdrojová lokalita: Brno_ViaPharma POTRAVINY.',
  'vendsoft-79'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Vitar' and coalesce(city, '') = 'Tišnov' and coalesce(address, '') = 'Železné 113' order by id limit 1),
  'LEI 600 Touch',
  'Coffee',
  'Bianchi',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 80; lokalita ''Tišnov_Vitar KÁVA''. Telemetry ID: 592150. Zdrojová lokalita: Tišnov_Vitar KÁVA.',
  'vendsoft-80'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'OSRAM Česká republika s.r.o.' and coalesce(city, '') = 'Bruntál' and coalesce(address, '') = 'Zahradní 1442/46' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20151002298',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 81; lokalita ''OSRAM Česká republika s.r.o. KÁVA''. Telemetry ID: 598502. Zdrojová lokalita: OSRAM Česká republika s.r.o. KÁVA.',
  'vendsoft-81'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'OSRAM Česká republika s.r.o.' and coalesce(city, '') = 'Bruntál' and coalesce(address, '') = 'Zahradní 1442/46' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  '20194301877',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 82; lokalita ''OSRAM Česká republika s.r.o. POTRAVINY''. Telemetry ID: 598504. Zdrojová lokalita: OSRAM Česká republika s.r.o. POTRAVINY.',
  'vendsoft-82'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'OSRAM Česká republika s.r.o.' and coalesce(city, '') = 'Bruntál' and coalesce(address, '') = 'Zahradní 1442/46' order by id limit 1),
  'Europa Snack Hala 13',
  'Snack',
  'Rheavendors',
  null,
  '20172801209',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 83; lokalita ''OSRAM Česká republika s.r.o. POTRAVINY''. Telemetry ID: 598503. Zdrojová lokalita: OSRAM Česká republika s.r.o. POTRAVINY.',
  'vendsoft-83'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Marius Pedersen a.s.' and coalesce(city, '') = 'Brno - Černovice' and coalesce(address, '') = 'Hájecká 1162/3' order by id limit 1),
  'Europa Snack',
  'Snack',
  'Rheavendors',
  null,
  '2166912E1',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 84; lokalita ''Marius Pedersen a.s. POTRAVINY''. Telemetry ID: 597852. Zdrojová lokalita: Marius Pedersen a.s. POTRAVINY.',
  'vendsoft-84'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Marius Pedersen a.s.' and coalesce(city, '') = 'Brno - Černovice' and coalesce(address, '') = 'Hájecká 1162/3' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20142402525',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 85; lokalita ''Marius Pedersen a.s. KÁVA''. Telemetry ID: 602226. Zdrojová lokalita: Marius Pedersen a.s. KÁVA.',
  'vendsoft-85'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Vitar' and coalesce(city, '') = 'Tišnov' and coalesce(address, '') = 'Železné 113' order by id limit 1),
  'Luce X2 I8',
  'Coffee',
  'Rheavendors',
  null,
  '20122902542',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 86; lokalita ''Tišnov_Vitar KÁVA''. Telemetry ID: 602227. Zdrojová lokalita: Tišnov_Vitar KÁVA.',
  'vendsoft-86'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'REMANTE GROUP s.r.o.' and coalesce(city, '') = 'Otice' and coalesce(address, '') = 'K Rybníčkům 13' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '2014081118',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 87; lokalita ''REMANTE GROUP s.r.o. KÁVA''. Telemetry ID: 602229. Zdrojová lokalita: REMANTE GROUP s.r.o. KÁVA.',
  'vendsoft-87'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'WINE LIFE a.s.' and coalesce(city, '') = 'Brno' and coalesce(address, '') = 'Železná 689/7b' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 88; lokalita ''WINE LIFE a.s. KÁVA''. Telemetry ID: 604310. Zdrojová lokalita: WINE LIFE a.s. KÁVA.',
  'vendsoft-88'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportisimo' and coalesce(city, '') = 'Slezská Ostrava-Hrušov' and coalesce(address, '') = 'Žižkova' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 89; lokalita ''Ostrava_Sportisimo KÁVA''. Telemetry ID: 596511. Zdrojová lokalita: Ostrava_Sportisimo KÁVA.',
  'vendsoft-89'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportisimo' and coalesce(city, '') = 'Slezská Ostrava-Hrušov' and coalesce(address, '') = 'Žižkova' order by id limit 1),
  'Saphirh 10',
  'Snack',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 90; lokalita ''Ostrava_Sportisimo POTRAVINY''. Telemetry ID: 592147. Zdrojová lokalita: Ostrava_Sportisimo POTRAVINY.',
  'vendsoft-90'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Domov seniorů' and coalesce(city, '') = 'Břeclav' and coalesce(address, '') = 'Na Pešině 2842/13' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20164707878',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 91; lokalita ''Břeclav_Domov seniorů hl.budova KÁVA''. Telemetry ID: 604309. Zdrojová lokalita: Břeclav_Domov seniorů hl.budova KÁVA.',
  'vendsoft-91'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'AZ Klima' and coalesce(city, '') = 'Milovice' and coalesce(address, '') = 'Milovice 156' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20114603363',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 92; lokalita ''Milovice_AZ Klima KÁVA''. Telemetry ID: 604315. Zdrojová lokalita: Milovice_AZ Klima KÁVA.',
  'vendsoft-92'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportovní Hala Krásné Pole' and coalesce(city, '') = 'Ostrava' and coalesce(address, '') = 'Sklopčická 860' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20150601617',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 93; lokalita ''Sportovní Hala Krásné Pole''. Telemetry ID: 604314. Zdrojová lokalita: Sportovní Hala Krásné Pole.',
  'vendsoft-93'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportovní Hala Krásné Pole' and coalesce(city, '') = 'Ostrava' and coalesce(address, '') = 'Sklopčická 860' order by id limit 1),
  'FAS 1050',
  'Snack',
  'FAS',
  null,
  '202514184',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 94; lokalita ''Sportovní Hala Krásné Pole''. Telemetry ID: 604311. Zdrojová lokalita: Sportovní Hala Krásné Pole.',
  'vendsoft-94'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'GMW měřící technika, s. r. o.' and coalesce(city, '') = 'Blansko' and coalesce(address, '') = 'Hybešova 584/53' order by id limit 1),
  'Luce X2 E',
  'Coffee',
  'Rheavendors',
  null,
  '20161401784',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 95; lokalita ''GMW-měřící technika, s. r. o.''. Telemetry ID: 604312. Zdrojová lokalita: GMW-měřící technika, s. r. o..',
  'vendsoft-95'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'VN machinery s.r.o.' and coalesce(city, '') = 'Židlochovice' and coalesce(address, '') = 'Nádražní 919' order by id limit 1),
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20160701003',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 96; lokalita ''VN machinery s.r.o.''. Telemetry ID: 602223. Zdrojová lokalita: VN machinery s.r.o..',
  'vendsoft-96'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'TEXTILOMANIE' and coalesce(city, '') = 'Blučina' and coalesce(address, '') = 'Blučina 627' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20132201542',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 97; lokalita ''Blučina_TEXTILOMANIE''. Telemetry ID: 587380. Zdrojová lokalita: Blučina_TEXTILOMANIE.',
  'vendsoft-97'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportisimo' and coalesce(city, '') = 'Slezská Ostrava-Hrušov' and coalesce(address, '') = 'Žižkova' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20150301130',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 98; lokalita ''Ostrava_Sportisimo KÁVA''. Telemetry ID: 596508. Zdrojová lokalita: Ostrava_Sportisimo KÁVA.',
  'vendsoft-98'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportisimo' and coalesce(city, '') = 'Slezská Ostrava-Hrušov' and coalesce(address, '') = 'Žižkova' order by id limit 1),
  'FAS 1050',
  'Snack',
  'FAS',
  null,
  '202514177',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 99; lokalita ''Ostrava_Sportisimo POTRAVINY''. Telemetry ID: 582172. Zdrojová lokalita: Ostrava_Sportisimo POTRAVINY.',
  'vendsoft-99'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'TEXTILOMANIE' and coalesce(city, '') = 'Blučina' and coalesce(address, '') = 'Blučina 627' order by id limit 1),
  'ARIA L EVO',
  'Snack',
  'Bianchi',
  null,
  '25005142',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 100; lokalita ''Blučina_TEXTILOMANIE''. Telemetry ID: 582176. Zdrojová lokalita: Blučina_TEXTILOMANIE.',
  'vendsoft-100'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Hotel Kovák' and coalesce(city, '') = 'Slezská Ostrava-Kunčice' and coalesce(address, '') = 'Vratimovská 142' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20154806097',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 101; lokalita ''Ostrava_Hotel Kovák - KÁVA''. Telemetry ID: 587374. Zdrojová lokalita: Ostrava_Hotel Kovák - KÁVA.',
  'vendsoft-101'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'AVE' and coalesce(city, '') = 'Břeclav' and coalesce(address, '') = 'Sovadinova 841' order by id limit 1),
  'rhFS1 buttons16',
  'Coffee',
  'Rheavendors',
  null,
  '20254403746',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 102; lokalita ''Břeclav_AVE''. Telemetry ID: 604308. Zdrojová lokalita: Břeclav_AVE.',
  'vendsoft-102'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'BVK Hády' and coalesce(city, '') = 'Brno-Maloměřice a Obřany' and coalesce(address, '') = 'Hády 971' order by id limit 1),
  'rhFS1 touch 21,5',
  'Coffee',
  'Rheavendors',
  null,
  '20254403747',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 103; lokalita ''Brno_BVK Hády''. Telemetry ID: 587375. Zdrojová lokalita: Brno_BVK Hády.',
  'vendsoft-103'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20140400737',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 104; lokalita ''-''.',
  'vendsoft-104'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20151903192',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 105; lokalita ''-''.',
  'vendsoft-105'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20121801505',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 106; lokalita ''-''.',
  'vendsoft-106'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Sportisimo' and coalesce(city, '') = 'Slezská Ostrava-Hrušov' and coalesce(address, '') = 'Žižkova' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20134804750',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 107; lokalita ''Ostrava_Sportisimo KÁVA''. Telemetry ID: 596510. Zdrojová lokalita: Ostrava_Sportisimo KÁVA.',
  'vendsoft-107'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'LEI 700',
  'Coffee',
  'Bianchi',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 108; lokalita ''-''.',
  'vendsoft-108'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce H6',
  'Coffee',
  'Rheavendors',
  null,
  null,
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 109; lokalita ''-''.',
  'vendsoft-109'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'Kabelové Bubny' and coalesce(city, '') = 'Velké Meziříčí' and coalesce(address, '') = 'Františkov 88/10' order by id limit 1),
  'rhFS1 touch 21,5',
  'Coffee',
  'Rheavendors',
  null,
  '20242302665',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 110; lokalita ''Velké Meziříčí_Kabelové Bubny''. Telemetry ID: 592148. Zdrojová lokalita: Velké Meziříčí_Kabelové Bubny.',
  'vendsoft-110'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'SPEED' and coalesce(city, '') = 'Kyjov' and coalesce(address, '') = 'Svatoborská 427/89' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20164207216',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 111; lokalita ''Kyjov_SPEED''. Telemetry ID: 587373. Zdrojová lokalita: Kyjov_SPEED.',
  'vendsoft-111'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '201200966',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 113; lokalita ''-''.',
  'vendsoft-113'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '201103362',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 115; lokalita ''-''.',
  'vendsoft-115'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20184908634',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 116; lokalita ''-''.',
  'vendsoft-116'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '201103367',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 117; lokalita ''-''.',
  'vendsoft-117'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '201300715',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 118; lokalita ''-''.',
  'vendsoft-118'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20133102217',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 119; lokalita ''-''.',
  'vendsoft-119'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20181802136',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 120; lokalita ''-''.',
  'vendsoft-120'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I/E',
  'Coffee',
  'Rheavendors',
  null,
  '20162004109',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 121; lokalita ''-''.',
  'vendsoft-121'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20164808086',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 122; lokalita ''-''.',
  'vendsoft-122'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  (select id from public.locations where name = 'RIGUM, s.r.o.' and coalesce(city, '') = 'Dubňany' and coalesce(address, '') = 'Jarohněvice 1666' order by id limit 1),
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '201103371',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 123; lokalita ''RIGUM, s.r.o.''. Telemetry ID: 604307. Zdrojová lokalita: RIGUM, s.r.o..',
  'vendsoft-123'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;

insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  status,
  active,
  note,
  qr_token
)
values (
  null,
  'Luce X2 I',
  'Coffee',
  'Rheavendors',
  null,
  '20150301131',
  'ok',
  true,
  'Import z VendSoft exportu; původní kód 124; lokalita ''-''.',
  'vendsoft-124'
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;
