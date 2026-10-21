import assert from 'node:assert/strict'
import { createFoodDomain } from '../mobile-food-domain.js'

let fullSwap = false
const domain = createFoodDomain({
  getPlanogramChange: () => fullSwap ? { fullSwap: true } : null,
  isExpiryExpired: (value) => value === 'expired',
  getTransferReservedByBatch: () => new Map([['b1', 2]])
})

const slot = {
  id: 1,
  machine_id: 10,
  product_sku: 'BAG',
  current_units: 4,
  capacity_units: 15,
  target_units: 15,
  desired_units: 2,
  replenishment_mode: 'sales_based'
}
const detail = {
  draft: { slots: {} },
  routePlanningContext: {
    loaded: true,
    sold28ByMachineSku: new Map([['10:BAG', 56]]),
    routeSlots: [slot],
    stopOrderByMachine: new Map([['10', 0]])
  },
  vehicleBatches: { 'p1': [{ batch_id: 'b1', quantity_on_hand: 12 }] },
  vehicleStock: { 'p1': 12 }
}

assert.equal(domain.getFoodDailySales(detail, slot), 2)
assert.equal(domain.getFoodDemandTargetQuantity(slot, detail), 15)
assert.equal(domain.getFoodRequiredFillQuantity(slot, detail), 11)
assert.equal(domain.getFoodRouteAllocatedQuantity(detail, 's1', slot, { id: 'p1', sku: 'BAG' }, 11), 10,
  'Dvě rezervované položky z dávky nesmí být znovu přiděleny')

detail.draft.slots['1'] = { actualBefore: 9, capacityUnits: 20, existingExpiryDate: 'expired', accepted: false }
const planningSlot = domain.getFoodPlanningSlot(slot, detail)
assert.equal(planningSlot.current_units, 9)
assert.equal(planningSlot.capacity_units, 20)
assert.equal(domain.getFoodRequiredFillQuantity(slot, detail), 20,
  'Prošlá fyzická zásoba se nesmí počítat jako prodejný stav')

detail.draft.slots['1'].accepted = true
assert.equal(domain.getFoodPlanningSlot(slot, detail), slot)

const slowSlot = { ...slot, current_units: 0, target_units: 15 }
const slowDetail = {
  routePlanningContext: {
    loaded: true,
    sold28ByMachineSku: new Map([['10:BAG', 2.8]]),
    routeSlots: [slowSlot],
    stopOrderByMachine: new Map([['10', 0]])
  }
}
assert.equal(domain.getFoodDemandTargetQuantity(slowSlot, slowDetail), 2)

fullSwap = true
const swapSlot = { ...slot, target_units: 15, changeover_new_units: 3 }
assert.equal(domain.getFoodRequiredFillQuantity(swapSlot, detail), 12)
assert.equal(domain.getFoodRouteAllocatedQuantity(detail, 's1', swapSlot, { id: 'p1', sku: 'BAG' }, 12), 12,
  'Kompletní výměna se řídí připraveným cílem a nesmí ji krátit běžná alokace')

console.log('PASS: food demand, route allocation and physical planning state are isolated')
