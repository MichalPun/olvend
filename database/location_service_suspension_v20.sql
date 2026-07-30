begin;

alter table public.locations
  add column if not exists service_suspended_until date;

comment on column public.locations.service_suspended_until is
  'Do tohoto data (výlučně) se lokalita nezobrazuje v provozních upozorněních ani v doporučeném plánování tras. Ruční výběr zůstává možný.';

commit;
notify pgrst, 'reload schema';
