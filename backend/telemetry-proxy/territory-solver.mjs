import {
  FirstSolutionStrategy,
  RoutingIndexManager,
  RoutingModel,
  setCloudNoticeEnabled
} from 'or-tools-wasm/routing'

setCloudNoticeEnabled(false)

const MAX_LOCATIONS = 90
const MAX_DAYS = 15
const MAX_PATTERN_CANDIDATES = 36
const MAX_EXACT_ORDER_STOPS = 12

function integer(value, label, minimum = 0, maximum = Number.MAX_SAFE_INTEGER) {
  const parsed = Math.round(Number(value))
  if (!Number.isFinite(parsed) || parsed < minimum || parsed > maximum) {
    throw new Error(`${label} musí být celé číslo od ${minimum} do ${maximum}.`)
  }
  return parsed
}

function squareMatrix(input, size, label) {
  if (!Array.isArray(input) || input.length !== size) throw new Error(`${label} nemá správný počet řádků.`)
  return input.map((row, rowIndex) => {
    if (!Array.isArray(row) || row.length !== size) throw new Error(`${label} není čtvercová.`)
    return row.map((value, columnIndex) => integer(value, `${label} ${rowIndex}:${columnIndex}`, 0, 100_000_000))
  })
}

function combinations(values, count, start = 0, chosen = [], result = []) {
  if (chosen.length === count) { result.push(chosen.slice()); return result }
  for (let index = start; index <= values.length - (count - chosen.length); index += 1) {
    chosen.push(values[index])
    combinations(values, count, index + 1, chosen, result)
    chosen.pop()
  }
  return result
}

function seededRandom(seed) {
  let value = seed >>> 0
  return () => {
    value += 0x6D2B79F5
    let result = value
    result = Math.imul(result ^ result >>> 15, result | 1)
    result ^= result + Math.imul(result ^ result >>> 7, result | 61)
    return ((result ^ result >>> 14) >>> 0) / 4294967296
  }
}

function circularGaps(days) {
  const ordered = [...days].sort((a, b) => a - b)
  return ordered.map((day, index) => (index === ordered.length - 1 ? ordered[0] + 21 : ordered[index + 1]) - day)
}

function temporalScore(days) {
  if (!days.length) return 0
  const ideal = 21 / days.length
  const gaps = circularGaps(days)
  const weeklyCounts = [0, 0, 0]
  days.forEach((day) => { weeklyCounts[Math.min(2, Math.floor(day / 7))] += 1 })
  const idealWeekly = days.length / 3
  return gaps.reduce((sum, gap) => sum + (gap - ideal) ** 2, 0) * 80
    + weeklyCounts.reduce((sum, count) => sum + (count - idealWeekly) ** 2, 0) * 200
}

function minimumGapFor(occurrences) {
  if (occurrences >= 10) return 1
  return Math.max(2, Math.ceil((21 / Math.max(1, occurrences)) * 0.75))
}

function patternCandidates(daySlots, occurrences) {
  if (occurrences > daySlots.length) return []
  const all = combinations(daySlots.map((_, index) => index), occurrences)
  const wantedGap = minimumGapFor(occurrences)
  let accepted = []
  for (let gap = wantedGap; gap >= 1 && !accepted.length; gap -= 1) {
    accepted = all.filter((indices) => Math.min(...circularGaps(indices.map((index) => daySlots[index].cycleDay))) >= gap)
  }
  return accepted
    .map((indices) => ({ indices, temporal: temporalScore(indices.map((index) => daySlots[index].cycleDay)) }))
    .sort((a, b) => a.temporal - b.temporal || a.indices.join(',').localeCompare(b.indices.join(',')))
    .slice(0, MAX_PATTERN_CANDIDATES)
}

function chooseSubset(pattern, count, daySlots) {
  if (count >= pattern.indices.length) return pattern.indices.slice()
  return combinations(pattern.indices, count)
    .map((indices) => ({ indices, score: temporalScore(indices.map((index) => daySlots[index].cycleDay)) }))
    .sort((a, b) => a.score - b.score)[0]?.indices || []
}

function normalizePayload(payload) {
  const rawLocations = Array.isArray(payload?.locations) ? payload.locations : []
  if (!rawLocations.length || rawLocations.length > MAX_LOCATIONS) throw new Error(`Výpočet podporuje 1 až ${MAX_LOCATIONS} lokalit.`)
  const size = rawLocations.length + 1
  const durationMatrix = squareMatrix(payload.durationMatrix, size, 'Matice jízdních časů')
  const distanceMatrix = squareMatrix(payload.distanceMatrix, size, 'Matice vzdáleností')
  const daySlots = (Array.isArray(payload.daySlots) ? payload.daySlots : []).map((slot, index) => ({
    key: String(slot?.key || `day-${index + 1}`),
    date: String(slot?.date || ''),
    weekIndex: integer(slot?.weekIndex ?? Math.floor(index / 5), 'Týden', 0, 2),
    weekday: integer(slot?.weekday ?? 1, 'Den týdne', 1, 7),
    cycleDay: integer(slot?.cycleDay ?? index, 'Den cyklu', 0, 20)
  }))
  if (daySlots.length < 2 || daySlots.length > MAX_DAYS) throw new Error(`Výpočet podporuje 2 až ${MAX_DAYS} pracovních dnů v cyklu.`)
  const locations = rawLocations.map((location, index) => {
    const machines = (Array.isArray(location?.machines) ? location.machines : []).map((machine) => ({
      id: String(machine?.id || ''),
      serviceMinutes: integer(machine?.serviceMinutes, 'Čas obsluhy', 1, 180),
      occurrences: integer(machine?.occurrences, 'Počet návštěv', 1, daySlots.length)
    }))
    if (!machines.length) throw new Error(`Lokalita ${location?.name || index + 1} nemá žádný automat.`)
    return {
      matrixIndex: index + 1,
      id: String(location?.id || index + 1),
      name: String(location?.name || `Lokalita ${index + 1}`),
      machines,
      occurrences: Math.max(...machines.map((machine) => machine.occurrences))
    }
  })
  return {
    durationMatrix,
    distanceMatrix,
    daySlots,
    locations,
    capacitySeconds: integer(Number(payload.capacityMinutes || 720) * 60, 'Denní limit', 3600, 16 * 3600),
    fundSeconds: integer(Number(payload.fundMinutes || 7200) * 60, 'Fond cyklu', 3600, 400 * 3600),
    seed: integer(payload.seed ?? 20261107, 'Seed', 1, 2_147_483_647)
  }
}

function buildSchedule(problem, selectedPatterns) {
  const days = problem.daySlots.map((slot) => ({ ...slot, stops: [] }))
  problem.locations.forEach((location, locationIndex) => {
    const pattern = selectedPatterns[locationIndex]
    if (!pattern) return
    const stopByDay = new Map()
    location.machines.forEach((machine) => {
      chooseSubset(pattern, machine.occurrences, problem.daySlots).forEach((dayIndex) => {
        let stop = stopByDay.get(dayIndex)
        if (!stop) {
          stop = { locationId: location.id, name: location.name, matrixIndex: location.matrixIndex, machineIds: [], serviceMinutes: 0 }
          stopByDay.set(dayIndex, stop)
        }
        stop.machineIds.push(machine.id)
        stop.serviceMinutes += machine.serviceMinutes
      })
    })
    stopByDay.forEach((stop, dayIndex) => days[dayIndex].stops.push(stop))
  })
  return days
}

function nearestOrder(stops, durationMatrix) {
  if (!stops.length) return []
  const remaining = stops.slice()
  const ordered = []
  let current = 0
  while (remaining.length) {
    let best = 0
    for (let index = 1; index < remaining.length; index += 1) {
      if (durationMatrix[current][remaining[index].matrixIndex] < durationMatrix[current][remaining[best].matrixIndex]) best = index
    }
    const [next] = remaining.splice(best, 1)
    ordered.push(next)
    current = next.matrixIndex
  }
  return ordered
}

function twoOptOrder(stops, durationMatrix) {
  const ordered = nearestOrder(stops, durationMatrix)
  if (ordered.length < 3) return ordered
  const routeSeconds = (items) => {
    let seconds = 0, from = 0
    items.forEach((stop) => { seconds += durationMatrix[from][stop.matrixIndex]; from = stop.matrixIndex })
    return seconds + durationMatrix[from][0]
  }
  let improved = true
  while (improved) {
    improved = false
    const baseline = routeSeconds(ordered)
    for (let left = 0; left < ordered.length - 1 && !improved; left += 1) {
      for (let right = left + 1; right < ordered.length; right += 1) {
        const candidate = [...ordered.slice(0, left), ...ordered.slice(left, right + 1).reverse(), ...ordered.slice(right + 1)]
        if (routeSeconds(candidate) + 1 < baseline) { ordered.splice(0, ordered.length, ...candidate); improved = true; break }
      }
    }
  }
  return ordered
}

function summarizeDay(day, problem, improve = true) {
  const ordered = improve ? twoOptOrder(day.stops, problem.durationMatrix) : nearestOrder(day.stops, problem.durationMatrix)
  let from = 0, driveSeconds = 0, distanceMeters = 0
  ordered.forEach((stop) => {
    driveSeconds += problem.durationMatrix[from][stop.matrixIndex]
    distanceMeters += problem.distanceMatrix[from][stop.matrixIndex]
    from = stop.matrixIndex
  })
  driveSeconds += problem.durationMatrix[from][0]
  distanceMeters += problem.distanceMatrix[from][0]
  const serviceSeconds = ordered.reduce((sum, stop) => sum + stop.serviceMinutes * 60, 0)
  return { ...day, stops: ordered, driveSeconds, distanceMeters, serviceSeconds, totalSeconds: driveSeconds + serviceSeconds }
}

function scheduleScore(problem, selectedPatterns) {
  const days = buildSchedule(problem, selectedPatterns).map((day) => summarizeDay(day, problem, false))
  const active = days.filter((day) => day.stops.length)
  const overtime = active.reduce((sum, day) => sum + Math.max(0, day.totalSeconds - problem.capacitySeconds), 0)
  const totalSeconds = active.reduce((sum, day) => sum + day.totalSeconds, 0)
  const fundOvertime = Math.max(0, totalSeconds - problem.fundSeconds)
  const driveSeconds = active.reduce((sum, day) => sum + day.driveSeconds, 0)
  const temporal = selectedPatterns.reduce((sum, pattern) => sum + Number(pattern?.temporal || 0), 0)
  const balance = active.reduce((sum, day) => sum + day.totalSeconds ** 2, 0) / 3600
  // Lexicographic intent: feasibility, minimum number of driving days, road time,
  // balanced shifts and only then small differences between equally valid patterns.
  const score = overtime * 1e12 + fundOvertime * 1e11 + active.length * 1e9 + driveSeconds * 1e4 + balance + temporal
  return { score, days, activeDays: active.length, overtime, fundOvertime, totalSeconds, driveSeconds }
}

function choosePatterns(problem) {
  const candidates = problem.locations.map((location) => patternCandidates(problem.daySlots, location.occurrences))
  const impossible = candidates.findIndex((items) => !items.length)
  if (impossible >= 0) throw new Error(`${problem.locations[impossible].name}: požadovanou četnost nelze rozložit do povolených dnů.`)
  let globalBest = null
  for (let restart = 0; restart < 3; restart += 1) {
    const random = seededRandom(problem.seed + restart * 997)
    const order = problem.locations.map((_, index) => index).sort((a, b) => {
      const frequency = problem.locations[b].occurrences - problem.locations[a].occurrences
      return frequency || random() - .5
    })
    const selected = new Array(problem.locations.length)
    order.forEach((locationIndex) => {
      let best = null
      candidates[locationIndex].forEach((pattern) => {
        selected[locationIndex] = pattern
        const value = scheduleScore(problem, selected)
        if (!best || value.score < best.value.score) best = { pattern, value }
      })
      selected[locationIndex] = best.pattern
    })
    let current = scheduleScore(problem, selected)
    for (let pass = 0; pass < 4; pass += 1) {
      let changed = false
      order.sort(() => random() - .5).forEach((locationIndex) => {
        const original = selected[locationIndex]
        let bestPattern = original, bestValue = current
        candidates[locationIndex].forEach((pattern) => {
          if (pattern === original) return
          selected[locationIndex] = pattern
          const value = scheduleScore(problem, selected)
          if (value.score + 1 < bestValue.score) { bestPattern = pattern; bestValue = value }
        })
        selected[locationIndex] = bestPattern
        if (bestPattern !== original) { current = bestValue; changed = true }
      })
      if (!changed) break
    }
    if (!globalBest || current.score < globalBest.value.score) globalBest = { patterns: selected.slice(), value: current }
  }
  return globalBest
}

async function exactDayOrder(day, problem) {
  if (day.stops.length < 2) return summarizeDay(day, problem)
  // U velkých dnů je 2-opt velmi blízko výsledku TSP a na rozdíl od WASM
  // nehrozí, že server zůstane minuty uzamčený v jednom výpočtu.
  if (day.stops.length > MAX_EXACT_ORDER_STOPS) return summarizeDay(day, problem)
  const nodes = [0, ...day.stops.map((stop) => stop.matrixIndex)]
  const matrix = nodes.map((from) => nodes.map((to) => problem.durationMatrix[from][to]))
  const manager = new RoutingIndexManager(nodes.length, 1, 0)
  const routing = new RoutingModel(manager)
  const transit = routing.registerTransitMatrix(matrix)
  routing.setArcCostEvaluatorOfAllVehicles(transit)
  const result = await routing.solve({ executor: 'direct', firstSolutionStrategy: FirstSolutionStrategy.PARALLEL_CHEAPEST_INSERTION, solutionLimit: 250 })
  if (!result.assignment) return summarizeDay(day, problem)
  const order = []
  let index = routing.start(0)
  while (!routing.isEnd(index)) {
    const localNode = manager.indexToNode(index)
    if (localNode > 0) order.push(day.stops.find((stop) => stop.matrixIndex === nodes[localNode]))
    index = result.assignment.value(routing.nextVar(index))
  }
  return summarizeDay({ ...day, stops: order.filter(Boolean) }, problem)
}

export async function solveTerritoryRoutes(payload) {
  const problem = normalizePayload(payload)
  const selected = choosePatterns(problem)
  const approximateDays = buildSchedule(problem, selected.patterns)
  const days = []
  for (const day of approximateDays) days.push(await exactDayOrder(day, problem))
  const active = days.filter((day) => day.stops.length)
  const totalSeconds = active.reduce((sum, day) => sum + day.totalSeconds, 0)
  const overtimeSeconds = active.reduce((sum, day) => sum + Math.max(0, day.totalSeconds - problem.capacitySeconds), 0)
  const fundOvertimeSeconds = Math.max(0, totalSeconds - problem.fundSeconds)
  return {
    provider: 'google_or_tools',
    feasible: overtimeSeconds === 0 && fundOvertimeSeconds === 0,
    activeDays: active.length,
    totalSeconds,
    driveSeconds: active.reduce((sum, day) => sum + day.driveSeconds, 0),
    serviceSeconds: active.reduce((sum, day) => sum + day.serviceSeconds, 0),
    distanceMeters: active.reduce((sum, day) => sum + day.distanceMeters, 0),
    overtimeSeconds,
    fundOvertimeSeconds,
    days
  }
}

