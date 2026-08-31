import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')

for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: 'mobile.html' })
  else new vm.Script(match[1], { filename: 'mobile.html' })
}

function extractFunction(name) {
  const marker = `function ${name}`
  const start = html.indexOf(marker)
  assert.notEqual(start, -1, `Funkce ${name} nebyla nalezena`)
  const bodyStart = html.indexOf('{', start)
  let depth = 0
  let quote = ''
  let lineComment = false
  let blockComment = false
  let escaped = false
  for (let index = bodyStart; index < html.length; index += 1) {
    const char = html[index]
    const next = html[index + 1]
    if (lineComment) {
      if (char === '\n') lineComment = false
      continue
    }
    if (blockComment) {
      if (char === '*' && next === '/') { blockComment = false; index += 1 }
      continue
    }
    if (quote) {
      if (escaped) { escaped = false; continue }
      if (char === '\\') { escaped = true; continue }
      if (char === quote) quote = ''
      continue
    }
    if (char === '/' && next === '/') { lineComment = true; index += 1; continue }
    if (char === '/' && next === '*') { blockComment = true; index += 1; continue }
    if (char === '"' || char === "'" || char === '`') { quote = char; continue }
    if (char === '{') depth += 1
    if (char === '}') {
      depth -= 1
      if (depth === 0) return html.slice(start, index + 1)
    }
  }
  throw new Error(`Funkce ${name} není ukončená`)
}

function context(extra = {}) {
  return vm.createContext({ console, Map, Math, Number, String, Date, ...extra })
}

{
  const sandbox = context({
    getFoodPlanogramChange: () => null,
    isFoodExpiryExpired: () => false,
    getFoodDailySales: (_detail, slot) => Number(slot.dailySales || 0),
    getFoodDemandTargetQuantity: (_slot, _detail, _sku) => Number(_slot.target_units || _slot.capacity_units || 0),
    getFoodTransferReservedByBatch: () => new Map()
  })
  vm.runInContext(extractFunction('getFoodRouteAllocatedQuantity'), sandbox)

  const last = { id: 1, machine_id: 100, product_sku: '28', current_units: 5, capacity_units: 15, target_units: 15, dailySales: 1 }
  const lastDetail = {
    routePlanningContext: { loaded: true, routeSlots: [last], stopOrderByMachine: new Map([['100', 0]]) },
    vehicleBatches: {}, vehicleStock: { '28': 10 }
  }
  assert.equal(sandbox.getFoodRouteAllocatedQuantity(lastDetail, 1, last, { id: 28, sku: '28' }, 10), 10,
    'Poslední automat musí dostat všech 10 volných kusů až do kapacity')

  const strong = { id: 1, machine_id: 100, product_sku: '28', current_units: 5, capacity_units: 15, target_units: 15, dailySales: 2 }
  const weak = { id: 2, machine_id: 200, product_sku: '28', current_units: 0, capacity_units: 15, target_units: 2, dailySales: 0.1 }
  const routeDetail = {
    routePlanningContext: { loaded: true, routeSlots: [strong, weak], stopOrderByMachine: new Map([['100', 0], ['200', 1]]) },
    vehicleBatches: {}, vehicleStock: { '28': 10 }
  }
  const strongAllocation = sandbox.getFoodRouteAllocatedQuantity(routeDetail, 1, strong, { id: 28, sku: '28' }, 10)
  const weakAllocation = sandbox.getFoodRouteAllocatedQuantity(routeDetail, 2, weak, { id: 28, sku: '28' }, 15)
  assert.ok(strongAllocation > weakAllocation, 'Silný automat musí dostat více než následující slabý')
  assert.equal(strongAllocation + weakAllocation, 10, 'Rozdělení nesmí ztratit kusy v autě')
}

{
  const sandbox = context({
    getFoodPlanogramChange: () => null,
    isFoodExpiryExpired: () => false,
    getFoodDemandTargetQuantity: () => 6
  })
  vm.runInContext(extractFunction('getFoodRequiredFillQuantity'), sandbox)
  const slot = { current_units: 5, capacity_units: 15, target_units: 15, desired_units: 1 }
  assert.equal(sandbox.getFoodRequiredFillQuantity(slot, { routePlanningContext: { loaded: true } }), 10,
    'Lokální strop na trase musí být fyzicky volná kapacita, ne nízký odhad prodejnosti')
}

{
  const sandbox = context({
    getAssignedRoutePlan: () => ({ planning_date: '2026-08-31' }),
    state: { products: [{ id: 2, sku: 'NEW', name: 'Nový produkt' }] }
  })
  vm.runInContext(extractFunction('getFoodPlanogramChange'), sandbox)
  const change = sandbox.getFoodPlanogramChange({
    product_sku: 'MARGOT', product_name: 'Margot', planned_product_sku: 'NEW',
    planned_product_name: 'Nový produkt', pending_change_mode: 'full_swap', changeover_new_units: 2
  })
  assert.equal(change?.nextSku, 'NEW', 'Rozběhnutá směs nesmí schovat cílový produkt')
  assert.equal(change?.fullSwap, true, 'Povinná kompletní změna musí zůstat viditelná')
}

{
  const drafts = new Map([[1, { pickedQuantity: 1, cartLoadOrder: 1 }], [2, { pickedQuantity: 1, cartLoadOrder: 3 }], [3, { pickedQuantity: 1, cartLoadOrder: 2 }]])
  const sandbox = context({
    getFoodSlotDraft: (_stopId, slot) => ({ accepted: false, assortmentMismatch: false, wasteItems: [], ...drafts.get(slot.id) }),
    normalizeFoodExpiryDate: () => '',
    getFoodPlanogramChange: () => null,
    compareFoodCartLoadOrder: (a, b) => a.sort_order - b.sort_order
  })
  vm.runInContext(extractFunction('getFoodGuidedWorkSlots'), sandbox)
  const slots = [{ id: 1, sort_order: 1 }, { id: 2, sort_order: 2 }, { id: 3, sort_order: 3 }]
  assert.deepEqual(Array.from(sandbox.getFoodGuidedWorkSlots('stop', { slots }), slot => slot.id), [2, 3, 1],
    'Doplňování musí být přesným opakem potvrzeného naskládání vozíku')
}

console.log('OK: mobilní regrese trasy — alokace, poslední automat, změna produktu a pořadí vozíku')
