-- Oprava karet surovin vedených v kg: "Balení 1 kg" nesmí znamenat 1000 kg.
update public.product_packages pack
set
  units_per_package = 1,
  updated_at = now()
from public.products product
where product.id = pack.product_id
  and product.base_unit = 'kg'
  and (product.product_category = 'ingredient' or product.usage_type = 'recipe_consumption')
  and pack.units_per_package = 1000
  and lower(coalesce(pack.package_name, '')) in ('balení 1 kg', '1 kg', 'baleni 1 kg');
