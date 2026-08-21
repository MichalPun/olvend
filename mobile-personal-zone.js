import { supabase } from './supabase.js?v=20260815-offline-auth-refresh-v4'

const $ = selector => document.querySelector(selector)
const $$ = selector => [...document.querySelectorAll(selector)]
const money = value => `${new Intl.NumberFormat('cs-CZ', { maximumFractionDigits: 0 }).format(Number(value || 0))} Kč`
const monthLabel = date => new Intl.DateTimeFormat('cs-CZ', { month: 'long', year: 'numeric' }).format(date).replace(/^./, char => char.toUpperCase())
const dateLabel = value => new Intl.DateTimeFormat('cs-CZ', { weekday: 'short', day: 'numeric', month: 'numeric' }).format(new Date(value))
const timeLabel = value => new Intl.DateTimeFormat('cs-CZ', { hour: '2-digit', minute: '2-digit' }).format(new Date(value))
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]))
const state = { month: new Date(new Date().getFullYear(), new Date().getMonth(), 1), slots: [], selectedSlot: null, meetings: [] }

function periodKey(date) { return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-01` }
function dateKey(date) { return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}` }
function setText(id, value) { const el = document.getElementById(id); if (el) el.textContent = value }

async function loadBonus() {
  const { data, error } = await supabase.rpc('my_bonus_summary', { p_period: periodKey(state.month) })
  if (error) throw error
  const row = data || {}
  setText('bonusMonthLabel', monthLabel(state.month)); setText('bonusHeroPeriod', monthLabel(state.month))
  setText('bonusHeroTotal', money(row.total)); setText('bonusBefore', money(row.bonus_before_adjustments))
  setText('bonusDeductions', row.deductions ? `−${money(row.deductions)}` : '0 Kč')
  setText('bonusVisits', String(row.visits || 0)); setText('bonusMachines', String(row.machines || 0))
  setText('bonusFinalState', row.is_final ? 'Uzavřený měsíc' : 'Průběžný odhad')
  setText('bonusUpdated', `Stav k ${new Date(row.updated_at || Date.now()).toLocaleString('cs-CZ', { dateStyle: 'short', timeStyle: 'short' })}`)
  if (periodKey(state.month) === periodKey(new Date())) {
    setText('personalBonusAmount', money(row.total)); setText('personalBonusVisits', `${row.visits || 0} návštěv vyhodnoceno`)
  }
}

async function loadBonusHistory() {
  const start = new Date(2026, 7, 1); const end = new Date(new Date().getFullYear(), new Date().getMonth(), 1); const rows = []
  for (let d = new Date(end); d >= start; d.setMonth(d.getMonth() - 1)) {
    const period = new Date(d); const { data, error } = await supabase.rpc('my_bonus_summary', { p_period: periodKey(period) }); if (!error) rows.push({ period, ...data })
  }
  $('#bonusHistory').innerHTML = rows.map(row => `<div class="personal-history-row"><span><strong>${esc(monthLabel(row.period))}</strong><small>${row.is_final ? 'Uzavřeno' : 'Průběžný odhad'} · ${Number(row.visits || 0)} návštěv</small></span><b>${esc(money(row.total))}</b></div>`).join('') || '<div class="personal-history-row"><span><strong>Zatím bez historie</strong></span></div>'
}

function slotDayKey(value) { const d = new Date(value); return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}` }
function renderSlots() {
  const groups = new Map(); state.slots.forEach(slot => { const key = slotDayKey(slot.slot_start); if (!groups.has(key)) groups.set(key, []); groups.get(key).push(slot) })
  const selectedDay = state.selectedSlot ? slotDayKey(state.selectedSlot.slot_start) : groups.keys().next().value
  $('#meetingDays').innerHTML = [...groups.entries()].map(([key, rows]) => `<button class="meeting-day ${key === selectedDay ? 'active' : ''}" type="button" data-meeting-day="${key}"><strong>${esc(dateLabel(rows[0].slot_start))}</strong><span>${rows.length} termínů</span></button>`).join('') || '<div class="empty">V publikovaném plánu teď není volný termín.</div>'
  const rows = groups.get(selectedDay) || []
  $('#meetingSlots').innerHTML = rows.map(slot => `<button class="meeting-slot ${state.selectedSlot?.slot_start === slot.slot_start ? 'active' : ''}" type="button" data-slot-start="${slot.slot_start}">${esc(timeLabel(slot.slot_start))}</button>`).join('')
  $$('[data-meeting-day]').forEach(button => button.onclick = () => { const first = groups.get(button.dataset.meetingDay)?.[0] || null; state.selectedSlot = first; renderSlots() })
  $$('[data-slot-start]').forEach(button => button.onclick = () => { state.selectedSlot = state.slots.find(slot => slot.slot_start === button.dataset.slotStart); renderSlots() })
}

function renderInvitations() {
  const pending = state.meetings.filter(row => row.direction === 'manager_invitation' && row.status === 'pending')
  $('#meetingInvitations').innerHTML = pending.map(row => `<article class="meeting-invitation"><h3>Manažer tě zve na schůzku</h3><p><strong>${esc(dateLabel(row.starts_at))} · ${esc(timeLabel(row.starts_at))}</strong><br>${esc(row.message || 'Bez doplňující zprávy.')}</p><div class="meeting-actions"><button class="accept" data-meeting-response="approved" data-meeting-id="${row.id}">Potvrdit</button><button data-meeting-response="reschedule_requested" data-meeting-id="${row.id}">Jiný termín</button><button data-meeting-response="rejected" data-meeting-id="${row.id}">Odmítnout</button></div></article>`).join('')
  $$('[data-meeting-response]').forEach(button => button.onclick = async () => {
    button.disabled = true
    const { error } = await supabase.rpc('respond_to_my_meeting', { p_meeting_id: Number(button.dataset.meetingId), p_status: button.dataset.meetingResponse, p_note: null })
    if (error) { alert(error.message); button.disabled = false; return }
    await loadMeetings()
  })
}

async function loadMeetings() {
  const from = new Date(); const to = new Date(); to.setDate(to.getDate() + 21)
  const [slots, meetings] = await Promise.all([
    supabase.rpc('my_meeting_slots', { p_from: dateKey(from), p_to: dateKey(to) }),
    supabase.from('employee_meetings').select('*').gte('ends_at', new Date().toISOString()).order('starts_at')
  ])
  if (slots.error) throw slots.error; if (meetings.error) throw meetings.error
  state.slots = slots.data || []; state.meetings = meetings.data || []; if (!state.selectedSlot) state.selectedSlot = state.slots[0] || null
  renderSlots(); renderInvitations()
}

async function sendMeeting() {
  if (!state.selectedSlot) return alert('Nejdřív vyber volný termín.')
  const button = $('#sendMeetingRequest'); button.disabled = true; button.textContent = 'Odesílám…'
  const { error } = await supabase.rpc('request_my_meeting', { p_starts_at: state.selectedSlot.slot_start, p_ends_at: state.selectedSlot.slot_end, p_meeting_mode: $('#meetingMode').value, p_topic: $('#meetingTopic').value, p_message: $('#meetingMessage').value.trim() || null })
  button.disabled = false; button.textContent = 'Odeslat žádost o schůzku'
  if (error) return alert(error.message)
  $('#meetingMessage').value = ''; state.selectedSlot = null; await loadMeetings(); alert('Žádost o schůzku byla odeslána.')
}

async function init() {
  const now = new Date(); setText('personalPeriodLabel', monthLabel(now))
  const { count } = await supabase.from('payroll_payslips').select('id', { count: 'exact', head: true }); setText('personalDocumentCount', count ?? '0')
  await Promise.all([loadBonus(), loadBonusHistory(), loadMeetings()])
  $('#bonusMonthPrev').onclick = async () => { state.month.setMonth(state.month.getMonth() - 1); if (state.month < new Date(2026, 7, 1)) state.month = new Date(2026, 7, 1); await loadBonus() }
  $('#bonusMonthNext').onclick = async () => { const next = new Date(state.month); next.setMonth(next.getMonth() + 1); if (next <= new Date(new Date().getFullYear(), new Date().getMonth(), 1)) { state.month = next; await loadBonus() } }
  $('#sendMeetingRequest').onclick = sendMeeting
}

init().catch(error => { console.error('Osobní zóna:', error); setText('personalBonusAmount', 'Nelze načíst') })
