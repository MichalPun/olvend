begin;

alter table public.mobile_stock_request_items
  add column if not exists prepared_product_id bigint references public.products (id) on delete restrict,
  add column if not exists prepared_product_name text,
  add column if not exists prepared_sku text,
  add column if not exists prepared_unit text;

create index if not exists mobile_stock_request_items_prepared_product_idx
  on public.mobile_stock_request_items (prepared_product_id)
  where prepared_product_id is not null;

comment on column public.mobile_stock_request_items.prepared_product_id is
  'Skutečně vydaný náhradní produkt. product_id vždy zůstává původně požadovaným produktem.';
comment on column public.mobile_stock_request_items.prepared_product_name is
  'Historický název skutečně vydané náhrady.';
comment on column public.mobile_stock_request_items.prepared_sku is
  'Historické SKU skutečně vydané náhrady.';
comment on column public.mobile_stock_request_items.prepared_unit is
  'Jednotka prepared_quantity při vydání náhrady.';

create or replace function public.validate_mobile_stock_request_substitution_v22()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_original public.products%rowtype;
  v_substitute public.products%rowtype;
  v_request_type text;
  v_approved boolean := false;
begin
  if new.prepared_product_id is null or new.prepared_product_id = new.product_id then
    new.prepared_product_id := null;
    new.prepared_product_name := null;
    new.prepared_sku := null;
    new.prepared_unit := null;
    return new;
  end if;

  select * into v_original from public.products where id = new.product_id;
  select * into v_substitute from public.products where id = new.prepared_product_id and active = true;
  select request_type into v_request_type from public.mobile_stock_requests where id = new.request_id;

  if v_original.id is null or v_substitute.id is null then
    raise exception 'Původní nebo náhradní produkt není aktivní.';
  end if;
  if v_request_type not in ('vehicle_order', 'vehicle_load') then
    raise exception 'Náhradu lze vydat jen pro nakládku do vozidla.';
  end if;
  if coalesce(new.prepared_quantity, 0) <= 0 then
    raise exception 'U náhrady musí být uvedené kladné vydané množství.';
  end if;

  select exists (
    select 1
    from public.machine_planogram_slots slot
    cross join lateral regexp_matches(coalesce(slot.allowed_substitutes, ''), 'SKU\s*([A-Za-z0-9_-]+)', 'gi') as allowed_match
    where slot.active = true
      and lower(coalesce(slot.product_sku, '')) = lower(coalesce(v_original.sku, ''))
      and slot.substitution_policy = 'approved_list'
      and lower(allowed_match[1]) = lower(v_substitute.sku)
  ) or exists (
    select 1
    from public.machine_planogram_slots original_slot
    join public.machine_planogram_slots substitute_slot
      on substitute_slot.active = true
     and lower(coalesce(substitute_slot.product_family, '')) = lower(coalesce(original_slot.product_family, ''))
     and lower(coalesce(substitute_slot.product_sku, '')) = lower(coalesce(v_substitute.sku, ''))
    where original_slot.active = true
      and original_slot.substitution_policy = 'same_family'
      and coalesce(original_slot.product_family, '') <> ''
      and lower(coalesce(original_slot.product_sku, '')) = lower(coalesce(v_original.sku, ''))
  ) into v_approved;

  if not v_approved then
    raise exception 'Produkt % není schválená náhrada za %.', v_substitute.name, v_original.name;
  end if;

  new.prepared_product_name := v_substitute.name;
  new.prepared_sku := v_substitute.sku;
  new.prepared_unit := coalesce(nullif(btrim(new.prepared_unit), ''), v_substitute.base_unit, 'ks');
  return new;
end;
$$;

drop trigger if exists trg_validate_mobile_stock_request_substitution_v22 on public.mobile_stock_request_items;
create trigger trg_validate_mobile_stock_request_substitution_v22
before insert or update of product_id, prepared_product_id, prepared_quantity, prepared_unit
on public.mobile_stock_request_items
for each row
execute function public.validate_mobile_stock_request_substitution_v22();

notify pgrst, 'reload schema';

commit;
