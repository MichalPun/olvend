-- Sjednotí obsah balení do základní jednotky produktu.
-- U produktů vedených v kg/l byly některé historické řádky uložené v g/ml,
-- zatímco novější řádky už správně používají kg/l.

begin;

create table if not exists public.product_package_unit_normalization_audit_v66 (
  package_id bigint primary key,
  product_id bigint not null,
  base_unit text not null,
  units_before numeric(12,3) not null,
  units_after numeric(12,3) not null,
  package_before jsonb not null,
  normalized_at timestamptz not null default now()
);

insert into public.product_package_unit_normalization_audit_v66 (
  package_id,
  product_id,
  base_unit,
  units_before,
  units_after,
  package_before
)
select
  package.id,
  package.product_id,
  lower(product.base_unit),
  package.units_per_package,
  round(package.units_per_package / 1000, 3),
  to_jsonb(package)
from public.product_packages package
join public.products product on product.id = package.product_id
where lower(product.base_unit) in ('kg', 'l')
  and package.units_per_package >= 100
on conflict (package_id) do nothing;

update public.product_packages package
set
  units_per_package = audit.units_after,
  updated_at = now()
from public.product_package_unit_normalization_audit_v66 audit
where package.id = audit.package_id
  and package.units_per_package = audit.units_before;

create or replace function public.enforce_product_package_base_unit_v66()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_base_unit text;
begin
  select lower(product.base_unit)
  into v_base_unit
  from public.products product
  where product.id = new.product_id;

  if v_base_unit in ('kg', 'l') and new.units_per_package >= 100 then
    raise exception
      'Obsah balení produktu vedeného v % musí být uložen přímo v této jednotce (např. 10 kg jako 10, ne 10000).',
      v_base_unit;
  end if;

  return new;
end
$$;

drop trigger if exists trg_product_package_base_unit_v66 on public.product_packages;
create trigger trg_product_package_base_unit_v66
before insert or update of product_id, units_per_package
on public.product_packages
for each row
execute function public.enforce_product_package_base_unit_v66();

commit;
