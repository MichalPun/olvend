import { supabase } from './supabase.js'

const $ = (selector, root = document) => root.querySelector(selector)
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)]
const csDate = new Intl.DateTimeFormat('cs-CZ', { weekday: 'short', day: 'numeric', month: 'numeric' })
const csTime = new Intl.DateTimeFormat('cs-CZ', { hour: '2-digit', minute: '2-digit' })
const state = { weekStart: startOfWeek(new Date()), employees: [], settings: null, shifts: [], routes: [], blocks: [], meetings: [] }
const topicLabels = { work: 'Práce a směny', pay_bonus: 'Mzda a prémie', operations: 'Provozní problém', evaluation: 'Vyhodnocení práce', personal: 'Osobní záležitost', other: 'Jiné' }
const modeLabels = { in_person: 'Osobně · Blučina', phone: 'Telefonicky', video: 'Videohovor' }

function startOfWeek(date) { const d = new Date(date); const day = (d.getDay() + 6) % 7; d.setDate(d.getDate() - day); d.setHours(0, 0, 0, 0); return d }
function key(date) { return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}` }
function esc(value) { return String(value ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch])) }
function employeeName(id) { const row = state.employees.find(item => item.id === id); return row ? [row.name, row.surname].filter(Boolean).join(' ') : 'Zaměstnanec' }
function initials(id) { return employeeName(id).split(/\s+/).map(v => v[0]).slice(0, 2).join('').toUpperCase() }
function isoAt(date, time) { return new Date(`${date}T${time}:00`).toISOString() }
function durationEnd(start, minutes) { return new Date(new Date(start).getTime() + minutes * 60000).toISOString() }
function overlaps(aStart, aEnd, bStart, bEnd) { return new Date(aStart) < new Date(bEnd) && new Date(aEnd) > new Date(bStart) }

async function requireManager() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) { location.href = 'index.html'; throw new Error('Nepřihlášený uživatel') }
  const { data: employee, error } = await supabase.from('employees').select('id,role').eq('auth_user_id', user.id).maybeSingle()
  if (error) throw error
  if (!['admin', 'manager'].includes(String(employee?.role || '').toLowerCase())) { location.href = 'mobile.html'; throw new Error('Bez oprávnění') }
}

async function load() {
  await requireManager()
  const from = key(state.weekStart); const toDate = new Date(state.weekStart); toDate.setDate(toDate.getDate() + 4); const to = key(toDate)
  const [employees, settings, shifts, routes, blocks, meetings] = await Promise.all([
    supabase.from('employees').select('id,name,surname,role,active').eq('active', true).order('surname'),
    supabase.from('meeting_calendar_settings').select('*').eq('id', 1).single(),
    supabase.from('shift_plan_days').select('*').gte('plan_date', from).lte('plan_date', to).eq('status', 'published'),
    supabase.from('route_plans').select('id,planning_date,planned_employee_id,planned_departure_time,estimated_drive_minutes,estimated_service_minutes,execution_status').gte('planning_date', from).lte('planning_date', to),
    supabase.from('manager_calendar_blocks').select('*').lt('starts_at', new Date(`${to}T23:59:59`).toISOString()).gt('ends_at', new Date(`${from}T00:00:00`).toISOString()),
    supabase.from('employee_meetings').select('*').lt('starts_at', new Date(`${to}T23:59:59`).toISOString()).gt('ends_at', new Date(`${from}T00:00:00`).toISOString()).neq('status', 'cancelled').order('starts_at')
  ])
  for (const result of [employees, settings, shifts, routes, blocks, meetings]) if (result.error) throw result.error
  state.employees = employees.data || []; state.settings = settings.data; state.shifts = shifts.data || []; state.routes = routes.data || []; state.blocks = blocks.data || []; state.meetings = meetings.data || []
  render()
}

function managerShift(dateKey) { return state.shifts.find(row => row.employee_id === state.settings?.manager_employee_id && row.plan_date === dateKey) }
function shiftLabel(shift) { if (!shift) return ['Bez plánu', 'off']; if (shift.shift_type === 'manager_office') return ['Office', '']; if (['vacation', 'day_off', 'holiday'].includes(shift.shift_type)) return ['Volno', 'off']; return ['Trasa', 'route'] }
function eventGrid(start, end) {
  const d = new Date(start); const localDay = new Date(d.getFullYear(), d.getMonth(), d.getDate()); const day = Math.round((localDay - state.weekStart) / 86400000) + 1
  const startHours = d.getHours() + d.getMinutes() / 60; const hours = Math.max(.5, (new Date(end) - d) / 3600000)
  return { day, row: Math.max(1, startHours - 7), length: hours }
}

function renderCalendar() {
  const calendar = $('#calendar'); if (!calendar) return
  const days = Array.from({ length: 5 }, (_, i) => { const d = new Date(state.weekStart); d.setDate(d.getDate() + i); const shift = managerShift(key(d)); const [label, cls] = shiftLabel(shift); return { d, label, cls } })
  calendar.innerHTML = '<div class="corner"></div>' + days.map(day => `<div class="day-head ${key(day.d) === key(new Date()) ? 'today' : ''}"><strong>${esc(csDate.format(day.d).split(' ')[0])}</strong><span>${esc(day.d.toLocaleDateString('cs-CZ'))}</span><span class="shift-chip ${day.cls}">${day.label}</span></div>`).join('') + Array.from({ length: 11 }, (_, h) => `<div class="time">${String(h + 7).padStart(2, '0')}:00</div>${days.map(() => '<div class="cell"></div>').join('')}`).join('')
  const events = []
  state.blocks.forEach(row => events.push({ start: row.starts_at, end: row.ends_at, cls: 'busy', title: row.note || 'Obsazeno', note: `${csTime.format(new Date(row.starts_at))}–${csTime.format(new Date(row.ends_at))}` }))
  state.routes.filter(row => row.planned_employee_id === state.settings?.manager_employee_id && row.execution_status !== 'cancelled').forEach(row => { const start = isoAt(row.planning_date, String(row.planned_departure_time).slice(0, 5)); events.push({ start, end: durationEnd(start, Number(row.estimated_drive_minutes || 0) + Number(row.estimated_service_minutes || 0)), cls: 'busy', title: 'Trasa / výjezd', note: 'Blokováno plánem trasy' }) })
  state.meetings.forEach(row => events.push({ start: row.starts_at, end: row.ends_at, cls: row.status === 'approved' ? 'meeting' : 'request', title: employeeName(row.employee_id), note: `${csTime.format(new Date(row.starts_at))} · ${row.status === 'approved' ? 'potvrzeno' : 'čeká'}`, meeting: row }))
  days.forEach(day => { const shift = managerShift(key(day.d)); if (!shift || shift.shift_type !== 'manager_office') return; const start = isoAt(shift.plan_date, String(shift.planned_start || '08:00').slice(0, 5)); const end = isoAt(shift.plan_date, String(shift.planned_end || '16:00').slice(0, 5)); for (let at = new Date(start); at < new Date(end); at = new Date(at.getTime() + (state.settings.slot_minutes + state.settings.buffer_minutes) * 60000)) { const slotEnd = new Date(at.getTime() + state.settings.slot_minutes * 60000); if (slotEnd > new Date(end) || slotEnd < new Date()) continue; if (events.some(e => overlaps(at, slotEnd, e.start, e.end))) continue; events.push({ start: at.toISOString(), end: slotEnd.toISOString(), cls: 'free', title: 'Volný termín', note: csTime.format(at) }) } })
  events.forEach(event => { const pos = eventGrid(event.start, event.end); if (pos.day < 1 || pos.day > 5) return; const el = document.createElement('div'); el.className = `event ${event.cls}`; el.style.gridColumn = String(pos.day + 1); el.style.gridRow = `${Math.floor(pos.row) + 2} / span ${Math.max(1, Math.ceil(pos.length))}`; el.innerHTML = `<strong>${esc(event.title)}</strong><span>${esc(event.note)}</span>`; if (event.meeting) { el.dataset.meetingId = event.meeting.id; el.onclick = () => openMeeting(event.meeting) } calendar.appendChild(el) })
  const end = days[4].d; $('.week-switch strong').textContent = `${state.weekStart.toLocaleDateString('cs-CZ')}–${end.toLocaleDateString('cs-CZ')}`
}

function renderRequests() {
  const incoming = state.meetings.filter(row => row.direction === 'employee_request'); const outgoing = state.meetings.filter(row => row.direction === 'manager_invitation')
  const rows = list => list.map(row => `<button class="request-row ${row.status === 'pending' ? 'active' : ''}" data-meeting-id="${row.id}"><span class="request-row-top"><h3>${esc(employeeName(row.employee_id))}</h3><time>${esc(csDate.format(new Date(row.starts_at)))} ${esc(csTime.format(new Date(row.starts_at)))}</time></span><p>${esc(row.message || 'Bez zprávy')}</p><small>${esc(topicLabels[row.topic] || 'Jiné')} · ${esc(modeLabels[row.meeting_mode] || '')} · ${row.status === 'pending' ? 'čeká' : row.status === 'approved' ? 'potvrzeno' : 'uzavřeno'}</small></button>`).join('') || '<div class="requests-foot">Žádné žádosti.</div>'
  $('#incomingRequests').innerHTML = rows(incoming); $('#outgoingRequests').innerHTML = rows(outgoing)
  $$('.request-row[data-meeting-id]').forEach(button => button.onclick = () => openMeeting(state.meetings.find(row => String(row.id) === button.dataset.meetingId)))
  $('.requests-head .count').textContent = `${state.meetings.filter(row => row.status === 'pending').length} nové`
}

function renderSummary() {
  const pending = state.meetings.filter(row => row.status === 'pending').length; const approved = state.meetings.filter(row => row.status === 'approved').length
  const free = $$('.event.free').length; const next = state.meetings.filter(row => row.status === 'approved' && new Date(row.starts_at) > new Date()).sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at))[0]
  const values = [pending, approved, free, next ? `${csDate.format(new Date(next.starts_at))} ${csTime.format(new Date(next.starts_at))}` : '—', `${Math.min(100, Math.round((state.blocks.length + approved) / Math.max(1, free + state.blocks.length + approved) * 100))} %`]
  $$('.summary strong').forEach((el, index) => { el.textContent = values[index] })
}
function renderSettings() {
  const selects = $$('#availabilityModal select')
  if (selects[0]) selects[0].value = `${state.settings.slot_minutes} minut`
  if (selects[1]) selects[1].value = state.settings.buffer_minutes ? `${state.settings.buffer_minutes} minut` : 'Bez rezervy'
}
function render() { renderCalendar(); renderRequests(); renderSummary(); populateEmployees(); renderSettings() }

function openMeeting(row) {
  const drawer = $('#requestDrawer'); drawer.hidden = false; drawer.dataset.meetingId = row.id
  $('.drawer-head h2').textContent = row.direction === 'employee_request' ? 'Žádost o schůzku' : 'Pozvánka na schůzku'
  $('.person .avatar').textContent = initials(row.employee_id); $('.person h3').textContent = employeeName(row.employee_id)
  const values = $$('.detail-row strong', drawer); values[0].textContent = `${csDate.format(new Date(row.starts_at))} · ${csTime.format(new Date(row.starts_at))}–${csTime.format(new Date(row.ends_at))}`; values[1].textContent = modeLabels[row.meeting_mode]; values[2].textContent = topicLabels[row.topic]; values[3].textContent = new Date(row.created_at).toLocaleString('cs-CZ')
  $('.message', drawer).textContent = row.message ? `„${row.message}“` : 'Bez zprávy.'
  $('#approveRequest').disabled = row.status !== 'pending'; $('#approveRequest').textContent = row.status === 'approved' ? 'Potvrzeno' : 'Potvrdit schůzku'
}
async function decide(status) { const id = Number($('#requestDrawer').dataset.meetingId); const note = $('.drawer-body textarea')?.value.trim() || null; const { error } = await supabase.from('employee_meetings').update({ status, response_note: note, responded_at: new Date().toISOString(), responded_by_employee_id: (await supabase.rpc('current_employee_id')).data }).eq('id', id); if (error) return alert(error.message); $('#requestDrawer').hidden = true; await load() }

function populateEmployees() { const select = $('#invitationEmployee'); if (select) select.innerHTML = state.employees.filter(row => row.id !== state.settings?.manager_employee_id).map(row => `<option value="${row.id}">${esc(employeeName(row.id))}</option>`).join('') }
function modalFields(id) { const root = $(id); return { root, selects: $$('select', root), dates: $$('input[type=date]', root), times: $$('input[type=time]', root), texts: $$('input[type=text]', root), textarea: $('textarea', root) } }
async function sendInvitation() { const f = modalFields('#invitationModal'); const employeeId = f.selects[0].value; const date = f.dates[0].value; const time = f.times[0].value; const minutes = Number(f.selects[1].value.match(/\d+/)?.[0] || 30); const start = isoAt(date, time); const current = (await supabase.rpc('current_employee_id')).data; const { error } = await supabase.from('employee_meetings').insert({ employee_id: employeeId, manager_employee_id: state.settings.manager_employee_id, direction: 'manager_invitation', starts_at: start, ends_at: durationEnd(start, minutes), meeting_mode: 'in_person', topic: ['work','pay_bonus','operations','evaluation','other'][f.selects[2].selectedIndex] || 'other', message: f.textarea.value.trim() || null, created_by_employee_id: current }); if (error) return alert(error.message); f.root.hidden = true; await load() }
async function saveBlock() { const f = modalFields('#busyBlockModal'); const start = isoAt(f.dates[0].value, f.times[0].value); const end = isoAt(f.dates[0].value, f.times[1].value); const current = (await supabase.rpc('current_employee_id')).data; const type = ['external_meeting','travel','doctor','focus','private','other'][f.selects[0].selectedIndex] || 'other'; const { error } = await supabase.from('manager_calendar_blocks').insert({ manager_employee_id: current, starts_at: start, ends_at: end, block_type: type, note: f.texts[0]?.value.trim() || null, private: $('input[type=checkbox]', f.root)?.checked !== false }); if (error) return alert(error.message); f.root.hidden = true; await load() }
async function saveAvailability() {
  const root = $('#availabilityModal'); const selects = $$('select', root)
  const payload = { id: 1, manager_employee_id: state.settings.manager_employee_id, slot_minutes: Number(selects[0].value.match(/\d+/)?.[0] || 30), buffer_minutes: Number(selects[1].value.match(/\d+/)?.[0] || 15), updated_at: new Date().toISOString() }
  const { error } = await supabase.from('meeting_calendar_settings').upsert(payload)
  if (error) return alert(error.message)
  root.hidden = true; await load()
}

function openModal(id) { $(id).hidden = false }
function closeModal(id) { $(id).hidden = true }
function bindModal(openers, id, closers) {
  openers.forEach(selector => { const button = $(selector); if (button) button.onclick = () => openModal(id) })
  closers.forEach(selector => { const button = $(selector); if (button) button.onclick = () => closeModal(id) })
}

$('#approveRequest').onclick = () => decide('approved'); $('.drawer-actions .btn:not(#offerAnother)').onclick = () => decide('rejected'); $('#offerAnother').onclick = () => decide('reschedule_requested')
$('#closeDrawer').onclick = () => closeModal('#requestDrawer'); $('#drawerBackdrop').onclick = () => closeModal('#requestDrawer')
bindModal(['#openAvailability', '#openAvailabilityFromInfo'], '#availabilityModal', ['#closeAvailability', '#cancelAvailability'])
bindModal(['#openInvitation'], '#invitationModal', ['#closeInvitation', '#cancelInvitation'])
bindModal(['#openBusyBlock'], '#busyBlockModal', ['#closeBusyBlock', '#cancelBusyBlock'])
$('#saveAvailability').onclick = saveAvailability; $('#sendInvitation').onclick = sendInvitation; $('#saveBusyBlock').onclick = saveBlock
$$('[data-request-view]').forEach(button => button.onclick = () => { $$('[data-request-view]').forEach(item => item.classList.toggle('active', item === button)); const outgoing = button.dataset.requestView === 'outgoing'; $('#incomingRequests').hidden = outgoing; $('#outgoingRequests').hidden = !outgoing })
const weekButtons = $$('.week-switch button'); weekButtons[0].onclick = () => { state.weekStart.setDate(state.weekStart.getDate() - 7); load() }; weekButtons[1].onclick = () => { state.weekStart = startOfWeek(new Date()); load() }; weekButtons[2].onclick = () => { state.weekStart.setDate(state.weekStart.getDate() + 7); load() }
load().catch(error => { console.error(error); alert(`Kalendář se nepodařilo načíst: ${error.message}`) })
