begin;
alter table public.machines
 add column if not exists subsidy_default_amount numeric(12,6) not null default 0 check (subsidy_default_amount between 0 and 99999),
 add column if not exists subsidy_default_basis text not null default 'net' check (subsidy_default_basis in ('net','gross')),
 add column if not exists subsidy_default_partner text,
 add column if not exists subsidy_default_enabled boolean not null default false;
-- Preserve every existing rule until the user explicitly adopts the machine default.
alter table public.machine_coffee_buttons add column if not exists subsidy_mode text not null default 'custom' check (subsidy_mode in ('inherit','custom','none'));
-- Legacy importers retain their explicitly supplied per-choice rules.
create or replace function public.apply_coffee_subsidy_default() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.machines%rowtype;
begin
 if new.subsidy_mode='inherit' then
  select * into strict m from public.machines where id=new.machine_id;
  new.settlement_type:='subsidy_receivable';
  new.settlement_amount_czk:=round(m.subsidy_default_amount / case when m.subsidy_default_basis='gross' then 1.21 else 1 end,6);
  new.settlement_partner:=m.subsidy_default_partner;
  new.settlement_billing_enabled:=m.subsidy_default_enabled and new.settlement_amount_czk>0;
 elsif new.subsidy_mode='none' then
  new.settlement_type:='none';
  new.settlement_billing_enabled:=false;
 end if;
 return new;
end $$;
create or replace function public.mirror_coffee_subsidy() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin
 update public.machine_planogram_slots set
 settlement_type=new.settlement_type,settlement_amount_czk=new.settlement_amount_czk,
 settlement_partner=new.settlement_partner,settlement_billing_enabled=new.settlement_billing_enabled,settlement_note=new.settlement_note,
 subsidy_amount_czk=case when new.settlement_type='subsidy_receivable' then new.settlement_amount_czk else 0 end,
 subsidy_payer=case when new.settlement_type='subsidy_receivable' then new.settlement_partner else null end,
 subsidy_billing_enabled=new.settlement_type='subsidy_receivable' and new.settlement_billing_enabled
 where machine_id=new.machine_id and slot_code=new.selection_code;
 return new;
end $$;
create or replace function public.refresh_machine_subsidy() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin
 update public.machine_coffee_buttons set subsidy_mode='inherit' where machine_id=new.id and subsidy_mode='inherit';
 return new;
end $$;
create trigger coffee_subsidy_default before insert or update on public.machine_coffee_buttons for each row execute function public.apply_coffee_subsidy_default();
create trigger coffee_subsidy_mirror after update of subsidy_mode,settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,settlement_note on public.machine_coffee_buttons for each row execute function public.mirror_coffee_subsidy();
create trigger machine_subsidy_refresh after update of subsidy_default_amount,subsidy_default_basis,subsidy_default_partner,subsidy_default_enabled on public.machines for each row execute function public.refresh_machine_subsidy();
create or replace function public.save_machine_subsidy(p_machine_id bigint,p_amount numeric,p_basis text,p_partner text,p_enabled boolean,p_apply_all boolean default false)
returns integer language plpgsql security invoker set search_path=pg_catalog,public as $$
declare n integer;
begin
 if not public.security_active_employee() then raise exception 'Vyžadován aktivní zaměstnanec.' using errcode='42501'; end if;
 if p_amount is null or p_amount::text='NaN' or p_amount<0 or p_amount>99999 or p_basis not in ('net','gross') or p_basis is null or p_enabled is null then raise exception 'Neplatné nastavení dotace.'; end if;
 if p_enabled and (p_amount<=0 or nullif(trim(p_partner),'') is null) then raise exception 'Vyplňte partnera a kladnou částku dotace.'; end if;
 -- Serialize default edits with selection edits and prevent partial mirror writes.
 perform 1 from public.machines where id=p_machine_id for update;
 if not found then raise exception 'Automat není dostupný.'; end if;
 if exists(select 1 from public.machine_coffee_buttons b where b.machine_id=p_machine_id and (b.subsidy_mode='inherit' or p_apply_all) and not exists(select 1 from public.machine_planogram_slots s where s.machine_id=b.machine_id and s.slot_code=b.selection_code)) then raise exception 'Chybí telemetrická pozice. Nastavení nebylo změněno.'; end if;
 update public.machines set subsidy_default_amount=p_amount,subsidy_default_basis=p_basis,subsidy_default_partner=nullif(trim(p_partner),''),subsidy_default_enabled=p_enabled where id=p_machine_id;
 if not found then raise exception 'Chybí oprávnění.'; end if;
 if p_apply_all then update public.machine_coffee_buttons set subsidy_mode='inherit' where machine_id=p_machine_id and active=true; end if;
 select count(*) into n from public.machine_coffee_buttons where machine_id=p_machine_id and active=true and subsidy_mode='inherit';
 return n;
end $$;
create or replace function public.set_coffee_subsidy_modes(p_machine_id bigint,p_selections text[],p_mode text,p_amount numeric default 0,p_partner text default null,p_enabled boolean default false)
returns integer language plpgsql security invoker set search_path=pg_catalog,public as $$
declare expected integer;n integer;
begin
 if not public.security_active_employee() then raise exception 'Vyžadován aktivní zaměstnanec.' using errcode='42501'; end if;
 if p_mode is null or p_mode not in ('inherit','custom','none') then raise exception 'Neplatný režim.'; end if;
 if p_mode='custom' and (p_amount is null or p_amount::text='NaN' or p_amount<0 or p_amount>99999 or p_enabled is null or (p_enabled and (p_amount=0 or nullif(trim(p_partner),'') is null))) then raise exception 'Vyplňte platnou dotaci a partnera.'; end if;
 select count(distinct x) into expected from unnest(p_selections) x;
 if expected=0 or expected<>cardinality(p_selections) then raise exception 'Neplatný výběr.'; end if;
 perform 1 from public.machines where id=p_machine_id for update;
 if not found then raise exception 'Automat není dostupný.'; end if;
 select count(*) into n from public.machine_planogram_slots where machine_id=p_machine_id and slot_code=any(p_selections);
 if n<>expected then raise exception 'Chybí telemetrická pozice.'; end if;
 update public.machine_coffee_buttons set subsidy_mode=p_mode,
 settlement_type=case when p_mode='custom' then 'subsidy_receivable' else settlement_type end,
 settlement_amount_czk=case when p_mode='custom' then p_amount else settlement_amount_czk end,
 settlement_partner=case when p_mode='custom' then nullif(trim(p_partner),'') else settlement_partner end,
 settlement_billing_enabled=case when p_mode='custom' then p_enabled else settlement_billing_enabled end
 where machine_id=p_machine_id and selection_code=any(p_selections) and active=true;
 get diagnostics n=row_count;
 if n<>expected then raise exception 'Výběr se změnil. Nebyla změněna žádná volba.'; end if;
 return n;
end $$;
revoke all on function public.apply_coffee_subsidy_default(),public.mirror_coffee_subsidy(),public.refresh_machine_subsidy() from public,anon;
revoke all on function public.save_machine_subsidy(bigint,numeric,text,text,boolean,boolean),public.set_coffee_subsidy_modes(bigint,text[],text,numeric,text,boolean) from public,anon;
grant execute on function public.save_machine_subsidy(bigint,numeric,text,text,boolean,boolean),public.set_coffee_subsidy_modes(bigint,text[],text,numeric,text,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
