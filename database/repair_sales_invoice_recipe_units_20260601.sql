begin;

create temp table repair_invoice_recipe_units_20260601 as
with docs as (
  select
    d.id as document_id,
    (regexp_match(d.note, '\[rada:([^\]]+)\]'))[1] as document_number,
    (((convert_from(decode((regexp_match(d.note, '\[meta:([^\]]+)\]'))[1], 'base64'), 'UTF8'))::jsonb ->> 'stockLocationId')::bigint) as stock_location_id,
    ((convert_from(decode((regexp_match(d.note, '\[meta:([^\]]+)\]'))[1], 'base64'), 'UTF8'))::jsonb ->> 'stockMovementReference') as stock_movement_reference
  from public.sales_documents d
  where (regexp_match(d.note, '\[rada:([^\]]+)\]'))[1] in ('FV26-0133', 'FV26-0135')
),
correct_quantities as (
  select
    docs.document_id,
    docs.document_number,
    docs.stock_location_id,
    docs.stock_movement_reference,
    ri.product_id,
    round(sum(i.quantity * ri.quantity * case
      when lower(coalesce(ri.unit, '')) in ('g', 'gram', 'grams') and lower(coalesce(component.base_unit, '')) in ('kg', 'kilogram') then 0.001
      when lower(coalesce(ri.unit, '')) in ('kg', 'kilogram') and lower(coalesce(component.base_unit, '')) in ('g', 'gram') then 1000
      when lower(coalesce(ri.unit, '')) in ('ml') and lower(coalesce(component.base_unit, '')) in ('l', 'lt', 'liter') then 0.001
      when lower(coalesce(ri.unit, '')) in ('l', 'lt', 'liter') and lower(coalesce(component.base_unit, '')) in ('ml') then 1000
      else 1
    end)::numeric, 3) as correct_quantity
  from docs
  join public.sales_document_items i on i.document_id = docs.document_id
  join public.recipes r on r.machine_type = 'product_catalog'
    and r.active = true
    and (
      r.note like ('%' || '[olvend_recipe_product_id:' || i.product_id || ']' || '%')
      or r.selection_code = ('product:' || i.product_id)
    )
  join public.recipe_items ri on ri.recipe_id = r.id
  join public.products component on component.id = ri.product_id
  group by docs.document_id, docs.document_number, docs.stock_location_id, docs.stock_movement_reference, ri.product_id
),
active_movements as (
  select
    m.id as movement_id,
    docs.document_id,
    docs.document_number,
    docs.stock_location_id,
    m.product_id,
    m.quantity_base_units as old_quantity,
    cq.correct_quantity
  from docs
  join public.stock_movements_v13 m on m.reference_type = 'sales_document'
    and m.reference_id = docs.stock_movement_reference
    and m.from_stock_location_id = docs.stock_location_id
  join correct_quantities cq on cq.document_id = docs.document_id
    and cq.product_id = m.product_id
)
select
  movement_id,
  document_id,
  document_number,
  stock_location_id,
  product_id,
  old_quantity,
  correct_quantity,
  round((old_quantity - correct_quantity)::numeric, 3) as balance_delta
from active_movements
where abs(old_quantity - correct_quantity) > 0.0001;

with balance_deltas as (
  select
    stock_location_id,
    product_id,
    round(sum(balance_delta)::numeric, 3) as balance_delta
  from repair_invoice_recipe_units_20260601
  group by stock_location_id, product_id
)
update public.stock_location_balances b
set
  quantity_on_hand = round((b.quantity_on_hand + d.balance_delta)::numeric, 3),
  updated_at = now()
from balance_deltas d
where b.stock_location_id = d.stock_location_id
  and b.product_id = d.product_id
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
  d.stock_location_id,
  d.product_id,
  null,
  d.balance_delta,
  0,
  now()
from (
  select
    stock_location_id,
    product_id,
    round(sum(balance_delta)::numeric, 3) as balance_delta
  from repair_invoice_recipe_units_20260601
  group by stock_location_id, product_id
) d
where not exists (
  select 1
  from public.stock_location_balances b
  where b.stock_location_id = d.stock_location_id
    and b.product_id = d.product_id
    and b.batch_id is null
);

update public.stock_movements_v13 m
set
  quantity_base_units = r.correct_quantity,
  note = concat(coalesce(m.note, ''), ' · Opraven přepočet receptury g/kg dne 2026-06-01.')
from repair_invoice_recipe_units_20260601 r
where m.id = r.movement_id;

select
  r.document_number,
  r.product_id,
  p.name,
  p.base_unit,
  r.old_quantity,
  r.correct_quantity,
  r.balance_delta
from repair_invoice_recipe_units_20260601 r
join public.products p on p.id = r.product_id
order by r.document_number, p.name;

commit;
