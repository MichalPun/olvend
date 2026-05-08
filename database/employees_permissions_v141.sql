begin;

alter table public.employees
  add column if not exists permissions jsonb not null default '{}'::jsonb;

update public.employees
set permissions = jsonb_build_object(
  'dashboard', true,
  'attendance', true,
  'service', true,
  'routes', true,
  'vehicles', true,
  'warehouses', true,
  'settings', true
)
where coalesce(role, '') = 'admin'
  and (permissions = '{}'::jsonb or permissions is null);

update public.employees
set permissions = jsonb_build_object(
  'dashboard', true,
  'attendance', true,
  'service', true,
  'routes', true,
  'vehicles', true,
  'warehouses', true,
  'settings', false
)
where coalesce(role, '') = 'manager'
  and (permissions = '{}'::jsonb or permissions is null);

update public.employees
set permissions = jsonb_build_object(
  'dashboard', false,
  'attendance', true,
  'service', true,
  'routes', true,
  'vehicles', false,
  'warehouses', false,
  'settings', false
)
where coalesce(role, '') = 'technician'
  and (permissions = '{}'::jsonb or permissions is null);

update public.employees
set permissions = jsonb_build_object(
  'dashboard', false,
  'attendance', true,
  'service', false,
  'routes', true,
  'vehicles', false,
  'warehouses', false,
  'settings', false
)
where coalesce(role, '') = 'operator'
  and (permissions = '{}'::jsonb or permissions is null);

update public.employees
set permissions = jsonb_build_object(
  'dashboard', true,
  'attendance', false,
  'service', true,
  'routes', true,
  'vehicles', false,
  'warehouses', false,
  'settings', false
)
where coalesce(role, '') = 'sales'
  and (permissions = '{}'::jsonb or permissions is null);

comment on column public.employees.permissions is 'Jednoduchý JSONB model oprávnění pro moduly OLVEND.';

commit;
