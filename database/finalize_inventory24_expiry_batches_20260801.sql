begin;

-- Oprava chybného roku potvrzená uživatelem; DrWitt (item 598) se záměrně neřeší.
update public.inventory_audit_expiry_counts
set expiry_date='2027-02-24'
where audit_item_id=583 and expiry_date='0007-02-24';

-- Vytvoření chybějících šarží podle přesných expiračních řádků.
insert into public.inventory_batches(product_id,lot_code,use_by_date,received_at,note)
select distinct e.product_id,null,e.expiry_date,now(),
  'Šarže materializovaná z řízené inventury #24'
from public.inventory_audit_expiry_counts e
join public.inventory_audit_items i on i.id=e.audit_item_id and i.audit_id=24 and i.id<>598
where e.expiry_date is not null
  and not exists (
    select 1 from public.inventory_batches b
    where b.product_id=e.product_id and b.lot_code is null
      and coalesce(b.use_by_date,b.best_before_date)=e.expiry_date
  );

-- Inventura je přesný snapshot: nejdříve vynulovat staré agregáty/batche všech jejích položek.
update public.stock_location_balances b set quantity_on_hand=0,updated_at=now()
where b.stock_location_id=1
  and b.product_id in (select product_id from public.inventory_audit_items where audit_id=24 and id<>598);

-- Produkty s expiracemi rozepsat do datovaných šarží.
insert into public.stock_location_balances(stock_location_id,product_id,batch_id,quantity_on_hand,reserved_quantity)
select i.stock_location_id,i.product_id,b.id,sum(e.quantity_base_units),0
from public.inventory_audit_items i
join public.inventory_audit_expiry_counts e on e.audit_item_id=i.id
join public.inventory_batches b on b.product_id=i.product_id and b.lot_code is null
 and coalesce(b.use_by_date,b.best_before_date)=e.expiry_date
where i.audit_id=24 and i.id<>598 and e.expiry_date is not null
group by i.stock_location_id,i.product_id,b.id
on conflict (stock_location_id,product_id,batch_id)
do update set quantity_on_hand=excluded.quantity_on_hand,updated_at=now();

-- Nesledované položky ponechat jako agregovaný zůstatek bez šarže.
insert into public.stock_location_balances(stock_location_id,product_id,batch_id,quantity_on_hand,reserved_quantity)
select i.stock_location_id,i.product_id,null,sum(i.counted_quantity),0
from public.inventory_audit_items i
where i.audit_id=24 and i.id<>598
  and not exists (select 1 from public.inventory_audit_expiry_counts e where e.audit_item_id=i.id)
group by i.stock_location_id,i.product_id
on conflict (stock_location_id,product_id,batch_id)
do update set quantity_on_hand=excluded.quantity_on_hand,updated_at=now();

update public.inventory_audits a
set status='closed',closed_at=now(),
    counted_quantity_total=x.counted_total,
    difference_quantity_total=x.counted_total-x.book_total
from (select audit_id,sum(book_quantity) book_total,sum(counted_quantity) counted_total
      from public.inventory_audit_items where audit_id=24 group by audit_id) x
where a.id=x.audit_id;

insert into public.app_settings(key,value,note)
values ('inventory24_expiry_materialized_20260801',
  jsonb_build_object('audit_id',24,'materialized_at',now()),
  'Expirační soupis inventury #24 převeden do inventory_batches a stock_location_balances.')
on conflict (key) do nothing;

commit;

select count(*) batch_rows,count(distinct b.product_id) products,sum(b.quantity_on_hand) quantity
from public.stock_location_balances b
join public.inventory_batches ib on ib.id=b.batch_id
where b.stock_location_id=1 and b.quantity_on_hand>0;
