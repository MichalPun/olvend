import assert from 'node:assert/strict'
import {
  persistCoffeeVisitItem,
  saveCoffeePreparationRecord,
  serializeCoffeePreparation
} from '../mobile-coffee-visit.js'

function createClient(handler) {
  return {
    from(table) {
      const query = { table, operation: null, value: null, filters: [], options: null }
      const builder = {
        update(value) {
          query.operation = 'update'
          query.value = value
          return builder
        },
        insert(value) {
          query.operation = 'insert'
          query.value = value
          return builder
        },
        upsert(value, options) {
          query.operation = 'upsert'
          query.value = value
          query.options = options
          return Promise.resolve(handler({ ...query }))
        },
        eq(column, value) {
          query.filters.push([column, value])
          return builder
        },
        select(columns) {
          query.select = columns
          return builder
        },
        maybeSingle() {
          return Promise.resolve(handler({ ...query }))
        },
        single() {
          return Promise.resolve(handler({ ...query }))
        }
      }
      return builder
    }
  }
}

const detail = {
  machineOpen: true,
  draft: {
    containers: { 10: { accepted: true, packages: 2 } },
    picklistStep: 'quality',
    gearChecks: { cups: true },
    qualityOutcomes: { coffee: 'ok' },
    qualityProblemReasons: { milk: 'empty' }
  }
}
const serialized = serializeCoffeePreparation(detail, undefined, '2026-10-21T08:00:00.000Z')
assert.deepEqual(serialized, {
  version: 2,
  phase: 'machine',
  containers: { 10: { accepted: true, packages: 2 } },
  picklistStep: 'quality',
  gearChecks: { cups: true },
  qualityOutcomes: { coffee: 'ok' },
  qualityProblemReasons: { milk: 'empty' },
  savedAt: '2026-10-21T08:00:00.000Z'
})

let preparationQuery
const preparationClient = createClient((query) => {
  preparationQuery = query
  return { data: { id: 'visit-1', coffee_preparation: serialized }, error: null }
})
const preparationResult = await saveCoffeePreparationRecord({
  client: preparationClient,
  visitId: 'visit-1',
  preparation: serialized,
  syncedAt: '2026-10-21T08:01:00.000Z'
})
assert.equal(preparationResult.saved, true)
assert.equal(preparationQuery.table, 'route_machine_visits')
assert.equal(preparationQuery.operation, 'update')
assert.deepEqual(preparationQuery.filters, [['id', 'visit-1']])
assert.equal(preparationQuery.value.synced_at, '2026-10-21T08:01:00.000Z')

const offlinePreparation = await saveCoffeePreparationRecord({
  client: null,
  visitId: 'visit-1',
  preparation: serialized,
  online: false
})
assert.deepEqual(offlinePreparation, { saved: false, queuedOffline: true, visit: null, error: null })

const row = {
  visit_id: 'visit-1',
  coffee_container_id: 'container-1',
  final_quantity: 1200
}

let onlineQuery
const onlineClient = createClient((query) => {
  onlineQuery = query
  return { data: { ...row, id: 'item-1' }, error: null }
})
const inserted = await persistCoffeeVisitItem({
  client: onlineClient,
  row,
  fallbackId: 'fallback-1',
  getPendingRequestCount: () => 0
})
assert.equal(onlineQuery.operation, 'insert')
assert.equal(inserted.savedRow.id, 'item-1')
assert.equal(inserted.requestQueued, false)

const existing = { ...row, id: 'item-1' }
await persistCoffeeVisitItem({
  client: onlineClient,
  row: { ...row, final_quantity: 1300 },
  existing,
  fallbackId: 'fallback-2',
  getPendingRequestCount: () => 0
})
assert.equal(onlineQuery.operation, 'update')
assert.deepEqual(onlineQuery.filters, [['id', 'item-1']])

let pendingRequests = 0
let offlineQuery
const offlineClient = createClient((query) => {
  offlineQuery = query
  pendingRequests += 1
  return { data: null, error: new Error('offline') }
})
const queued = await persistCoffeeVisitItem({
  client: offlineClient,
  row,
  offline: true,
  fallbackId: 'fallback-3',
  createUuid: () => 'uuid-new',
  getPendingRequestCount: () => pendingRequests
})
assert.equal(offlineQuery.operation, 'upsert')
assert.deepEqual(offlineQuery.options, { onConflict: 'client_uuid' })
assert.equal(queued.savedRow.id, 'offline-uuid-new')
assert.equal(queued.savedRow.client_uuid, 'uuid-new')
assert.equal(queued.savedRow._offlinePending, true)

const queuedExisting = await persistCoffeeVisitItem({
  client: offlineClient,
  row: { ...row, final_quantity: 1400 },
  existing: { id: 'offline-old', client_uuid: 'uuid-old', _offlinePending: true },
  offline: true,
  fallbackId: 'fallback-4',
  createUuid: () => { throw new Error('Nesmí se vytvořit nové UUID') },
  getPendingRequestCount: () => pendingRequests
})
assert.equal(offlineQuery.value[0].client_uuid, 'uuid-old')
assert.equal(queuedExisting.savedRow.id, 'offline-old')
assert.equal(queuedExisting.requestQueued, true)

const databaseError = new Error('database failed')
const failingClient = createClient(() => ({ data: null, error: databaseError }))
await assert.rejects(
  persistCoffeeVisitItem({
    client: failingClient,
    row,
    fallbackId: 'fallback-5',
    getPendingRequestCount: () => 0
  }),
  databaseError
)

console.log('PASS: coffee visit persistence module covers online, offline and retry paths')
