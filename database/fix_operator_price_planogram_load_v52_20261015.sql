-- OLVEND v52 hotfix: cenove schvalovani nesmi zablokovat nacteni planogramu.
-- V51 zalozila SELECT RLS policy, ale po REVOKE chybel tabulkovy grant pro
-- authenticated. PostgREST proto vracel permission denied.

do $$
begin
  if to_regclass('public.operator_price_change_requests') is not null then
    grant select on public.operator_price_change_requests to authenticated;
  end if;
end
$$;
