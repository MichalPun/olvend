import assert from 'node:assert/strict'
import {
  completeRouteVisitRecord,
  getMissingCoffeeContainerStates,
  hasAcceptedCoffeeContainerState,
  persistUnchangedCoffeeContainerStates
} from '../mobile-route-completion.js'

const containers = [
  { id: 1, container_code: 'Z1', current_quantity: 800 },
  { id: 2, container_code: 'Z2', current_quantity: 1200 },
  { id: 3, container_code: 'Z3', current_quantity: 500 }
]
const detail = {
  visitId: 1408,
  containers,
  visitItems: [{
    item_kind: 'coffee_container',
    coffee_container_id: 2,
    accepted_at: '2026-10-21T12:00:00Z',
    final_quantity: 1200,
    actual_add_quantity: 0,
    issue_type: 'none'
  }]
}

assert.equal(hasAcceptedCoffeeContainerState(detail, containers[1]), true)
assert.deepEqual(getMissingCoffeeContainerStates(detail).map((item) => item.id), [1, 3])
assert.equal(hasAcceptedCoffeeContainerState({ visitItems: [{
  item_kind: 'coffee_container',
  coffee_container_id: 3,
  accepted_at: '2026-10-21T12:00:00Z',
  final_quantity: null,
  actual_add_quantity: 0,
  issue_type: 'missing_stock',
  operator_note: 'Ve vozidle nebyla potřebná surovina.'
}] }, containers[2]), true, 'Popsaná provozní výjimka musí zůstat platným potvrzením')

await assert.rejects(() => persistUnchangedCoffeeContainerStates({
  detail: { ...detail, needsCalibration: true },
  saveContainerState: async () => {}
}), /První načtení automatu není dokončené/, 'První návštěva nesmí hromadně převzít neznámé systémové nuly')

const saves = []
await persistUnchangedCoffeeContainerStates({
  detail,
  saveContainerState: async (container, payload) => {
    saves.push({ container, payload })
    detail.visitItems.push({
      item_kind: 'coffee_container',
      coffee_container_id: container.id,
      accepted_at: '2026-10-21T12:05:00Z',
      final_quantity: payload.final_quantity,
      actual_add_quantity: 0,
      issue_type: payload.issue_type
    })
  }
})
assert.deepEqual(saves.map((item) => [item.container.id, item.payload.final_quantity]), [[1, 800], [3, 500]])
assert.equal(getMissingCoffeeContainerStates(detail).length, 0)

let pending = 0
const successfulClient = {
  from(table) {
    assert.equal(table, 'route_machine_visits')
    return {
      update(payload) {
        assert.equal(payload.status, 'completed')
        return {
          eq(column, value) {
            assert.equal(column, 'id')
            assert.equal(value, 1408)
            return {
              select() {
                return {
                  async maybeSingle() {
                    return { data: { id: 1408, status: 'completed', completed_at: payload.completed_at }, error: null }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
const completed = await completeRouteVisitRecord({
  client: successfulClient,
  visitId: 1408,
  completedAt: '2026-10-21T12:10:00Z',
  getPendingRequestCount: () => pending
})
assert.equal(completed.completionQueued, false)
assert.equal(completed.visit.status, 'completed')

const offlineClient = {
  from() {
    return {
      update() {
        return {
          eq() {
            return {
              select() {
                return {
                  async maybeSingle() {
                    pending += 1
                    return { data: null, error: new Error('offline') }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
const queued = await completeRouteVisitRecord({
  client: offlineClient,
  visitId: 1408,
  completedAt: '2026-10-21T12:10:00Z',
  getPendingRequestCount: () => pending
})
assert.equal(queued.completionQueued, true, 'Offline dokončení musí zůstat ve frontě místo falešné chyby')

const rejectedClient = {
  from() {
    return {
      update() {
        return {
          eq() {
            return {
              select() {
                return { async maybeSingle() { return { data: null, error: null } } }
              }
            }
          }
        }
      }
    }
  }
}
await assert.rejects(() => completeRouteVisitRecord({
  client: rejectedClient,
  visitId: 1408,
  completedAt: '2026-10-21T12:10:00Z',
  getPendingRequestCount: () => pending
}), /Server nepotvrdil dokončení návštěvy/)

console.log('PASS: route completion module persists missing stock states and requires durable visit completion')
