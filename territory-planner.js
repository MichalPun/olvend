import { supabase } from './supabase.js';

const STORAGE_KEY = 'olvend-territory-planner-draft-v16';
const LEGACY_STORAGE_KEYS = ['olvend-territory-planner-draft-v15', 'olvend-territory-planner-draft-v14', 'olvend-territory-planner-draft-v13', 'olvend-territory-planner-draft-v12', 'olvend-territory-planner-draft-v11', 'olvend-territory-planner-draft-v10', 'olvend-territory-planner-draft-v9', 'olvend-territory-planner-draft-v8', 'olvend-territory-planner-draft-v7', 'olvend-territory-planner-draft-v6', 'olvend-territory-planner-draft-v5', 'olvend-territory-planner-draft-v4', 'olvend-territory-planner-draft-v3'];
const TERRITORY_SOLVER_URL = 'https://olvend-telemetry-proxy.onrender.com/territory-route-solver';
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

function targetCycleDays(employee) {
  const settings = scheduleFor(employee), available = [...new Set(settings.availableDays || [1, 2, 3, 4, 5])].filter((day) => day >= 1 && day <= 5);
  const maximum = Math.max(1, Number(settings.maxHours || 12));
  return Math.max(6, Math.min(available.length * 3, Math.ceil((Number(employee.weeklyFund || 0) * 3) / maximum - .001)));
}

function targetDrivingDays(employee) { return targetCycleDays(employee) / 3; }

function rhythmText(value) {
  const days = Number(value || 0);
  if (Number.isInteger(days)) return `${days} ${days === 1 ? 'den' : days < 5 ? 'dny' : 'dnů'} týdně`;
  return `${number(days)} dne týdně v průměru`;
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

function bestSpreadDays(availableDays, count, limit = 1) {
  const available = [...new Set(availableDays || [1, 2, 3, 4, 5])].sort((a, b) => a - b);
  return combinations(available, Math.min(count, available.length)).sort((a, b) => weekdaySpreadPenalty(a) - weekdaySpreadPenalty(b) || a.join('').localeCompare(b.join(''))).slice(0, limit);
}

function balancedWeekCounts(totalDays) {
  const base = Math.floor(totalDays / 3), counts = [base, base, base];
  for (let index = 0; index < totalDays % 3; index += 1) counts[2 - index] += 1;
  return counts;
}

function prepareAutomaticSchedule(employee) {
  const settings = scheduleFor(employee), counts = balancedWeekCounts(targetCycleDays(employee));
  settings.weeks = counts.map((count) => bestSpreadDays(settings.availableDays, count)[0] || []);
  return { employee, settings, cycleDays: counts.reduce((sum, count) => sum + count, 0), drivingDays: counts.reduce((sum, count) => sum + count, 0) / 3, maxMinutes: Number(employee.weeklyFund || 0) * 60 };
}

function locationDemand(location) {
  const point = pointOf(location), machines = machinesAt(location.id);
  const frequency = Math.max(...machines.map((machine) => requiredVisitsMachine(machine.id)), 0);
  const serviceMinutes = machines.reduce((sum, machine) => sum + plannedMinutesMachine(machine.id) * requiredVisitsMachine(machine.id), 0);
  const travelMinutes = point ? distanceKm(state.depot, point) * 2 / 55 * 60 * Math.max(.5, frequency) : 0;
  return { location, point, machines, frequency, serviceMinutes, workload: serviceMinutes + travelMinutes };
}

function weightedCentroid(items, fallback) {
  const valid = items.filter((item) => item.point);
  const total = valid.reduce((sum, item) => sum + Math.max(1, item.workload), 0);
  if (!total) return fallback;
  return [valid.reduce((sum, item) => sum + item.point[0] * Math.max(1, item.workload), 0) / total, valid.reduce((sum, item) => sum + item.point[1] * Math.max(1, item.workload), 0) / total];
}

function setLocationOwner(assignments, demand, employeeId) {
  demand.machines.forEach((machine) => assignments.set(String(machine.id), new Set([String(employeeId)])));
}

function primaryOwnerOf(assignments, demand) {
  return demand.machines.flatMap((machine) => ownersOfMachine(assignments, machine.id))[0] || null;
}

function territoryGeography(assignments, profiles) {
  const groups = new Map(profiles.map((profile) => [String(profile.employee.id), []]));
  const locationItems = [];
  state.locations.forEach((location) => {
    const point = pointOf(location); if (!point) return;
    const owners = ownerIdsAt(assignments, location.id).filter((id) => groups.has(String(id)));
    if (!owners.length) return;
    const fullWeight = Math.max(.25, requiredVisitsLocation(location.id)), weight = fullWeight / owners.length;
    locationItems.push({ point, owners: new Set(owners.map(String)), weight: fullWeight });
    owners.forEach((ownerId) => groups.get(String(ownerId)).push({ point, weight }));
  });
  const centroids = new Map([...groups].map(([employeeId, items]) => {
    const total = items.reduce((sum, item) => sum + item.weight, 0);
    if (!total) return [employeeId, state.depot];
    return [employeeId, [items.reduce((sum, item) => sum + item.point[0] * item.weight, 0) / total, items.reduce((sum, item) => sum + item.point[1] * item.weight, 0) / total]];
  }));
  let dispersion = 0, isolation = 0, boundaryCut = 0;
  groups.forEach((items, employeeId) => items.forEach((item, index) => {
    dispersion += distanceKm(item.point, centroids.get(employeeId)) * item.weight;
    const ownDistances = items.filter((_, candidate) => candidate !== index).map((candidate) => distanceKm(item.point, candidate.point));
    const otherDistances = [...groups].filter(([otherId]) => otherId !== employeeId).flatMap(([, candidates]) => candidates.map((candidate) => distanceKm(item.point, candidate.point)));
    const nearestOwn = ownDistances.length ? Math.min(...ownDistances) : distanceKm(item.point, state.depot);
    const nearestOther = otherDistances.length ? Math.min(...otherDistances) : Infinity;
    isolation += Math.max(0, nearestOwn - nearestOther) * item.weight;
  }));
  locationItems.forEach((item, index) => locationItems.slice(index + 1).forEach((other) => {
    const sharedOwner = [...item.owners].some((ownerId) => other.owners.has(ownerId));
    if (sharedOwner) return;
    const gap = distanceKm(item.point, other.point);
    boundaryCut += Math.max(0, 55 - gap) * Math.min(item.weight, other.weight);
  }));
  return { dispersion, isolation, boundaryCut };
}

function assignmentEvaluation(assignments, profiles) {
  const stats = profiles.map((profile) => ({ profile, ...employeeStats(profile.employee, assignments) }));
  const overloads = stats.map((item) => Math.max(0, item.hours - Number(item.profile.employee.weeklyFund || 0)));
  const ratios = stats.map((item) => item.hours / Math.max(1, Number(item.profile.employee.weeklyFund || 0)));
  const averageRatio = ratios.reduce((sum, value) => sum + value, 0) / Math.max(1, ratios.length);
  const utilizationDeviation = ratios.reduce((sum, value) => sum + Math.max(0, Math.abs(value - averageRatio) - .18) ** 2, 0);
  const maxOverload = Math.max(0, ...overloads);
  const overloadSquares = overloads.reduce((sum, value) => sum + value ** 2, 0);
  const imbalance = ratios.reduce((sum, value) => sum + (value - averageRatio) ** 2, 0);
  const totalKm = stats.reduce((sum, item) => sum + item.km, 0);
  const geography = territoryGeography(assignments, profiles);
  return {
    stats,
    maxOverload,
    totalOverload: overloads.reduce((sum, value) => sum + value, 0),
    score: maxOverload ** 2 * 1e12 + overloadSquares * 1e10 + utilizationDeviation * 200000000 + geography.boundaryCut * 200000 + geography.isolation * 20000 + geography.dispersion * 1000 + totalKm * 5000 + imbalance * 50000
  };
}

function assignmentCentroids(assignments, profiles) {
  return new Map(profiles.map((profile) => {
    const employeeId = String(profile.employee.id);
    const items = state.locations.map((location) => {
      const point = pointOf(location), frequency = employeeFrequency(assignments, employeeId, location.id);
      return point && frequency > 0 ? { point, workload: Math.max(.25, frequency) } : null;
    }).filter(Boolean);
    return [employeeId, weightedCentroid(items, state.depot)];
  }));
}

function geographicallyAdjacentMove(demand, currentOwner, candidateOwner, centroids) {
  if (!currentOwner || !demand.point) return true;
  const currentDistance = distanceKm(demand.point, centroids.get(String(currentOwner)) || state.depot);
  const candidateDistance = distanceKm(demand.point, centroids.get(String(candidateOwner)) || state.depot);
  // A boundary may move, an isolated island hundreds of kilometres away may not.
  return candidateDistance <= currentDistance * 1.35 + 18;
}

function rebalanceAssignments(assignments, demands, profiles) {
  let evaluation = assignmentEvaluation(assignments, profiles);
  for (let pass = 0; pass < 12; pass += 1) {
    const centroids = assignmentCentroids(assignments, profiles);
    let changed = false;
    const ordered = [...demands].sort((a, b) => {
      const ownerA = primaryOwnerOf(assignments, a), ownerB = primaryOwnerOf(assignments, b);
      const statA = evaluation.stats.find((item) => String(item.profile.employee.id) === String(ownerA));
      const statB = evaluation.stats.find((item) => String(item.profile.employee.id) === String(ownerB));
      const pressureA = statA ? statA.hours / Math.max(1, statA.profile.employee.weeklyFund) : 0;
      const pressureB = statB ? statB.hours / Math.max(1, statB.profile.employee.weeklyFund) : 0;
      return pressureB - pressureA || b.workload - a.workload;
    });
    ordered.forEach((demand) => {
      const currentOwner = primaryOwnerOf(assignments, demand);
      const feasibleExists = profiles.some((profile) => Math.ceil(profile.drivingDays) >= Math.ceil(demand.frequency - .001));
      let best = { assignments, evaluation };
      profiles.forEach((profile) => {
        const employeeId = String(profile.employee.id);
        if (employeeId === String(currentOwner)) return;
        if (feasibleExists && Math.ceil(profile.drivingDays) < Math.ceil(demand.frequency - .001)) return;
        if (!geographicallyAdjacentMove(demand, currentOwner, employeeId, centroids)) return;
        const simulated = copyAssignments(assignments);
        setLocationOwner(simulated, demand, employeeId);
        const candidate = assignmentEvaluation(simulated, profiles);
        if (candidate.score + .01 < best.evaluation.score) best = { assignments: simulated, evaluation: candidate };
      });
      if (best.assignments !== assignments) {
        assignments = best.assignments;
        evaluation = best.evaluation;
        changed = true;
      }
    });
    if (!changed) break;
  }
  return { assignments, evaluation };
}

function addSharedLocationOwner(assignments, demand, employeeId) {
  demand.machines.forEach((machine) => {
    const owners = new Set(ownersOfMachine(assignments, machine.id));
    owners.add(String(employeeId));
    assignments.set(String(machine.id), owners);
  });
}

function rebalanceBySharing(assignments, demands, profiles) {
  let evaluation = assignmentEvaluation(assignments, profiles);
  for (let pass = 0; pass < profiles.length * 2 && evaluation.totalOverload > .05; pass += 1) {
    const centroids = assignmentCentroids(assignments, profiles);
    let best = { assignments, evaluation };
    demands.forEach((demand) => profiles.forEach((profile) => {
      const existingOwners = new Set(demand.machines.flatMap((machine) => ownersOfMachine(assignments, machine.id)));
      const employeeId = String(profile.employee.id);
      if (existingOwners.has(employeeId)) return;
      const sharedFrequency = demand.frequency / (existingOwners.size + 1);
      if (sharedFrequency > Math.ceil(profile.drivingDays) + .001) return;
      const nearestExisting = [...existingOwners].reduce((best, ownerId) => {
        const distance = distanceKm(demand.point, centroids.get(String(ownerId)) || state.depot);
        return distance < best.distance ? { ownerId, distance } : best;
      }, { ownerId: null, distance: Infinity });
      if (!geographicallyAdjacentMove(demand, nearestExisting.ownerId, employeeId, centroids)) return;
      const simulated = copyAssignments(assignments);
      addSharedLocationOwner(simulated, demand, employeeId);
      const candidate = assignmentEvaluation(simulated, profiles);
      if (candidate.score + .01 < best.evaluation.score) best = { assignments: simulated, evaluation: candidate };
    }));
    if (best.assignments === assignments) break;
    assignments = best.assignments;
    evaluation = best.evaluation;
  }
  return { assignments, evaluation };
}

function automaticAssignment() {
  const profiles = activeEmployees().map(prepareAutomaticSchedule);
  if (!profiles.length) return say('Zařaď do návrhu alespoň jednoho člověka.', true);
  const demands = state.locations.map(locationDemand).filter((item) => item.point && item.machines.length).sort((a, b) => b.workload - a.workload);
  if (!demands.length) return say('Nenalezl jsem žádné aktivní automaty k rozdělení.', true);
  if ([...state.draft.values()].some((owners) => owners.size) && !confirm('Automatický návrh nahradí nynější ruční rozdělení. Pokračovat?')) return;

  const seeds = [];
  const remaining = [...demands];
  while (seeds.length < profiles.length && remaining.length) {
    let bestIndex = 0, bestDistance = -1;
    remaining.forEach((item, index) => {
      const separation = seeds.length ? Math.min(...seeds.map((seed) => distanceKm(item.point, seed.point))) : distanceKm(state.depot, item.point);
      if (separation > bestDistance) { bestDistance = separation; bestIndex = index; }
    });
    seeds.push(remaining.splice(bestIndex, 1)[0]);
  }
  const orderedProfiles = [...profiles].sort((a, b) => b.maxMinutes - a.maxMinutes || nameOf(a.employee).localeCompare(nameOf(b.employee), 'cs'));
  let centroids = new Map(orderedProfiles.map((profile, index) => [String(profile.employee.id), seeds[index]?.point || state.depot]));
  let groups = new Map();
  let loads = new Map();
  for (let pass = 0; pass < 8; pass += 1) {
    groups = new Map(profiles.map((profile) => [String(profile.employee.id), []]));
    loads = new Map(profiles.map((profile) => [String(profile.employee.id), 0]));
    demands.forEach((demand) => {
      const feasibleExists = profiles.some((profile) => Math.ceil(profile.drivingDays) >= Math.ceil(demand.frequency - .001));
      const selected = profiles.reduce((best, profile) => {
        const key = String(profile.employee.id), projected = (loads.get(key) || 0) + demand.workload;
        const utilization = projected / Math.max(1, profile.maxMinutes), overload = Math.max(0, utilization - 1);
        const geographic = distanceKm(centroids.get(key) || state.depot, demand.point) * Math.max(1, demand.frequency);
        const frequencyPenalty = feasibleExists && Math.ceil(profile.drivingDays) < Math.ceil(demand.frequency - .001) ? 1000000 : 0;
        const score = frequencyPenalty + geographic * 20 + utilization ** 2 * 1200 + overload ** 2 * 500000;
        return !best || score < best.score ? { profile, score } : best;
      }, null).profile;
      const key = String(selected.employee.id); groups.get(key).push(demand); loads.set(key, (loads.get(key) || 0) + demand.workload);
    });
    centroids = new Map(profiles.map((profile) => {
      const key = String(profile.employee.id); return [key, weightedCentroid(groups.get(key) || [], centroids.get(key) || state.depot)];
    }));
  }

  let preliminary = new Map(state.machines.map((machine) => [String(machine.id), new Set()]));
  profiles.forEach((profile) => (groups.get(String(profile.employee.id)) || []).forEach((demand) => setLocationOwner(preliminary, demand, profile.employee.id)));
  const balanced = rebalanceAssignments(preliminary, demands, profiles);
  state.draft = balanced.assignments;
  demands.forEach((demand) => demand.machines.forEach((machine) => {
    const primary = profiles.find((profile) => String(profile.employee.id) === String(primaryOwnerOf(state.draft, demand)));
    if (!primary) return;
    const owners = [primary], frequency = requiredVisitsMachine(machine.id);
    while (owners.some((owner) => frequency / owners.length > Math.ceil(owner.drivingDays) + .001) && owners.length < profiles.length) {
      const candidates = profiles.filter((candidate) => !owners.includes(candidate));
      if (!candidates.length) break;
      candidates.sort((a, b) => {
        const score = (candidate) => distanceKm(centroids.get(String(candidate.employee.id)) || state.depot, demand.point) * 5 + (loads.get(String(candidate.employee.id)) || 0) / Math.max(1, candidate.maxMinutes) * 100;
        return score(a) - score(b);
      });
      owners.push(candidates[0]);
    }
    state.draft.set(String(machine.id), new Set(owners.map((owner) => String(owner.employee.id))));
  }));
  const sharedBalance = rebalanceBySharing(state.draft, demands, profiles);
  state.draft = sharedBalance.assignments;
  const finalEvaluation = sharedBalance.evaluation;
  markDirty(); renderAll();
  const summary = profiles.map((profile) => `${profile.employee.name}: ${rhythmText(profile.drivingDays)}`).join(' · ');
  const overloaded = finalEvaluation.stats.filter((item) => item.hours > item.profile.employee.weeklyFund + .05);
  say(overloaded.length ? `Kapacita stále nevychází: ${overloaded.map((item) => `${item.profile.employee.name} ${number(item.hours)}/${number(item.profile.employee.weeklyFund)} h`).join(', ')}. Část lokalit je nutné přerozdělit nebo změnit četnost.` : `Automatický návrh je kapacitně vyvážený. ${summary}. Teď můžeš lokality ručně doladit.`, overloaded.length > 0);
}

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
    const rhythm = routeDraft ? rhythmText(routeDraft.rhythmDays) : `výchozí kapacita ${rhythmText(targetDrivingDays(employee))}`;
    return `<button class="person ${String(employee.id) === String(state.selectedEmployeeId) ? 'active' : ''} ${employee.included ? '' : 'excluded'}" data-employee-id="${esc(employee.id)}" style="--person:${employee.color}"><span class="avatar">${esc(initials)}</span><span><b>${esc(nameOf(employee))}</b><small>${number(displayed.hours)} h · ${Math.round(displayed.km)} km týdně ${routeDraft ? 'po silnici' : '· předběžně'}</small><small class="person-route-state ${routeDraft ? '' : 'pending'}">${routeDraft ? `trasy spočítány · ${rhythm}` : rhythm}</small><label class="include-row"><input class="include-input" data-include-id="${esc(employee.id)}" type="checkbox" ${employee.included ? 'checked' : ''}> zahrnout do návrhu</label></span><span class="fund"><span><input class="fund-input" data-fund-id="${esc(employee.id)}" type="number" min="1" max="80" value="${employee.weeklyFund}" ${employee.included ? '' : 'disabled'}> h</span><small>týdně</small></span></button>`;
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

function minimumVisitGapDays(visitCount) {
  if (visitCount > 9) return 1;
  return Math.max(1, Math.floor(21 / Math.max(1, visitCount)));
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
    const minimumGapDays = minimumVisitGapDays(visits.length);
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
    const minimumGapDays = minimumVisitGapDays(visits.length);
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
  const idealGap = 21 / days.length, minimumGap = minimumVisitGapDays(days.length);
  return days.reduce((score, day, index) => {
    const next = index === days.length - 1 ? days[0] + 21 : days[index + 1];
    const gap = next - day;
    return score + Math.max(0, minimumGap - gap) * 1000000000000 + ((gap - idealGap) ** 2) * 10000;
  }, 0);
}

function operationalRouteSetScore(selectedRoutes, location, point, serviceMinutes, settings) {
  return selectedRoutes.reduce((score, route) => {
    const existing = route.stops.find((stop) => String(stop.locationId) === String(location.id));
    const projectedService = route.serviceMinutes + serviceMinutes;
    const projectedStops = existing ? route.stops : [...route.stops, { latitude: point[0], longitude: point[1] }];
    const projectedDrive = projectedStops.length ? routeLength(projectedStops.map((stop) => [stop.latitude, stop.longitude])) / 55 * 60 : 0;
    const projectedTotal = projectedService + projectedDrive, maximum = Math.max(60, Number(settings.maxHours || 12) * 60);
    const overtime = Math.max(0, projectedTotal - maximum);
    return score + overtime ** 2 * 1000000 + projectedTotal ** 2 * 10 + projectedDrive * 500;
  }, 0);
}

function bestTemporalSubsetScore(routes, count) {
  if (count >= routes.length) return temporalRouteScore(routes);
  return combinations(routes, count).reduce((best, selectedRoutes) => Math.min(best, temporalRouteScore(selectedRoutes)), Infinity);
}

function bestRoutesForMachine(routes, count, location, point, serviceMinutes, settings) {
  const routeSets = combinations(routes, count);
  return routeSets.reduce((best, selectedRoutes) => {
    const score = temporalRouteScore(selectedRoutes) + operationalRouteSetScore(selectedRoutes, location, point, serviceMinutes, settings);
    return !best || score < best.score ? { routes: selectedRoutes, score } : best;
  }, null)?.routes || [];
}

function bestRoutesForLocation(routes, plan, location, point, settings) {
  const visitCount = Math.min(plan.occurrences, routes.length);
  const averageService = plan.machines.reduce((sum, item) => sum + plannedMinutesMachine(item.machine.id) * Math.min(item.occurrences, visitCount), 0) / visitCount;
  return combinations(routes, visitCount).reduce((best, selectedRoutes) => {
    const compatibility = plan.machines.reduce((score, item) => score + bestTemporalSubsetScore(selectedRoutes, Math.min(item.occurrences, selectedRoutes.length)), 0);
    const score = temporalRouteScore(selectedRoutes) + compatibility + operationalRouteSetScore(selectedRoutes, location, point, averageService, settings);
    return !best || score < best.score ? { routes: selectedRoutes, score } : best;
  }, null)?.routes || [];
}

function removeLocationFromRoutes(routes, locationId) {
  routes.forEach((route) => {
    route.stops = route.stops.filter((stop) => String(stop.locationId) !== String(locationId));
    estimateRoute(route);
  });
}

function assignLocationPlan(routes, plan, settings) {
  const location = state.locations.find((item) => String(item.id) === plan.locationId), point = pointOf(location);
  if (!point) return;
  const locationRoutes = bestRoutesForLocation(routes, plan, location, point, settings);
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
  routes.forEach(estimateRoute);
}

function rhythmCandidates(employee, settings) {
  const available = [...new Set(settings.availableDays || [1, 2, 3, 4, 5])].filter((day) => day >= 1 && day <= 5).sort((a, b) => a - b);
  const highestFrequency = assignedMachines(employee).reduce((maximum, machine) => Math.max(maximum, requiredVisitsMachine(machine.id) / Math.max(1, ownersOfMachine(state.draft, machine.id).length)), 0);
  const minimumDays = Math.min(available.length, Math.max(2, Math.floor(highestFrequency + .001)));
  const minimumCycleDays = Math.max(minimumDays * 3, Math.ceil(highestFrequency * 3 - .001));
  const candidates = [];
  for (let totalDays = minimumCycleDays; totalDays <= available.length * 3; totalDays += 1) {
    const counts = balancedWeekCounts(totalDays);
    if (counts.some((count) => count < minimumDays || count > available.length)) continue;
    const weeks = counts.map((count) => bestSpreadDays(available, count)[0] || []);
    candidates.push({ weeks, totalDays, averageDays: totalDays / 3 });
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
  locationPlans.forEach((plan) => assignLocationPlan(routes, plan, settings));
  for (let pass = 0; pass < 2; pass += 1) {
    const plans = pass % 2 ? [...locationPlans].reverse() : locationPlans;
    plans.forEach((plan) => { removeLocationFromRoutes(routes, plan.locationId); assignLocationPlan(routes, plan, settings); });
  }
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
  const rhythmDescription = Array.isArray(draft.weekDayCounts) ? `${draft.weekDayCounts.join(' + ')} jízdních dnů v týdnech cyklu` : rhythmText(draft.rhythmDays);
  const overFund = totals.totalHours > cycleFund + .05, invalid = draft.solverFeasible === false || spacingViolations > 0 || hardDays > 0 || overFund;
  const problems = [overFund ? `fond je překročen o ${number(totals.totalHours - cycleFund)} h` : '', hardDays ? `${hardDays} směny jsou nad denním maximem` : '', spacingViolations ? `${spacingViolations} návštěvy jsou příliš blízko po sobě` : '', draft.solverFeasible === false && !overFund && !hardDays ? 'solver nenašel proveditelnou variantu' : ''].filter(Boolean);
  $('routeResults').innerHTML = `<div class="route-recommendation ${invalid ? 'bad' : ''}"><div><b>${invalid ? 'Tento rajón není v této podobě odjezditelný' : `Doporučuji ${rhythmDescription}`}</b><p>${invalid ? `${problems.join(' · ')}. Vrať se k mapě a část lokalit přesuň jinému člověku; tento výsledek nelze uložit jako hotový.` : `Opakované návštěvy jsou rozložené v týdnu; četnost 2× týdně není naplánovaná ve dvou sousedních dnech. Jednotlivé týdny se mohou lišit podle četností automatů.`}</p></div><span class="pill">průměr ${number(average)} h/den · nejdelší ${minutesLabel(longest)}</span></div><div class="cycle-summary"><div class="cycle-kpi ${budgetClass}"><span>Celý 3týdenní cyklus</span><b>${number(totals.totalHours)} / ${number(cycleFund)} h</b></div><div class="cycle-kpi"><span>Silniční vzdálenost</span><b>${Math.round(totals.totalKm)} km</b></div><div class="cycle-kpi"><span>Cesta / obsluha</span><b>${number(totals.driveHours)} / ${number(totals.serviceHours)} h</b></div><div class="cycle-kpi ${hardClass}"><span>Denní limity</span><b>${hardDays ? `${hardDays} nad maximum` : softDays ? `${softDays} delší směny` : 'bez překročení'}</b></div></div>${weeks}<div class="route-provider">Optimalizace: Google OR-Tools · silniční časy a km: Google Routes Matrix · obsluha: přesný součet nastavených minut automatů</div>`;
  $('saveRouteDraft').disabled = invalid;
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

function solverDaySlots(settings) {
  const start = localDate(settings.cycleStart);
  const available = [...new Set(settings.availableDays || [1, 2, 3, 4, 5])].filter((day) => day >= 1 && day <= 5).sort((a, b) => a - b);
  return [0, 1, 2].flatMap((weekIndex) => available.map((weekday) => ({
    key: `${weekIndex + 1}-${weekday}`,
    date: isoDate(addCalendarDays(start, weekIndex * 7 + weekday - 1)),
    weekIndex,
    weekday,
    cycleDay: weekIndex * 7 + weekday - 1
  })));
}

function solverLocations(employee, dayCount) {
  const grouped = new Map();
  assignedMachines(employee).forEach((machine) => {
    const location = state.locations.find((item) => String(item.id) === String(machine.location_id));
    const point = pointOf(location); if (!location || !point) return;
    const owners = ownersOfMachine(state.draft, machine.id);
    const occurrences = Math.max(1, Math.round(requiredVisitsMachine(machine.id) * 3 / Math.max(1, owners.length)));
    if (occurrences > dayCount) throw new Error(`${location.name}: požadovaná četnost ${occurrences} návštěv se nevejde do ${dayCount} povolených dnů.`);
    const key = String(location.id), item = grouped.get(key) || {
      id: key, name: location.name || 'Lokalita', city: location.city || '', address: location.address || '', latitude: point[0], longitude: point[1], machines: []
    };
    item.machines.push({ id: String(machine.id), serviceMinutes: plannedMinutesMachine(machine.id), occurrences });
    grouped.set(key, item);
  });
  return [...grouped.values()].sort((a, b) => a.name.localeCompare(b.name, 'cs'));
}

async function googleRoadMatrix(locations, settings) {
  const departure = new Date(`${settings.cycleStart}T${settings.startTime || '06:00'}:00`);
  const departureTime = departure.getTime() > Date.now() + 60000 ? departure.toISOString() : new Date(Date.now() + 120000).toISOString();
  const points = [
    { latitude: state.depot[0], longitude: state.depot[1], label: 'Sklad Blučina' },
    ...locations.map((location) => ({ latitude: location.latitude, longitude: location.longitude, label: location.name }))
  ];
  const response = await supabase.functions.invoke('google-route-plan', { body: {
    mode: 'matrix', origin: points[0], points, departureTime
  } });
  if (response.error || response.data?.error) throw new Error(response.data?.error || response.error?.message || 'Google Routes nevrátil silniční matici.');
  if (!Array.isArray(response.data?.durationSeconds) || !Array.isArray(response.data?.distanceMeters)) throw new Error('Google Routes vrátil neúplnou silniční matici.');
  return response.data;
}

async function runTerritorySolver(payload) {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error('Přihlášení vypršelo. Přihlas se prosím znovu.');
  const controller = new AbortController(), timer = window.setTimeout(() => controller.abort(), 90000);
  try {
    const response = await fetch(TERRITORY_SOLVER_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${session.access_token}` },
      body: JSON.stringify(payload),
      signal: controller.signal
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok || data?.error) throw new Error(data?.error || `Optimalizační služba odpověděla ${response.status}.`);
    return data;
  } finally { window.clearTimeout(timer); }
}

function routesFromSolver(result, locations) {
  const byId = new Map(locations.map((location) => [String(location.id), location]));
  return (result.days || []).filter((day) => Array.isArray(day.stops) && day.stops.length).map((day) => ({
    key: String(day.key),
    weekIndex: Number(day.weekIndex),
    day: Number(day.weekday),
    date: day.date,
    stops: day.stops.map((stop) => {
      const location = byId.get(String(stop.locationId));
      return {
        locationId: String(stop.locationId), name: location?.name || stop.name || 'Lokalita', city: location?.city || '', address: location?.address || '',
        latitude: location?.latitude, longitude: location?.longitude, machineIds: (stop.machineIds || []).map(String), serviceMinutes: Number(stop.serviceMinutes || 0)
      };
    }),
    serviceMinutes: Number(day.serviceSeconds || 0) / 60,
    driveMinutes: Number(day.driveSeconds || 0) / 60,
    distanceKm: Number(day.distanceMeters || 0) / 1000,
    totalMinutes: Number(day.totalSeconds || 0) / 60,
    provider: 'google_or_tools'
  }));
}

async function generateRoutes() {
  const employee = employeeById(state.planningEmployeeId); if (!employee) return;
  let settings;
  try { settings = syncRouteSettings(employee, true); } catch (error) { return say(error.message, true); }
  const requestId = ++state.routeRequestId;
  $('routeProgress').hidden = false; $('generateRoutes').disabled = true;
  try {
    const daySlots = solverDaySlots(settings), locations = solverLocations(employee, daySlots.length);
    if (!locations.length) throw new Error('Rajón neobsahuje žádnou lokalitu s platnými souřadnicemi.');
    $('routeProgressText').textContent = `Načítám skutečné silniční časy pro ${locations.length} lokalit…`;
    const matrix = await googleRoadMatrix(locations, settings);
    if (requestId !== state.routeRequestId) return;
    $('routeProgressText').textContent = 'Google OR-Tools hledá nejlepší rozložení návštěv a tras…';
    const result = await runTerritorySolver({
      durationMatrix: matrix.durationSeconds,
      distanceMatrix: matrix.distanceMeters,
      daySlots,
      locations: locations.map(({ id, name, machines }) => ({ id, name, machines })),
      capacityMinutes: Number(settings.maxHours) * 60,
      fundMinutes: Number(employee.weeklyFund) * 3 * 60,
      seed: 20261107
    });
    if (requestId !== state.routeRequestId) return;
    const routes = routesFromSolver(result, locations), totals = routeDraftTotals(routes);
    settings.weeks = [0, 1, 2].map((weekIndex) => routes.filter((route) => route.weekIndex === weekIndex).map((route) => route.day).sort((a, b) => a - b));
    const activeRoutes = routes.filter((route) => route.stops.length);
    settings.recommendedHours = Math.min(settings.maxHours, Math.ceil((totals.totalHours / Math.max(1, activeRoutes.length)) * 2) / 2);
    const spacingViolations = planningSpacingViolations(routes, employee);
    state.routeDrafts.set(String(employee.id), {
      routes,
      rhythmDays: routes.length / 3,
      weekDayCounts: settings.weeks.map((days) => days.length),
      spacingViolations,
      solverFeasible: result.feasible === true,
      solverProvider: result.provider,
      generatedAt: new Date().toISOString(),
      ...totals
    });
    markDirty(false); renderPeople(); renderRouteResults(employee);
    const hardDays = routes.filter((route) => route.totalMinutes > settings.maxHours * 60).length;
    const invalid = !result.feasible || spacingViolations > 0 || hardDays > 0;
    say(invalid
      ? 'Solver potvrdil, že tento rajón v zadaném fondu nebo denním limitu není odjezditelný. Přesuň část lokalit jinému člověku.'
      : `OR-Tools našel odjezditelný rytmus ${settings.weeks.map((days) => days.length).join(' + ')} dní. Trasy i rozestupy jsou ověřené po skutečných silnicích.`, invalid);
  } catch (error) {
    console.error(error);
    const message = error?.name === 'AbortError' ? 'Optimalizační výpočet překročil 90 sekund.' : (error.message || error);
    say(`Trasy nelze spočítat: ${message}`, true);
  } finally { if (requestId === state.routeRequestId) { $('routeProgress').hidden = true; $('generateRoutes').disabled = false; } }
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
function snapshot() { return { version: 16, savedAt: new Date().toISOString(), machineAssignments: Object.fromEntries([...state.draft].map(([id, owners]) => [id, [...owners]])), requiredVisitsByMachine: Object.fromEntries(state.requiredVisits), plannedMachineMinutes: Object.fromEntries(state.plannedMachineMinutes), funds: Object.fromEntries(state.employees.map((employee) => [employee.id, employee.weeklyFund])), included: Object.fromEntries(state.employees.map((employee) => [employee.id, employee.included])), scheduleSettings: Object.fromEntries(state.scheduleSettings), routeDrafts: Object.fromEntries(state.routeDrafts) }; }
function saveDraft() { localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot())); state.dirty = false; $('saveDraft').textContent = 'Uloženo ✓'; say('Návrh je uložen jen v tomto prohlížeči. Ostré rajóny se nezměnily.'); }

function loadDraft() {
  try {
    localStorage.removeItem('olvend-territory-planner-draft-v1'); localStorage.removeItem('olvend-territory-planner-draft-v2');
    const legacy = LEGACY_STORAGE_KEYS.map((key) => localStorage.getItem(key)).find(Boolean);
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || legacy || 'null'); if (![3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16].includes(saved?.version)) return false;
    state.employees.forEach((employee) => { if (Number(saved.funds?.[employee.id]) > 0) employee.weeklyFund = Number(saved.funds[employee.id]); if (typeof saved.included?.[employee.id] === 'boolean') employee.included = saved.included[employee.id]; });
    Object.entries(saved.machineAssignments || {}).forEach(([machineId, owners]) => { if (state.machines.some((machine) => String(machine.id) === String(machineId))) state.draft.set(String(machineId), new Set((owners || []).filter((id) => employeeById(id)?.included))); });
    if (saved.version >= 4) Object.entries(saved.requiredVisitsByMachine || {}).forEach(([machineId, visits]) => state.requiredVisits.set(String(machineId), Math.max(.1, Number(visits) || .1)));
    else Object.entries(saved.requiredVisits || {}).forEach(([locationId, visits]) => machinesAt(locationId).forEach((machine) => state.requiredVisits.set(String(machine.id), Math.max(.1, Number(visits) || .1))));
    if (saved.version >= 6) Object.entries(saved.plannedMachineMinutes || {}).forEach(([machineId, minutes]) => state.plannedMachineMinutes.set(String(machineId), Math.max(1, Math.min(180, Number(minutes) || 20))));
    if (saved.version >= 13) {
      Object.entries(saved.scheduleSettings || {}).forEach(([employeeId, settings]) => { if (employeeById(employeeId) && Array.isArray(settings?.weeks)) state.scheduleSettings.set(String(employeeId), settings); });
      if (saved.version >= 16) Object.entries(saved.routeDrafts || {}).forEach(([employeeId, draft]) => { if (employeeById(employeeId) && Array.isArray(draft?.routes)) state.routeDrafts.set(String(employeeId), draft); });
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
$('autoAssignAll').addEventListener('click', automaticAssignment);
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
