begin;
-- Invoker rights retain the existing RLS boundaries; both representations change atomically.
create or replace function public.set_coffee_selection_prices(p_machine_id bigint, p_selections text[], p_price numeric)
returns integer language plpgsql security invoker set search_path=pg_catalog,public as $$
declare expected integer; changed integer;
begin
 if not public.security_active_employee() then raise exception 'Vyžadován aktivní zaměstnanec.' using errcode='42501'; end if;
 if p_price is null or p_price < 0 or p_price > 99999 or p_price <> round(p_price,2) or p_price::text in ('NaN','Infinity','-Infinity') then raise exception 'Neplatná cena.'; end if;
 select count(distinct x) into expected from unnest(p_selections) x;
 if expected = 0 or expected <> cardinality(p_selections) then raise exception 'Neplatný výběr.'; end if;
 perform 1 from public.machine_coffee_buttons where machine_id=p_machine_id and selection_code=any(p_selections) and active is true for update;
 update public.machine_coffee_buttons set sale_price_czk=p_price,customer_price_czk=p_price
 where machine_id=p_machine_id and selection_code=any(p_selections) and active is true;
 get diagnostics changed=row_count;
 if changed <> expected then raise exception 'Výběr se změnil nebo chybí oprávnění. Obnovte detail automatu.'; end if;
 update public.machine_planogram_slots set price_czk=p_price,customer_price_czk=p_price
 where machine_id=p_machine_id and slot_code=any(p_selections) and active is true;
 get diagnostics changed=row_count;
 if changed <> expected then raise exception 'Chybí odpovídající telemetrické pozice. Nebyla změněna žádná cena.'; end if;
 return changed;
end $$;
revoke all on function public.set_coffee_selection_prices(bigint,text[],numeric) from public,anon;
grant execute on function public.set_coffee_selection_prices(bigint,text[],numeric) to authenticated;
notify pgrst,'reload schema';
commit;
