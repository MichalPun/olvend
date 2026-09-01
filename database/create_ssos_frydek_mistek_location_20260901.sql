begin;

select pg_advisory_xact_lock(hashtext('create_ssos_frydek_mistek_location_20260901'));

insert into public.business_contacts (
  contact_type,
  name,
  name_norm,
  company_id,
  contact_name,
  email,
  phone,
  billing_address,
  delivery_address,
  note,
  active,
  source
)
values (
  'customer',
  'Soukromá střední odborná škola Frýdek-Místek, s.r.o.',
  public.olvend_contact_norm('Soukromá střední odborná škola Frýdek-Místek, s.r.o.'),
  '25383442',
  'Jan Křepel',
  'jan.krepel@ssosfm.cz',
  '+420 734 261 321',
  'tř. T. G. Masaryka 456, 738 01 Frýdek-Místek',
  'tř. T. G. Masaryka 456, 738 01 Frýdek-Místek',
  'Provozní kontakt: Jan Křepel, školník.',
  true,
  'manual_ssosfm_20260901'
)
on conflict (contact_type, name_norm)
do update set
  company_id = excluded.company_id,
  contact_name = excluded.contact_name,
  email = excluded.email,
  phone = excluded.phone,
  billing_address = excluded.billing_address,
  delivery_address = excluded.delivery_address,
  note = excluded.note,
  active = true,
  source = excluded.source;

do $$
declare
  v_customer_id bigint;
  v_location_id bigint;
begin
  select id
  into strict v_customer_id
  from public.business_contacts
  where contact_type = 'customer'
    and name_norm = public.olvend_contact_norm('Soukromá střední odborná škola Frýdek-Místek, s.r.o.');

  select id
  into v_location_id
  from public.locations
  where public.olvend_contact_norm(coalesce(name, '')) = public.olvend_contact_norm('Soukromá střední odborná škola Frýdek-Místek')
     or public.olvend_contact_norm(coalesce(address, '')) = public.olvend_contact_norm('tř. T. G. Masaryka 456, 738 01 Frýdek-Místek')
     or lower(coalesce(contact_email, '')) = 'jan.krepel@ssosfm.cz'
  order by id
  limit 1;

  if v_location_id is null then
    insert into public.locations (
      name,
      city,
      address,
      customer_name,
      customer_id,
      contact_person,
      contact_phone,
      contact_email,
      service_window,
      route_note,
      service_plan_note,
      latitude,
      longitude,
      route_access_hours,
      route_access_status,
      route_access_source,
      route_access_verified_at,
      active
    ) values (
      'Soukromá střední odborná škola Frýdek-Místek',
      'Frýdek-Místek',
      'tř. T. G. Masaryka 456, 738 01 Frýdek-Místek',
      'Soukromá střední odborná škola Frýdek-Místek, s.r.o.',
      v_customer_id,
      'Jan Křepel',
      '+420 734 261 321',
      'jan.krepel@ssosfm.cz',
      'po–pá 7:30–14:00',
      'Soukromá střední odborná škola. Kontaktní osoba Jan Křepel (školník).',
      'Nová lokalita bez přiřazeného automatu. Školní provoz; v červenci a srpnu nenabízet do automatického plánování bez ručního potvrzení.',
      49.684211689519245,
      18.354665486806525,
      '{"mo":[["07:30","14:00"]],"tu":[["07:30","14:00"]],"we":[["07:30","14:00"]],"th":[["07:30","14:00"]],"fr":[["07:30","14:00"]]}'::jsonb,
      'confirmed',
      'https://www.ssosfm.cz/kontaktni-informace/',
      now(),
      true
    )
    returning id into v_location_id;
  else
    update public.locations
    set
      name = 'Soukromá střední odborná škola Frýdek-Místek',
      city = 'Frýdek-Místek',
      address = 'tř. T. G. Masaryka 456, 738 01 Frýdek-Místek',
      customer_name = 'Soukromá střední odborná škola Frýdek-Místek, s.r.o.',
      customer_id = v_customer_id,
      contact_person = 'Jan Křepel',
      contact_phone = '+420 734 261 321',
      contact_email = 'jan.krepel@ssosfm.cz',
      service_window = 'po–pá 7:30–14:00',
      route_note = 'Soukromá střední odborná škola. Kontaktní osoba Jan Křepel (školník).',
      service_plan_note = 'Nová lokalita bez přiřazeného automatu. Školní provoz; v červenci a srpnu nenabízet do automatického plánování bez ručního potvrzení.',
      latitude = 49.684211689519245,
      longitude = 18.354665486806525,
      route_access_hours = '{"mo":[["07:30","14:00"]],"tu":[["07:30","14:00"]],"we":[["07:30","14:00"]],"th":[["07:30","14:00"]],"fr":[["07:30","14:00"]]}'::jsonb,
      route_access_status = 'confirmed',
      route_access_source = 'https://www.ssosfm.cz/kontaktni-informace/',
      route_access_verified_at = now(),
      active = true
    where id = v_location_id;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from public.locations location
    join public.business_contacts customer on customer.id = location.customer_id
    where location.name = 'Soukromá střední odborná škola Frýdek-Místek'
      and location.active
      and customer.company_id = '25383442'
      and lower(location.contact_email) = 'jan.krepel@ssosfm.cz'
  ) then
    raise exception 'Lokalita SSOŠ Frýdek-Místek nebyla správně založena a propojena.';
  end if;
end
$$;

select jsonb_build_object(
  'location_id', location.id,
  'name', location.name,
  'address', location.address,
  'customer_id', customer.id,
  'company_id', customer.company_id,
  'contact', location.contact_person,
  'phone', location.contact_phone,
  'email', location.contact_email,
  'service_window', location.service_window,
  'latitude', location.latitude,
  'longitude', location.longitude
) as result
from public.locations location
join public.business_contacts customer on customer.id = location.customer_id
where location.name = 'Soukromá střední odborná škola Frýdek-Místek';

commit;
