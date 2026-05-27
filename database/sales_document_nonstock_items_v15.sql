alter table public.sales_document_items
  add column if not exists product_name text,
  add column if not exists unit text,
  add column if not exists unit_cost numeric(14, 4) not null default 0;

comment on column public.sales_document_items.product_name is 'Text item name for non-stock invoice lines and cached display for stock lines.';
comment on column public.sales_document_items.unit is 'Displayed unit on issued sales documents.';
comment on column public.sales_document_items.unit_cost is 'Internal purchase/cost price without VAT per unit for invoice profit calculation.';
