alter table public.purchase_product_profiles
  add column if not exists order_quantity_by_weekday jsonb not null default '{}'::jsonb;

comment on column public.purchase_product_profiles.order_quantity_by_weekday
  is 'Volitelne mnozstvi objednavky podle dne v tydnu. Klice 1-7 = Po-Ne, hodnota = bezne mnozstvi pro dany den.';
