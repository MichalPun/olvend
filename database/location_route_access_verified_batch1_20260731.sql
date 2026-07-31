-- Ověřené veřejné provozní hodiny, 1. dávka.
-- Interní přístup operátorky se může lišit; taková místa zůstávají needs_confirmation.

-- Střední škola Bohumín, obě budovy. V létě má ředitelství po–pá 8–12.
update public.locations
set route_access_hours = '{
      "default": {
        "mo":[["07:00","11:00"],["13:00","14:30"]],
        "tu":[["07:00","11:00"],["14:00","14:30"]],
        "we":[["07:00","11:00"],["13:00","14:30"]],
        "th":[["07:00","11:00"],["13:00","14:30"]],
        "fr":[["07:00","11:00"],["13:00","14:30"]]
      },
      "periods":[{
        "from":"2026-07-01","to":"2026-08-31",
        "hours":{"mo":[["08:00","12:00"]],"tu":[["08:00","12:00"]],"we":[["08:00","12:00"]],"th":[["08:00","12:00"]],"fr":[["08:00","12:00"]]}
      }]
    }'::jsonb,
    route_access_status = 'confirmed',
    route_access_source = 'https://www.sosboh.cz/cz/kontakty/kontaktni-informace/',
    route_access_verified_at = now()
where id in (4, 5);

-- Hotel Kovák: recepce 24/7.
update public.locations
set route_access_hours = '{"mo":[["00:00","24:00"]],"tu":[["00:00","24:00"]],"we":[["00:00","24:00"]],"th":[["00:00","24:00"]],"fr":[["00:00","24:00"]],"sa":[["00:00","24:00"]],"su":[["00:00","24:00"]]}'::jsonb,
    route_access_status = 'confirmed',
    route_access_source = 'https://hotelkovak.cz/kontakt/',
    route_access_verified_at = now(),
    service_window = 'recepce 24/7'
where id = 59;

-- Bazén Hrušovany: oficiálně oznámená mimořádná uzavírka.
update public.locations
set route_access_hours = jsonb_set(
      coalesce(route_access_hours, '{}'::jsonb),
      '{closed_dates}',
      '["2026-07-31","2026-08-01"]'::jsonb,
      true
    ),
    route_access_source = 'https://bazen.hrusovany.cz/index.php/home',
    route_access_verified_at = now()
where id = 27;

-- WINE LIFE, sklad Brno: po–pá 7:30–16:00, sobota 7:30–12:00.
update public.locations
set route_access_hours = '{"mo":[["07:30","16:00"]],"tu":[["07:30","16:00"]],"we":[["07:30","16:00"]],"th":[["07:30","16:00"]],"fr":[["07:30","16:00"]],"sa":[["07:30","12:00"]]}'::jsonb,
    route_access_status = 'confirmed',
    route_access_source = 'https://www.winelife.cz/kontakt/',
    route_access_verified_at = now(),
    service_window = 'po–pá 7:30–16:00, so 7:30–12:00'
where id = 11;

-- Sonepar Jihlava Heroltická: po–čt 6–16, pá 6–15.
update public.locations
set route_access_hours = '{"mo":[["06:00","16:00"]],"tu":[["06:00","16:00"]],"we":[["06:00","16:00"]],"th":[["06:00","16:00"]],"fr":[["06:00","15:00"]]}'::jsonb,
    route_access_status = 'confirmed',
    route_access_source = 'https://www.sonepar.cz/pobocky-na-mape',
    route_access_verified_at = now(),
    service_window = 'po–čt 6:00–16:00, pá 6:00–15:00'
where id = 32;

-- VRTAL Jihlava centrální sklad: po–pá 7:30–17, so 9–11:30.
update public.locations
set route_access_hours = '{"mo":[["07:30","17:00"]],"tu":[["07:30","17:00"]],"we":[["07:30","17:00"]],"th":[["07:30","17:00"]],"fr":[["07:30","17:00"]],"sa":[["09:00","11:30"]]}'::jsonb,
    route_access_status = 'confirmed',
    route_access_source = 'https://vrtal.preview.ideacloud.cz/kontakty',
    route_access_verified_at = now(),
    service_window = 'po–pá 7:30–17:00, so 9:00–11:30'
where id = 33;
