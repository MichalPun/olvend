begin;

create temp table repair_fv26_0135_missing_balance_delta_20260601 (
  product_id bigint primary key,
  balance_delta numeric(12,3) not null
);

insert into repair_fv26_0135_missing_balance_delta_20260601 (product_id, balance_delta)
values
  (42, 20840.938),
  (110, 39652.308),
  (103, 8187.804),
  (104, 43310.246),
  (105, 8292.199),
  (106, 29374.096),
  (107, 13126.860),
  (108, 7027.765),
  (109, 16835.148);

update public.stock_location_balances b
set
  quantity_on_hand = round((b.quantity_on_hand + r.balance_delta)::numeric, 3),
  updated_at = now()
from repair_fv26_0135_missing_balance_delta_20260601 r
where b.stock_location_id = 5
  and b.product_id = r.product_id
  and b.batch_id is null;

insert into public.stock_location_balances (
  stock_location_id,
  product_id,
  batch_id,
  quantity_on_hand,
  reserved_quantity,
  updated_at
)
select
  5,
  r.product_id,
  null,
  r.balance_delta,
  0,
  now()
from repair_fv26_0135_missing_balance_delta_20260601 r
where not exists (
  select 1
  from public.stock_location_balances b
  where b.stock_location_id = 5
    and b.product_id = r.product_id
    and b.batch_id is null
);

select
  p.id as product_id,
  p.name,
  p.base_unit,
  r.balance_delta,
  b.quantity_on_hand as quantity_after_fix
from repair_fv26_0135_missing_balance_delta_20260601 r
join public.products p on p.id = r.product_id
join public.stock_location_balances b on b.stock_location_id = 5
  and b.product_id = r.product_id
  and b.batch_id is null
order by p.name;

commit;
