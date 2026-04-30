alter table public.employees
  add column if not exists vacation_allowance_days numeric(6,2),
  add column if not exists vacation_carryover_days numeric(6,2);

comment on column public.employees.vacation_allowance_days is
  'Roční nárok dovolené ve dnech. Používá se pro zaměstnanecký profil a HR žádosti.';

comment on column public.employees.vacation_carryover_days is
  'Převod dovolené z předchozího období ve dnech.';
