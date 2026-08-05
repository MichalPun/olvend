create table if not exists public.supplier_order_rules (
  supplier_id bigint primary key references public.purchase_suppliers (id) on delete cascade,
  order_cutoff_time time not null default '15:00',
  delivery_lead_workdays integer not null default 1 check (delivery_lead_workdays >= 0),
  minimum_order_value numeric(12,2) not null default 0 check (minimum_order_value >= 0),
  minimum_order_product_category text,
  note text,
  updated_at timestamp with time zone not null default now()
);

alter table public.supplier_order_rules enable row level security;

drop policy if exists "Allow read supplier order rules" on public.supplier_order_rules;
create policy "Allow read supplier order rules"
on public.supplier_order_rules for select to authenticated, anon using (true);

drop policy if exists "Allow manage supplier order rules" on public.supplier_order_rules;
create policy "Allow manage supplier order rules"
on public.supplier_order_rules for all to authenticated, anon using (true) with check (true);

insert into public.supplier_order_rules (
  supplier_id,
  order_cutoff_time,
  delivery_lead_workdays,
  minimum_order_value,
  minimum_order_product_category,
  note
)
select
  id,
  '15:00',
  1,
  10000,
  'snack_ready',
  'JiP: objednávka na následující pracovní den musí být odeslána do 15:00; cukrovinková část závozu minimálně 10 000 Kč.'
from public.purchase_suppliers
where lower(name) like '%jip%'
order by id
limit 1
on conflict (supplier_id) do update set
  order_cutoff_time = excluded.order_cutoff_time,
  delivery_lead_workdays = excluded.delivery_lead_workdays,
  minimum_order_value = excluded.minimum_order_value,
  minimum_order_product_category = excluded.minimum_order_product_category,
  note = excluded.note,
  updated_at = now();
