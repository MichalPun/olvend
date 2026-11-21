begin;

create or replace function public.get_finance_mailbox_status_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_account public.mail_accounts%rowtype;
  v_statuses jsonb;
  v_total bigint;
begin
  if not public.finance_can_manage_v1() then
    raise exception 'Přístup odepřen.' using errcode='42501';
  end if;

  select * into v_account
  from public.mail_accounts
  where account_purpose='finance_intake' and active
  order by updated_at desc
  limit 1;

  select
    coalesce(sum(document_count),0),
    coalesce(jsonb_object_agg(status,document_count),'{}'::jsonb)
  into v_total,v_statuses
  from (
    select status,count(*) as document_count
    from public.finance_document_intake_queue
    group by status
  ) q;

  return jsonb_build_object(
    'account',case when v_account.id is null then null else jsonb_build_object(
      'id',v_account.id,
      'email_address',v_account.email_address,
      'display_name',v_account.display_name,
      'username',v_account.username,
      'imap_host',v_account.imap_host,
      'imap_port',v_account.imap_port,
      'imap_secure',v_account.imap_secure,
      'sync_history_days',v_account.sync_history_days,
      'last_sync_at',v_account.last_sync_at,
      'last_error',v_account.last_error,
      'active',v_account.active,
      'updated_at',v_account.updated_at
    ) end,
    'stats',jsonb_build_object('total',coalesce(v_total,0),'statuses',coalesce(v_statuses,'{}'::jsonb)),
    'source','database_fallback'
  );
end;
$$;

revoke all on function public.get_finance_mailbox_status_v1() from public,anon;
grant execute on function public.get_finance_mailbox_status_v1() to authenticated;

comment on function public.get_finance_mailbox_status_v1() is
  'Bezpečný stav sdílené fakturační schránky bez šifrovaného hesla; slouží jako záloha při nedostupnosti poštovní služby.';

commit;
