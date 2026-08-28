import { supabase } from './supabase.js?v=20260815-offline-auth-refresh-v4'

const $ = selector => document.querySelector(selector)
const $$ = selector => [...document.querySelectorAll(selector)]
const money = value => `${new Intl.NumberFormat('cs-CZ', { maximumFractionDigits: 0 }).format(Number(value || 0))} Kč`
const monthLabel = date => new Intl.DateTimeFormat('cs-CZ', { month: 'long', year: 'numeric' }).format(date).replace(/^./, char => char.toUpperCase())
const dateLabel = value => new Intl.DateTimeFormat('cs-CZ', { weekday: 'short', day: 'numeric', month: 'numeric' }).format(new Date(value))
const timeLabel = value => new Intl.DateTimeFormat('cs-CZ', { hour: '2-digit', minute: '2-digit' }).format(new Date(value))
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]))
const state = { month: new Date(new Date().getFullYear(), new Date().getMonth(), 1), slots: [], selectedSlot: null, meetings: [], territoryRows: [], territoryMap: null, territoryLayers: [] }

function periodKey(date) { return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-01` }
function dateKey(date) { return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}` }
function setText(id, value) { const el = document.getElementById(id); if (el) el.textContent = value }

function mapPoint(location) {
  const lat = Number(location?.latitude), lng = Number(location?.longitude)
  return Number.isFinite(lat) && Number.isFinite(lng) && lat >= 48.3 && lat <= 51.2 && lng >= 11.8 && lng <= 19.2 ? [lat, lng] : null
}

function convexHull(points) {
  const unique = [...new Map(points.map(([lat, lng]) => [`${lat}:${lng}`, [lng, lat]])).values()].sort((a, b) => a[0] - b[0] || a[1] - b[1])
  if (unique.length <= 2) return unique.map(([lng, lat]) => [lat, lng])
  const cross = (origin, a, b) => (a[0] - origin[0]) * (b[1] - origin[1]) - (a[1] - origin[1]) * (b[0] - origin[0])
  const half = rows => rows.reduce((hull, point) => {
    while (hull.length >= 2 && cross(hull.at(-2), hull.at(-1), point) <= 0) hull.pop()
    hull.push(point)
    return hull
  }, [])
  return half(unique).slice(0, -1).concat(half([...unique].reverse()).slice(0, -1)).map(([lng, lat]) => [lat, lng])
}

function expandedHull(points, factor = 1.1) {
  const center = points.reduce((sum, point) => [sum[0] + point[0], sum[1] + point[1]], [0, 0]).map(value => value / points.length)
  return points.map(([lat, lng]) => [center[0] + (lat - center[0]) * factor, center[1] + (lng - center[1]) * factor])
}

function territoryLabel(rows) {
  const cities = [...new Set(rows.filter(row => row.role === 'primary').map(row => row.location.city).filter(Boolean))]
  if (!cities.length) return 'Moje oblast'
  if (cities.some(city => /Ostrava|Bohumín|Bruntál/i.test(city))) return 'Moravskoslezský kraj'
  if (cities.some(city => /Břeclav|Hodonín|Dubňany|Pohořelice|Milovice/i.test(city))) return 'Jižní oblast'
  if (cities.some(city => /Brno|Tišnov|Jihlava|Meziříčí/i.test(city))) return 'Brno, Tišnov a Vysočina'
  return cities.slice(0, 3).join(', ')
}

function renderTerritoryMap() {
  const container = document.getElementById('mobileTerritoryMap')
  if (!container || typeof window.L === 'undefined') return
  const rows = state.territoryRows.filter(row => row.role === 'primary' && mapPoint(row.location))
  const points = rows.map(row => mapPoint(row.location))
  if (!state.territoryMap) {
    state.territoryMap = window.L.map(container, { zoomControl: true, attributionControl: true, scrollWheelZoom: false })
    window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18, attribution: '&copy; OpenStreetMap' }).addTo(state.territoryMap)
  }
  state.territoryLayers.forEach(layer => layer.remove())
  state.territoryLayers = []
  if (!points.length) {
    state.territoryMap.setView([49.25, 16.9], 7)
    setTimeout(() => state.territoryMap?.invalidateSize(), 0)
    return
  }
  const hull = convexHull(points)
  if (hull.length >= 3) state.territoryLayers.push(window.L.polygon(expandedHull(hull), { color:'#16865a', weight:2, dashArray:'7 6', fillColor:'#16865a', fillOpacity:.08 }).addTo(state.territoryMap))
  rows.forEach(row => state.territoryLayers.push(window.L.circleMarker(mapPoint(row.location), { radius:6, color:'#fff', weight:2, fillColor:'#16865a', fillOpacity:1 }).bindTooltip(esc(row.location.name || row.location.city || 'Lokalita')).addTo(state.territoryMap)))
  state.territoryMap.fitBounds(points, { padding:[24, 24], maxZoom:9 })
  setTimeout(() => state.territoryMap?.invalidateSize(), 0)
}

function renderTerritory() {
  const primaryRows = state.territoryRows.filter(row => row.role === 'primary')
  const backupRows = state.territoryRows.filter(row => row.role === 'backup')
  const machineCount = primaryRows.reduce((sum, row) => sum + row.machineCount, 0)
  const validFrom = primaryRows.map(row => row.assignment.effective_from).filter(Boolean).sort()[0]
  const title = territoryLabel(primaryRows)
  setText('personalTerritoryLocations', `${primaryRows.length} lokalit`)
  setText('personalTerritoryMachines', `${machineCount} automatů`)
  setText('territoryTitle', title)
  setText('territorySubtitle', primaryRows.length ? primaryRows.map(row => row.location.city).filter(Boolean).filter((value, index, all) => all.indexOf(value) === index).slice(0, 4).join(', ') : 'Zatím bez přidělené hlavní oblasti')
  setText('territoryRole', primaryRows.length ? 'Hlavní operátor' : 'Náhradník')
  setText('territoryLocationCount', primaryRows.length)
  setText('territoryMachineCount', machineCount)
  setText('territoryBackupCount', backupRows.length)
  setText('territoryListCount', `${state.territoryRows.length} záznamů`)
  setText('territoryValidFrom', validFrom ? `Platí od ${new Date(`${validFrom}T12:00:00`).toLocaleDateString('cs-CZ')}` : 'Aktuální rozdělení')
  const list = document.getElementById('territoryLocationList')
  if (list) list.innerHTML = state.territoryRows.map(row => `<div class="territory-location-row ${row.role === 'backup' ? 'backup' : ''}"><span><strong>${esc(row.location.name || 'Lokalita')}</strong><small>${esc([row.location.city, row.location.address].filter(Boolean).join(' · '))}</small></span><b>${row.role === 'backup' ? 'Náhradník' : `${row.machineCount} automatů`}</b></div>`).join('') || '<div class="territory-empty">Zatím nemáte přidělenou oblast. Konkrétní naplánovanou trasu tím nejsou dotčeny.</div>'
}

async function loadTerritory() {
  const { data: { user }, error: userError } = await supabase.auth.getUser()
  if (userError) throw userError
  if (!user) return
  const { data: employee, error: employeeError } = await supabase.from('employees').select('id').eq('auth_user_id', user.id).maybeSingle()
  if (employeeError) throw employeeError
  if (!employee?.id) return
  const { data: assignments, error: assignmentError } = await supabase.from('operator_territory_assignments').select('*').or(`primary_employee_id.eq.${employee.id},backup_employee_id.eq.${employee.id}`).order('effective_from', { ascending:false })
  if (assignmentError) throw assignmentError
  const locationIds = [...new Set((assignments || []).map(row => row.location_id).filter(Boolean))]
  if (!locationIds.length) { state.territoryRows = []; renderTerritory(); return }
  const [locations, machines] = await Promise.all([
    supabase.from('locations').select('id,name,city,address,latitude,longitude,active').in('id', locationIds),
    supabase.from('machines').select('id,location_id,active,status').in('location_id', locationIds).eq('active', true)
  ])
  if (locations.error) throw locations.error
  if (machines.error) throw machines.error
  const locationById = new Map((locations.data || []).filter(row => row.active !== false).map(row => [String(row.id), row]))
  const machinesByLocation = new Map()
  ;(machines.data || []).filter(machine => !/warehouse|sklad|reserve|rezerv/i.test(String(machine.status || ''))).forEach(machine => machinesByLocation.set(String(machine.location_id), [...(machinesByLocation.get(String(machine.location_id)) || []), machine]))
  state.territoryRows = (assignments || []).flatMap(assignment => {
    const location = locationById.get(String(assignment.location_id))
    if (!location) return []
    const allMachines = machinesByLocation.get(String(location.id)) || []
    const machineCount = assignment.assignment_scope === 'machines' ? allMachines.filter(machine => (assignment.selected_machine_ids || []).map(String).includes(String(machine.id))).length : allMachines.length
    return [{ assignment, location, machineCount, role: String(assignment.primary_employee_id) === String(employee.id) ? 'primary' : 'backup' }]
  }).sort((a, b) => (a.role === b.role ? String(a.location.city || a.location.name).localeCompare(String(b.location.city || b.location.name), 'cs') : a.role === 'primary' ? -1 : 1))
  renderTerritory()
}

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
  $('#bonusMonthPrev').onclick = async () => { state.month.setMonth(state.month.getMonth() - 1); if (state.month < new Date(2026, 7, 1)) state.month = new Date(2026, 7, 1); await loadBonus() }
  $('#bonusMonthNext').onclick = async () => { const next = new Date(state.month); next.setMonth(next.getMonth() + 1); if (next <= new Date(new Date().getFullYear(), new Date().getMonth(), 1)) { state.month = next; await loadBonus() } }
  $('#sendMeetingRequest').onclick = sendMeeting

  const documents = await supabase.from('payroll_payslips').select('id', { count: 'exact', head: true })
  setText('personalDocumentCount', documents.error ? '—' : (documents.count ?? '0'))

  const results = await Promise.allSettled([loadBonus(), loadBonusHistory(), loadMeetings(), loadTerritory()])
  if (results[0].status === 'rejected') {
    console.error('Prémie:', results[0].reason)
    setText('personalBonusAmount', 'Nelze načíst')
  }
  if (results[1].status === 'rejected') {
    console.error('Historie prémií:', results[1].reason)
    $('#bonusHistory').innerHTML = '<div class="personal-history-row"><span><strong>Historii se nepodařilo načíst</strong></span></div>'
  }
  if (results[2].status === 'rejected') {
    console.error('Schůzky:', results[2].reason)
    $('#meetingDays').innerHTML = '<div class="empty">Volné termíny se teď nepodařilo načíst.</div>'
    $('#meetingSlots').innerHTML = ''
    $('#meetingInvitations').innerHTML = ''
  }
  if (results[3].status === 'rejected') {
    console.error('Moje oblast:', results[3].reason)
    setText('personalTerritoryLocations', 'Nelze načíst')
    setText('personalTerritoryMachines', 'Zkuste obnovit stránku')
    const list = document.getElementById('territoryLocationList')
    if (list) list.innerHTML = '<div class="territory-empty">Oblast se teď nepodařilo načíst.</div>'
  }
}

window.addEventListener('olvend:screen-opened', event => {
  if (event.detail?.screen === 'territory') setTimeout(renderTerritoryMap, 0)
})

init().catch(error => { console.error('Osobní zóna:', error) })
