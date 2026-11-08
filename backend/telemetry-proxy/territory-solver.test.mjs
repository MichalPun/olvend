import assert from 'node:assert/strict'
import test from 'node:test'
import { solveTerritoryRoutes } from './territory-solver.mjs'

function daySlots() {
  return Array.from({ length: 15 }, (_, index) => ({
    key: `day-${index}`,
    date: `2026-11-${String(9 + index + Math.floor(index / 5) * 2).padStart(2, '0')}`,
    weekIndex: Math.floor(index / 5),
    weekday: index % 5 + 1,
    cycleDay: Math.floor(index / 5) * 7 + index % 5
  }))
}

test('two weekly visits are spaced and aligned into the minimum feasible driving days', async () => {
  const result = await solveTerritoryRoutes({
    durationMatrix: [[0, 600, 900], [600, 0, 300], [900, 300, 0]],
    distanceMatrix: [[0, 10_000, 15_000], [10_000, 0, 5_000], [15_000, 5_000, 0]],
    daySlots: daySlots(),
    locations: [
      { id: 'a', name: 'A', machines: [{ id: 'ma', serviceMinutes: 20, occurrences: 6 }] },
      { id: 'b', name: 'B', machines: [{ id: 'mb', serviceMinutes: 20, occurrences: 3 }] }
    ],
    capacityMinutes: 720,
    fundMinutes: 7_200
  })

  assert.equal(result.feasible, true)
  assert.equal(result.activeDays, 6)
  const aDays = result.days.filter((day) => day.stops.some((stop) => stop.locationId === 'a')).map((day) => day.cycleDay)
  const gaps = aDays.map((day, index) => (index === aDays.length - 1 ? aDays[0] + 21 : aDays[index + 1]) - day)
  assert.ok(gaps.every((gap) => gap >= 3), `unexpected gaps: ${gaps.join(', ')}`)
})

test('a result above the daily maximum is explicitly infeasible', async () => {
  const result = await solveTerritoryRoutes({
    durationMatrix: [[0, 21_600], [21_600, 0]],
    distanceMatrix: [[0, 300_000], [300_000, 0]],
    daySlots: daySlots(),
    locations: [{ id: 'far', name: 'Daleko', machines: [{ id: 'm', serviceMinutes: 120, occurrences: 3 }] }],
    capacityMinutes: 720,
    fundMinutes: 7_200
  })

  assert.equal(result.feasible, false)
  assert.ok(result.overtimeSeconds > 0)
})

test('a day with many stops finishes without an unbounded exact TSP search', async () => {
  const slots = daySlots().slice(0, 2)
  const locations = Array.from({ length: 13 }, (_, index) => ({
    id: `location-${index}`,
    name: `Lokalita ${index}`,
    machines: [{ id: `machine-${index}`, serviceMinutes: 20, occurrences: 2 }]
  }))
  const size = locations.length + 1
  const durationMatrix = Array.from({ length: size }, (_, from) => Array.from({ length: size }, (_, to) => from === to ? 0 : 300 + Math.abs(from - to) * 15))
  const distanceMatrix = durationMatrix.map((row) => row.map((seconds) => seconds * 12))

  const result = await solveTerritoryRoutes({
    durationMatrix,
    distanceMatrix,
    daySlots: slots,
    locations,
    capacityMinutes: 720,
    fundMinutes: 2_400
  })

  assert.equal(result.days.length, 2)
  assert.ok(result.days.every((day) => day.stops.length === 13))
})

