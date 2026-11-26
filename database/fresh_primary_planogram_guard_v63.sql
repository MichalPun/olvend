begin;

-- Jednorazova oprava jedineho zjisteneho zakladniho planogramu, ktery ma
-- ve tripozicovem automatu dvakrat Debrecin. Fyzicky obsah slotu 31 uz je
-- Mlska; opravujeme pouze jeho dlouhodoby cil.
update public.machine_planogram_slots slot
set primary_product_id = product.id,
    primary_product_sku = product.sku,
    primary_product_name = product.name,
    updated_at = now()
from public.products product
where slot.id = 1458
  and slot.machine_id = 51
  and product.sku = 'SIMPLY-MLSKA'
  and coalesce(slot.primary_product_sku, '') <> product.sku;

create or replace function public.guard_basic_fresh_planogram_uniqueness_v63()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_is_fresh boolean;
  v_fresh_count integer;
  v_unique_count integer;
  v_required_unique integer;
  v_sku text;
begin
  v_sku := coalesce(new.primary_product_sku, new.product_sku);

  if tg_op = 'UPDATE'
     and new.machine_id is not distinct from old.machine_id
     and coalesce(new.primary_product_sku, new.product_sku)
       is not distinct from coalesce(old.primary_product_sku, old.product_sku)
     and new.active is not distinct from old.active then
    return new;
  end if;

  if new.active is not true or v_sku is null then return new; end if;

  select exists (
    select 1
    from public.products product
    where product.sku = v_sku
      and lower(coalesce(product.product_category, '')) = 'food_ready'
  ) into v_is_fresh;

  if not v_is_fresh then return new; end if;

  with fresh_after as (
    select coalesce(slot.primary_product_sku, slot.product_sku) as sku
    from public.machine_planogram_slots slot
    join public.products product
      on product.sku = coalesce(slot.primary_product_sku, slot.product_sku)
    where slot.machine_id = new.machine_id
      and slot.active is true
      and slot.id <> coalesce(new.id, -1)
      and lower(coalesce(product.product_category, '')) = 'food_ready'
    union all
    select v_sku
  )
  select count(*), count(distinct sku)
  into v_fresh_count, v_unique_count
  from fresh_after;

  -- U automatu se 2-3 cerstvymi pozicemi musi byt kazda jina. Vetsimu
  -- automatu zachovavame opakovani podle prodejnosti, ale nejmene 3 druhy.
  v_required_unique := least(v_fresh_count, 3);
  if v_fresh_count >= 2 and v_unique_count < v_required_unique then
    raise exception using
      message = 'Zakladni planogram musi zachovat rozmanitost baget. Docasnou fyzickou nahradu zapis pouze do vrstev pruziny.',
      errcode = '23514';
  end if;

  return new;
end
$function$;

drop trigger if exists guard_basic_fresh_planogram_uniqueness_v62
  on public.machine_planogram_slots;
drop trigger if exists guard_basic_fresh_planogram_uniqueness_v63
  on public.machine_planogram_slots;

create trigger guard_basic_fresh_planogram_uniqueness_v63
before insert or update of machine_id, primary_product_sku, active
on public.machine_planogram_slots
for each row execute function public.guard_basic_fresh_planogram_uniqueness_v63();

commit;
