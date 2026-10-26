import assert from 'node:assert/strict'
import { createCoffeeDomain } from '../mobile-coffee-domain.js'

const normalizeText = (value) => String(value ?? '')
  .trim()
  .toLowerCase()
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '')

const convertQuantity = (quantity, fromUnit, toUnit) => {
  const from = normalizeText(fromUnit)
  const to = normalizeText(toUnit)
  if (!from || !to || from === to) return Number(quantity || 0)
  if (from === 'kg' && to === 'g') return Number(quantity || 0) * 1000
  if (from === 'g' && to === 'kg') return Number(quantity || 0) / 1000
  if (from === 'l' && to === 'ml') return Number(quantity || 0) * 1000
  if (from === 'ml' && to === 'l') return Number(quantity || 0) / 1000
  return Number(quantity || 0)
}

const products = [
  { id: 'cups', base_unit: 'ks' },
  { id: 'lids', base_unit: 'ks' },
  { id: 'coffee', base_unit: 'g' }
]
const productPackages = [
  { product_id: 'cups', package_name: 'Tyč 50 ks', units_per_package: 50, is_default: true, active: true },
  { product_id: 'lids', package_name: 'Tyč 100 ks', units_per_package: 100, is_default: true, active: true },
  { product_id: 'coffee', package_name: '1 kg balení', units_per_package: 1000, is_default: true, active: true }
]
const cup = { id: 'c1', product_id: 'cups', product_name: 'Kelímek 180 ml', unit: 'ks', capacity_quantity: 300, current_quantity: 120, container_code: 'Z6', sort_order: 6 }
const lid = { id: 'c2', product_id: 'lids', product_name: 'Víčka', unit: 'ks', capacity_quantity: 300, current_quantity: 250, container_code: 'Z7', sort_order: 7 }
const coffee = { id: 'c3', product_id: 'coffee', product_name: 'Káva zrno', unit: 'g', capacity_quantity: 3000, current_quantity: 900, refill_package_quantity: 1000, refill_package_unit: 'g', container_code: 'Z1', sort_order: 1 }

const details = {
  stop: {
    containers: [cup, lid, coffee],
    visitItems: [],
    manualCounterMode: false,
    vehiclePackages: { cups: 2, lids: 0, coffee: 4 },
    calibratedContainers: {},
    needsCalibration: false,
    machineOpen: false,
    cash: null,
    checkRows: [],
    draft: { containers: {}, calibration: {}, refillReviewed: false }
  }
}

const domain = createCoffeeDomain({
  getDetail: (stopId) => details[stopId],
  getProducts: () => products,
  getProductPackages: () => productPackages,
  normalizeText,
  convertQuantity,
  formatNumber: (value) => String(value)
})

assert.equal(domain.isCoffeeCupProduct(cup), true)
assert.equal(domain.isCoffeeLidProduct(lid), true)
assert.deepEqual(domain.getCoffeeRefillPackage(cup), { quantity: 50, unit: 'ks', label: 'tyč' })
assert.deepEqual(domain.getCoffeeRefillPackage(lid), { quantity: 100, unit: 'ks', label: 'tyč' })
assert.equal(domain.getCoffeePackageCountLabel(1, cup), '1 tyč')
assert.equal(domain.getCoffeePackageCountLabel(3, cup), '3 tyče')
assert.equal(domain.getCoffeePackageCountLabel(5, cup), '5 tyčí')
assert.equal(domain.getCoffeeSuggestedPackages(cup), 3)
assert.equal(domain.getCoffeeSuggestedPackages(coffee), 2)
assert.deepEqual(domain.getCoffeeContainersInBagOrder(details.stop).map((item) => item.id), ['c3', 'c1', 'c2'])

details.stop.draft.containers.c3 = { actualBeforeQuantity: 1200, packages: 3, movedPackages: 1 }
assert.equal(domain.getCoffeeActualBeforeQuantity('stop', coffee), 1200)
assert.equal(domain.getCoffeeMaxPackages('stop', coffee), 1)
assert.equal(domain.getCoffeeVehicleAvailablePackages('stop', coffee), 5)
assert.equal(domain.getCoffeeSelectableMaxPackages('stop', coffee), 1)
assert.equal(domain.getCoffeeActualPackages('stop', coffee), 1)
assert.equal(domain.getCoffeeAddedQuantity('stop', coffee), 1000)
assert.equal(domain.getCoffeeAfterQuantity('stop', coffee), 2200)

assert.equal(domain.getCoffeeEntryUnit(coffee), 'kg')
assert.equal(domain.getCoffeeEntryQuantity(1500, coffee), 1.5)
assert.equal(domain.getCoffeeContainerQuantity(1.5, coffee), 1500)
assert.equal(domain.getCoffeeFillPercent(1500, coffee), 50)
assert.equal(domain.getCoffeeQuantityFromFillPercent(33, coffee), 990)
assert.equal(domain.getCoffeePackageBaseQuantity(coffee), 1000)
assert.equal(domain.getCoffeeVehiclePackageCount(coffee, 4500), 4)
assert.equal(domain.getCoffeeVehicleStockQuantity(coffee, 2), 2000)

assert.equal(domain.getCoffeeNetMovedQuantity([
  { product_id: 'coffee', movement_type: 'issue', quantity_base_units: 2000, reference_id: 'route_visit_v1_container_c3' },
  { product_id: 'coffee', movement_type: 'return', quantity_base_units: 1000, reference_id: 'route_visit_v1_container_c3_return' },
  { product_id: 'coffee', movement_type: 'issue', quantity_base_units: 500, reference_id: 'other' }
], 'v1', coffee), 1000)

details.stop.needsCalibration = true
assert.equal(domain.isCoffeeCalibrationComplete('stop'), false)
details.stop.machineOpen = true
assert.equal(domain.getCoffeeGuidedStage('stop', details.stop), 'calibration', 'Nový automat musí před doplněním projít fyzickým načtením všech zásobníků')
details.stop.machineOpen = false
details.stop.draft.calibration = { c1: { quantity: 125, done: true }, c2: { quantity: 200, done: true }, c3: { quantity: 1500, done: true } }
assert.equal(domain.getCoffeeCalibrationQuantity('stop', coffee), 1500)
assert.equal(domain.isCoffeeCalibrationComplete('stop'), true)
assert.equal(domain.roundCoffeeCalibrationQuantity(1234, coffee), 1230)

assert.equal(domain.getCoffeeGuidedStage('stop', details.stop), 'goods')
details.stop.machineOpen = true
details.stop.draft.containers.c3 = { accepted: false, packages: 1 }
assert.equal(domain.getCoffeeGuidedStage('stop', details.stop), 'refill')
details.stop.draft.containers.c3.accepted = true
details.stop.draft.containers.c1 = { accepted: true, packages: 0 }
details.stop.draft.containers.c2 = { accepted: true, packages: 0 }
details.stop.draft.refillReviewed = true
assert.equal(domain.getCoffeeGuidedStage('stop', details.stop), 'cash')
details.stop.cash = { collection_required: false, retained_for_next_visit: true }
details.stop.checkRows = [{ status: 'pending', assigned_payload: { section: 'inside', order: 2 } }]
assert.equal(domain.getCoffeeGuidedStage('stop', details.stop), 'check')
details.stop.checkRows[0].status = 'done'
assert.equal(domain.getCoffeeGuidedStage('stop', details.stop), 'finish')
assert.equal(domain.getCoffeeGuidedStage('stop', details.stop, true), 'done')

details.stop.draft.containers.c1 = { picked: true, movedPackages: 2, packages: 2 }
assert.equal(domain.getCoffeePickDecision('stop', cup), 'taken')
details.stop.draft.containers.c1 = { picked: true, movedPackages: 0, packages: 0 }
assert.equal(domain.getCoffeePickDecision('stop', cup), 'skipped')
assert.deepEqual(domain.getCoffeePickVisual(coffee), { type: 'coffee', icon: '●', label: 'Káva' })

console.log('PASS: coffee domain keeps package, capacity, calibration and workflow rules outside the UI')
