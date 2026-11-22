begin;

create or replace function public.finance_get_invoice_stock_lines_v1(p_invoice_id bigint)
returns table(
  id bigint,
  invoice_id bigint,
  line_number integer,
  description text,
  quantity numeric,
  unit_code text,
  unit_price numeric,
  supplier_item_code text,
  ean text,
  product_id bigint,
  stock_relevant boolean,
  stock_quantity_base_units numeric,
  net_amount numeric,
  vat_amount numeric,
  total_amount numeric
)
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
begin
  if not public.finance_can_manage_v1() then
    raise exception 'Přístup k položkám faktury byl odepřen.' using errcode='42501';
  end if;

  return query
  select
    a.id,a.invoice_id,a.line_number,a.description,a.quantity,a.unit_code,a.unit_price,
    a.supplier_item_code,a.ean,a.product_id,a.stock_relevant,a.stock_quantity_base_units,
    a.net_amount,a.vat_amount,a.total_amount
  from public.finance_invoice_allocations a
  where a.invoice_id=p_invoice_id and a.stock_relevant
  order by a.line_number,a.id;
end;
$$;

revoke all on function public.finance_get_invoice_stock_lines_v1(bigint) from public,anon;
grant execute on function public.finance_get_invoice_stock_lines_v1(bigint) to authenticated,service_role;

comment on function public.finance_get_invoice_stock_lines_v1(bigint) is
  'Vrátí pouze skladově relevantní řádky jedné přijaté faktury oprávněnému uživateli Finance.';

notify pgrst,'reload schema';
commit;
