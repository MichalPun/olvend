alter table public.machines
  add column if not exists stock_initialized_at timestamptz;

comment on column public.machines.stock_initialized_at is
  'Potvrzuje, ze vychozi fyzicky stav zasob automatu byl nastaven i bez prvni zaznamenane navstevy.';

update public.machines
set
  stock_initialized_at = coalesce(stock_initialized_at, now()),
  updated_at = now()
where id = 27
  and evidence_number = 32
  and exists (
    select 1
    from public.machine_coffee_containers container
    where container.machine_id = machines.id
      and container.active = true
      and container.current_quantity is not null
      and container.capacity_quantity > 0
  );

select id, evidence_number, name, stock_initialized_at
from public.machines
where id = 27;
