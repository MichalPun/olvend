import { supabase } from './supabase.js';

const STORAGE_KEY = 'olvend-territory-planner-draft-v5';
const LEGACY_STORAGE_KEYS = ['olvend-territory-planner-draft-v4', 'olvend-territory-planner-draft-v3'];
const MICHAL_ID = 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
const DEPOT_FALLBACK = [49.054, 16.646];
const palette = ['#3478bf', '#258463', '#7d62ad', '#d5101a', '#b46b00', '#00838f'];
const state = {
  employees: [], locations: [], machines: [], current: new Map(), draft: new Map(),
  visitDates: new Map(), lastVisits: new Map(), locationVisitDates: new Map(), lastLocationVisits: new Map(),
  visitDurationSamples: new Map(), actualVisitMinutes: new Map(), plannedVisitMinutes: new Map(), fallbackVisitMinutes: 20,
  requiredVisits: new Map(), markers: new Map(), depot: DEPOT_FALLBACK,
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

function plannedMinutesLocation(locationId) {
  return Math.max(1, Number(state.plannedVisitMinutes.get(String(locationId)) || state.actualVisitMinutes.get(String(locationId)) || state.fallbackVisitMinutes));
}

function serviceWeight(machine) {
  return /Potravin/.test(kindOf(machine)) ? 1.25 : 1;
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

function routeDays(employee) { return Math.max(1, Math.min(5, Math.round(Number(employee.weeklyFund || 1) / 12))); }

function employeeFrequency(assignments, employeeId, locationId) {
  return machinesAt(locationId).reduce((maximum, machine) => {
    const owners = ownersOfMachine(assignments, machine.id);
    if (!owners.some((id) => String(id) === String(employeeId))) return maximum;
    return Math.max(maximum, requiredVisitsMachine(machine.id) / Math.max(1, owners.length));
  }, 0);
}

function weeklyKm(employee, assignments) {
  const days = routeDays(employee);
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
  });
  locations.forEach((locationId) => {
    const machines = machinesAt(locationId);
    const totalWeight = machines.reduce((sum, machine) => sum + serviceWeight(machine), 0) || 1;
    const weeklyShare = machines.reduce((sum, machine) => {
      const owners = ownersOfMachine(assignments, machine.id);
      if (!owners.some((id) => String(id) === String(employee.id))) return sum;
      return sum + serviceWeight(machine) * requiredVisitsMachine(machine.id) / Math.max(1, owners.length);
    }, 0);
    service += plannedMinutesLocation(locationId) / 60 * weeklyShare / totalWeight;
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
    const initials = `${employee.name?.[0] || ''}${employee.surname?.[0] || ''}`.toUpperCase() || '—';
    return `<button class="person ${String(employee.id) === String(state.selectedEmployeeId) ? 'active' : ''} ${employee.included ? '' : 'excluded'}" data-employee-id="${esc(employee.id)}" style="--person:${employee.color}"><span class="avatar">${esc(initials)}</span><span><b>${esc(nameOf(employee))}</b><small>${number(item.hours)} h · ${Math.round(item.km)} km týdně</small><label class="include-row"><input class="include-input" data-include-id="${esc(employee.id)}" type="checkbox" ${employee.included ? 'checked' : ''}> zahrnout do návrhu</label></span><span class="fund"><span><input class="fund-input" data-fund-id="${esc(employee.id)}" type="number" min="1" max="80" value="${employee.weeklyFund}" ${employee.included ? '' : 'disabled'}> h</span><small>týdně</small></span></button>`;
  }).join('');
  document.querySelectorAll('.person').forEach((button) => button.addEventListener('click', (event) => {
    if (event.target.closest('input')) return;
    const employee = employeeById(button.dataset.employeeId);
    if (!employee?.included) return say('Nejdřív tohoto člověka zařaď do návrhu.', true);
    state.selectedEmployeeId = employee.id; renderPeople(); renderPaintMode(); renderSummary();
  }));
  document.querySelectorAll('.fund-input').forEach((input) => input.addEventListener('change', () => {
    const employee = employeeById(input.dataset.fundId); if (!employee) return;
    employee.weeklyFund = Math.max(1, Math.min(80, Number(input.value) || 1)); markDirty(); renderAll();
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
    <div class="fact-row"><span>Skutečná doba návštěvy</span><b>${actualMinutes ? `${number(actualMinutes)} min · medián` : 'bez dostatečné historie'}<br><small>${actualMinutes ? `${durationSamples === 1 ? '1 dokončená návštěva' : `${durationSamples} dokončených návštěv`} za 13 týdnů` : `použit celkový medián ${number(state.fallbackVisitMinutes)} min`}</small></b></div>
    <div class="fact-row"><span>Pro výpočet času</span><b><input class="frequency-input" id="plannedVisitMinutes" type="number" min="1" max="240" step="1" value="${Math.round(plannedMinutesLocation(location.id))}"> min / návštěva</b></div>
    ${state.showComparison ? `<div class="fact-row"><span>Současný stav</span><b>${esc(ownerNamesAt(state.current, location.id))}</b></div>` : ''}
    <div class="fact-row"><span>V tomto návrhu</span><b>${esc(ownerNamesAt(state.draft, location.id))}</b></div>
    ${employee && impact ? `<div class="fact-row"><span>Dopad pro ${esc(employee.name)}</span><b>${impact.hours >= 0 ? '+' : ''}${number(impact.hours)} h · ${impact.km >= 0 ? '+' : ''}${Math.round(impact.km)} km/týden</b></div>` : ''}
    <div class="machine-picker"><div class="machine-picker-title"><span>Vyber stroje k přidělení</span><button type="button" id="toggleMachines">Vybrat / zrušit vše</button></div>
    ${machines.map((machine) => {
      const owners = ownersOfMachine(state.draft, machine.id).map(employeeById).filter(Boolean);
      const recommendation = recommendationForMachine(machine);
      return `<div class="machine-option"><input type="checkbox" data-selected-machine="${machine.id}" ${state.selectedMachineIds.has(String(machine.id)) ? 'checked' : ''}><span><strong>${esc(machine.evidence_number ? `EV ${machine.evidence_number} · ` : '')}${esc(machine.name || kindOf(machine))}</strong><small>${kindOf(machine)} · nyní ${number(weeklyVisitsMachine(machine.id))}× týdně · naposledy ${dateLabel(state.lastVisits.get(String(machine.id)) || lastVisit)}</small><small>${esc(owners.length ? owners.map(nameOf).join(', ') : 'bez operátora')} <span class="owner-dots">${owners.map((owner) => `<i style="--c:${owner.color}"></i>`).join('')}</span></small><span class="machine-frequency"><span>Doporučuji <b>${number(recommendation.visits)}×</b><small>${esc(recommendation.reason)}</small></span><label>Pro návrh <input class="frequency-input" data-machine-frequency="${machine.id}" type="number" min="0.1" max="7" step="0.1" value="${requiredVisitsMachine(machine.id).toFixed(1)}"> × týdně</label></span></span></div>`;
    }).join('')}</div>`;
  $('selectedActions').hidden = !employee;
  if (employee) { $('assignSelected').textContent = `Přidělit vybrané · ${employee.name}`; $('shareSelected').textContent = `Přidat ${employee.name} jako výpomoc`; }
  document.querySelectorAll('[data-selected-machine]').forEach((input) => input.addEventListener('change', () => {
    if (input.checked) state.selectedMachineIds.add(String(input.dataset.selectedMachine)); else state.selectedMachineIds.delete(String(input.dataset.selectedMachine)); renderSelected(location);
  }));
  $('toggleMachines')?.addEventListener('click', () => { const ids = machines.map((machine) => String(machine.id)); state.selectedMachineIds = state.selectedMachineIds.size === ids.length ? new Set() : new Set(ids); renderSelected(location); });
  $('plannedVisitMinutes')?.addEventListener('change', (event) => {
    state.plannedVisitMinutes.set(String(location.id), Math.max(1, Math.min(240, Number(event.target.value) || state.fallbackVisitMinutes)));
    markDirty(); renderAll();
  });
  document.querySelectorAll('[data-machine-frequency]').forEach((input) => input.addEventListener('change', (event) => {
    state.requiredVisits.set(String(event.target.dataset.machineFrequency), Math.max(.1, Math.min(7, Number(event.target.value) || .1)));
    markDirty(); renderAll();
  }));
}

function renderSummary() {
  const proposed = statsFor(state.draft), current = statsFor(state.current), people = activeEmployees();
  const overloaded = people.filter((employee) => proposed.get(String(employee.id)).hours > employee.weeklyFund);
  const unassigned = state.machines.filter((machine) => ownersOfMachine(state.draft, machine.id).length === 0).length;
  const coverage = people.reduce((count, employee) => count + state.locations.filter((location) => employeeFrequency(state.draft, employee.id, location.id) > routeDays(employee) + .2).length, 0);
  renderSelected(state.locations.find((location) => String(location.id) === String(state.selectedLocationId)));
  const warnings = [];
  if (unassigned) warnings.push(`${unassigned} strojů ještě nemá člověka`);
  if (overloaded.length) warnings.push(`fond překračuje ${overloaded.map(nameOf).join(', ')}`);
  if (coverage) warnings.push(`${coverage} míst vyžaduje více návštěv, než má člověk jízdních dnů`);
  $('feasibility').classList.toggle('warn', warnings.length > 0);
  $('feasibility').innerHTML = warnings.length ? `<b>⚠ Návrh ještě není hotový</b><br>${esc(warnings.join(' · '))}.` : '<b>✓ Návrh je podle odhadu odjezditelný</b><br>Všechny aktivní stroje mají přiřazenou péči a fondy nejsou překročené.';
  $('metrics').innerHTML = people.map((employee) => {
    const next = proposed.get(String(employee.id)), now = current.get(String(employee.id)), hours = next.hours - now.hours, km = next.km - now.km;
    const percent = Math.min(115, Math.round(next.hours / employee.weeklyFund * 100));
    const comparison = state.showComparison ? `<div class="metriccompare"><span>Dnes ${number(now.hours)} h · ${Math.round(now.km)} km</span><b class="${hours > .05 || km > 1 ? 'positive' : hours < -.05 || km < -1 ? 'negative' : ''}">${hours >= 0 ? '+' : ''}${number(hours)} h · ${km >= 0 ? '+' : ''}${Math.round(km)} km</b></div>` : '';
    return `<div class="metric"><div class="metricline"><span>${esc(employee.name)}</span><b>${number(next.hours)} / ${employee.weeklyFund} h<br>${Math.round(next.km)} km/týden</b></div>${comparison}<div class="bar"><i style="--c:${employee.color};width:${Math.min(100, percent)}%;${percent > 100 ? 'background:#d5101a' : ''}"></i></div></div>`;
  }).join('');
}

function markDirty() { state.dirty = true; $('saveDraft').textContent = 'Uložit návrh'; }
function snapshot() { return { version: 5, savedAt: new Date().toISOString(), machineAssignments: Object.fromEntries([...state.draft].map(([id, owners]) => [id, [...owners]])), requiredVisitsByMachine: Object.fromEntries(state.requiredVisits), plannedVisitMinutesByLocation: Object.fromEntries(state.plannedVisitMinutes), funds: Object.fromEntries(state.employees.map((employee) => [employee.id, employee.weeklyFund])), included: Object.fromEntries(state.employees.map((employee) => [employee.id, employee.included])) }; }
function saveDraft() { localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot())); state.dirty = false; $('saveDraft').textContent = 'Uloženo ✓'; say('Návrh je uložen jen v tomto prohlížeči. Ostré rajóny se nezměnily.'); }

function loadDraft() {
  try {
    localStorage.removeItem('olvend-territory-planner-draft-v1'); localStorage.removeItem('olvend-territory-planner-draft-v2');
    const legacy = LEGACY_STORAGE_KEYS.map((key) => localStorage.getItem(key)).find(Boolean);
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || legacy || 'null'); if (![3, 4, 5].includes(saved?.version)) return false;
    state.employees.forEach((employee) => { if (Number(saved.funds?.[employee.id]) > 0) employee.weeklyFund = Number(saved.funds[employee.id]); if (typeof saved.included?.[employee.id] === 'boolean') employee.included = saved.included[employee.id]; });
    Object.entries(saved.machineAssignments || {}).forEach(([machineId, owners]) => { if (state.machines.some((machine) => String(machine.id) === String(machineId))) state.draft.set(String(machineId), new Set((owners || []).filter((id) => employeeById(id)?.included))); });
    if (saved.version >= 4) Object.entries(saved.requiredVisitsByMachine || {}).forEach(([machineId, visits]) => state.requiredVisits.set(String(machineId), Math.max(.1, Number(visits) || .1)));
    else Object.entries(saved.requiredVisits || {}).forEach(([locationId, visits]) => machinesAt(locationId).forEach((machine) => state.requiredVisits.set(String(machine.id), Math.max(.1, Number(visits) || .1))));
    Object.entries(saved.plannedVisitMinutesByLocation || {}).forEach(([locationId, minutes]) => state.plannedVisitMinutes.set(String(locationId), Math.max(1, Math.min(240, Number(minutes) || state.fallbackVisitMinutes))));
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
  state.plannedVisitMinutes = new Map(state.locations.map((location) => [String(location.id), state.actualVisitMinutes.get(String(location.id)) || state.fallbackVisitMinutes]));
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
  const plans = await supabase.from('route_plans').select('id,title,route_payload,execution_status,planning_date').gte('planning_date', since.toISOString().slice(0, 10)).eq('execution_status', 'done');
  if (plans.error) throw plans.error;
  const validPlans = (plans.data || []).filter((plan) => plan.route_payload?.test_mode !== true && !/^\s*\[?TEST/i.test(String(plan.title || '')));
  const planDates = new Map(validPlans.map((plan) => [String(plan.id), plan.planning_date]));
  const machineLocations = new Map(state.machines.map((machine) => [String(machine.id), String(machine.location_id)]));
  const durationKeys = new Set();
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
    if (!locationKey || !stop.arrived_at || !stop.completed_at) return;
    const key = `${stop.route_plan_id}:${locationKey}`;
    if (durationKeys.has(key)) return;
    const minutes = (new Date(stop.completed_at) - new Date(stop.arrived_at)) / 60000;
    if (!Number.isFinite(minutes) || minutes < 2 || minutes > 180) return;
    durationKeys.add(key);
    if (!state.visitDurationSamples.has(locationKey)) state.visitDurationSamples.set(locationKey, []);
    state.visitDurationSamples.get(locationKey).push(minutes);
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
  state.visitDurationSamples.forEach((values, locationId) => state.actualVisitMinutes.set(locationId, median(values)));
  state.fallbackVisitMinutes = median([...state.visitDurationSamples.values()].flat()) || 20;
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
  state.plannedVisitMinutes = new Map(state.locations.map((location) => [String(location.id), state.actualVisitMinutes.get(String(location.id)) || state.fallbackVisitMinutes]));
  const restored = loadDraft(); state.selectedEmployeeId = activeEmployees()[0]?.id || null;
  renderAll(); renderMap(true); $('loading').hidden = true; if (restored) say('Načetl jsem poslední uložený pracovní návrh.');
}

$('saveDraft').addEventListener('click', saveDraft); $('resetDraft').addEventListener('click', resetDraft);
$('assignSelected').addEventListener('click', () => applyAssignment(false)); $('shareSelected').addEventListener('click', () => applyAssignment(true)); $('removeSelected').addEventListener('click', removeSelected);
$('toggleComparison').addEventListener('click', () => { state.showComparison = !state.showComparison; $('toggleComparison').textContent = state.showComparison ? 'Skrýt současný stav' : 'Porovnat se současným stavem'; renderSummary(); });
$('fitMap').addEventListener('click', () => renderMap(true)); $('drawArea').addEventListener('click', () => selectedEmployee() ? setDrawing(true) : say('Nejdřív vyber člověka.', true)); $('finishArea').addEventListener('click', finishDrawing); $('cancelArea').addEventListener('click', () => setDrawing(false));
$('showDetails').addEventListener('click', () => { $('summary').classList.toggle('open'); $('showDetails').textContent = $('summary').classList.contains('open') ? 'Skrýt výpočet' : 'Jak se počítají km a hodiny'; });
$('openCurrent').addEventListener('click', () => { location.href = 'operator-territories.html'; });
window.addEventListener('beforeunload', (event) => { if (state.dirty) { event.preventDefault(); event.returnValue = ''; } });

load().catch((error) => { console.error(error); $('loading').hidden = true; say(`Data nelze načíst: ${error.message || error}`, true); });
