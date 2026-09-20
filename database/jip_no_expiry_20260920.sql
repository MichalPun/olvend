-- JIP assortment does not require expiry entry. Existing batches remain historical evidence.
begin;
do $$ begin
  if not exists(select 1 from public.purchase_suppliers where id=3 and name ilike '%jip%') then
    raise exception 'Expected JIP supplier #3 not found';
  end if;
end $$;

create or replace function public.jip_product_expiry_policy_20260920()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if TG_TABLE_NAME = 'products' then
    if exists(select 1 from public.supplier_product_mappings m where m.product_id=new.id and m.supplier_id=3) then
      new.expiry_tracking_mode := 'none';
      new.requires_batch_tracking := false;
    end if;
  elsif new.supplier_id=3 and new.product_id is not null then
    update public.products set expiry_tracking_mode='none', requires_batch_tracking=false
    where id=new.product_id and (expiry_tracking_mode is distinct from 'none' or requires_batch_tracking is distinct from false);
  end if;
  return new;
end $$;
revoke all on function public.jip_product_expiry_policy_20260920() from public, anon, authenticated;
drop trigger if exists jip_product_expiry_policy on public.products;
create trigger jip_product_expiry_policy before update of expiry_tracking_mode, requires_batch_tracking on public.products
for each row execute function public.jip_product_expiry_policy_20260920();
drop trigger if exists jip_mapping_expiry_policy on public.supplier_product_mappings;
create trigger jip_mapping_expiry_policy after insert or update of supplier_id,product_id on public.supplier_product_mappings
for each row execute function public.jip_product_expiry_policy_20260920();

update public.products p set expiry_tracking_mode='none', requires_batch_tracking=false
where exists(select 1 from public.supplier_product_mappings m where m.product_id=p.id and m.supplier_id=3)
and (p.expiry_tracking_mode is distinct from 'none' or p.requires_batch_tracking is distinct from false);
commit;
