begin;

do $$
declare
  v_matched integer;
begin
  select count(*)
  into v_matched
  from public.products
  where (sku, name) in (
    ('52', 'Creamio Topping 0,7 kg'),
    ('197', 'oVe BASE WITH PISTACHIO FLAVOUR 1000g'),
    ('37', 'Ensa Arašídy loupané pražené solené 100g')
  );

  if v_matched <> 3 then
    raise exception 'Očekávány 3 přesné produkty pro vyřazení z doporučené nakládky, nalezeno %.', v_matched;
  end if;
end $$;

update public.vehicle_auto_load_profiles profile
set active = false,
    note = 'Vyřazeno z doporučené nakládky 4. 11. 2026: položka se již standardně nenakládá na vozidla.',
    updated_at = now()
from public.products product
where profile.product_id = product.id
  and (product.sku, product.name) in (
    ('52', 'Creamio Topping 0,7 kg'),
    ('197', 'oVe BASE WITH PISTACHIO FLAVOUR 1000g'),
    ('37', 'Ensa Arašídy loupané pražené solené 100g')
  );

update public.vehicle_auto_load_deferred_needs need
set status = 'closed',
    closed_at = coalesce(need.closed_at, now()),
    note = concat_ws(E'\n', nullif(need.note, ''), 'Uzavřeno 4. 11. 2026: produkt byl vyřazen z doporučené nakládky vozidel.'),
    updated_at = now()
from public.products product
where need.product_id = product.id
  and need.status = 'open'
  and (product.sku, product.name) in (
    ('52', 'Creamio Topping 0,7 kg'),
    ('197', 'oVe BASE WITH PISTACHIO FLAVOUR 1000g'),
    ('37', 'Ensa Arašídy loupané pražené solené 100g')
  );

commit;

select product.id,
       product.sku,
       product.name,
       product.active as product_active,
       profile.active as auto_load_active,
       profile.note
from public.products product
join public.vehicle_auto_load_profiles profile on profile.product_id = product.id
where (product.sku, product.name) in (
  ('52', 'Creamio Topping 0,7 kg'),
  ('197', 'oVe BASE WITH PISTACHIO FLAVOUR 1000g'),
  ('37', 'Ensa Arašídy loupané pražené solené 100g')
)
order by product.id;
