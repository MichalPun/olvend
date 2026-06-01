begin;

create temp table repair_fv26_0135_balance_overapply_20260601 (
  product_id bigint primary key,
  balance_delta numeric(12,3) not null,
  expected_quantity numeric(12,3) not null
);

insert into repair_fv26_0135_balance_overapply_20260601 (product_id, balance_delta, expected_quantity)
values
  (105, -1031.967, 47.040),
  (106, -24901.473, 158.055),
  (107, -13126.860, 52.009),
  (108, -5552.542, 116.294);

update public.stock_location_balances b
set
  quantity_on_hand = r.expected_quantity,
  updated_at = now()
from repair_fv26_0135_balance_overapply_20260601 r
where b.stock_location_id = 5
  and b.product_id = r.product_id
  and b.batch_id is null;

select
  p.id as product_id,
  p.name,
  p.base_unit,
  r.balance_delta,
  b.quantity_on_hand as quantity_after_fix
from repair_fv26_0135_balance_overapply_20260601 r
join public.products p on p.id = r.product_id
join public.stock_location_balances b on b.stock_location_id = 5
  and b.product_id = r.product_id
  and b.batch_id is null
order by p.name;

commit;
