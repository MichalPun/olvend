begin;

alter table public.mobile_stock_requests
  add column if not exists calculation_snapshot jsonb not null default '{}'::jsonb;

comment on column public.mobile_stock_requests.calculation_snapshot is
  'Úplný audit automatického výpočtu vychystání, včetně nulových a vynechaných řádků a důvodů.';

commit;
