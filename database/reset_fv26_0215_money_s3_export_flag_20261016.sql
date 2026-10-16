-- FV26-0215 byla v OLVENDU oznacena jako exportovana do Money S3,
-- ale uzivatel potvrdil, ze import v Money S3 neprobehl.
-- Uvolni pouze tento doklad pro novy hromadny export.

begin;

do $$
declare
  v_document_id bigint;
  v_updated_count integer;
begin
  select id into strict v_document_id
  from public.sales_documents
  where id=91
    and (regexp_match(note, '\[rada:([^\]]+)\]'))[1]='FV26-0215'
    and customer_name='VITAR, s.r.o.'
    and document_type='invoice'
    and status='issued'
    and money_s3_exported_at='2026-10-01T09:46:53.627Z'::timestamptz
    and money_s3_export_batch_id='money-s3:1790848013627:2a7b661e-4a5b-4cc6-9835-6185a8244fe3';

  if (
    select count(*)
    from public.sales_documents
    where money_s3_export_batch_id='money-s3:1790848013627:2a7b661e-4a5b-4cc6-9835-6185a8244fe3'
  )<>1 then
    raise exception 'Exportni davka FV26-0215 uz neobsahuje prave jeden doklad.';
  end if;

  update public.sales_documents
  set money_s3_exported_at=null,
      money_s3_export_batch_id=null,
      updated_at=now()
  where id=v_document_id;

  get diagnostics v_updated_count=row_count;
  if v_updated_count<>1 then
    raise exception 'Ocekavana aktualizace jednoho dokladu, aktualizovano %.',v_updated_count;
  end if;

  if exists (
    select 1
    from public.sales_documents
    where id=v_document_id
      and (money_s3_exported_at is not null or money_s3_export_batch_id is not null)
  ) then
    raise exception 'Priznak Money S3 nebyl z FV26-0215 odstranen.';
  end if;
end $$;

commit;

select jsonb_build_object(
  'id',d.id,
  'document_number',(regexp_match(d.note, '\[rada:([^\]]+)\]'))[1],
  'customer_name',d.customer_name,
  'status',d.status,
  'money_s3_exported_at',d.money_s3_exported_at,
  'money_s3_export_batch_id',d.money_s3_export_batch_id,
  'available_for_bulk_money_export',
    d.status<>'cancelled'
    and d.money_s3_exported_at is null
    and d.money_s3_export_batch_id is null
) as verification
from public.sales_documents d
where d.id=91;
