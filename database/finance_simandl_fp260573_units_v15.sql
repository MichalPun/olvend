begin;

do $$
declare
  v_invoice_id bigint;
  v_updated integer;
begin
  select id into v_invoice_id
  from public.finance_received_invoices
  where internal_number='FP260573' and document_number='26002070'
  for update;

  if v_invoice_id is null then
    raise exception 'Faktura FP260573 / 26002070 nebyla nalezena.';
  end if;

  update public.finance_invoice_allocations
  set unit_code='kg',
      source_payload=coalesce(source_payload,'{}'::jsonb)||jsonb_build_object(
        'source_unit_code',coalesce(source_payload->>'source_unit_code','ks'),
        'stock_unit_normalized','kg',
        'normalized_by','finance_simandl_fp260573_units_v15'
      )
  where invoice_id=v_invoice_id
    and supplier_item_code in ('980','983','652/A')
    and description ~* '(^|[^0-9])1[[:space:]]*kg([^a-z]|$)';

  get diagnostics v_updated=row_count;
  if v_updated<>3 then
    raise exception 'Očekávány 3 kilogramové položky FP260573, upraveno %.',v_updated;
  end if;

  update public.finance_document_intake_queue q
  set extracted_payload=jsonb_set(
    q.extracted_payload,
    '{line_items}',
    (
      select jsonb_agg(
        case
          when item->>'supplier_item_code' in ('980','983','652/A')
            then item||jsonb_build_object('unit_code','kg','source_unit_code',coalesce(item->>'source_unit_code','ks'))
          else item
        end
        order by ordinality
      )
      from jsonb_array_elements(coalesce(q.extracted_payload->'line_items','[]'::jsonb)) with ordinality as lines(item,ordinality)
    ),
    true
  ),processed_at=now()
  where q.invoice_id=v_invoice_id;

  if not exists(
    select 1 from public.finance_invoice_events
    where invoice_id=v_invoice_id and event_type='line_item_units_normalized'
      and metadata->>'migration'='finance_simandl_fp260573_units_v15'
  ) then
    insert into public.finance_invoice_events(invoice_id,event_type,note,metadata)
    values(
      v_invoice_id,
      'line_item_units_normalized',
      'Tři suroviny v jednokilogramovém balení byly pro sklad převedeny z kusů na kilogramy.',
      jsonb_build_object('migration','finance_simandl_fp260573_units_v15','line_count',3,'source_unit','ks','stock_unit','kg')
    );
  end if;
end;
$$;

commit;
