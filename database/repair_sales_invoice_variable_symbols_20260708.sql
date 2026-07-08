with parsed as (
  select
    id,
    note,
    (regexp_match(note, '\[rada:([^\]]+)\]'))[1] as doc_no,
    (regexp_match(note, '\[meta:([^\]]+)\]'))[1] as meta_token
  from sales_documents
  where status <> 'cancelled'
),
prepared as (
  select
    id,
    note,
    doc_no,
    meta_token,
    regexp_replace(doc_no, '\D', '', 'g') as expected_variable_symbol,
    convert_from(decode(meta_token, 'base64'), 'UTF8')::jsonb as meta
  from parsed
  where doc_no is not null
    and meta_token is not null
),
patched as (
  select
    id,
    regexp_replace(
      note,
      '\[meta:[^\]]+\]',
      '[meta:' || encode(
        convert_to(
          jsonb_set(meta, '{variableSymbol}', to_jsonb(expected_variable_symbol), true)::text,
          'UTF8'
        ),
        'base64'
      ) || ']'
    ) as next_note
  from prepared
  where coalesce(meta->>'variableSymbol', '') <> expected_variable_symbol
)
update sales_documents documents
set note = patched.next_note
from patched
where documents.id = patched.id;
