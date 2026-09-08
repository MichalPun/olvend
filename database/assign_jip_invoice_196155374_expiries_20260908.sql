begin;

do $$
declare
  v_order public.purchase_orders%rowtype;
  v_lines jsonb;
  v_result jsonb;
  v_expected_products integer;
  v_matched_products integer;
begin
  select * into v_order
  from public.purchase_orders
  where id = 111
  for update;

  if not found
     or v_order.status <> 'received'
     or v_order.supplier_id <> 3
     or v_order.invoice_number <> '196155374' then
    raise exception 'Doklad JIP 196155374 nebyl nalezen v očekávaném stavu.';
  end if;

  with current_lines as (
    select
      poi.product_id,
      sum(poi.received_quantity)::numeric(14,3) as quantity
    from public.purchase_order_items poi
    join public.products p on p.id = poi.product_id
    where poi.purchase_order_id = 111
      and poi.received_quantity > 0
      and p.expiry_tracking_mode <> 'none'
    group by poi.product_id
  ),
  prior_receipts as (
    select
      sm.product_id,
      po.id as prior_purchase_order_id,
      coalesce(po.received_at, po.created_at) as prior_received_at,
      coalesce(ib.best_before_date, ib.use_by_date) as expiry_date,
      ib.storage_bin_code,
      row_number() over (
        partition by sm.product_id
        order by
          case when po.id = 108 then 0 else 1 end,
          coalesce(po.received_at, po.created_at) desc,
          po.id desc,
          ib.id desc
      ) as rn
    from public.stock_movements_v13 sm
    join public.purchase_orders po
      on sm.reference_type = 'purchase_order'
     and sm.reference_id = po.id::text
    join public.inventory_batches ib on ib.id = sm.batch_id
    where sm.movement_type = 'receipt'
      and po.supplier_id = 3
      and po.id < 111
      and coalesce(ib.best_before_date, ib.use_by_date) is not null
      and nullif(btrim(ib.storage_bin_code), '') is not null
  ),
  selected as (
    select
      c.product_id,
      c.quantity,
      p.prior_purchase_order_id,
      p.expiry_date,
      p.storage_bin_code
    from current_lines c
    join prior_receipts p
      on p.product_id = c.product_id
     and p.rn = 1
  )
  select
    (select count(*) from current_lines),
    count(*),
    jsonb_agg(
      jsonb_build_object(
        'product_id', product_id,
        'allocations', jsonb_build_array(
          jsonb_build_object(
            'quantity', quantity,
            'expiry_date', expiry_date,
            'storage_bin_code', storage_bin_code
          )
        )
      )
      order by product_id
    )
  into v_expected_products, v_matched_products, v_lines
  from selected;

  if v_expected_products <> 31 or v_matched_products <> v_expected_products then
    raise exception 'Nelze bezpečně přiřadit expirace: očekáváno %, nalezeno %.',
      v_expected_products, v_matched_products;
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_lines) line
    cross join jsonb_array_elements(line->'allocations') allocation
    where (allocation->>'expiry_date')::date < current_date
  ) then
    raise exception 'Některá převzatá expirace je již prošlá.';
  end if;

  select public.assign_purchase_receipt_expiries_v31(111, v_lines)
  into v_result;

  raise notice 'Výsledek zařazení expirací: %', v_result;
end
$$;

-- Uchovej v šarži auditní informaci, že datum bylo převzato z dřívějšího
-- příjmu stejného produktu od stejného dodavatele.
with prior_receipts as (
  select
    sm.product_id,
    po.id as prior_purchase_order_id,
    po.invoice_number as prior_invoice_number,
    row_number() over (
      partition by sm.product_id
      order by
        case when po.id = 108 then 0 else 1 end,
        coalesce(po.received_at, po.created_at) desc,
        po.id desc,
        ib.id desc
    ) as rn
  from public.stock_movements_v13 sm
  join public.purchase_orders po
    on sm.reference_type = 'purchase_order'
   and sm.reference_id = po.id::text
  join public.inventory_batches ib on ib.id = sm.batch_id
  where sm.movement_type = 'receipt'
    and po.supplier_id = 3
    and po.id < 111
    and coalesce(ib.best_before_date, ib.use_by_date) is not null
    and nullif(btrim(ib.storage_bin_code), '') is not null
),
new_batches as (
  select distinct sm.product_id, sm.batch_id
  from public.stock_movements_v13 sm
  where sm.reference_type = 'purchase_order'
    and sm.reference_id = '111'
    and sm.movement_type = 'receipt'
    and sm.batch_id is not null
)
update public.inventory_batches ib
set note = concat(
  ib.note,
  '; expirace převzata z dokladu #',
  pr.prior_purchase_order_id,
  ' (faktura ', pr.prior_invoice_number, ')'
)
from new_batches nb
join prior_receipts pr
  on pr.product_id = nb.product_id
 and pr.rn = 1
where ib.id = nb.batch_id;

do $$
declare
  v_unbatched integer;
  v_batched_products integer;
  v_invalid_batches integer;
begin
  select count(*) into v_unbatched
  from public.stock_movements_v13 sm
  join public.products p on p.id = sm.product_id
  where sm.reference_type = 'purchase_order'
    and sm.reference_id = '111'
    and sm.movement_type = 'receipt'
    and p.expiry_tracking_mode <> 'none'
    and sm.batch_id is null;

  select count(distinct sm.product_id) into v_batched_products
  from public.stock_movements_v13 sm
  join public.products p on p.id = sm.product_id
  where sm.reference_type = 'purchase_order'
    and sm.reference_id = '111'
    and sm.movement_type = 'receipt'
    and p.expiry_tracking_mode <> 'none'
    and sm.batch_id is not null;

  select count(*) into v_invalid_batches
  from public.stock_movements_v13 sm
  join public.inventory_batches ib on ib.id = sm.batch_id
  where sm.reference_type = 'purchase_order'
    and sm.reference_id = '111'
    and sm.movement_type = 'receipt'
    and (
      coalesce(ib.best_before_date, ib.use_by_date) is null
      or nullif(btrim(ib.storage_bin_code), '') is null
    );

  if v_unbatched <> 0 or v_batched_products <> 31 or v_invalid_batches <> 0 then
    raise exception 'Kontrola po zařazení selhala: bez šarže %, produkty %, neplatné šarže %.',
      v_unbatched, v_batched_products, v_invalid_batches;
  end if;
end
$$;

commit;
