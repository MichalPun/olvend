alter table public.inventory_audit_items enable row level security;

drop policy if exists "Allow update inventory audit items" on public.inventory_audit_items;
create policy "Allow update inventory audit items"
on public.inventory_audit_items
for update
to authenticated, anon
using (true)
with check (true);
