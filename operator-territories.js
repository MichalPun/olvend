import { supabase, requireAuth } from './supabase.js';

const palette = ['#df111c', '#246db6', '#16834b', '#7656a8', '#b46b00', '#00838f', '#9b3659'];
const MICHAL_EMPLOYEE_ID = 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
const state = { employees: [], locations: [], machines: [], assignments: new Map(), markers: new Map(), selectedId: null, settings: null };
const $ = (id) => document.getElementById(id);
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
const employeeName = (employee) => employee ? `${employee.name || ''} ${employee.surname || ''}`.trim() : 'Bez operátora';
const employeeById = (id) => state.employees.find((employee) => String(employee.id) === String(id || '')) || null;
const assignmentFor = (locationId) => state.assignments.get(String(locationId)) || { location_id: locationId, primary_employee_id: null, backup_employee_id: null, assignment_scope: 'location', selected_machine_ids: [], effective_from: new Date().toISOString().slice(0, 10), note: '' };
const machinesFor = (locationId) => state.machines.filter((machine) => String(machine.location_id) === String(locationId));
const colorForEmployee = (id) => employeeById(id)?.color || '#7b8493';
const map = L.map('map', { zoomControl: true }).setView([49.25, 16.9], 7);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18, attribution: '&copy; OpenStreetMap' }).addTo(map);
const toast = $('toast');
let toastTimer;

function say(message, error = false) {
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.style.background = error ? '#a20f18' : '#1d2936';
  toast.classList.add('show');
  toastTimer = setTimeout(() => toast.classList.remove('show'), 2600);
}

function markerIcon(location) {
  const assignment = assignmentFor(location.id);
  const label = machinesFor(location.id).length || '•';
  return L.divIcon({ className: 'marker-label', html: `<span style="display:grid;place-items:center;width:28px;height:28px;border-radius:50%;background:${colorForEmployee(assignment.primary_employee_id)}">${label}</span>` });
}

function ownerOptions(selected, emptyLabel = 'Bez operátora') {
  return `<option value="">${emptyLabel}</option>${state.employees.map((employee) => `<option value="${esc(employee.id)}" ${String(employee.id) === String(selected || '') ? 'selected' : ''}>${esc(employeeName(employee))}</option>`).join('')}`;
}

function locationSearch(location) {
  return `${location.name || ''} ${location.city || ''} ${location.address || ''} ${machinesFor(location.id).map((machine) => `${machine.evidence_number || ''} ${machine.name || ''}`).join(' ')}`.toLowerCase();
}

function renderLegend() {
  $('mapLegend').innerHTML = state.employees.map((employee) => `<span class="badge"><i class="legend-dot" style="--c:${employee.color}"></i>${esc(employee.name || employeeName(employee))}</span>`).join('') + '<span class="badge"><i class="legend-dot" style="--c:#7b8493"></i>Bez operátora</span>';
}

function renderMap() {
  state.markers.forEach((marker) => marker.remove());
  state.markers.clear();
  const bounds = [];
  state.locations.forEach((location) => {
    const lat = Number(location.latitude), lng = Number(location.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
    const assignment = assignmentFor(location.id);
    const owner = employeeName(employeeById(assignment.primary_employee_id));
    const marker = L.marker([lat, lng], { icon: markerIcon(location) }).addTo(map)
      .bindTooltip(`${location.name || 'Lokalita'} · ${owner}`)
      .bindPopup(`<b>${esc(location.name || 'Lokalita')}</b><br>${esc(location.city || '')} · ${esc(location.address || '')}<br>${machinesFor(location.id).length} automatů · ${esc(owner)}`);
    marker.on('click', () => selectLocation(location.id, false));
    state.markers.set(String(location.id), marker);
    bounds.push([lat, lng]);
  });
  if (bounds.length) map.fitBounds(bounds, { padding: [24, 24] });
  setTimeout(() => map.invalidateSize(), 80);
}

function renderOperators() {
  const routeOperators = state.employees.filter((employee) => employee.isRouteOperator);
  const counts = new Map(state.employees.map((employee) => [String(employee.id), { locations: 0, machines: 0 }]));
  state.locations.forEach((location) => {
    const assignment = assignmentFor(location.id);
    const count = counts.get(String(assignment.primary_employee_id || ''));
    if (!count) return;
    count.locations += 1;
    count.machines += assignment.assignment_scope === 'machines' ? (assignment.selected_machine_ids || []).length : machinesFor(location.id).length;
  });
  $('operatorList').innerHTML = routeOperators.map((employee) => {
    const count = counts.get(String(employee.id));
    return `<div class="operator-row" data-owner="${esc(employee.id)}" style="--c:${employee.color}"><i class="operator-dot"></i><div><div class="name">${esc(employeeName(employee))}</div><div class="sub">Uložený rajón</div></div><div class="operator-stats"><b>${count.locations} lokalit</b><span class="sub">${count.machines} automatů</span></div></div>`;
  }).join('');
  document.querySelectorAll('.operator-row').forEach((row) => row.addEventListener('click', () => {
    $('ownerFilter').value = row.dataset.owner;
    filterRows();
  }));
}

function renderRows() {
  $('rows').innerHTML = state.locations.map((location) => {
    const assignment = assignmentFor(location.id);
    const machines = machinesFor(location.id);
    const assigned = Boolean(assignment.primary_employee_id);
    const exception = assignment.assignment_scope === 'machines';
    const scopeText = exception ? `${(assignment.selected_machine_ids || []).length} z ${machines.length} automatů` : 'Celá lokalita';
    const type = machines.some((machine) => /snack|food|potrav/i.test(`${machine.machine_type || ''} ${machine.name || ''}`)) ? 'mixed' : 'coffee';
    return `<tr data-id="${location.id}" data-owner="${esc(assignment.primary_employee_id || '')}" data-status="${!assigned ? 'unassigned' : exception ? 'exception' : 'assigned'}" data-type="${type}" data-search="${esc(locationSearch(location))}"><td><div class="name">${esc(location.name || 'Bez názvu')}</div><div class="sub">${machines.map((machine) => `EV ${machine.evidence_number || '—'}`).join(', ') || 'Bez aktivního automatu'}</div></td><td><b>${esc(location.city || '—')}</b><div class="sub">${esc(location.address || '—')}</div></td><td>${machines.length}</td><td>${esc(location.city || 'Bez oblasti')}</td><td><select class="compact-select assign owner-select">${ownerOptions(assignment.primary_employee_id)}</select></td><td><select class="compact-select assign backup-select">${ownerOptions(assignment.backup_employee_id, 'Bez náhradníka')}</select></td><td>${exception ? `<span class="badge amber">${scopeText}</span>` : scopeText}</td><td>${!assigned ? '<span class="status none">Vyřešit</span>' : exception ? '<span class="status warn">Výjimka</span>' : '<span class="status ok">Přiřazeno</span>'}</td><td><button class="btn icon small" aria-label="Upravit">•••</button></td></tr>`;
  }).join('');
  document.querySelectorAll('#rows tr').forEach((row) => {
    row.addEventListener('click', (event) => { if (!event.target.closest('select')) selectLocation(Number(row.dataset.id), true); });
    row.querySelector('.owner-select').addEventListener('change', (event) => quickSave(row.dataset.id, event.target.value, row.querySelector('.backup-select').value));
    row.querySelector('.backup-select').addEventListener('change', (event) => quickSave(row.dataset.id, row.querySelector('.owner-select').value, event.target.value));
  });
  filterRows();
}

function renderSummary() {
  const assigned = state.locations.filter((location) => assignmentFor(location.id).primary_employee_id).length;
  $('operatorMetric').textContent = state.employees.filter((employee) => employee.isRouteOperator).length;
  $('assignedMetric').textContent = assigned;
  $('unassignedMetric').textContent = state.locations.length - assigned;
  $('machineMetric').textContent = state.machines.length;
  $('exceptionMetric').textContent = state.locations.filter((location) => assignmentFor(location.id).assignment_scope === 'machines').length;
  $('coverageMetric').textContent = state.locations.length ? `${Math.round(assigned / state.locations.length * 100)} %` : '0 %';
}

function showPanel(edit) {
  $('operatorsTab').classList.toggle('active', !edit);
  $('editTab').classList.toggle('active', edit);
  $('operatorList').style.display = edit ? 'none' : 'block';
  $('editor').classList.toggle('active', edit);
}

function selectLocation(id, pan = true) {
  const location = state.locations.find((item) => String(item.id) === String(id));
  if (!location) return;
  state.selectedId = location.id;
  const assignment = assignmentFor(location.id);
  const machines = machinesFor(location.id);
  document.querySelectorAll('#rows tr').forEach((row) => row.classList.toggle('selected', String(row.dataset.id) === String(id)));
  $('editName').textContent = location.name || 'Bez názvu';
  $('editAddress').textContent = `${location.city || '—'} · ${location.address || '—'}`;
  $('editMachines').textContent = machines.length;
  $('editRevenue').textContent = 'Dle reportu';
  $('editZone').textContent = location.city || '—';
  $('editVisit').textContent = 'Dle historie tras';
  $('editOwner').innerHTML = ownerOptions(assignment.primary_employee_id);
  $('editBackup').innerHTML = ownerOptions(assignment.backup_employee_id, 'Bez náhradníka');
  $('editScope').value = assignment.assignment_scope || 'location';
  renderMachineScope(location, assignment);
  showPanel(true);
  if (pan && state.markers.has(String(id))) {
    const marker = state.markers.get(String(id));
    map.setView(marker.getLatLng(), Math.max(map.getZoom(), 11));
    marker.openPopup();
  }
}

function renderMachineScope(location, assignment) {
  const machines = machinesFor(location.id);
  const selected = new Set((assignment.selected_machine_ids || []).map(String));
  $('machineScope').hidden = $('editScope').value !== 'machines';
  $('machineScope').innerHTML = machines.map((machine) => `<label class="machine-row"><input type="checkbox" value="${machine.id}" ${selected.has(String(machine.id)) ? 'checked' : ''}><b>EV ${machine.evidence_number || '—'}</b><span>${esc(machine.name || machine.machine_type || 'Automat')}</span></label>`).join('');
}

async function saveAssignment(locationId, primaryId, backupId, scope, machineIds) {
  const { data, error } = await supabase.rpc('save_operator_territory_assignment', {
    p_location_id: Number(locationId),
    p_primary_employee_id: primaryId || null,
    p_backup_employee_id: backupId || null,
    p_assignment_scope: scope,
    p_selected_machine_ids: machineIds.map(Number),
    p_effective_from: $('effectiveFrom').value || new Date().toISOString().slice(0, 10),
    p_note: null
  });
  if (error) throw error;
  state.assignments.set(String(locationId), data);
  renderAll();
  return data;
}

async function quickSave(locationId, primaryId, backupId) {
  try {
    const current = assignmentFor(locationId);
    await saveAssignment(locationId, primaryId, backupId, current.assignment_scope, current.selected_machine_ids || []);
    say('Přiřazení bylo uloženo.');
  } catch (error) { say(error.message || 'Uložení se nezdařilo.', true); renderRows(); }
}

function filterRows() {
  const q = ($('tableSearch').value || $('search').value).trim().toLowerCase();
  const owner = $('ownerFilter').value, status = $('statusFilter').value, type = $('typeFilter').value;
  let count = 0;
  document.querySelectorAll('#rows tr').forEach((row) => {
    const visible = (!q || row.dataset.search.includes(q)) && (!owner || row.dataset.owner === owner) && (!status || row.dataset.status === status) && (!type || row.dataset.type === type);
    row.hidden = !visible;
    state.markers.get(String(row.dataset.id))?.setOpacity(visible ? 1 : .12);
    if (visible) count += 1;
  });
  $('visibleCount').textContent = `${count} lokalit`;
}

function renderAll() {
  renderLegend(); renderMap(); renderOperators(); renderRows(); renderSummary();
  $('ownerFilter').innerHTML = `<option value="">Všichni operátoři</option>${state.employees.map((employee) => `<option value="${employee.id}">${esc(employeeName(employee))}</option>`).join('')}<option value="__none">Bez operátora</option>`;
  if (state.selectedId) selectLocation(state.selectedId, false);
}

async function load() {
  await requireAuth();
  $('effectiveFrom').value = '2026-08-31';
  const [employees, locations, machines, assignments, settings] = await Promise.all([
    supabase.from('employees').select('id,name,surname,role,active,bonus_eligible').eq('active', true).order('surname'),
    supabase.from('locations').select('id,name,city,address,latitude,longitude,active').eq('active', true).order('name'),
    supabase.from('machines').select('id,location_id,evidence_number,name,machine_type,active,status').eq('active', true),
    supabase.from('operator_territory_assignments').select('*'),
    supabase.from('operator_territory_settings').select('*').eq('id', true).maybeSingle()
  ]);
  const failed = [employees, locations, machines, assignments, settings].find((result) => result.error);
  if (failed) throw failed.error;
  state.employees = (employees.data || [])
    .filter((employee) => ['operator', 'admin', 'manager'].includes(String(employee.role || '').toLowerCase()))
    .map((employee, index) => ({
      ...employee,
      color: palette[index % palette.length],
      isRouteOperator: Boolean(employee.bonus_eligible) || String(employee.id) === MICHAL_EMPLOYEE_ID
    }));
  state.locations = locations.data || [];
  state.machines = (machines.data || []).filter((machine) => machine.location_id && !/warehouse|sklad|reserve|rezerv/i.test(String(machine.status || '')));
  state.assignments = new Map((assignments.data || []).map((assignment) => [String(assignment.location_id), assignment]));
  state.settings = settings.data || { territory_strength: 'strong', history_fallback_days: 90, balance_employee_km: true, keep_locations_together: true, manager_default_reserve: true };
  $('ruleStrength').value = state.settings.territory_strength;
  $('ruleHistory').value = String(state.settings.history_fallback_days);
  $('ruleBalance').value = String(state.settings.balance_employee_km);
  $('ruleTogether').value = String(state.settings.keep_locations_together);
  $('ruleManager').value = String(state.settings.manager_default_reserve);
  renderAll();
}

$('operatorsTab').onclick = () => showPanel(false);
$('editTab').onclick = () => showPanel(true);
$('cancelEdit').onclick = () => showPanel(false);
$('editScope').onchange = () => renderMachineScope(state.locations.find((location) => String(location.id) === String(state.selectedId)), assignmentFor(state.selectedId));
$('apply').onclick = async () => {
  try {
    const scope = $('editScope').value;
    const machineIds = scope === 'machines' ? [...document.querySelectorAll('#machineScope input:checked')].map((input) => Number(input.value)) : [];
    await saveAssignment(state.selectedId, $('editOwner').value, $('editBackup').value, scope, machineIds);
    say('Oblast byla uložena a plánovač ji použije.');
  } catch (error) { say(error.message || 'Uložení se nezdařilo.', true); }
};
['search', 'tableSearch'].forEach((id) => $(id).addEventListener('input', filterRows));
['statusFilter', 'typeFilter', 'ownerFilter'].forEach((id) => $(id).addEventListener('change', filterRows));
$('clear').onclick = () => { ['search', 'tableSearch'].forEach((id) => $(id).value = ''); ['statusFilter', 'typeFilter', 'ownerFilter'].forEach((id) => $(id).value = ''); filterRows(); };
$('fit').onclick = () => { const points = state.locations.filter((location) => Number.isFinite(Number(location.latitude)) && Number.isFinite(Number(location.longitude))).map((location) => [Number(location.latitude), Number(location.longitude)]); if (points.length) map.fitBounds(points, { padding: [24, 24] }); };
$('showUnassigned').onclick = () => { $('statusFilter').value = 'unassigned'; filterRows(); };
$('suggest').onclick = () => say('Výchozí návrh byl vytvořen z posledních 90 dní. Ruční změny zůstávají uzamčené.');
$('save').onclick = () => say('Změny se ukládají průběžně po každé úpravě.');
$('saveRules').onclick = async () => {
  const { data, error } = await supabase.rpc('save_operator_territory_settings', {
    p_territory_strength: $('ruleStrength').value,
    p_history_fallback_days: Number($('ruleHistory').value),
    p_balance_employee_km: $('ruleBalance').value === 'true',
    p_keep_locations_together: $('ruleTogether').value === 'true',
    p_manager_default_reserve: $('ruleManager').value === 'true'
  });
  if (error) return say(error.message || 'Pravidla se nepodařilo uložit.', true);
  state.settings = data;
  say('Pravidla byla uložena a plánovač je použije.');
};

load().catch((error) => { console.error(error); say(`Data nelze načíst: ${error.message || error}`, true); });
