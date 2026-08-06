alter table public.sales_documents
  add column if not exists money_s3_exported_at timestamp with time zone,
  add column if not exists money_s3_export_batch_id text;

create index if not exists sales_documents_money_s3_exported_at_idx
  on public.sales_documents (money_s3_exported_at);

