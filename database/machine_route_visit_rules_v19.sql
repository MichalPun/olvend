alter table public.machine_service_rules
  add column if not exists stock_critical_percent numeric(5,2) not null default 19,
  add column if not exists max_visit_interval_days integer not null default 10,
  add column if not exists route_visit_rules_active boolean not null default true;

alter table public.machine_service_rules
  drop constraint if exists machine_service_rules_stock_critical_percent_check;

alter table public.machine_service_rules
  add constraint machine_service_rules_stock_critical_percent_check
  check (stock_critical_percent >= 0 and stock_critical_percent <= 100);

alter table public.machine_service_rules
  drop constraint if exists machine_service_rules_max_visit_interval_days_check;

alter table public.machine_service_rules
  add constraint machine_service_rules_max_visit_interval_days_check
  check (max_visit_interval_days >= 1 and max_visit_interval_days <= 365);

comment on column public.machine_service_rules.stock_critical_percent is
  'Automat se doporučí do trasy, pokud je některý sledovaný zásobník pod tímto procentem.';
comment on column public.machine_service_rules.max_visit_interval_days is
  'Nejvyšší povolený počet dnů mezi návštěvami automatu.';
comment on column public.machine_service_rules.route_visit_rules_active is
  'Zapíná doporučení návštěvy podle zásoby nebo maximálního intervalu.';
