begin;

update public.locations
set latitude = 49.2163401,
    longitude = 16.6594338
where id = 75
  and name = 'NetDataComm, s.r.o.'
  and latitude is null
  and longitude is null;

commit;
