-- OLVEND v22: vychystávací doklad je dohledatelně svázaný s trasou.
alter table public.mobile_stock_requests
  add column if not exists route_plan_id bigint references public.route_plans (id) on delete set null,
  add column if not exists picking_cutoff_at timestamp with time zone,
  add column if not exists calculation_source text not null default 'manual'
    check (calculation_source in ('manual', 'history', 'route_plan', 'route_plan_with_history'));

create index if not exists mobile_stock_requests_route_plan_idx
  on public.mobile_stock_requests (route_plan_id, status);

-- Vychystání se neodečítají ani neslučují. Každý výpočet je samostatný snímek
-- telemetrie v okamžiku, kdy sklad skutečně jde vychystávat.
drop index if exists public.mobile_stock_requests_one_active_route_pick_idx;

comment on column public.mobile_stock_requests.route_plan_id is
  'Trasa, podle které byl vychystávací doklad spočítán.';
comment on column public.mobile_stock_requests.picking_cutoff_at is
  'Volitelný termín; telemetrické vychystávání nemá pevnou denní uzávěrku.';
comment on column public.mobile_stock_requests.calculation_source is
  'Zdroj množství: ruční zadání, historie nebo konkrétní trasa.';
