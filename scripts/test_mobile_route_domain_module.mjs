import assert from 'node:assert/strict'
import { createRouteDomain, ensureRouteVisitRecord } from '../mobile-route-domain.js'

const stops = [
  { id: 's1', route_plan_id: 'p1', machine_id: 'm1', location_id: 'l1', stop_order: 1, status: 'done' },
  { id: 's2', route_plan_id: 'p1', machine_id: 'm2', location_id: 'l2', stop_order: 2, status: 'pending' },
  { id: 's3', route_plan_id: 'p1', machine_id: 'm3', location_id: 'l2', stop_order: 3, status: 'pending' }
]
const plans = [
  { id: 'old', planning_date: '2026-10-20', execution_status: 'assigned', route_plan_stops: [] },
  { id: 'p1', planning_date: '2026-10-21', execution_status: 'assigned', route_plan_stops: stops }
]
const visits = []
const addRequests = [{
  route_plan_id: 'p1',
  status: 'approved',
  added_route_plan_stop_id: 's3',
  decided_at: '2026-10-21T08:00:00Z'
}]
const machines = {
  m1: { id: 'm1', location_id: 'l1' },
  m2: { id: 'm2', location_id: 'l2' },
  m3: { id: 'm3', location_id: 'l2' }
}

const domain = createRouteDomain({
  getRoutePlans: () => plans,
  getVisits: () => visits,
  getAddRequests: () => addRequests,
  getMachine: (stop) => machines[stop?.machine_id],
  getTodayIso: () => '2026-10-21'
})

assert.equal(domain.getAssignedRoutePlan().id, 'p1')
assert.deepEqual(domain.getRouteStops(plans[1]).map((stop) => stop.id), ['s1', 's3', 's2'],
  'Schválený přidaný automat musí být první otevřená zastávka')
assert.equal(domain.getRouteStopStatus(stops[0]), 'completed')
assert.equal(domain.isRouteStopClosed(stops[0]), true)
assert.deepEqual(domain.getCurrentRouteLocationStops(plans[1]).map((stop) => stop.id), ['s3', 's2'])
assert.equal(domain.isCurrentRouteLocationStop(plans[1], stops[1]), true)
assert.equal(domain.findRouteStop('s2').stop.id, 's2')

visits.push({ id: 10, route_plan_stop_id: 's2', route_plan_id: 'p1', machine_id: 'm2', status: 'arrived', arrived_at: '2026-10-21T08:30:00Z' })
assert.equal(domain.getRouteStopStatus(stops[1]), 'arrived')
assert.deepEqual(domain.getRouteStops(plans[1]).map((stop) => stop.id), ['s1', 's2', 's3'],
  'Rozpracovaná zastávka se nesmí přeřadit pod nově schválený automat')

function createClient(handler) {
  return {
    from(table) {
      const query = { table, operation: null, value: null, filters: [] }
      const builder = {
        update(value) { query.operation = 'update'; query.value = value; return builder },
        insert(value) { query.operation = 'insert'; query.value = value; return builder },
        eq(column, value) { query.filters.push([column, value]); return builder },
        select(columns) { query.select = columns; return builder },
        single() { return Promise.resolve(handler({ ...query, filters: [...query.filters] })) },
        then(resolve, reject) { return Promise.resolve(handler({ ...query, filters: [...query.filters] })).then(resolve, reject) }
      }
      return builder
    }
  }
}

let insertQuery
const insertedId = await ensureRouteVisitRecord({
  client: createClient((query) => { insertQuery = query; return { data: { id: 77 }, error: null } }),
  plan: plans[1],
  stop: stops[2],
  machine: machines.m3,
  existing: null,
  employeeId: 4,
  vehicleId: 8,
  visitDate: '2026-10-21',
  machineKind: 'food',
  nowIso: '2026-10-21T09:00:00Z'
})
assert.equal(insertedId, 77)
assert.equal(insertQuery.operation, 'insert')
assert.equal(insertQuery.value[0].route_plan_stop_id, 's3')
assert.equal(insertQuery.value[0].status, 'arrived')

let updateQuery
const existingId = await ensureRouteVisitRecord({
  client: createClient((query) => { updateQuery = query; return { data: null, error: null } }),
  plan: plans[1],
  stop: stops[2],
  machine: machines.m3,
  existing: { id: 88, status: 'pending', arrived_at: null },
  visitDate: '2026-10-21',
  machineKind: 'food',
  nowIso: '2026-10-21T09:05:00Z'
})
assert.equal(existingId, 88)
assert.equal(updateQuery.operation, 'update')
assert.deepEqual(updateQuery.filters, [['id', 88]])

console.log('PASS: shared route order, stop status and visit creation are isolated')
