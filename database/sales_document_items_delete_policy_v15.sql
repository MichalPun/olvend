do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'sales_document_items'
      and policyname = 'Allow delete sales document items'
  ) then
    create policy "Allow delete sales document items"
    on public.sales_document_items
    for delete
    to authenticated, anon
    using (true);
  end if;
end $$;
