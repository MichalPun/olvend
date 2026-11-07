import { supabase } from './supabase.js';

const STORAGE_KEY = 'olvend-territory-planner-draft-v1';
const MICHAL_EMPLOYEE_ID = 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
const palette = ['#3478bf', '#258463', '#7d62ad', '#d5101a', '#b46b00', '#00838f', '#9b3659'];
const preferredColors = [
  [/michal\s+punčochář/i, '#3478bf'],
  [/veronika\s+jirdová/i, '#258463'],
  [/kristýna\s+dvořáková/i, '#7d62ad']
];
const state = {
  employees: [],
  locations: [],
  machines: [],
  currentAssignments: new Map(),
  draftAssignments: new Map(),
  visitCounts: new Map(),
  markers: new Map(),
  selectedEmployeeId: null,
  selectedLocationId: null,
  drawing: false,
  drawPoints: [],
  drawLayer: null,
  dirty: false
};

const $ = (id) => document.getElementById(id);
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
const employeeName = (employee) => `${employee?.name || ''} ${employee?.surname || ''}`.trim() || 'Bez operátora';
const initials = (employee) => `${employee?.name?.[0] || ''}${employee?.surname?.[0] || ''}`.toUpperCase() || '—';
const employeeById = (id) => state.employees.find((employee) => String(employee.id) === String(id || '')) || null;
const includedEmployees = () => state.employees.filter((employee) => employee.included);
const selectedEmployee = () => employeeById(state.selectedEmployeeId);
const machineCountFor = (locationId) => state.machines.filter((machine) => String(machine.location_id) === String(locationId)).length;
const mapPointFor = (location) => {
  const lat = Number(location.latitude), lng = Number(location.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < 48.2 || lat > 51.2 || lng < 11.8 || lng > 19.3) return null;
  return [lat, lng];
};

const map = L.map('map', { zoomControl: true }).setView([49.25, 16.9], 7);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18, attribution: '&copy; OpenStreetMap' }).addTo(map);
let toastTimer;

function say(message, error = false) {
  clearTimeout(toastTimer);
  $('toast').textContent = message;
  $('toast').classList.toggle('error', error);
  $('toast').classList.add('show');
  toastTimer = setTimeout(() => $('toast').classList.remove('show'), 2800);
}

async function requireManager() {
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError) throw userError;
  if (!user) {
    location.href = 'index.html';
    throw new Error('Nejste přihlášený.');
  }
  const { data: employee, error } = await supabase.from('employees').select('id,role,active').eq('auth_user_id', user.id).maybeSingle();
  if (error) throw error;
  if (employee?.active === false || !/admin|manager|manaž|manaz|vedouc|majitel/i.test(String(employee?.role || ''))) {
    location.href = 'mobile.html';
    throw new Error('Tato stránka je určená pro vedení.');
  }
}

function colorFor(employee, index) {
  const name = employeeName(employee);
  return preferredColors.find(([pattern]) => pattern.test(name))?.[1] || palette[index % palette.length];
}

function defaultWeeklyFund(employee) {
  const name = employeeName(employee);
  if (/michal\s+punčochář/i.test(name)) return 24;
  const databaseFund = Number(employee.contracted_weekly_hours);
  return Number.isFinite(databaseFund) && databaseFund > 0 ? databaseFund : 40;
}

function weeklyVisitsFor(locationId) {
  const count = Number(state.visitCounts.get(String(locationId)) || 0);
  return count > 0 ? Math.max(.25, count / 13) : .25;
}

function estimatedHoursFor(location) {
  const visits = weeklyVisitsFor(location.id);
  const machines = Math.max(1, machineCountFor(location.id));
  const servicePerVisit = .42 + machines * .18;
  const travelAllowance = .42 * visits;
  return Math.max(.35, visits * servicePerVisit + travelAllowance);
}

function assignmentFor(locationId) {
  return state.draftAssignments.get(String(locationId)) || null;
}

function employeeLoads() {
  const loads = new Map(includedEmployees().map((employee) => [String(employee.id), 0]));
  state.locations.forEach((location) => {
    const ownerId = assignmentFor(location.id);
    if (ownerId && loads.has(String(ownerId))) loads.set(String(ownerId), loads.get(String(ownerId)) + estimatedHoursFor(location));
  });
  return loads;
}

function markerIcon(location) {
  const owner = employeeById(assignmentFor(location.id));
  const color = owner?.included ? owner.color : '#8a94a6';
  const label = machineCountFor(location.id) || '•';
  return L.divIcon({ className: 'marker-label', html: `<span style="display:grid;place-items:center;width:28px;height:28px;border-radius:50%;background:${color}">${label}</span>`, iconSize: [28, 28], iconAnchor: [14, 14] });
}

function renderPeople() {
  const loads = employeeLoads();
  $('people').innerHTML = state.employees.map((employee) => {
    const load = loads.get(String(employee.id)) || 0;
    const active = String(employee.id) === String(state.selectedEmployeeId);
    return `<button class="person ${active ? 'active' : ''} ${employee.included ? '' : 'excluded'}" data-employee-id="${esc(employee.id)}" style="--person:${employee.color}"><span class="avatar">${esc(initials(employee))}</span><span><b>${esc(employeeName(employee))}</b><small>${load.toFixed(1).replace('.', ',')} h odhad v návrhu</small><label class="include-row"><input class="include-input" data-include-id="${esc(employee.id)}" type="checkbox" ${employee.included ? 'checked' : ''}> zahrnout do návrhu</label></span><span class="fund"><span><input class="fund-input" data-fund-id="${esc(employee.id)}" type="number" min="1" max="80" step="1" value="${employee.weeklyFund}" ${employee.included ? '' : 'disabled'} aria-label="Týdenní fond ${esc(employeeName(employee))}"> h</span><small>týdně</small></span></button>`;
  }).join('');
  document.querySelectorAll('.person').forEach((button) => button.addEventListener('click', (event) => {
    if (event.target.closest('input')) return;
    const employee = employeeById(button.dataset.employeeId);
    if (!employee?.included) return say('Nejdřív tohoto člověka zařaď do návrhu.', true);
    state.selectedEmployeeId = button.dataset.employeeId;
    renderPeople();
    renderPaintMode();
  }));
  document.querySelectorAll('.fund-input').forEach((input) => input.addEventListener('change', () => {
    const employee = employeeById(input.dataset.fundId);
    if (!employee) return;
    employee.weeklyFund = Math.max(1, Math.min(80, Number(input.value) || 1));
    markDirty();
    renderPeople();
    renderSummary();
  }));
  document.querySelectorAll('.include-input').forEach((input) => input.addEventListener('change', () => {
    const employee = employeeById(input.dataset.includeId);
    if (!employee) return;
    employee.included = input.checked;
    if (!employee.included) {
      state.draftAssignments.forEach((ownerId, locationId) => {
        if (String(ownerId || '') === String(employee.id)) state.draftAssignments.set(locationId, null);
      });
      if (String(state.selectedEmployeeId) === String(employee.id)) state.selectedEmployeeId = includedEmployees()[0]?.id || null;
    } else if (!state.selectedEmployeeId) {
      state.selectedEmployeeId = employee.id;
    }
    markDirty();
    renderAll();
  }));
}

function renderPaintMode() {
  const employee = selectedEmployee();
  $('paintMode').textContent = employee ? `Právě přiřazuješ: ${employeeName(employee)}` : 'Nejdřív vyber operátora';
}

function renderLegend() {
  $('legend').innerHTML = includedEmployees().map((employee) => `<span><i class="dot" style="--c:${employee.color}"></i>${esc(employee.name || employeeName(employee))}</span>`).join('') + '<span><i class="dot" style="--c:#8a94a6"></i>Bez operátora</span>';
}

function renderMap(fit = false) {
  const bounds = [];
  state.locations.forEach((location) => {
    const point = mapPointFor(location);
    if (!point) return;
    let marker = state.markers.get(String(location.id));
    const owner = employeeById(assignmentFor(location.id));
    const tooltip = `${location.name || 'Lokalita'} · ${owner?.included ? employeeName(owner) : 'bez operátora'}`;
    if (!marker) {
      marker = L.marker(point, { icon: markerIcon(location), bubblingMouseEvents: false }).addTo(map);
      marker.on('click', () => selectAndAssignLocation(location.id));
      state.markers.set(String(location.id), marker);
    } else {
      marker.setLatLng(point).setIcon(markerIcon(location));
    }
    marker.unbindTooltip().bindTooltip(tooltip, { direction: 'top', offset: [0, -13] });
    bounds.push(point);
  });
  if (fit && bounds.length) map.fitBounds(bounds, { padding: [26, 26] });
  setTimeout(() => map.invalidateSize(), 50);
}

function selectAndAssignLocation(locationId) {
  const location = state.locations.find((item) => String(item.id) === String(locationId));
  if (!location) return;
  state.selectedLocationId = location.id;
  if (state.selectedEmployeeId) {
    state.draftAssignments.set(String(location.id), state.selectedEmployeeId);
    markDirty();
    renderMap(false);
    renderPeople();
  }
  renderSummary();
}

function renderSummary() {
  const loads = employeeLoads();
  const activePeople = includedEmployees();
  const remaining = activePeople.reduce((sum, employee) => sum + Math.max(0, employee.weeklyFund - (loads.get(String(employee.id)) || 0)), 0);
  const overloaded = activePeople.filter((employee) => (loads.get(String(employee.id)) || 0) > employee.weeklyFund);
  const selected = state.locations.find((location) => String(location.id) === String(state.selectedLocationId));
  if (selected) {
    const owner = employeeById(assignmentFor(selected.id));
    $('selectedName').textContent = selected.name || 'Lokalita bez názvu';
    $('selectedMeta').textContent = `${selected.city || 'Bez města'} · ${machineCountFor(selected.id)} automatů · ${weeklyVisitsFor(selected.id).toFixed(1).replace('.', ',')} návštěvy týdně · ${owner?.included ? employeeName(owner) : 'bez operátora'}`;
  } else {
    $('selectedName').textContent = 'Zatím nic nevybráno';
    $('selectedMeta').textContent = 'Klikni na bod v mapě. Barva bodu označuje operátora v tomto návrhu.';
  }
  $('feasibility').classList.toggle('warn', overloaded.length > 0);
  $('feasibility').innerHTML = overloaded.length
    ? `<b>⚠ Návrh překračuje fond</b><br>${esc(overloaded.map(employeeName).join(', '))} · uprav rozdělení nebo fond hodin.`
    : `<b>✓ Návrh je podle odhadu odjezditelný</b><br>Celková rezerva je přibližně ${remaining.toFixed(1).replace('.', ',')} hodiny týdně.`;
  $('metrics').innerHTML = activePeople.map((employee) => {
    const load = loads.get(String(employee.id)) || 0;
    const percent = Math.min(115, Math.round(load / employee.weeklyFund * 100));
    return `<div class="metric"><div class="metricline"><span>${esc(employee.name || employeeName(employee))}</span><b>${load.toFixed(1).replace('.', ',')} / ${employee.weeklyFund} h</b></div><div class="bar"><i style="--c:${employee.color};width:${Math.min(100, percent)}%;${percent > 100 ? 'background:#d5101a' : ''}"></i></div></div>`;
  }).join('');
}

function markDirty() {
  state.dirty = true;
  $('saveDraft').textContent = 'Uložit návrh';
}

function snapshot() {
  return {
    version: 1,
    savedAt: new Date().toISOString(),
    assignments: Object.fromEntries(state.draftAssignments),
    funds: Object.fromEntries(state.employees.map((employee) => [employee.id, employee.weeklyFund])),
    included: Object.fromEntries(state.employees.map((employee) => [employee.id, employee.included]))
  };
}

function saveDraft() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot()));
  state.dirty = false;
  $('saveDraft').textContent = 'Uloženo ✓';
  say('Pracovní návrh byl uložen v tomto prohlížeči. Ostré rajóny se nezměnily.');
  setTimeout(() => { if (!state.dirty) $('saveDraft').textContent = 'Uložit návrh'; }, 1800);
}

function loadSavedDraft() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
    if (!saved || saved.version !== 1) return false;
    Object.entries(saved.assignments || {}).forEach(([locationId, employeeId]) => {
      if (employeeById(employeeId)) state.draftAssignments.set(String(locationId), employeeId);
    });
    state.employees.forEach((employee) => {
      const fund = Number(saved.funds?.[employee.id]);
      if (Number.isFinite(fund) && fund > 0) employee.weeklyFund = fund;
      if (typeof saved.included?.[employee.id] === 'boolean') employee.included = saved.included[employee.id];
    });
    return true;
  } catch (_) {
    return false;
  }
}

function resetDraft() {
  if (state.dirty && !window.confirm('Zahodit neuložené úpravy tohoto návrhu?')) return;
  localStorage.removeItem(STORAGE_KEY);
  state.employees.forEach((employee) => {
    employee.weeklyFund = defaultWeeklyFund(employee);
    employee.included = !/david\s+boudný/i.test(employeeName(employee));
  });
  state.draftAssignments = new Map([...state.currentAssignments].map(([locationId, employeeId]) => [locationId, employeeById(employeeId)?.included ? employeeId : null]));
  state.dirty = false;
  renderAll();
  say('Návrh byl vrácen na současné ostré rozdělení.');
}

function distanceKm(a, b) {
  const toRad = (value) => value * Math.PI / 180;
  const dLat = toRad(b[0] - a[0]), dLng = toRad(b[1] - a[1]);
  const value = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a[0])) * Math.cos(toRad(b[0])) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
}

function suggestAssignments() {
  const activePeople = includedEmployees();
  if (!activePeople.length) return say('Vyber alespoň jednoho člověka do návrhu.', true);
  const centroids = new Map();
  activePeople.forEach((employee) => {
    const points = state.locations.filter((location) => String(state.currentAssignments.get(String(location.id)) || '') === String(employee.id)).map(mapPointFor).filter(Boolean);
    centroids.set(String(employee.id), points.length ? points.reduce((sum, point) => [sum[0] + point[0] / points.length, sum[1] + point[1] / points.length], [0, 0]) : [49.05, 16.65]);
  });
  const loads = new Map(activePeople.map((employee) => [String(employee.id), 0]));
  const next = new Map();
  [...state.locations].sort((a, b) => estimatedHoursFor(b) - estimatedHoursFor(a)).forEach((location) => {
    const point = mapPointFor(location);
    const currentOwner = state.currentAssignments.get(String(location.id));
    const ranked = activePeople.map((employee) => {
      const currentLoad = loads.get(String(employee.id)) || 0;
      const loadScore = currentLoad / Math.max(1, employee.weeklyFund);
      const distanceScore = point ? distanceKm(point, centroids.get(String(employee.id))) / 280 : .3;
      const continuityBonus = String(currentOwner || '') === String(employee.id) ? -.18 : 0;
      return { employee, score: loadScore * 1.35 + distanceScore + continuityBonus };
    }).sort((a, b) => a.score - b.score);
    const chosen = ranked[0].employee;
    next.set(String(location.id), chosen.id);
    loads.set(String(chosen.id), (loads.get(String(chosen.id)) || 0) + estimatedHoursFor(location));
  });
  state.draftAssignments = next;
  markDirty();
  renderAll();
  say('Program připravil návrh podle polohy, historie návštěv a fondů hodin.');
}

function pointInPolygon(point, polygon) {
  const x = point[1], y = point[0];
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const xi = polygon[i][1], yi = polygon[i][0], xj = polygon[j][1], yj = polygon[j][0];
    const intersects = ((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / ((yj - yi) || .0000001) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

function setDrawing(active) {
  state.drawing = active;
  $('mapWrap').classList.toggle('drawing', active);
  $('drawArea').hidden = active;
  $('finishArea').hidden = !active;
  $('cancelArea').hidden = !active;
  if (!active) {
    state.drawPoints = [];
    if (state.drawLayer) state.drawLayer.remove();
    state.drawLayer = null;
  }
}

function startDrawing() {
  if (!state.selectedEmployeeId) return say('Nejdřív vyber operátora.', true);
  setDrawing(true);
}

function finishDrawing() {
  if (state.drawPoints.length < 3) return say('Pro oblast klikni do mapy alespoň třikrát.', true);
  const inside = state.locations.filter((location) => {
    const point = mapPointFor(location);
    return point && pointInPolygon(point, state.drawPoints);
  });
  inside.forEach((location) => state.draftAssignments.set(String(location.id), state.selectedEmployeeId));
  setDrawing(false);
  if (!inside.length) return say('V nakreslené oblasti není žádná lokalita.', true);
  markDirty();
  renderAll();
  say(`Přiřazeno ${inside.length} lokalit operátorovi ${employeeName(selectedEmployee())}.`);
}

map.on('click', (event) => {
  if (!state.drawing) return;
  state.drawPoints.push([event.latlng.lat, event.latlng.lng]);
  if (state.drawLayer) state.drawLayer.remove();
  state.drawLayer = state.drawPoints.length >= 3
    ? L.polygon(state.drawPoints, { color: selectedEmployee()?.color || '#d5101a', weight: 3, fillOpacity: .08 }).addTo(map)
    : L.polyline(state.drawPoints, { color: selectedEmployee()?.color || '#d5101a', weight: 3, dashArray: '6 5' }).addTo(map);
});

async function loadRouteHistory() {
  const since = new Date();
  since.setDate(since.getDate() - 91);
  const date = since.toISOString().slice(0, 10);
  const { data: plans, error: plansError } = await supabase.from('route_plans').select('id').gte('planning_date', date).neq('execution_status', 'cancelled');
  if (plansError) throw plansError;
  const ids = (plans || []).map((plan) => plan.id);
  const counts = new Map();
  for (let index = 0; index < ids.length; index += 200) {
    const chunk = ids.slice(index, index + 200);
    if (!chunk.length) continue;
    const { data: stops, error } = await supabase.from('route_plan_stops').select('location_id,status,completed_at').in('route_plan_id', chunk).not('location_id', 'is', null);
    if (error) throw error;
    (stops || []).forEach((stop) => {
      if (stop.status === 'skipped') return;
      const key = String(stop.location_id);
      counts.set(key, (counts.get(key) || 0) + 1);
    });
  }
  state.visitCounts = counts;
}

function renderAll() {
  renderPeople();
  renderPaintMode();
  renderLegend();
  renderMap(false);
  renderSummary();
}

async function load() {
  await requireManager();
  const [employees, locations, machines, assignments] = await Promise.all([
    supabase.from('employees').select('id,name,surname,role,active,bonus_eligible,contracted_weekly_hours').eq('active', true).order('surname'),
    supabase.from('locations').select('id,name,city,address,latitude,longitude,active').eq('active', true).order('name'),
    supabase.from('machines').select('id,location_id,evidence_number,name,machine_type,active,status').eq('active', true),
    supabase.rpc('get_operator_territories_v51', { p_date: new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Prague', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date()) })
  ]);
  const failed = [employees, locations, machines, assignments].find((result) => result.error);
  if (failed) throw failed.error;
  state.employees = (employees.data || [])
    .filter((employee) => /operator|operátor/i.test(String(employee.role || '')) || String(employee.id) === MICHAL_EMPLOYEE_ID)
    .map((employee, index) => ({ ...employee, color: colorFor(employee, index), weeklyFund: defaultWeeklyFund(employee), included: !/david\s+boudný/i.test(employeeName(employee)) }));
  if (!state.employees.length) {
    state.employees = (employees.data || []).filter((employee) => /operator|operátor|admin|manager/i.test(String(employee.role || ''))).map((employee, index) => ({ ...employee, color: colorFor(employee, index), weeklyFund: defaultWeeklyFund(employee), included: true }));
  }
  state.locations = (locations.data || []).filter(mapPointFor);
  state.machines = (machines.data || []).filter((machine) => machine.location_id && !/warehouse|sklad|reserve|rezerv/i.test(String(machine.status || '')));
  state.currentAssignments = new Map((assignments.data || []).map((assignment) => [String(assignment.location_id), assignment.primary_employee_id || null]));
  state.draftAssignments = new Map([...state.currentAssignments].map(([locationId, employeeId]) => [locationId, employeeById(employeeId)?.included ? employeeId : null]));
  await loadRouteHistory();
  const restored = loadSavedDraft();
  state.selectedEmployeeId = includedEmployees()[0]?.id || null;
  renderAll();
  renderMap(true);
  $('loading').hidden = true;
  if (restored) say('Načetl jsem poslední uložený pracovní návrh.');
}

$('saveDraft').addEventListener('click', saveDraft);
$('resetDraft').addEventListener('click', resetDraft);
$('suggest').addEventListener('click', suggestAssignments);
$('fitMap').addEventListener('click', () => renderMap(true));
$('drawArea').addEventListener('click', startDrawing);
$('finishArea').addEventListener('click', finishDrawing);
$('cancelArea').addEventListener('click', () => setDrawing(false));
$('showDetails').addEventListener('click', () => {
  $('summary').classList.toggle('open');
  $('showDetails').textContent = $('summary').classList.contains('open') ? 'Skrýt podrobnosti výpočtu' : 'Zobrazit podrobnosti výpočtu';
});
$('openCurrent').addEventListener('click', () => { location.href = 'operator-territories.html'; });
window.addEventListener('beforeunload', (event) => { if (state.dirty) { event.preventDefault(); event.returnValue = ''; } });

load().catch((error) => {
  console.error(error);
  $('loading').hidden = true;
  say(`Data nelze načíst: ${error.message || error}`, true);
});
