import { supabase } from './supabase.js';

const STORAGE_KEY = 'olvend-territory-planner-draft-v11';
const LEGACY_STORAGE_KEYS = ['olvend-territory-planner-draft-v10', 'olvend-territory-planner-draft-v9', 'olvend-territory-planner-draft-v8', 'olvend-territory-planner-draft-v7', 'olvend-territory-planner-draft-v6', 'olvend-territory-planner-draft-v5', 'olvend-territory-planner-draft-v4', 'olvend-territory-planner-draft-v3'];
const MICHAL_ID = 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
const DEPOT_FALLBACK = [49.054, 16.646];
const palette = ['#3478bf', '#258463', '#7d62ad', '#d5101a', '#b46b00', '#00838f'];
const state = {
  employees: [], locations: [], machines: [], current: new Map(), draft: new Map(),
  visitDates: new Map(), lastVisits: new Map(), locationVisitDates: new Map(), lastLocationVisits: new Map(),
  visitDurationSamples: new Map(), actualVisitMinutes: new Map(),
  machineDurationSamples: new Map(), actualMachineMinutes: new Map(), plannedMachineMinutes: new Map(), fallbackMachineMinutes: 20,
  requiredVisits: new Map(), markers: new Map(), depot: DEPOT_FALLBACK,
  scheduleSettings: new Map(), routeDrafts: new Map(), planningEmployeeId: null, routeRequestId: 0,
  selectedEmployeeId: null, selectedLocationId: null, selectedMachineIds: new Set(),
  drawing: false, drawPoints: [], drawLayer: null, dirty: false, showComparison: false
};
const $ = (id) => document.getElementById(id);
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
const nameOf = (employee) => `${employee?.name || ''} ${employee?.surname || ''}`.trim() || 'Bez operátora';
const employeeById = (id) => state.employees.find((employee) => String(employee.id) === String(id || '')) || null;
const activeEmployees = () => state.employees.filter((employee) => employee.included);
const selectedEmployee = () => employeeById(state.selectedEmployeeId);
const machinesAt = (locationId) => state.machines.filter((machine) => String(machine.location_id) === String(locationId));
const pointOf = (location) => {
  const lat = Number(location?.latitude), lng = Number(location?.longitude);
  return Number.isFinite(lat) && Number.isFinite(lng) && lat >= 48.2 && lat <= 51.2 && lng >= 11.8 && lng <= 19.3 ? [lat, lng] : null;
};
const copyAssignments = (source) => new Map([...source].map(([machineId, owners]) => [String(machineId), new Set(owners || [])]));
const ownersOfMachine = (assignments, machineId) => [...(assignments.get(String(machineId)) || new Set())].filter(Boolean);
const number = (value, digits = 1) => Number(value || 0).toFixed(digits).replace('.', ',');
const dateLabel = (value) => value ? new Intl.DateTimeFormat('cs-CZ').format(new Date(`${value}T12:00:00`)) : 'bez návštěvy';
const weekDayLabels = ['Po', 'Út', 'St', 'Čt', 'Pá'];

const map = L.map('map', { zoomControl: true }).setView([49.25, 16.9], 7);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18, attribution: '&copy; OpenStreetMap' }).addTo(map);
let toastTimer;

function say(message, error = false) {
  clearTimeout(toastTimer);
  $('toast').textContent = message;
  $('toast').classList.toggle('error', error);
  $('toast').classList.add('show');
  toastTimer = setTimeout(() => $('toast').classList.remove('show'), 3200);
}

async function requireManager() {
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error) throw error;
  if (!user) { location.href = 'index.html'; throw new Error('Nejste přihlášený.'); }
  const profile = await supabase.from('employees').select('role,active').eq('auth_user_id', user.id).maybeSingle();
  if (profile.error) throw profile.error;
  if (profile.data?.active === false || !/admin|manager|manaž|manaz|vedouc|majitel/i.test(String(profile.data?.role || ''))) {
    location.href = 'mobile.html'; throw new Error('Tato stránka je určená pro vedení.');
  }
}

function defaultFund(employee) {
  if (/michal\s+punčochář/i.test(nameOf(employee))) return 24;
  const value = Number(employee.contracted_weekly_hours);
  return Number.isFinite(value) && value > 0 ? value : 40;
}

function nextMondayValue() { const date = new Date(); date.setHours(12, 0, 0, 0); date.setDate(date.getDate() + (((8 - date.getDay()) % 7) || 7)); return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Prague', year: 'numeric', month: '2-digit', day: '2-digit' }).format(date); }

function defaultSchedule() { return { mode: 'auto', recommendedHours: null, maxHours: 12, startTime: '06:00', cycleStart: nextMondayValue(), availableDays: [1, 2, 3, 4, 5], weeks: [[], [], []] }; }

function scheduleFor(employee) {
  const key = String(employee?.id || '');
  if (!state.scheduleSettings.has(key)) state.scheduleSettings.set(key, defaultSchedule(employee));
  return state.scheduleSettings.get(key);
}

function colorFor(employee, index) {
  const name = nameOf(employee);
  if (/michal\s+punčochář/i.test(name)) return '#3478bf';
  if (/veronika\s+jirdová/i.test(name)) return '#258463';
  if (/kristýna\s+dvořáková/i.test(name)) return '#7d62ad';
  return palette[index % palette.length];
}

function kindOf(machine) {
  const source = `${machine.machine_type || ''} ${machine.name || ''}`;
  if (/food|snack|potrav|fas|saphir|aria|vitality/i.test(source)) return 'Potravinový automat';
  if (/coffee|káva|kav|jetinno|luce|lei|bianchi/i.test(source)) return 'Kávový automat';
  return 'Automat';
}

function weeklyVisitsMachine(machineId) {
  const count = state.visitDates.get(String(machineId))?.size || 0;
  return count ? count / 13 : .25;
}

function weeklyVisitsLocation(locationId) {
  const recorded = state.locationVisitDates.get(String(locationId));
  if (recorded?.size) return recorded.size / 13;
  const dates = new Set();
  machinesAt(locationId).forEach((machine) => (state.visitDates.get(String(machine.id)) || new Set()).forEach((date) => dates.add(date)));
  return dates.size ? dates.size / 13 : .25;
}

function recommendationForMachine(machine) {
  const actual = weeklyVisitsMachine(machine.id);
  const food = /Potravin/.test(kindOf(machine));
  const rounded = actual >= 1 ? Math.round(actual * 2) / 2 : Math.round(actual * 10) / 10;
  const minimum = food ? 2 : .7;
  return {
    visits: Math.min(7, Math.max(minimum, rounded)),
    reason: food ? 'podle posledních 13 týdnů; potravinový automat nejméně 2×' : 'podle skutečné četnosti za posledních 13 týdnů'
  };
}

function requiredVisitsMachine(machineId) {
  const machine = state.machines.find((item) => String(item.id) === String(machineId));
  return Math.max(.1, Number(state.requiredVisits.get(String(machineId)) || (machine ? recommendationForMachine(machine).visits : .7)));
}

function requiredVisitsLocation(locationId) {
  return Math.max(...machinesAt(locationId).map((machine) => requiredVisitsMachine(machine.id)), 0);
}

function median(values) {
  const sorted = values.filter(Number.isFinite).sort((a, b) => a - b);
  if (!sorted.length) return null;
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

function plannedMinutesMachine(machineId) {
  return Math.max(1, Number(state.plannedMachineMinutes.get(String(machineId)) || 20));
}

function plannedMinutesLocation(locationId) {
  return machinesAt(locationId).reduce((sum, machine) => sum + plannedMinutesMachine(machine.id), 0);
}

function daysSince(value) {
  if (!value) return Infinity;
  const today = new Date(); today.setHours(12, 0, 0, 0);
  return Math.max(0, Math.floor((today - new Date(`${value}T12:00:00`)) / 86400000));
}

function lastVisitLocation(locationId) {
  return state.lastLocationVisits.get(String(locationId)) || machinesAt(locationId).map((machine) => state.lastVisits.get(String(machine.id))).filter(Boolean).sort().at(-1) || null;
}

function ownerIdsAt(assignments, locationId) {
  const ids = new Set();
  machinesAt(locationId).forEach((machine) => ownersOfMachine(assignments, machine.id).forEach((id) => ids.add(String(id))));
  return [...ids];
}

function ownerNamesAt(assignments, locationId) {
  const names = ownerIdsAt(assignments, locationId).map((id) => nameOf(employeeById(id)));
  return names.length ? names.join(', ') : 'bez operátora';
}

function distanceKm(a, b) {
  const rad = (value) => value * Math.PI / 180;
  const dLat = rad(b[0] - a[0]), dLng = rad(b[1] - a[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a[0])) * Math.cos(rad(b[0])) * Math.sin(dLng / 2) ** 2;
  return 12742 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

function routeLength(points) {
  const remaining = [...points]; let current = state.depot; let total = 0;
  while (remaining.length) {
    let index = 0; let best = Infinity;
    remaining.forEach((point, candidate) => { const value = distanceKm(current, point); if (value < best) { best = value; index = candidate; } });
    total += best; current = remaining.splice(index, 1)[0];
  }
  return total + distanceKm(current, state.depot);
}

function routeDays(employee) { return scheduleFor(employee).weeks.reduce((sum, days) => sum + days.length, 0) / 3; }

function employeeFrequency(assignments, employeeId, locationId) {
  return machinesAt(locationId).reduce((maximum, machine) => {
    const owners = ownersOfMachine(assignments, machine.id);
    if (!owners.some((id) => String(id) === String(employeeId))) return maximum;
    return Math.max(maximum, requiredVisitsMachine(machine.id) / Math.max(1, owners.length));
  }, 0);
}

function weeklyKm(employee, assignments) {
  const scheduledDays = routeDays(employee); if (!scheduledDays) return 0;
  const days = Math.max(1, Math.round(scheduledDays));
  const routes = Array.from({ length: days }, () => ({ points: [], locations: new Set(), partial: 0 }));
  const targets = state.locations.map((location) => ({ location, point: pointOf(location), frequency: employeeFrequency(assignments, employee.id, location.id) }))
    .filter((item) => item.point && item.frequency > 0)
    .sort((a, b) => distanceKm(state.depot, b.point) - distanceKm(state.depot, a.point));
  targets.forEach(({ location, point, frequency }) => {
    const capped = Math.min(days, frequency), whole = Math.floor(capped), fraction = capped - whole;
    for (let i = 0; i < whole; i += 1) {
      const target = routes.map((route) => ({ route, increase: route.locations.has(String(location.id)) ? Infinity : routeLength([...route.points, point]) - routeLength(route.points) })).sort((a, b) => a.increase - b.increase)[0].route;
      target.points.push(point); target.locations.add(String(location.id));
    }
    if (fraction > .01) {
      const target = routes.map((route) => ({ route, increase: routeLength([...route.points, point]) - routeLength(route.points) })).sort((a, b) => a.increase - b.increase)[0];
      target.route.partial += target.increase * fraction;
    }
  });
  return routes.reduce((sum, route) => sum + routeLength(route.points) + route.partial, 0);
}

function employeeStats(employee, assignments) {
  let service = 0, machineCount = 0; const locations = new Set();
  state.machines.forEach((machine) => {
    const owners = ownersOfMachine(assignments, machine.id);
    if (!owners.some((id) => String(id) === String(employee.id))) return;
    machineCount += 1; locations.add(String(machine.location_id));
    service += plannedMinutesMachine(machine.id) / 60 * requiredVisitsMachine(machine.id) / Math.max(1, owners.length);
  });
  const km = weeklyKm(employee, assignments);
  return { hours: service + km / 55, km, machineCount, locationCount: locations.size };
}

function statsFor(assignments) { return new Map(state.employees.map((employee) => [String(employee.id), employeeStats(employee, assignments)])); }

function markerIcon(location) {
  const colors = [...new Set(ownerIdsAt(state.draft, location.id).map(employeeById).filter((employee) => employee?.included).map((employee) => employee.color))];
  const background = colors.length > 1 ? `conic-gradient(${colors.map((color, i) => `${color} ${i / colors.length * 100}% ${(i + 1) / colors.length * 100}%`).join(',')})` : (colors[0] || '#8a94a6');
  return L.divIcon({ className: 'marker-label', html: `<span style="display:grid;place-items:center;width:28px;height:28px;border-radius:50%;background:${background}">${machinesAt(location.id).length}</span>`, iconSize: [28, 28], iconAnchor: [14, 14] });
}

function renderPeople() {
  const stats = statsFor(state.draft);
  $('people').innerHTML = state.employees.map((employee) => {
    const item = stats.get(String(employee.id)) || { hours: 0, km: 0 };
    const routeDraft = state.routeDrafts.get(String(employee.id));
    const displayed = routeDraft ? { hours: Number(routeDraft.totalHours || 0) / 3, km: Number(routeDraft.totalKm || 0) / 3 } : item;
    const initials = `${employee.name?.[0] || ''}${employee.surname?.[0] || ''}`.toUpperCase() || '—';
    return `<button class="person ${String(employee.id) === String(state.selectedEmployeeId) ? 'active' : ''} ${employee.included ? '' : 'excluded'}" data-employee-id="${esc(employee.id)}" style="--person:${employee.color}"><span class="avatar">${esc(initials)}</span><span><b>${esc(nameOf(employee))}</b><small>${number(displayed.hours)} h · ${Math.round(displayed.km)} km týdně ${routeDraft ? 'po silnici' : '· předběžně'}</small><small class="person-route-state ${routeDraft ? '' : 'pending'}">${routeDraft ? `trasy spočítány · ${number(routeDraft.totalHours)} h / cyklus` : 'trasy ještě nejsou rozvržené'}</small><label class="include-row"><input class="include-input" data-include-id="${esc(employee.id)}" type="checkbox" ${employee.included ? 'checked' : ''}> zahrnout do návrhu</label></span><span class="fund"><span><input class="fund-input" data-fund-id="${esc(employee.id)}" type="number" min="1" max="80" value="${employee.weeklyFund}" ${employee.included ? '' : 'disabled'}> h</span><small>týdně</small></span></button>`;
  }).join('');
  document.querySelectorAll('.person').forEach((button) => button.addEventListener('click', (event) => {
    if (event.target.closest('input')) return;
    const employee = employeeById(button.dataset.employeeId);
    if (!employee?.included) return say('Nejdřív tohoto člověka zařaď do návrhu.', true);
    state.selectedEmployeeId = employee.id; renderPeople(); renderPaintMode(); renderSummary();
  }));
  document.querySelectorAll('.fund-input').forEach((input) => input.addEventListener('change', () => {
    const employee = employeeById(input.dataset.fundId); if (!employee) return;
    employee.weeklyFund = Math.max(1, Math.min(80, Number(input.value) || 1)); state.routeDrafts.delete(String(employee.id)); markDirty(); renderAll();
  }));
  document.querySelectorAll('.include-input').forEach((input) => input.addEventListener('change', () => {
    const employee = employeeById(input.dataset.includeId); if (!employee) return;
    employee.included = input.checked;
    if (!employee.included) {
      state.draft.forEach((owners, machineId) => state.draft.set(machineId, new Set([...owners].filter((id) => String(id) !== String(employee.id)))));
      if (String(state.selectedEmployeeId) === String(employee.id)) state.selectedEmployeeId = activeEmployees()[0]?.id || null;
    }
    markDirty(); renderAll();
  }));
}

function renderPaintMode() { $('paintMode').textContent = selectedEmployee() ? `Právě plánuješ pro: ${nameOf(selectedEmployee())}` : 'Nejdřív vyber člověka'; }
function renderLegend() { $('legend').innerHTML = activeEmployees().map((employee) => `<span><i class="dot" style="--c:${employee.color}"></i>${esc(employee.name)}</span>`).join('') + '<span><i class="dot" style="--c:#8a94a6"></i>Bez operátora</span>'; }

function renderMap(fit = false) {
  const bounds = [];
  state.locations.forEach((location) => {
    const point = pointOf(location); if (!point) return;
    let marker = state.markers.get(String(location.id));
    if (!marker) { marker = L.marker(point, { icon: markerIcon(location), bubblingMouseEvents: false }).addTo(map); marker.on('click', () => selectLocation(location.id)); state.markers.set(String(location.id), marker); }
    else marker.setIcon(markerIcon(location));
    marker.unbindTooltip().bindTooltip(`${location.name} · ${ownerNamesAt(state.draft, location.id)}`, { direction: 'top', offset: [0, -13] }); bounds.push(point);
  });
  if (fit && bounds.length) map.fitBounds(bounds, { padding: [26, 26] });
  setTimeout(() => map.invalidateSize(), 30);
}

function selectLocation(locationId) {
  state.selectedLocationId = locationId;
  state.selectedMachineIds = new Set(machinesAt(locationId).map((machine) => String(machine.id)));
  renderSummary();
}

function selectedImpact() {
  const employee = selectedEmployee(); if (!employee || !state.selectedMachineIds.size) return null;
  const before = employeeStats(employee, state.draft), simulated = copyAssignments(state.draft);
  state.selectedMachineIds.forEach((machineId) => simulated.set(String(machineId), new Set([String(employee.id)])));
  const after = employeeStats(employee, simulated);
  return { hours: after.hours - before.hours, km: after.km - before.km };
}

function renderSelected(location) {
  if (!location) {
    $('selectedName').textContent = 'Zatím nic nevybráno'; $('selectedMeta').textContent = 'Klikni na bod v mapě. Nic se nepřiřadí bez potvrzení.';
    $('selectedFacts').hidden = true; $('selectedActions').hidden = true; return;
  }
  const machines = machinesAt(location.id), employee = selectedEmployee(), impact = selectedImpact();
  const lastVisit = lastVisitLocation(location.id), age = daysSince(lastVisit), overdue = age > 10;
  const actualMinutes = state.actualVisitMinutes.get(String(location.id));
  const durationSamples = state.visitDurationSamples.get(String(location.id))?.length || 0;
  $('selectedName').textContent = location.name || 'Lokalita bez názvu';
  $('selectedMeta').textContent = `${location.city || 'Bez města'} · ${machines.length} aktivní ${machines.length === 1 ? 'automat' : 'automaty'}`;
  $('selectedFacts').hidden = false;
  $('selectedFacts').innerHTML = `
    <div class="fact-row"><span>Nyní lokalitu skutečně navštěvujeme</span><b>${number(weeklyVisitsLocation(location.id))}× týdně</b></div>
    <div class="fact-row"><span>Pro dopravu počítám</span><b>${number(requiredVisitsLocation(location.id))}× týdně<br><small>nejvyšší četnost ze zdejších automatů</small></b></div>
    <div class="fact-row"><span>Poslední návštěva</span><b class="${overdue ? 'overdue' : ''}">${esc(dateLabel(lastVisit))}${Number.isFinite(age) ? ` · ${age} dní` : ''}${overdue ? ' · PO TERMÍNU' : ''}</b></div>
    <div class="fact-row"><span>Skutečná plná obsluha</span><b>${actualMinutes ? `${number(actualMinutes)} min · medián` : 'zatím bez kompletní návštěvy'}<br><small>${actualMinutes ? `${durationSamples === 1 ? '1 návštěva' : `${durationSamples} návštěv`} se všemi ${machines.length} automaty` : 'čas se skládá z jednotlivých automatů'}</small></b></div>
    <div class="fact-row"><span>Pro výpočet celé lokality</span><b>${number(plannedMinutesLocation(location.id))} min<br><small>součet časů všech ${machines.length} automatů</small></b></div>
    ${state.showComparison ? `<div class="fact-row"><span>Současný stav</span><b>${esc(ownerNamesAt(state.current, location.id))}</b></div>` : ''}
    <div class="fact-row"><span>V tomto návrhu</span><b>${esc(ownerNamesAt(state.draft, location.id))}</b></div>
    ${employee && impact ? `<div class="fact-row"><span>Dopad pro ${esc(employee.name)}</span><b>${impact.hours >= 0 ? '+' : ''}${number(impact.hours)} h · ${impact.km >= 0 ? '+' : ''}${Math.round(impact.km)} km/týden</b></div>` : ''}
    <div class="machine-picker"><div class="machine-picker-title"><span>Vyber stroje k přidělení</span><button type="button" id="toggleMachines">Vybrat / zrušit vše</button></div>
    ${machines.map((machine) => {
      const owners = ownersOfMachine(state.draft, machine.id).map(employeeById).filter(Boolean);
      const recommendation = recommendationForMachine(machine);
      const machineMinutes = state.actualMachineMinutes.get(String(machine.id));
      const machineSamples = state.machineDurationSamples.get(String(machine.id))?.length || 0;
      return `<div class="machine-option"><input type="checkbox" data-selected-machine="${machine.id}" ${state.selectedMachineIds.has(String(machine.id)) ? 'checked' : ''}><span><strong>${esc(machine.evidence_number ? `EV ${machine.evidence_number} · ` : '')}${esc(machine.name || kindOf(machine))}</strong><small>${kindOf(machine)} · nyní ${number(weeklyVisitsMachine(machine.id))}× týdně · naposledy ${dateLabel(state.lastVisits.get(String(machine.id)) || lastVisit)}</small><small>${esc(owners.length ? owners.map(nameOf).join(', ') : 'bez operátora')} <span class="owner-dots">${owners.map((owner) => `<i style="--c:${owner.color}"></i>`).join('')}</span></small><span class="machine-frequency"><span>Doporučuji <b>${number(recommendation.visits)}×</b><small>${esc(recommendation.reason)}</small></span><label>Pro návrh <input class="frequency-input" data-machine-frequency="${machine.id}" type="number" min="0.1" max="7" step="0.1" value="${requiredVisitsMachine(machine.id).toFixed(1)}"> × týdně</label></span><span class="machine-duration"><span>Skutečný čas <b>${machineMinutes ? `${number(machineMinutes)} min` : 'bez historie'}</b><small>${machineSamples ? `${machineSamples} měření` : 'bez historického měření'}</small></span><label>Pro výpočet <input class="frequency-input" data-machine-minutes="${machine.id}" type="number" min="1" max="180" step="1" value="${Math.round(plannedMinutesMachine(machine.id))}"> min</label></span></span></div>`;
    }).join('')}</div>`;
  $('selectedActions').hidden = !employee;
  if (employee) { $('assignSelected').textContent = `Přidělit vybrané · ${employee.name}`; $('shareSelected').textContent = `Přidat ${employee.name} jako výpomoc`; }
  document.querySelectorAll('[data-selected-machine]').forEach((input) => input.addEventListener('change', () => {
    if (input.checked) state.selectedMachineIds.add(String(input.dataset.selectedMachine)); else state.selectedMachineIds.delete(String(input.dataset.selectedMachine)); renderSelected(location);
  }));
  $('toggleMachines')?.addEventListener('click', () => { const ids = machines.map((machine) => String(machine.id)); state.selectedMachineIds = state.selectedMachineIds.size === ids.length ? new Set() : new Set(ids); renderSelected(location); });
  document.querySelectorAll('[data-machine-frequency]').forEach((input) => input.addEventListener('change', (event) => {
    state.requiredVisits.set(String(event.target.dataset.machineFrequency), Math.max(.1, Math.min(7, Number(event.target.value) || .1)));
    markDirty(); renderAll();
  }));
  document.querySelectorAll('[data-machine-minutes]').forEach((input) => input.addEventListener('change', (event) => {
    state.plannedMachineMinutes.set(String(event.target.dataset.machineMinutes), Math.max(1, Math.min(180, Number(event.target.value) || 20)));
    markDirty(); renderAll();
  }));
}

function renderSummary() {
  const proposed = statsFor(state.draft), current = statsFor(state.current), people = activeEmployees();
  const effective = (employee) => { const routeDraft = state.routeDrafts.get(String(employee.id)); return routeDraft ? { hours: Number(routeDraft.totalHours || 0) / 3, km: Number(routeDraft.totalKm || 0) / 3, routed: true } : { ...proposed.get(String(employee.id)), routed: false }; };
  const overloaded = people.filter((employee) => effective(employee).hours > employee.weeklyFund);
  const unrouted = people.filter((employee) => assignedMachines(employee).length && !state.routeDrafts.has(String(employee.id)));
  const hardLimit = people.filter((employee) => { const draft = state.routeDrafts.get(String(employee.id)), settings = scheduleFor(employee); return draft?.routes?.some((route) => Number(route.totalMinutes) > settings.maxHours * 60); });
  const unassigned = state.machines.filter((machine) => ownersOfMachine(state.draft, machine.id).length === 0).length;
  const coverage = people.reduce((count, employee) => count + state.locations.filter((location) => employeeFrequency(state.draft, employee.id, location.id) > routeDays(employee) + .2).length, 0);
  renderSelected(state.locations.find((location) => String(location.id) === String(state.selectedLocationId)));
  const warnings = [];
  if (unassigned) warnings.push(`${unassigned} strojů ještě nemá člověka`);
  if (overloaded.length) warnings.push(`fond překračuje ${overloaded.map(nameOf).join(', ')}`);
  if (unrouted.length) warnings.push(`silniční trasy ještě nejsou ověřené pro ${unrouted.map(nameOf).join(', ')}`);
  if (hardLimit.length) warnings.push(`denní maximum překračuje ${hardLimit.map(nameOf).join(', ')}`);
  if (coverage) warnings.push(`${coverage} míst vyžaduje více návštěv, než má člověk jízdních dnů`);
  $('feasibility').classList.toggle('warn', warnings.length > 0);
  $('feasibility').innerHTML = warnings.length ? `<b>⚠ Návrh ještě není hotový</b><br>${esc(warnings.join(' · '))}.` : '<b>✓ Návrh je podle odhadu odjezditelný</b><br>Všechny aktivní stroje mají přiřazenou péči a fondy nejsou překročené.';
  $('metrics').innerHTML = people.map((employee) => {
    const next = effective(employee), now = current.get(String(employee.id)), hours = next.hours - now.hours, km = next.km - now.km;
    const percent = Math.min(115, Math.round(next.hours / employee.weeklyFund * 100));
    const comparison = state.showComparison ? `<div class="metriccompare"><span>Dnes ${number(now.hours)} h · ${Math.round(now.km)} km</span><b class="${hours > .05 || km > 1 ? 'positive' : hours < -.05 || km < -1 ? 'negative' : ''}">${hours >= 0 ? '+' : ''}${number(hours)} h · ${km >= 0 ? '+' : ''}${Math.round(km)} km</b></div>` : '';
    return `<div class="metric"><div class="metricline"><span>${esc(employee.name)}<br><small>${next.routed ? 'Google Routes · průměr cyklu' : 'předběžný odhad'}</small></span><b>${number(next.hours)} / ${employee.weeklyFund} h<br>${Math.round(next.km)} km/týden</b></div>${comparison}<div class="bar"><i style="--c:${employee.color};width:${Math.min(100, percent)}%;${percent > 100 ? 'background:#d5101a' : ''}"></i></div></div>`;
  }).join('');
  const employee = selectedEmployee();
  $('planSelectedEmployee').disabled = !employee || !state.machines.some((machine) => ownersOfMachine(state.draft, machine.id).includes(String(employee.id)));
  $('planSelectedEmployee').textContent = employee ? `Dokončit rajón · ${employee.name}` : 'Dokončit rajón a rozvrhnout trasy';
}

function localDate(value) { return new Date(`${value}T12:00:00`); }
function isoDate(value) { return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Prague', year: 'numeric', month: '2-digit', day: '2-digit' }).format(value); }
function addCalendarDays(value, days) { const next = new Date(value); next.setDate(next.getDate() + days); return next; }
function dayLabel(value) { return new Intl.DateTimeFormat('cs-CZ', { weekday: 'short', day: 'numeric', month: 'numeric' }).format(localDate(value)); }
function minutesLabel(value) { const minutes = Math.max(0, Math.round(Number(value) || 0)); return `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')} min`; }

function assignedMachines(employee) {
  return state.machines.filter((machine) => ownersOfMachine(state.draft, machine.id).some((id) => String(id) === String(employee.id)));
}

function cycleDaysFor(employee, settings) {
  const start = localDate(settings.cycleStart);
  return settings.weeks.flatMap((days, weekIndex) => [...days].sort((a, b) => a - b).map((day) => ({
    key: `${weekIndex + 1}-${day}`,
    weekIndex,
    day,
    date: isoDate(addCalendarDays(start, weekIndex * 7 + day - 1)),
    stops: [],
    serviceMinutes: 0,
    driveMinutes: 0,
    distanceKm: 0,
    totalMinutes: 0,
    provider: 'estimate'
  })));
}

function combinations(values, size, start = 0, picked = [], result = []) {
  if (picked.length === size) { result.push(picked.slice()); return result; }
  for (let index = start; index <= values.length - (size - picked.length); index += 1) { picked.push(values[index]); combinations(values, size, index + 1, picked, result); picked.pop(); }
  return result;
}

function weekdaySpreadPenalty(days) {
  const sorted = [...days].sort((a, b) => a - b);
  if (sorted.length < 2) return 0;
  const idealGap = 7 / sorted.length;
  return sorted.reduce((penalty, day, index) => {
    const next = index === sorted.length - 1 ? sorted[0] + 7 : sorted[index + 1];
    return penalty + ((next - day) - idealGap) ** 2;
  }, 0);
}

function machineSpacingViolations(routes, employee) {
  const visitsByMachine = new Map();
  routes.forEach((route) => route.stops.forEach((stop) => stop.machineIds.forEach((machineId) => {
    const key = String(machineId), visits = visitsByMachine.get(key) || [];
    visits.push(localDate(route.date)); visitsByMachine.set(key, visits);
  })));
  return assignedMachines(employee).reduce((violations, machine) => {
    const visits = (visitsByMachine.get(String(machine.id)) || []).sort((a, b) => a - b);
    if (visits.length < 2) return violations;
    const minimumGapDays = Math.max(1, Math.floor(21 / visits.length));
    for (let index = 1; index < visits.length; index += 1) {
      const gap = Math.round((visits[index] - visits[index - 1]) / 86400000);
      if (gap < minimumGapDays) violations += 1;
    }
    const cycleGap = Math.round((addCalendarDays(visits[0], 21) - visits[visits.length - 1]) / 86400000);
    return violations + (cycleGap < minimumGapDays ? 1 : 0);
  }, 0);
}

function locationSpacingViolations(routes) {
  const visitsByLocation = new Map();
  routes.forEach((route) => route.stops.forEach((stop) => {
    const key = String(stop.locationId), visits = visitsByLocation.get(key) || [];
    visits.push(localDate(route.date)); visitsByLocation.set(key, visits);
  }));
  return [...visitsByLocation.values()].reduce((violations, visits) => {
    visits.sort((a, b) => a - b);
    if (visits.length < 2) return violations;
    const minimumGapDays = Math.max(1, Math.floor(21 / visits.length));
    for (let index = 1; index < visits.length; index += 1) {
      if (Math.round((visits[index] - visits[index - 1]) / 86400000) < minimumGapDays) violations += 1;
    }
    const cycleGap = Math.round((addCalendarDays(visits[0], 21) - visits[visits.length - 1]) / 86400000);
    return violations + (cycleGap < minimumGapDays ? 1 : 0);
  }, 0);
}

function planningSpacingViolations(routes, employee) {
  return machineSpacingViolations(routes, employee) + locationSpacingViolations(routes);
}

function temporalRouteScore(selectedRoutes) {
  if (selectedRoutes.length < 2) return 0;
  const days = selectedRoutes.map((route) => Math.round((localDate(route.date) - localDate(selectedRoutes[0].date)) / 86400000)).sort((a, b) => a - b);
  const idealGap = 21 / days.length, minimumGap = Math.max(1, Math.floor(idealGap));
  return days.reduce((score, day, index) => {
    const next = index === days.length - 1 ? days[0] + 21 : days[index + 1];
    const gap = next - day;
    return score + Math.max(0, minimumGap - gap) * 100000000 + ((gap - idealGap) ** 2) * 10000;
  }, 0);
}

function bestRoutesForMachine(routes, count, location, point, serviceMinutes, settings) {
  const routeSets = combinations(routes, count);
  return routeSets.reduce((best, selectedRoutes) => {
    const operationalScore = selectedRoutes.reduce((score, route) => {
      const existing = route.stops.find((stop) => String(stop.locationId) === String(location.id));
      const geography = existing ? 0 : Math.min(...route.stops.map((stop) => distanceKm(point, [stop.latitude, stop.longitude])), distanceKm(state.depot, point));
      const projectedService = route.serviceMinutes + serviceMinutes;
      const projectedStops = existing ? route.stops : [...route.stops, { latitude: point[0], longitude: point[1] }];
      const projectedDrive = projectedStops.length ? routeLength(projectedStops.map((stop) => [stop.latitude, stop.longitude])) / 55 * 60 : 0;
      const projectedTotal = projectedService + projectedDrive, maximum = Math.max(60, Number(settings.maxHours || 12) * 60);
      const overtime = Math.max(0, projectedTotal - maximum);
      return score + overtime ** 2 * 1000 + projectedTotal ** 2 / maximum * 2 + geography * .7 - (existing ? 35 : 0);
    }, 0);
    const score = temporalRouteScore(selectedRoutes) + operationalScore;
    return !best || score < best.score ? { routes: selectedRoutes, score } : best;
  }, null)?.routes || [];
}

function rhythmCandidates(employee, settings) {
  const available = [...new Set(settings.availableDays || [1, 2, 3, 4, 5])].filter((day) => day >= 1 && day <= 5).sort((a, b) => a - b);
  const highestFrequency = assignedMachines(employee).reduce((maximum, machine) => Math.max(maximum, requiredVisitsMachine(machine.id) / Math.max(1, ownersOfMachine(state.draft, machine.id).length)), 0);
  const minimumDays = Math.min(available.length, Math.max(2, Math.ceil(highestFrequency - .001)));
  const candidates = [];
  for (let size = minimumDays; size <= available.length; size += 1) {
    const variants = combinations(available, size).map((days) => {
      const candidateSettings = { ...settings, recommendedHours: settings.maxHours, weeks: [days.slice(), days.slice(), days.slice()] };
      const routes = buildCycleRoutes(employee, candidateSettings);
      const totals = routeDraftTotals(routes), longest = Math.max(...routes.map((route) => route.totalMinutes), 0);
      const overMaximum = routes.reduce((sum, route) => sum + Math.max(0, route.totalMinutes - settings.maxHours * 60), 0);
      const overFund = Math.max(0, totals.totalHours - employee.weeklyFund * 3) * 60;
      const spacingViolations = planningSpacingViolations(routes, employee), spreadPenalty = weekdaySpreadPenalty(days);
      return { days, routes, totals, longest, spacingViolations, spreadPenalty, penalty: spacingViolations * 1000000000 + overMaximum * 1000000 + overFund * 1000000 + spreadPenalty * 10000 + routes.reduce((sum, route) => sum + route.totalMinutes, 0) };
    }).sort((a, b) => a.penalty - b.penalty);
    if (variants[0]) candidates.push(variants[0]);
  }
  return candidates;
}

function buildCycleRoutes(employee, settings) {
  const routes = cycleDaysFor(employee, settings);
  if (!routes.length) throw new Error('Vyber alespoň jeden jízdní den v tří­týdenním cyklu.');
  const machineDistance = (machine) => { const point = pointOf(state.locations.find((location) => String(location.id) === String(machine.location_id))); return point ? distanceKm(state.depot, point) : -1; };
  const machines = assignedMachines(employee).map((machine) => {
    const owners = ownersOfMachine(state.draft, machine.id);
    return { machine, occurrences: Math.max(1, Math.round(requiredVisitsMachine(machine.id) * 3 / Math.max(1, owners.length))) };
  }).sort((a, b) => b.occurrences - a.occurrences || machineDistance(b.machine) - machineDistance(a.machine));
  const locationPlans = [...machines.reduce((plans, machinePlan) => {
    const key = String(machinePlan.machine.location_id), plan = plans.get(key) || { locationId: key, machines: [], occurrences: 0 };
    plan.machines.push(machinePlan); plan.occurrences = Math.max(plan.occurrences, machinePlan.occurrences); plans.set(key, plan); return plans;
  }, new Map()).values()].sort((a, b) => b.occurrences - a.occurrences || machineDistance(b.machines[0].machine) - machineDistance(a.machines[0].machine));
  locationPlans.forEach((plan) => {
    const location = state.locations.find((item) => String(item.id) === plan.locationId);
    const point = pointOf(location); if (!point) return;
    const visitCount = Math.min(plan.occurrences, routes.length);
    const averageService = plan.machines.reduce((sum, item) => sum + plannedMinutesMachine(item.machine.id) * Math.min(item.occurrences, visitCount), 0) / visitCount;
    const locationRoutes = bestRoutesForMachine(routes, visitCount, location, point, averageService, settings);
    plan.machines.sort((a, b) => b.occurrences - a.occurrences).forEach(({ machine, occurrences }) => {
      const machineRoutes = bestRoutesForMachine(locationRoutes, Math.min(occurrences, locationRoutes.length), location, point, plannedMinutesMachine(machine.id), settings);
      machineRoutes.forEach((route) => {
        let stop = route.stops.find((item) => String(item.locationId) === String(location.id));
        if (!stop) {
          stop = { locationId: String(location.id), name: location.name || 'Lokalita', city: location.city || '', address: location.address || '', latitude: point[0], longitude: point[1], machineIds: [], serviceMinutes: 0 };
          route.stops.push(stop);
        }
        stop.machineIds.push(String(machine.id)); stop.serviceMinutes += plannedMinutesMachine(machine.id); route.serviceMinutes += plannedMinutesMachine(machine.id);
      });
    });
  });
  routes.forEach(estimateRoute);
  return routes;
}

function estimateRoute(route) {
  route.serviceMinutes = route.stops.reduce((sum, stop) => sum + Number(stop.serviceMinutes || 0), 0);
  route.distanceKm = route.stops.length ? routeLength(route.stops.map((stop) => [stop.latitude, stop.longitude])) : 0;
  route.driveMinutes = route.distanceKm / 55 * 60;
  route.totalMinutes = route.serviceMinutes + route.driveMinutes;
  route.provider = 'estimate';
  return route;
}

async function calculateRoadRoute(route, settings) {
  if (!route.stops.length) return estimateRoute(route);
  if (route.stops.length > 25) throw new Error(`${dayLabel(route.date)} má ${route.stops.length} zastávek. Přesuň část lokalit do jiného dne.`);
  const departure = new Date(`${route.date}T${settings.startTime}:00`);
  const response = await supabase.functions.invoke('google-route-plan', { body: {
    origin: { latitude: state.depot[0], longitude: state.depot[1], label: 'Sklad Blučina' },
    stops: route.stops.map((stop) => ({ id: stop.locationId, locationId: stop.locationId, name: stop.name, city: stop.city, address: stop.address, latitude: stop.latitude, longitude: stop.longitude, estimatedServiceMinutes: stop.serviceMinutes })),
    returnToStart: true,
    departureTime: departure.toISOString()
  } });
  if (response.error || response.data?.error) throw new Error(response.data?.error || response.error?.message || 'Google Routes trasu nevrátil.');
  const data = response.data;
  const byId = new Map(route.stops.map((stop) => [String(stop.locationId), stop]));
  const ordered = (data.orderedStops || []).map((stop) => byId.get(String(stop.locationId || stop.id))).filter(Boolean);
  if (ordered.length === route.stops.length) route.stops = ordered;
  route.distanceKm = Number(data.route?.distanceMeters || 0) / 1000;
  route.driveMinutes = Number(data.route?.durationSeconds || data.route?.staticDurationSeconds || 0) / 60;
  route.serviceMinutes = route.stops.reduce((sum, stop) => sum + Number(stop.serviceMinutes || 0), 0);
  route.totalMinutes = route.serviceMinutes + route.driveMinutes;
  route.provider = 'google_routes';
  return route;
}

async function calculateRoadRoutes(routes, settings, requestId, onlyKeys = null) {
  const targets = routes.filter((route) => route.stops.length && (!onlyKeys || onlyKeys.has(route.key)));
  for (let index = 0; index < targets.length; index += 3) {
    if (requestId !== state.routeRequestId) return;
    const batch = targets.slice(index, index + 3);
    $('routeProgressText').textContent = `Ověřuji silniční trasy ${Math.min(index + 3, targets.length)} / ${targets.length}…`;
    await Promise.all(batch.map((route) => calculateRoadRoute(route, settings)));
  }
}

function machineNames(machineIds) {
  return machineIds.map((id) => {
    const machine = state.machines.find((item) => String(item.id) === String(id));
    return machine ? `${machine.evidence_number ? `EV ${machine.evidence_number} · ` : ''}${kindOf(machine)}` : 'Automat';
  }).join(', ');
}

function routeDraftTotals(routes) {
  return {
    totalHours: routes.reduce((sum, route) => sum + route.totalMinutes, 0) / 60,
    totalKm: routes.reduce((sum, route) => sum + route.distanceKm, 0),
    driveHours: routes.reduce((sum, route) => sum + route.driveMinutes, 0) / 60,
    serviceHours: routes.reduce((sum, route) => sum + route.serviceMinutes, 0) / 60
  };
}

function renderRouteResults(employee) {
  const draft = state.routeDrafts.get(String(employee.id));
  if (!draft) {
    $('routeResults').innerHTML = '<div class="route-empty"><div><b>Zatím bez automatického návrhu</b>Klikni na „Navrhnout nejlepší variantu“. Program sám porovná možné pracovní rytmy a ověří vítěznou variantu přes Google Routes.</div></div>';
    $('saveRouteDraft').disabled = true; return;
  }
  const settings = scheduleFor(employee), totals = routeDraftTotals(draft.routes), cycleFund = Number(employee.weeklyFund) * 3;
  const hardDays = draft.routes.filter((route) => route.totalMinutes > settings.maxHours * 60).length;
  const spacingViolations = planningSpacingViolations(draft.routes, employee);
  const softDays = draft.routes.filter((route) => route.totalMinutes > settings.recommendedHours * 60 && route.totalMinutes <= settings.maxHours * 60).length;
  const budgetClass = totals.totalHours > cycleFund ? 'bad' : totals.totalHours > cycleFund * .92 ? 'warn' : '';
  const hardClass = hardDays ? 'bad' : softDays ? 'warn' : '';
  const routeOptions = draft.routes.map((route) => `<option value="${esc(route.key)}">${esc(dayLabel(route.date))} · ${minutesLabel(route.totalMinutes)}</option>`).join('');
  const weeks = [0, 1, 2].map((weekIndex) => {
    const routes = draft.routes.filter((route) => route.weekIndex === weekIndex), weekMinutes = routes.reduce((sum, route) => sum + route.totalMinutes, 0);
    return `<details class="route-week" ${weekIndex === 0 ? 'open' : ''}><summary class="route-week-title"><h3>Týden ${weekIndex + 1}</h3><span>${routes.length} jízdní ${routes.length === 1 ? 'den' : routes.length < 5 ? 'dny' : 'dnů'} · ${minutesLabel(weekMinutes)} · ${Math.round(routes.reduce((sum, route) => sum + route.distanceKm, 0))} km</span></summary><div class="route-days">${routes.map((route) => {
      const hard = route.totalMinutes > settings.maxHours * 60, soft = !hard && route.totalMinutes > settings.recommendedHours * 60;
      return `<details class="route-day ${hard ? 'hard' : soft ? 'soft' : ''} ${route.stops.length ? '' : 'empty'}" data-route-date="${esc(route.date)}"><summary class="route-day-head"><div><b>${esc(dayLabel(route.date))}</b><small>${route.stops.length} lokalit · ${settings.startTime} · sklad → trasa → sklad</small></div><div class="route-day-time"><strong class="${hard ? 'hard-text' : soft ? 'soft-text' : ''}">${minutesLabel(route.totalMinutes)}</strong><small>${Math.round(route.distanceKm)} km · cesta ${minutesLabel(route.driveMinutes)}</small></div></summary><div class="route-stop-list">${route.stops.length ? route.stops.map((stop, index) => `<div class="route-stop"><span class="route-stop-index">${index + 1}</span><span><b>${esc(stop.name)}</b><small>${esc(machineNames(stop.machineIds))}<br>obsluha ${Math.round(stop.serviceMinutes)} min</small><select class="move-stop" data-route-key="${esc(route.key)}" data-location-id="${esc(stop.locationId)}"><option value="">Přesunout do jiného dne…</option>${routeOptions}</select></span></div>`).join('') : '<div class="route-day-empty">Volný den bez trasy</div>'}</div></details>`;
    }).join('')}</div></details>`;
  }).join('');
  const activeRoutes = draft.routes.filter((route) => route.stops.length), average = activeRoutes.length ? totals.totalHours / activeRoutes.length : 0, longest = Math.max(...activeRoutes.map((route) => route.totalMinutes), 0);
  $('routeResults').innerHTML = `<div class="route-recommendation ${spacingViolations ? 'bad' : ''}"><div><b>Doporučuji ${draft.rhythmDays} jízdní ${draft.rhythmDays === 1 ? 'den' : draft.rhythmDays < 5 ? 'dny' : 'dnů'} týdně</b><p>${spacingViolations ? `Pozor: ${spacingViolations} opakovaných návštěv je příliš blízko po sobě. Přesuň je do vzdálenějšího dne.` : `Opakované návštěvy jsou rozložené v týdnu; četnost 2× týdně není naplánovaná ve dvou sousedních dnech.`} Jednotlivé týdny se mohou lišit podle četností automatů.</p></div><span class="pill">průměr ${number(average)} h/den · nejdelší ${minutesLabel(longest)}</span></div><div class="cycle-summary"><div class="cycle-kpi ${budgetClass}"><span>Celý 3týdenní cyklus</span><b>${number(totals.totalHours)} / ${number(cycleFund)} h</b></div><div class="cycle-kpi"><span>Silniční vzdálenost</span><b>${Math.round(totals.totalKm)} km</b></div><div class="cycle-kpi"><span>Cesta / obsluha</span><b>${number(totals.driveHours)} / ${number(totals.serviceHours)} h</b></div><div class="cycle-kpi ${hardClass}"><span>Denní limity</span><b>${hardDays ? `${hardDays} nad maximum` : softDays ? `${softDays} delší směny` : 'bez překročení'}</b></div></div>${weeks}<div class="route-provider">Silniční km a čas: Google Routes · obsluha: součet nastavených minut jednotlivých automatů · bez skrytých koeficientů</div>`;
  $('saveRouteDraft').disabled = false;
  document.querySelectorAll('.move-stop').forEach((select) => select.addEventListener('change', () => { if (select.value) moveRouteStop(employee, select.dataset.routeKey, select.dataset.locationId, select.value); }));
}

function renderAvailableDays(employee) {
  const settings = scheduleFor(employee), available = new Set(settings.availableDays || [1, 2, 3, 4, 5]);
  $('availableDays').innerHTML = weekDayLabels.map((label, index) => `<button type="button" class="day-switch ${available.has(index + 1) ? 'on' : ''}" data-available-day="${index + 1}">${label}</button>`).join('');
  document.querySelectorAll('[data-available-day]').forEach((button) => button.addEventListener('click', () => {
    const day = Number(button.dataset.availableDay), next = new Set(settings.availableDays || [1, 2, 3, 4, 5]);
    if (next.has(day)) { if (next.size <= 2) return say('Pro automatický výpočet nech alespoň dva možné dny.', true); next.delete(day); } else next.add(day);
    settings.availableDays = [...next].sort((a, b) => a - b); settings.weeks = [[], [], []]; state.routeDrafts.delete(String(employee.id)); markDirty(false); renderAvailableDays(employee); renderRouteResults(employee); renderPeople();
  }));
}

function renderRouteStage(employee) {
  const settings = scheduleFor(employee);
  $('routeTitle').textContent = `Trasy · ${nameOf(employee)}`;
  $('routeSubtitle').textContent = `Rajón obsahuje ${assignedMachines(employee).length} automatů. Program sám vybere nejvhodnější rytmus a fond vyhodnotí za celý tří­týdenní cyklus.`;
  $('routeWeeklyFund').value = employee.weeklyFund;
  $('routeStartTime').value = settings.startTime || '06:00';
  $('routeMaxHours').value = settings.maxHours || 12;
  $('routeCycleStart').value = settings.cycleStart || nextMondayValue();
  renderAvailableDays(employee); renderRouteResults(employee);
}

function openRouteStage() {
  const employee = selectedEmployee();
  if (!employee) return say('Nejdřív vyber člověka.', true);
  if (!assignedMachines(employee).length) return say('Tomuto člověku nejdřív přiděl alespoň jeden automat.', true);
  state.planningEmployeeId = String(employee.id); $('routeStage').hidden = false; renderRouteStage(employee); $('routeStage').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function syncRouteSettings(employee, validate = false) {
  const settings = scheduleFor(employee);
  employee.weeklyFund = Math.max(1, Math.min(80, Number($('routeWeeklyFund').value) || employee.weeklyFund));
  settings.startTime = $('routeStartTime').value || '06:00';
  settings.maxHours = Number($('routeMaxHours').value) || 12;
  settings.cycleStart = $('routeCycleStart').value || nextMondayValue();
  settings.availableDays = settings.availableDays?.length ? settings.availableDays : [1, 2, 3, 4, 5];
  if (validate) {
    if (settings.maxHours < 1 || settings.maxHours > 16) throw new Error('Nejvyšší možný den musí být mezi 1 a 16 hodinami.');
    if (settings.availableDays.length < 2) throw new Error('Pro automatický výpočet musí zůstat alespoň dva možné dny.');
  }
  return settings;
}

async function generateRoutes() {
  const employee = employeeById(state.planningEmployeeId); if (!employee) return;
  let settings;
  try { settings = syncRouteSettings(employee, true); } catch (error) { return say(error.message, true); }
  const requestId = ++state.routeRequestId;
  $('routeProgress').hidden = false; $('generateRoutes').disabled = true; $('routeProgressText').textContent = 'Rozděluji návštěvy mezi pracovní dny…';
  try {
    const candidates = rhythmCandidates(employee, settings);
    if (!candidates.length) throw new Error('V povolených dnech nelze sestavit žádnou variantu.');
    let selected = null, lastError = null;
    for (let index = 0; index < candidates.length; index += 1) {
      const candidate = candidates[index]; settings.weeks = [candidate.days.slice(), candidate.days.slice(), candidate.days.slice()];
      $('routeProgressText').textContent = `Ověřuji variantu ${candidate.days.length} jízdních dnů týdně…`;
      try {
        await calculateRoadRoutes(candidate.routes, settings, requestId);
        if (requestId !== state.routeRequestId) return;
        const totals = routeDraftTotals(candidate.routes), hardDays = candidate.routes.filter((route) => route.totalMinutes > settings.maxHours * 60).length;
        const spacingViolations = planningSpacingViolations(candidate.routes, employee);
        const overtimeMinutes = candidate.routes.reduce((sum, route) => sum + Math.max(0, route.totalMinutes - settings.maxHours * 60), 0);
        const fundOvertimeMinutes = Math.max(0, totals.totalHours - employee.weeklyFund * 3) * 60;
        const selectionScore = spacingViolations * 1000000000000 + overtimeMinutes * 100000000 + fundOvertimeMinutes * 1000000 + candidate.routes.reduce((sum, route) => sum + route.totalMinutes ** 2, 0);
        const evaluated = { ...candidate, routes: candidate.routes, totals, hardDays, spacingViolations, overtimeMinutes, selectionScore };
        if (!selected || evaluated.selectionScore < selected.selectionScore) selected = evaluated;
        if (!spacingViolations && !hardDays && totals.totalHours <= employee.weeklyFund * 3) break;
      } catch (error) { lastError = error; }
    }
    if (!selected) throw lastError || new Error('Silniční trasy nelze sestavit.');
    const routes = selected.routes;
    if (requestId !== state.routeRequestId) return;
    const totals = routeDraftTotals(routes);
    const activeRoutes = routes.filter((route) => route.stops.length);
    settings.recommendedHours = Math.min(settings.maxHours, Math.ceil((totals.totalHours / Math.max(1, activeRoutes.length)) * 2) / 2);
    state.routeDrafts.set(String(employee.id), { routes, rhythmDays: selected.days.length, spacingViolations: selected.spacingViolations, generatedAt: new Date().toISOString(), ...totals });
    markDirty(false); renderPeople(); renderRouteResults(employee);
    const hardDays = routes.filter((route) => route.totalMinutes > settings.maxHours * 60).length;
    say(selected.spacingViolations ? `Návrh má ještě ${selected.spacingViolations} návštěv příliš blízko po sobě. Rajón bude potřeba upravit.` : hardDays ? `Nejlepší nalezená varianta má ještě ${hardDays} směn nad maximem. Rajón bude potřeba upravit.` : `Doporučený rytmus: ${selected.days.length} jízdní dny týdně. Opakované návštěvy mají správný rozestup a trasy jsou ověřené po silnici.`, selected.spacingViolations > 0 || hardDays > 0);
  } catch (error) { console.error(error); say(`Trasy nelze spočítat: ${error.message || error}`, true); }
  finally { if (requestId === state.routeRequestId) { $('routeProgress').hidden = true; $('generateRoutes').disabled = false; } }
}

async function moveRouteStop(employee, sourceKey, locationId, targetKey) {
  if (sourceKey === targetKey) return;
  const draft = state.routeDrafts.get(String(employee.id)), settings = scheduleFor(employee); if (!draft) return;
  const source = draft.routes.find((route) => route.key === sourceKey), target = draft.routes.find((route) => route.key === targetKey); if (!source || !target) return;
  const index = source.stops.findIndex((stop) => String(stop.locationId) === String(locationId)); if (index < 0) return;
  const moved = source.stops.splice(index, 1)[0], existing = target.stops.find((stop) => String(stop.locationId) === String(locationId));
  if (existing) { existing.machineIds = [...new Set([...existing.machineIds, ...moved.machineIds])]; existing.serviceMinutes += moved.serviceMinutes; } else target.stops.push(moved);
  estimateRoute(source); estimateRoute(target); const requestId = ++state.routeRequestId;
  $('routeProgress').hidden = false; $('routeProgressText').textContent = 'Přepočítávám dva změněné dny…';
  try {
    await calculateRoadRoutes(draft.routes, settings, requestId, new Set([sourceKey, targetKey]));
    Object.assign(draft, routeDraftTotals(draft.routes), { generatedAt: new Date().toISOString() }); markDirty(false); renderPeople(); renderRouteResults(employee); say('Lokalita byla přesunuta a oba dny jsou znovu spočítané po silnici.');
  } catch (error) { say(`Přesun se nepodařilo ověřit: ${error.message || error}`, true); }
  finally { if (requestId === state.routeRequestId) $('routeProgress').hidden = true; }
}

function markDirty(clearRoutes = true) { if (clearRoutes) state.routeDrafts.clear(); state.dirty = true; $('saveDraft').textContent = 'Uložit návrh'; }
function snapshot() { return { version: 11, savedAt: new Date().toISOString(), machineAssignments: Object.fromEntries([...state.draft].map(([id, owners]) => [id, [...owners]])), requiredVisitsByMachine: Object.fromEntries(state.requiredVisits), plannedMachineMinutes: Object.fromEntries(state.plannedMachineMinutes), funds: Object.fromEntries(state.employees.map((employee) => [employee.id, employee.weeklyFund])), included: Object.fromEntries(state.employees.map((employee) => [employee.id, employee.included])), scheduleSettings: Object.fromEntries(state.scheduleSettings), routeDrafts: Object.fromEntries(state.routeDrafts) }; }
function saveDraft() { localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot())); state.dirty = false; $('saveDraft').textContent = 'Uloženo ✓'; say('Návrh je uložen jen v tomto prohlížeči. Ostré rajóny se nezměnily.'); }

function loadDraft() {
  try {
    localStorage.removeItem('olvend-territory-planner-draft-v1'); localStorage.removeItem('olvend-territory-planner-draft-v2');
    const legacy = LEGACY_STORAGE_KEYS.map((key) => localStorage.getItem(key)).find(Boolean);
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || legacy || 'null'); if (![3, 4, 5, 6, 7, 8, 9, 10, 11].includes(saved?.version)) return false;
    state.employees.forEach((employee) => { if (Number(saved.funds?.[employee.id]) > 0) employee.weeklyFund = Number(saved.funds[employee.id]); if (typeof saved.included?.[employee.id] === 'boolean') employee.included = saved.included[employee.id]; });
    Object.entries(saved.machineAssignments || {}).forEach(([machineId, owners]) => { if (state.machines.some((machine) => String(machine.id) === String(machineId))) state.draft.set(String(machineId), new Set((owners || []).filter((id) => employeeById(id)?.included))); });
    if (saved.version >= 4) Object.entries(saved.requiredVisitsByMachine || {}).forEach(([machineId, visits]) => state.requiredVisits.set(String(machineId), Math.max(.1, Number(visits) || .1)));
    else Object.entries(saved.requiredVisits || {}).forEach(([locationId, visits]) => machinesAt(locationId).forEach((machine) => state.requiredVisits.set(String(machine.id), Math.max(.1, Number(visits) || .1))));
    if (saved.version >= 6) Object.entries(saved.plannedMachineMinutes || {}).forEach(([machineId, minutes]) => state.plannedMachineMinutes.set(String(machineId), Math.max(1, Math.min(180, Number(minutes) || 20))));
    if (saved.version >= 11) {
      Object.entries(saved.scheduleSettings || {}).forEach(([employeeId, settings]) => { if (employeeById(employeeId) && Array.isArray(settings?.weeks)) state.scheduleSettings.set(String(employeeId), settings); });
      Object.entries(saved.routeDrafts || {}).forEach(([employeeId, draft]) => { if (employeeById(employeeId) && Array.isArray(draft?.routes)) state.routeDrafts.set(String(employeeId), draft); });
    }
    return true;
  } catch (_) { return false; }
}

function resetDraft() {
  if (state.dirty && !confirm('Zahodit neuložené úpravy tohoto návrhu?')) return;
  localStorage.removeItem(STORAGE_KEY);
  LEGACY_STORAGE_KEYS.forEach((key) => localStorage.removeItem(key));
  state.employees.forEach((employee) => { employee.weeklyFund = defaultFund(employee); employee.included = !/david\s+boudný/i.test(nameOf(employee)); });
  state.draft = new Map(state.machines.map((machine) => [String(machine.id), new Set()]));
  state.requiredVisits = new Map(state.machines.map((machine) => [String(machine.id), recommendationForMachine(machine).visits]));
  state.plannedMachineMinutes = new Map(state.machines.map((machine) => [String(machine.id), 20]));
  state.scheduleSettings = new Map(); state.routeDrafts = new Map(); state.planningEmployeeId = null; $('routeStage').hidden = true;
  state.selectedLocationId = null; state.selectedMachineIds = new Set(); state.dirty = false; renderAll(); say('Čistý návrh je připraven. Mapa neobsahuje žádné předvyplněné rajóny.');
}

function applyAssignment(shared) {
  const employee = selectedEmployee(), location = state.locations.find((item) => String(item.id) === String(state.selectedLocationId));
  if (!employee || !location) return say('Nejdřív vyber člověka a lokalitu.', true);
  if (!state.selectedMachineIds.size) return say('Vyber alespoň jeden automat.', true);
  state.selectedMachineIds.forEach((machineId) => { const owners = shared ? new Set(ownersOfMachine(state.draft, machineId)) : new Set(); owners.add(String(employee.id)); state.draft.set(String(machineId), owners); });
  markDirty(); renderAll(); say(shared ? `${employee.name} je přidán jako výpomoc pro ${state.selectedMachineIds.size} strojů.` : `${state.selectedMachineIds.size} strojů bylo přiděleno: ${nameOf(employee)}.`);
}

function removeSelected() {
  const location = state.locations.find((item) => String(item.id) === String(state.selectedLocationId)); if (!location) return;
  const ids = state.selectedMachineIds.size ? state.selectedMachineIds : new Set(machinesAt(location.id).map((machine) => String(machine.id)));
  ids.forEach((machineId) => state.draft.set(String(machineId), new Set()));
  markDirty(); renderAll(); say(`${ids.size} strojů bylo z návrhu odebráno.`);
}

function pointInPolygon(point, polygon) {
  const x = point[1], y = point[0]; let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) { const xi = polygon[i][1], yi = polygon[i][0], xj = polygon[j][1], yj = polygon[j][0]; if (((yi > y) !== (yj > y)) && x < (xj - xi) * (y - yi) / ((yj - yi) || .000001) + xi) inside = !inside; }
  return inside;
}

function setDrawing(active) {
  state.drawing = active; $('mapWrap').classList.toggle('drawing', active); $('drawArea').hidden = active; $('finishArea').hidden = !active; $('cancelArea').hidden = !active;
  if (!active) { state.drawPoints = []; state.drawLayer?.remove(); state.drawLayer = null; }
}

function finishDrawing() {
  if (state.drawPoints.length < 3) return say('Pro oblast klikni do mapy alespoň třikrát.', true);
  const locations = state.locations.filter((location) => pointInPolygon(pointOf(location), state.drawPoints)); const employee = selectedEmployee();
  if (!locations.length) return say('V oblasti není žádná lokalita se strojem.', true);
  if (!confirm(`Přidělit všechny stroje v ${locations.length} lokalitách člověku ${nameOf(employee)}?`)) return;
  locations.forEach((location) => machinesAt(location.id).forEach((machine) => state.draft.set(String(machine.id), new Set([String(employee.id)])))); setDrawing(false); markDirty(); renderAll();
}

map.on('click', (event) => {
  if (!state.drawing) return; state.drawPoints.push([event.latlng.lat, event.latlng.lng]); state.drawLayer?.remove();
  state.drawLayer = state.drawPoints.length >= 3 ? L.polygon(state.drawPoints, { color: selectedEmployee()?.color || '#d5101a', weight: 3, fillOpacity: .08 }).addTo(map) : L.polyline(state.drawPoints, { color: selectedEmployee()?.color || '#d5101a', weight: 3 }).addTo(map);
});

async function loadVisitHistory() {
  const since = new Date(); since.setDate(since.getDate() - 91);
  state.visitDates = new Map(); state.lastVisits = new Map(); state.locationVisitDates = new Map(); state.lastLocationVisits = new Map();
  state.visitDurationSamples = new Map(); state.actualVisitMinutes = new Map();
  state.machineDurationSamples = new Map(); state.actualMachineMinutes = new Map();
  const plans = await supabase.from('route_plans').select('id,title,route_payload,execution_status,planning_date').gte('planning_date', since.toISOString().slice(0, 10)).eq('execution_status', 'done');
  if (plans.error) throw plans.error;
  const validPlans = (plans.data || []).filter((plan) => plan.route_payload?.test_mode !== true && !/^\s*\[?TEST/i.test(String(plan.title || '')));
  const planDates = new Map(validPlans.map((plan) => [String(plan.id), plan.planning_date]));
  const machineLocations = new Map(state.machines.map((machine) => [String(machine.id), String(machine.location_id)]));
  const durationKeys = new Set(), spanGroups = new Map();
  const record = (machineId, locationId, date) => {
    if (!date) return;
    const machineKey = machineId ? String(machineId) : null;
    const locationKey = locationId ? String(locationId) : machineLocations.get(machineKey);
    if (machineKey) {
      if (!state.visitDates.has(machineKey)) state.visitDates.set(machineKey, new Set());
      state.visitDates.get(machineKey).add(date);
      if (!state.lastVisits.get(machineKey) || date > state.lastVisits.get(machineKey)) state.lastVisits.set(machineKey, date);
    }
    if (locationKey) {
      if (!state.locationVisitDates.has(locationKey)) state.locationVisitDates.set(locationKey, new Set());
      state.locationVisitDates.get(locationKey).add(date);
      if (!state.lastLocationVisits.get(locationKey) || date > state.lastLocationVisits.get(locationKey)) state.lastLocationVisits.set(locationKey, date);
    }
  };
  const recordDuration = (stop) => {
    const locationKey = stop.location_id ? String(stop.location_id) : machineLocations.get(String(stop.machine_id || ''));
    const machineKey = stop.machine_id ? String(stop.machine_id) : null;
    if (!locationKey || !machineKey || !stop.arrived_at || !stop.completed_at) return;
    const minutes = (new Date(stop.completed_at) - new Date(stop.arrived_at)) / 60000;
    const key = `${stop.route_plan_id}:${machineKey}`;
    if (!durationKeys.has(key) && Number.isFinite(minutes) && minutes >= 2 && minutes <= 180) {
      durationKeys.add(key);
      if (!state.machineDurationSamples.has(machineKey)) state.machineDurationSamples.set(machineKey, []);
      state.machineDurationSamples.get(machineKey).push(minutes);
    }
    const spanKey = `${stop.route_plan_id}:${locationKey}`;
    const arrived = new Date(stop.arrived_at).getTime(), completed = new Date(stop.completed_at).getTime();
    const group = spanGroups.get(spanKey) || { locationKey, first: arrived, last: completed, machineIds: new Set() };
    group.first = Math.min(group.first, arrived); group.last = Math.max(group.last, completed); group.machineIds.add(machineKey); spanGroups.set(spanKey, group);
  };
  const ids = validPlans.map((plan) => plan.id);
  // API vrací nejvýše 1 000 řádků. Velká dávka dříve u všech lokalit odřízla nejnovější návštěvy.
  for (let index = 0; index < ids.length; index += 15) {
    const chunk = ids.slice(index, index + 15);
    const [visits, stops] = await Promise.all([
      supabase.from('route_machine_visits').select('route_plan_id,machine_id,visit_date,status,completed_at').in('route_plan_id', chunk).eq('status', 'completed'),
      supabase.from('route_plan_stops').select('route_plan_id,machine_id,location_id,status,arrived_at,completed_at').in('route_plan_id', chunk).in('status', ['done', 'completed'])
    ]);
    if (visits.error) throw visits.error;
    if (stops.error) throw stops.error;
    (visits.data || []).forEach((visit) => record(visit.machine_id, null, visit.completed_at?.slice(0, 10) || visit.visit_date || planDates.get(String(visit.route_plan_id))));
    (stops.data || []).forEach((stop) => { record(stop.machine_id, stop.location_id, stop.completed_at?.slice(0, 10) || planDates.get(String(stop.route_plan_id))); recordDuration(stop); });
  }
  spanGroups.forEach((group) => {
    const activeIds = machinesAt(group.locationKey).map((machine) => String(machine.id));
    if (!activeIds.length || !activeIds.every((id) => group.machineIds.has(id))) return;
    const minutes = (group.last - group.first) / 60000;
    if (!Number.isFinite(minutes) || minutes < 2 || minutes > 240) return;
    if (!state.visitDurationSamples.has(group.locationKey)) state.visitDurationSamples.set(group.locationKey, []);
    state.visitDurationSamples.get(group.locationKey).push(minutes);
  });
  state.machineDurationSamples.forEach((values, machineId) => state.actualMachineMinutes.set(machineId, median(values)));
  state.fallbackMachineMinutes = median([...state.machineDurationSamples.values()].flat()) || 20;
  state.visitDurationSamples.forEach((values, locationId) => state.actualVisitMinutes.set(locationId, median(values)));
}

function buildAssignments(rows) {
  const byLocation = new Map((rows || []).map((row) => [String(row.location_id), row])); const result = new Map();
  state.machines.forEach((machine) => {
    const row = byLocation.get(String(machine.location_id)), owners = new Set(), selected = Array.isArray(row?.selected_machine_ids) ? row.selected_machine_ids.map(String) : [];
    const scoped = /selected|machine|stroj/i.test(String(row?.assignment_scope || '')) && selected.length;
    if (row?.primary_employee_id && (!scoped || selected.includes(String(machine.id)))) owners.add(String(row.primary_employee_id));
    else if (row?.backup_employee_id && scoped) owners.add(String(row.backup_employee_id));
    result.set(String(machine.id), owners);
  }); return result;
}

function renderAll() { renderPeople(); renderPaintMode(); renderLegend(); renderMap(); renderSummary(); }

async function load() {
  await requireManager();
  const [employees, locations, machines, assignments] = await Promise.all([
    supabase.from('employees').select('id,name,surname,role,active,contracted_weekly_hours').eq('active', true).order('surname'),
    supabase.from('locations').select('id,name,city,address,latitude,longitude,active').eq('active', true).order('name'),
    supabase.from('machines').select('id,location_id,evidence_number,name,machine_type,active,status').eq('active', true),
    supabase.rpc('get_operator_territories_v51', { p_date: new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Prague', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date()) })
  ]);
  const failed = [employees, locations, machines, assignments].find((result) => result.error); if (failed) throw failed.error;
  state.employees = (employees.data || []).filter((employee) => /operator|operátor/i.test(String(employee.role || '')) || String(employee.id) === MICHAL_ID).map((employee, index) => ({ ...employee, color: colorFor(employee, index), weeklyFund: defaultFund(employee), included: !/david\s+boudný/i.test(nameOf(employee)) }));
  state.machines = (machines.data || []).filter((machine) => machine.location_id && !/warehouse|sklad|reserve|rezerv/i.test(String(machine.status || '')));
  const allLocations = (locations.data || []).filter(pointOf), depot = allLocations.find((location) => /olmika/i.test(String(location.name)) && /blu/i.test(String(location.city)));
  state.depot = pointOf(depot) || DEPOT_FALLBACK; state.locations = allLocations.filter((location) => machinesAt(location.id).length > 0);
  state.current = buildAssignments(assignments.data);
  state.draft = new Map(state.machines.map((machine) => [String(machine.id), new Set()]));
  await loadVisitHistory();
  state.requiredVisits = new Map(state.machines.map((machine) => [String(machine.id), recommendationForMachine(machine).visits]));
  state.plannedMachineMinutes = new Map(state.machines.map((machine) => [String(machine.id), 20]));
  const restored = loadDraft(); state.selectedEmployeeId = activeEmployees()[0]?.id || null;
  renderAll(); renderMap(true); $('loading').hidden = true; if (restored) say('Načetl jsem poslední uložený pracovní návrh.');
}

$('saveDraft').addEventListener('click', saveDraft); $('resetDraft').addEventListener('click', resetDraft);
$('assignSelected').addEventListener('click', () => applyAssignment(false)); $('shareSelected').addEventListener('click', () => applyAssignment(true)); $('removeSelected').addEventListener('click', removeSelected);
$('planSelectedEmployee').addEventListener('click', openRouteStage); $('generateRoutes').addEventListener('click', generateRoutes);
$('closeRouteStage').addEventListener('click', () => { state.routeRequestId += 1; $('routeStage').hidden = true; document.querySelector('.workspace')?.scrollIntoView({ behavior: 'smooth', block: 'start' }); });
$('saveRouteDraft').addEventListener('click', () => { const employee = employeeById(state.planningEmployeeId); if (employee) syncRouteSettings(employee); saveDraft(); });
['routeWeeklyFund', 'routeStartTime', 'routeMaxHours', 'routeCycleStart'].forEach((id) => $(id).addEventListener('change', () => {
  const employee = employeeById(state.planningEmployeeId); if (!employee) return;
  syncRouteSettings(employee); state.routeDrafts.delete(String(employee.id)); markDirty(false); renderRouteStage(employee); renderPeople(); renderSummary();
}));
$('toggleComparison').addEventListener('click', () => { state.showComparison = !state.showComparison; $('toggleComparison').textContent = state.showComparison ? 'Skrýt současný stav' : 'Porovnat se současným stavem'; renderSummary(); });
$('fitMap').addEventListener('click', () => renderMap(true)); $('drawArea').addEventListener('click', () => selectedEmployee() ? setDrawing(true) : say('Nejdřív vyber člověka.', true)); $('finishArea').addEventListener('click', finishDrawing); $('cancelArea').addEventListener('click', () => setDrawing(false));
$('showDetails').addEventListener('click', () => { $('summary').classList.toggle('open'); $('showDetails').textContent = $('summary').classList.contains('open') ? 'Skrýt výpočet' : 'Jak se počítají km a hodiny'; });
$('openCurrent').addEventListener('click', () => { location.href = 'operator-territories.html'; });
window.addEventListener('beforeunload', (event) => { if (state.dirty) { event.preventDefault(); event.returnValue = ''; } });

load().catch((error) => { console.error(error); $('loading').hidden = true; say(`Data nelze načíst: ${error.message || error}`, true); });
