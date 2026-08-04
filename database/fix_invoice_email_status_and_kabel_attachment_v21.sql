-- Kabelové Bubny: podklad je volitelný a neúspěšný pokus o odeslání
-- FV26-0176 je viditelný v trvalé historii dokladu.

begin;

do $$
begin
  if (select count(*) from public.partner_billing_profiles where location_id = 62) <> 1 then
    raise exception 'Partnerský profil Kabelové Bubny (location_id 62) nebyl nalezen jednoznačně.';
  end if;

  if (
    select count(*)
    from public.sales_documents
    where id = 52
      and note like '%[rada:FV26-0176]%'
  ) <> 1 then
    raise exception 'Doklad FV26-0176 nebyl nalezen na očekávaném záznamu id 52.';
  end if;
end
$$;

update public.partner_billing_profiles
set
  attachment_mode = 'optional',
  updated_at = now()
where location_id = 62;

with target as (
  select
    document.id,
    document.note,
    (regexp_match(document.note, '\[meta:([^\]]+)\]'))[1] as meta_token
  from public.sales_documents document
  where document.id = 52
    and document.note like '%[rada:FV26-0176]%'
), decoded as (
  select
    id,
    note,
    meta_token,
    convert_from(decode(regexp_replace(meta_token, '\s+', '', 'g'), 'base64'), 'UTF8')::jsonb as meta
  from target
), amended as (
  select
    id,
    note,
    meta_token,
    meta
      || jsonb_build_object(
        'partnerBilling',
        coalesce(meta -> 'partnerBilling', '{}'::jsonb)
          || jsonb_build_object('attachmentMode', 'optional'),
        'email',
        case
          when coalesce(meta -> 'email' ->> 'sentAt', '') <> ''
            or meta -> 'email' ->> 'status' = 'sent'
          then meta -> 'email'
          else jsonb_build_object(
            'status', 'failed',
            'attemptedAt', '2026-08-04T18:52:00.000Z',
            'failedAt', '2026-08-04T18:52:00.000Z',
            'to', 'info@kabelovebubny.cz',
            'error', 'Failed to send a request to the Edge Function',
            'partnerEvidenceIncluded', true,
            'attemptCount', 1
          )
        end
      ) as next_meta
  from decoded
)
update public.sales_documents document
set note = replace(
  amended.note,
  '[meta:' || amended.meta_token || ']',
  '[meta:' || encode(convert_to(amended.next_meta::text, 'UTF8'), 'base64') || ']'
)
from amended
where document.id = amended.id;

do $$
declare
  v_meta jsonb;
begin
  select convert_from(
    decode(
      regexp_replace((regexp_match(note, '\[meta:([^\]]+)\]'))[1], '\s+', '', 'g'),
      'base64'
    ),
    'UTF8'
  )::jsonb
  into v_meta
  from public.sales_documents
  where id = 52;

  if v_meta -> 'partnerBilling' ->> 'attachmentMode' <> 'optional' then
    raise exception 'FV26-0176 nemá volitelný podklad.';
  end if;

  if not (
    coalesce(v_meta -> 'email' ->> 'sentAt', '') <> ''
    or v_meta -> 'email' ->> 'status' = 'sent'
    or (
      v_meta -> 'email' ->> 'status' = 'failed'
      and v_meta -> 'email' ->> 'to' = 'info@kabelovebubny.cz'
    )
  ) then
    raise exception 'FV26-0176 nemá uložený stav pokusu o odeslání.';
  end if;
end
$$;

commit;

select
  profile.location_id,
  profile.attachment_mode,
  document.id as document_id,
  document.note like '%[rada:FV26-0176]%' as is_fv26_0176
from public.partner_billing_profiles profile
cross join public.sales_documents document
where profile.location_id = 62
  and document.id = 52;
