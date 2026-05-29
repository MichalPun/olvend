alter table public.mobile_stock_request_items enable row level security;

drop policy if exists "Allow delete mobile stock request items" on public.mobile_stock_request_items;
create policy "Allow delete mobile stock request items"
on public.mobile_stock_request_items
for delete
to anon, authenticated
using (true);
