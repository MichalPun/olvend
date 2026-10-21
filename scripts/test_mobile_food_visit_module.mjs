import assert from 'node:assert/strict'
import {
  hasPersistedFoodVisitItemId,
  persistFoodVisitItem,
  saveFoodProgressRecord,
  serializeFoodPreparation
} from '../mobile-food-visit.js'

function createClient(handler) {
  return {
    from(table) {
      const query = { table, operation: 'select', value: null, filters: [] }
      const builder = {
        select(columns) { query.select = columns; return builder },
        update(value) { query.operation = 'update'; query.value = value; return builder },
        insert(value) { query.operation = 'insert'; query.value = value; return builder },
        eq(column, value) { query.filters.push([column, value]); return builder },
        order(column, options) { query.order = [column, options]; return builder },
        limit(value) { query.limit = value; return builder },
        maybeSingle() { return Promise.resolve(handler({ ...query, filters: [...query.filters] })) },
        single() { return Promise.resolve(handler({ ...query, filters: [...query.filters] })) },
        then(resolve, reject) { return Promise.resolve(handler({ ...query, filters: [...query.filters] })).then(resolve, reject) }
      }
      return builder
    }
  }
}

const slots = [{ id: 9, capacity_units: 15 }]
const normalDraft = {
  selectedProductId: 12,
  fillItems: [{ productId: 12, quantity: 3, batchId: 7, expiryDate: '2026-11-15' }],
  preparedQuantity: 4,
  basePreparedQuantity: 3,
  extraVehicleQuantity: 1,
  picked: true,
  skipped: false,
  skipReason: '',
  notInsertedReason: 'not_needed',
  capacityUnits: 18,
  actualBefore: 6,
  wasteItems: [{ quantity: 1, reason: 'expired', autoSuggested: true }],
  existingExpiryDate: '2026-10-20',
  assortmentMismatch: false,
  existingProductId: 12,
  expiryVerified: true,
  transferQuantity: 0,
  transferRecommendation: null,
  manualProductChoice: true,
  pickConfirmed: true,
  operatorProposedPrice: '',
  operatorPriceNote: '',
  operatorPriceConfirmed: false,
  operatorPriceRequestStatus: '',
  operatorPriceRequestId: null,
  operatorPriceClientKey: '',
  operatorPriceMailWarning: '',
  deferFullSwap: false,
  cartLoadOrder: 2,
  note: 'kontrola'
}
const preparation = serializeFoodPreparation({ slots, getDraft: () => normalDraft })
assert.equal(preparation['9'].actualAdd, 3)
assert.equal(preparation['9'].preparedQuantity, 4)
assert.equal(preparation['9'].capacityUnits, 18)
assert.equal(preparation['9'].operatorProposedPrice, null)
assert.deepEqual(preparation['9'].wasteItems, [{ quantity: 1, reason: 'expired', autoSuggested: true }])

const skipped = serializeFoodPreparation({
  slots,
  getDraft: () => ({ ...normalDraft, skipped: true, skipReason: 'not_in_vehicle' })
})
assert.equal(skipped['9'].actualAdd, 0)
assert.equal(skipped['9'].preparedQuantity, 0)
assert.equal(skipped['9'].fillItems[0].quantity, 0)

let progressQuery
await saveFoodProgressRecord({
  client: createClient((query) => { progressQuery = query; return { error: null } }),
  visitId: 44,
  workPhase: 'machine',
  preparation,
  syncedAt: '2026-10-21T12:00:00.000Z'
})
assert.equal(progressQuery.table, 'route_machine_visits')
assert.equal(progressQuery.operation, 'update')
assert.deepEqual(progressQuery.filters, [['id', 44]])
assert.equal(progressQuery.value.work_phase, 'machine')

assert.equal(hasPersistedFoodVisitItemId(123), true)
assert.equal(hasPersistedFoodVisitItemId('offline-123'), false)

const row = { visit_id: 44, planogram_slot_id: 9, final_quantity: 9 }
const calls = []
const insertClient = createClient((query) => {
  calls.push(query)
  if (query.operation === 'select') return { data: null, error: null }
  return { data: { ...row, id: 501 }, error: null }
})
const inserted = await persistFoodVisitItem({ client: insertClient, row, online: true })
assert.equal(calls[0].operation, 'select')
assert.deepEqual(calls[0].filters, [['visit_id', 44], ['planogram_slot_id', 9]])
assert.equal(calls[1].operation, 'insert')
assert.equal(inserted.savedRow.id, 501)

let updateQuery
const updateClient = createClient((query) => {
  updateQuery = query
  return { data: { ...row, id: 502 }, error: null }
})
const updated = await persistFoodVisitItem({
  client: updateClient,
  row,
  existing: { id: '502', final_quantity: 8 },
  online: true
})
assert.equal(updateQuery.operation, 'update')
assert.deepEqual(updateQuery.filters, [['id', 502]])
assert.equal(updated.savedRow.id, 502)

const databaseError = new Error('lookup failed')
await assert.rejects(
  persistFoodVisitItem({
    client: createClient(() => ({ data: null, error: databaseError })),
    row,
    online: true
  }),
  databaseError
)

console.log('PASS: food visit serialization, autosave and duplicate-safe item persistence are isolated')
