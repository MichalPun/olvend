alter table public.vehicles
  add column if not exists service_scope text not null default 'mixed';

alter table public.vehicles
  drop constraint if exists vehicles_service_scope_check;

alter table public.vehicles
  add constraint vehicles_service_scope_check
  check (service_scope in ('coffee_only', 'mixed'));

comment on column public.vehicles.service_scope is
  'Rozsah obsluhy pro planovani tras: coffee_only = pouze kavove automaty, mixed = kava i potraviny.';

update public.vehicles
set service_scope = case
  when lower(concat_ws(' ', name, brand, model)) similar to '%(kangoo|combo|doblo)%'
    then 'coffee_only'
  else 'mixed'
end;

select id, plate, name, brand, model, service_scope
from public.vehicles
where active = true
order by id;
