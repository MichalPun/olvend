begin;

create or replace function public.is_my_route_skip_request_v40(p_operator_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.employees e
    where e.id = p_operator_employee_id
      and e.auth_user_id = auth.uid()
      and e.active is true
  );
$$;

revoke all on function public.is_my_route_skip_request_v40(uuid) from public, anon;
grant execute on function public.is_my_route_skip_request_v40(uuid) to authenticated;

drop policy if exists route_stop_skip_requests_operator_select_v40 on public.route_stop_skip_requests;
create policy route_stop_skip_requests_operator_select_v40
on public.route_stop_skip_requests
for select
to authenticated
using (public.is_my_route_skip_request_v40(operator_employee_id));

grant select on public.route_stop_skip_requests to authenticated;

comment on function public.is_my_route_skip_request_v40(uuid)
is 'Bezpečná RLS kontrola, že žádost o nejetí patří právě přihlášenému operátorovi.';

commit;
