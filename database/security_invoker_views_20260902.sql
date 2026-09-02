begin;

alter view public.shift_plan_employee_summary
  set (security_invoker = true);

alter view public.technical_job_material_availability_v29
  set (security_invoker = true);

alter view public.telemetry_possible_stock_losses
  set (security_invoker = true);

alter view public.purchase_product_recommendations_v13
  set (security_invoker = true);

do $$
declare
  v_unprotected integer;
begin
  select count(*) into v_unprotected
  from pg_class view_class
  join pg_namespace view_schema on view_schema.oid = view_class.relnamespace
  where view_class.relkind = 'v'
    and view_schema.nspname = 'public'
    and view_class.relname in (
      'shift_plan_employee_summary',
      'technical_job_material_availability_v29',
      'telemetry_possible_stock_losses',
      'purchase_product_recommendations_v13'
    )
    and not coalesce(view_class.reloptions, array[]::text[]) @> array['security_invoker=true'];

  if v_unprotected <> 0 then
    raise exception '% target views still do not use security_invoker.', v_unprotected;
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
