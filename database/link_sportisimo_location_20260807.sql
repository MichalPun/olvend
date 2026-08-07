begin;

update public.locations
set
  customer_id = contact.id,
  customer_name = contact.name
from public.business_contacts contact
where public.locations.id = 58
  and public.locations.customer_id is null
  and contact.company_id = '26194627'
  and lower(public.locations.customer_name) = 'sportisimo';

do $$
begin
  if not exists (
    select 1
    from public.locations location
    join public.business_contacts contact on contact.id = location.customer_id
    where location.id = 58
      and contact.company_id = '26194627'
  ) then
    raise exception 'Sportisimo location 58 was not linked to company 26194627.';
  end if;
end;
$$;

commit;
