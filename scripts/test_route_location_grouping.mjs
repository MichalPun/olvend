import assert from 'node:assert/strict'
import fs from 'node:fs'
import {
  expandGroupedRouteStops,
  groupRouteStopsByLocation,
  routeLocationGroupKey,
} from '../route-location-groups.js'

const serviceMinutes = (stop) => Number(stop.estimatedServiceMinutes || 0)
const selectedStops = [
  { id: 103, machineId: 103, locationId: 50, name: 'Via coffee', latitude: 49.82461, longitude: 18.16067, estimatedServiceMinutes: 20 },
  { id: 69, machineId: 69, locationId: 58, name: 'Sportisimo coffee 1', latitude: 49.86865, longitude: 18.29187, estimatedServiceMinutes: 20 },
  { id: 59, machineId: 59, locationId: 50, name: 'Via food', latitude: 49.82461, longitude: 18.16067, estimatedServiceMinutes: 20 },
  { id: 70, machineId: 70, locationId: 58, name: 'Sportisimo coffee 2', latitude: 49.86865, longitude: 18.29187, estimatedServiceMinutes: 15 },
  { id: 4, machineId: 4, locationId: 52, name: 'Remante', latitude: 49.91533, longitude: 17.87266, estimatedServiceMinutes: 20 },
]

const groups = groupRouteStopsByLocation(selectedStops, { estimateServiceMinutes: serviceMinutes })
assert.equal(groups.length, 3, 'same location must be sent to the optimizer only once')
assert.deepEqual(groups.map((group) => group.locationId), [50, 58, 52])
assert.deepEqual(groups[0].groupMembers.map((stop) => stop.machineId), [103, 59])
assert.equal(groups[0].estimatedServiceMinutes, 40)
assert.equal(groups[1].estimatedServiceMinutes, 35)

const googleOrder = [groups[2], groups[0], groups[1]].map((group, index) => ({
  ...group,
  googleLegDistanceMeters: [12000, 8000, 5000][index],
  googleLegDurationSeconds: [900, 600, 420][index],
}))
const expanded = expandGroupedRouteStops(googleOrder, groups, {
  estimateServiceMinutes: serviceMinutes,
  legScale: 1,
})

assert.deepEqual(expanded.map((stop) => stop.machineId), [4, 103, 59, 69, 70])
assert.deepEqual(expanded.map((stop) => stop.locationId), [52, 50, 50, 58, 58])
assert.deepEqual(expanded.map((stop) => stop.googleLegDurationSeconds), [900, 600, 0, 420, 0])
assert.deepEqual(expanded.map((stop) => stop.distanceFromPreviousKm), [12, 8, 0, 5, 0])
assert.equal(expanded.reduce((sum, stop) => sum + stop.estimatedServiceMinutes, 0), 95)

assert.equal(routeLocationGroupKey({ locationId: 50, latitude: 1, longitude: 2 }), 'location:50')
assert.equal(
  routeLocationGroupKey({ latitude: 49.82461041, longitude: 18.16067649 }),
  routeLocationGroupKey({ latitude: 49.82461039, longitude: 18.16067651 }),
  'coordinate fallback should absorb harmless rounding differences',
)

const html = fs.readFileSync(new URL('../routes-create.html', import.meta.url), 'utf8')
assert.match(html, /import \{ groupRouteStopsByLocation, expandGroupedRouteStops \} from '\.\/route-location-groups\.js'/)
assert.ok((html.match(/groupRouteStopsByLocation\(/g) || []).length >= 3, 'Google, manual, and heuristic paths must group locations')
assert.ok((html.match(/expandGroupedRouteStops\(/g) || []).length >= 3, 'all three planner paths must expand grouped locations')

console.log('route location grouping checks passed')
