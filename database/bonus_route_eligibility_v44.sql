begin;

-- The monthly bonus belongs to everyone who actually completed replenishment
-- visits in the period, regardless of their employment role.
create or replace function public.manager_bonus_month(p_period date)
returns table(employee_id uuid, employee_name text, attributed_revenue numeric, bonus_before_adjustments numeric, deductions numeric, quality_bonus numeric, total numeric, visits bigint)
language sql stable security definer set search_path=public as $$
  with params as (
    select greatest(date '2026-08-01',date_trunc('month',p_period)::date) from_date,
      (date_trunc('month',p_period)+interval '1 month')::date to_date
  ), events as (
    select ev.* from public.telemetry_sales_events ev,params p
    where ev.source_event_at>=p.from_date::timestamp at time zone 'Europe/Prague'
      and ev.source_event_at<p.to_date::timestamp at time zone 'Europe/Prague'
      and not (lower(coalesce(ev.provider,''))='vendsoft' and exists(select 1 from public.telemetry_sales_events direct where direct.machine_id=ev.machine_id and lower(coalesce(direct.provider,''))='ima'))
  ), attributed as (
    select visit.employee_id,coalesce(ev.total_amount_czk,0)+case when coalesce(slot.settlement_billing_enabled,false) then coalesce(slot.settlement_amount_czk,0)*coalesce(ev.quantity,0) else 0 end revenue
    from events ev left join public.machine_planogram_slots slot on slot.id=ev.planogram_slot_id
    left join lateral (select v.employee_id from public.route_machine_visits v where v.machine_id=ev.machine_id and v.status='completed' and v.employee_id is not null and v.completed_at<=ev.source_event_at order by v.completed_at desc limit 1) visit on true
  ), revenue as (
    select employee_id,coalesce(sum(revenue),0) amount from attributed where employee_id is not null group by employee_id
  ), deduction as (
    select a.assigned_employee_id employee_id,coalesce(sum(abs(a.bonus_impact_amount)),0) amount from public.inventory_audits a,params p
    where a.responsibility_status='operator' and a.status='closed' and a.bonus_impact_amount is not null and coalesce(a.bonus_period,date_trunc('month',a.audit_date)::date)=p.from_date group by a.assigned_employee_id
  ), visit_counts as (
    select v.employee_id,count(*) count from public.route_machine_visits v,params p
    where v.status='completed' and v.completed_at>=p.from_date::timestamp at time zone 'Europe/Prague' and v.completed_at<p.to_date::timestamp at time zone 'Europe/Prague' group by v.employee_id
  ), settings as (
    select coalesce((select bonus_rate from public.payroll_settings where id=1),1) rate
  )
  select e.id,concat_ws(' ',e.name,e.surname),round(coalesce(r.amount,0),2),round(coalesce(r.amount,0)*s.rate/100,2),round(coalesce(d.amount,0),2),0::numeric,greatest(0,round(coalesce(r.amount,0)*s.rate/100-coalesce(d.amount,0),2)),v.count
  from public.employees e cross join settings s
  join visit_counts v on v.employee_id=e.id and v.count>0
  left join revenue r on r.employee_id=e.id
  left join deduction d on d.employee_id=e.id
  where e.active is not false and public.has_manager_access()
  order by e.surname,e.name
$$;

revoke all on function public.manager_bonus_month(date) from public;
grant execute on function public.manager_bonus_month(date) to authenticated;

comment on function public.manager_bonus_month(date) is
  'Monthly route bonus for each active employee with a completed replenishment visit in the period.';

commit;
