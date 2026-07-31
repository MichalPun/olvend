-- OLVEND v23: plánovaný odjezd zpřesňuje ETA zastávek a prodejní forecast.
alter table public.route_plans
  add column if not exists planned_departure_time time without time zone not null default '07:00';

comment on column public.route_plans.planned_departure_time is
  'Předpokládaný místní čas odjezdu trasy; používá se pro ETA zastávek a výpočet prodejů do příjezdu.';

