alter table public.machine_planogram_slots
  add column if not exists product_family text,
  add column if not exists product_variant text,
  add column if not exists planned_product_name text,
  add column if not exists planned_product_sku text,
  add column if not exists planned_price_czk numeric(10,2),
  add column if not exists substitution_policy text not null default 'exact',
  add column if not exists allowed_substitutes text,
  add column if not exists operator_instruction text;

create index if not exists machine_planogram_slots_product_family_idx
  on public.machine_planogram_slots (machine_id, product_family)
  where product_family is not null;
