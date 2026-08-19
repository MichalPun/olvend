-- Keep one-off telemetry repair backups out of the public PostgREST surface.
-- The tables remain available to postgres/service-role maintenance workflows.
begin;

do $security$
declare
  table_name text;
  backup_tables constant text[] := array[
    'telemetry_all_stock_shortfall_backup_v26_20260806',
    'telemetry_coffee_container_backup_20260803',
    'telemetry_coffee_container_backup_20260804',
    'telemetry_coffee_container_backup_20260805',
    'telemetry_coffee_container_backup_20260806',
    'telemetry_sales_payment_backup_20260804',
    'telemetry_sales_payment_backup_v25_20260803',
    'telemetry_sales_payment_backup_v25_20260804',
    'telemetry_sales_payment_backup_v25_20260805',
    'telemetry_sales_payment_backup_v25_20260806',
    'telemetry_sales_payment_backup_vitar_20260804',
    'telemetry_state_credit_backup_v26_20260806',
    'telemetry_stock_balance_backup_20260803',
    'telemetry_stock_balance_backup_20260804',
    'telemetry_stock_balance_backup_20260805',
    'telemetry_stock_balance_backup_20260806',
    'telemetry_stock_reconstruction_backup_v25_20260805',
    'telemetry_stock_reconstruction_backup_v25_20260805_aug3',
    'telemetry_stock_reconstruction_backup_v25_20260806'
  ];
begin
  foreach table_name in array backup_tables loop
    if to_regclass(format('public.%I', table_name)) is null then
      raise exception 'Expected backup table public.% is missing', table_name;
    end if;

    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all privileges on table public.%I from public, anon, authenticated', table_name);
  end loop;
end
$security$;

commit;
