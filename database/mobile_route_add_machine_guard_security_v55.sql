-- OLVEND v55 hotfix: převzetí/uzavření trasy nesmí spadnout na oprávnění
-- k interní tabulce žádostí. Trigger běží se stejným bezpečnostním modelem
-- jako ostatní schvalovací funkce a tabulka zůstává klientům nedostupná.

create or replace function public.guard_route_plan_pending_add_v52()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and current_user not in ('postgres','supabase_admin')
     and exists(
       select 1
       from public.route_add_machine_requests r
       where r.route_plan_id = new.id
         and r.status = 'pending'
     )
     and (
       new.execution_status is distinct from old.execution_status
       or new.completed_at is distinct from old.completed_at
     ) then
    raise exception 'Trasu nelze uzavřít, dokud čeká žádost o přidání automatu.';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_route_plan_pending_add_v52() from public, anon, authenticated;

comment on function public.guard_route_plan_pending_add_v52() is
  'Bezpečně kontroluje čekající přidání automatu bez zpřístupnění interní tabulky mobilnímu klientovi.';
