drop policy if exists "Allow delete route plan stops"
on public.route_plan_stops;

create policy "Allow delete route plan stops"
on public.route_plan_stops
for delete
to authenticated, anon
using (true);
