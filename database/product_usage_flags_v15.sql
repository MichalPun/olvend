alter table public.products
  add column if not exists can_be_sold_directly boolean not null default false,
  add column if not exists can_be_used_in_recipe boolean not null default false,
  add column if not exists can_be_consumed_internally boolean not null default false,
  add column if not exists can_be_used_in_service boolean not null default false;

update public.products
set
  can_be_sold_directly = can_be_sold_directly
    or usage_type = 'direct_sale'
    or product_category in ('beverage_ready', 'snack_ready', 'food_ready'),
  can_be_used_in_recipe = can_be_used_in_recipe
    or usage_type = 'recipe_consumption'
    or product_category = 'ingredient',
  can_be_consumed_internally = can_be_consumed_internally
    or usage_type = 'internal_consumption',
  can_be_used_in_service = can_be_used_in_service
    or usage_type = 'service_use'
    or product_category in ('service_material', 'spare_part');
