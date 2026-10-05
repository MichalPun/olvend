begin;

create or replace function public.apply_ima_a5_payment_method(
  p_event_key text,
  p_payment_method text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_key text := trim(coalesce(p_event_key, ''));
  v_payment text := lower(trim(coalesce(p_payment_method, '')));
  v_is_card boolean;
begin
  if v_event_key = '' or v_payment not in ('cash', 'card') then
    return false;
  end if;

  v_is_card := v_payment = 'card';

  update public.ima_a5_sales_imports
  set payment_method = v_payment,
      updated_at = now()
  where event_key = v_event_key
    and status = 'applied';

  update public.telemetry_sales_events
  set cash_quantity = case when v_is_card then 0 else quantity end,
      cashless_quantity = case when v_is_card then quantity else 0 end,
      unknown_payment_quantity = 0,
      cash_amount_czk = case when v_is_card then null else total_amount_czk end,
      cashless_amount_czk = case when v_is_card then total_amount_czk else null end,
      unknown_payment_amount_czk = null
  where provider = 'IMA-A5'
    and source_event_key = v_event_key;

  return found;
end;
$$;

revoke all on function public.apply_ima_a5_payment_method(text, text) from public;
revoke all on function public.apply_ima_a5_payment_method(text, text) from anon;
revoke all on function public.apply_ima_a5_payment_method(text, text) from authenticated;
grant execute on function public.apply_ima_a5_payment_method(text, text) to service_role;

commit;
