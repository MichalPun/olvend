import assert from 'node:assert/strict'
import vm from 'node:vm'
import { readFile } from 'node:fs/promises'
import { webcrypto } from 'node:crypto'

const source = await readFile(new URL('../mobile.html', import.meta.url), 'utf8')
const moduleMatch = source.match(/<script type="module">\s*([\s\S]*?)<\/script>/)
assert.ok(moduleMatch, 'Mobilní modul nebyl nalezen.')

const confirmBlock = source.slice(source.indexOf("if (action === 'confirm-slot' && slot)"), source.indexOf('async function saveFoodCheck'))
assert.match(confirmBlock, /const submitPriceAfterConfirmation = operatorPriceChangeReady/)
assert.ok(confirmBlock.indexOf('await confirmFoodSlot(stopId, slot)') < confirmBlock.indexOf('submitOperatorPriceChange(stopId, slot, null).catch'), 'Cena se musí odesílat až po bezpečném uložení pozice.')
assert.doesNotMatch(confirmBlock, /await submitOperatorPriceChange\(stopId, slot, null\)/, 'Odesílání ceny nesmí blokovat další práci operátora.')

let moduleCode = moduleMatch[1]
  .replace(/import \{ supabase, syncOfflineRequests, getOfflineRequestCount \} from ['"][^'"]+['"]/, `
    const supabase = window.__supabaseMock
    const syncOfflineRequests = async () => ({ pending: 0, synced: 0 })
    const getOfflineRequestCount = () => 0
  `)
  .replace('function renderRouteMachineScreen() {', 'function renderRouteMachineScreenOriginal() {')
  .replace('function scheduleFoodWorkProgressSave(stopId) {', 'function scheduleFoodWorkProgressSaveOriginal(stopId) {')
  .replace(/\n\s*init\(\)\s*$/, `
    window.__priceTest = {
      state,
      operatorPriceChangeReady,
      updateOperatorPriceDraftFromField,
      updateFoodSlotDraft,
      getFoodSlotDraft,
      submitOperatorPriceChange
    }
  `)

moduleCode = `
  const renderRouteMachineScreen = () => { window.__renderCount = (window.__renderCount || 0) + 1 }
  const scheduleFoodWorkProgressSave = () => { window.__saveScheduled = (window.__saveScheduled || 0) + 1 }
  ${moduleCode}
`

const messageArea = { innerHTML: '', scrollIntoView() {} }
const storage = new Map()
const context = vm.createContext({
  console,
  URL,
  URLSearchParams,
  Headers,
  Response,
  Request,
  CustomEvent: class CustomEvent {},
  Date,
  Intl,
  Math,
  Number,
  String,
  Boolean,
  Object,
  Array,
  Map,
  Set,
  JSON,
  Promise,
  RegExp,
  Error,
  crypto: webcrypto,
  navigator: { onLine: true },
  location: { search: '', origin: 'http://localhost', pathname: '/mobile.html', href: 'http://localhost/mobile.html' },
  localStorage: {
    getItem: (key) => storage.get(key) ?? null,
    setItem: (key, value) => storage.set(key, String(value)),
    removeItem: (key) => storage.delete(key)
  },
  document: {
    body: { classList: { add() {} } },
    getElementById: (id) => id === 'messageArea' ? messageArea : null,
    querySelectorAll: () => [],
    addEventListener() {},
    visibilityState: 'visible'
  },
  window: {
    parent: null,
    addEventListener() {},
    dispatchEvent() {},
    setTimeout,
    clearTimeout,
    setInterval,
    requestAnimationFrame: (callback) => callback(),
    scrollTo() {}
  },
  setTimeout,
  clearTimeout,
  setInterval
})
context.window.parent = context.window
context.window.__invokeMode = 'success'
context.window.__supabaseMock = {
  functions: {
    invoke: async (_name, options) => {
      context.window.__lastPricePayload = options.body
      if (context.window.__invokeMode === 'failure') {
        return {
          data: null,
          error: {
            message: 'Edge function failed',
            context: { json: async () => ({ error: 'Testovací odmítnutí serveru' }) }
          }
        }
      }
      return { data: { ok: true, request_id: 'request-1', approver_name: 'Michal' }, error: null }
    }
  }
}

const module = new vm.SourceTextModule(moduleCode, { context, identifier: 'mobile-price-test' })
await module.link(() => { throw new Error('Testovací modul nesmí načítat externí importy.') })
await module.evaluate()

const test = context.window.__priceTest
assert.ok(test, 'Testovací rozhraní mobilní aplikace nebylo vytvořeno.')
const slot = {
  id: 1363,
  machine_id: 19,
  slot_code: '27',
  product_sku: 'VA-ARASIDY-PRAZ-SOL-100',
  product_name: 'VA Arašídy pražené solené 100g',
  price_czk: 20,
  customer_price_czk: 20,
  dex_price_czk: 20,
  current_units: 2,
  capacity_units: 10,
  target_units: 10,
  active: true
}
test.state.products = [{ id: 501, sku: slot.product_sku, name: slot.product_name, active: true }]
test.state.routeFoodDetails = {
  stop1: {
    visitId: 1299,
    slots: [slot],
    vehicleBatches: {},
    draft: {
      phase: 'work',
      slots: {
        '1363': {
          selectedProductId: 501,
          fillItems: [],
          pickedQuantity: 0,
          actualBefore: 2,
          operatorProposedPrice: '',
          operatorPriceConfirmed: false,
          operatorPriceRequestStatus: ''
        }
      }
    }
  }
}

const defaultPriceInput = { value: '21' }
const confirmationField = {
  checked: true,
  dataset: { foodField: 'operator-price-confirmed', stopId: 'stop1', slotId: '1363' },
  closest: () => ({ querySelector: () => defaultPriceInput })
}
test.updateOperatorPriceDraftFromField(confirmationField)
let draft = test.getFoodSlotDraft('stop1', slot)
assert.equal(draft.operatorProposedPrice, 21, 'Potvrzení musí uložit i zobrazenou výchozí cenu, i když operátor číslo ručně nepřepsal.')
assert.equal(draft.operatorPriceConfirmed, true)

test.updateFoodSlotDraft('stop1', 1363, {
  operatorProposedPrice: 25,
  operatorPriceConfirmed: true,
  operatorPriceRequestStatus: '',
  operatorPriceClientKey: ''
})
draft = test.getFoodSlotDraft('stop1', slot)
assert.equal(test.operatorPriceChangeReady(slot, draft), true)
await test.submitOperatorPriceChange('stop1', slot, null)
draft = test.getFoodSlotDraft('stop1', slot)
assert.equal(draft.operatorPriceRequestStatus, 'pending')
assert.equal(context.window.__lastPricePayload.visit_id, 1299)
assert.equal(context.window.__lastPricePayload.planogram_slot_id, 1363)
assert.equal(context.window.__lastPricePayload.proposed_price_czk, 25)

context.window.__invokeMode = 'failure'
slot._priceRequest = null
test.updateFoodSlotDraft('stop1', 1363, {
  operatorProposedPrice: 26,
  operatorPriceConfirmed: true,
  operatorPriceRequestStatus: '',
  operatorPriceClientKey: ''
})
await assert.rejects(
  () => test.submitOperatorPriceChange('stop1', slot, null),
  /Testovací odmítnutí serveru/
)
draft = test.getFoodSlotDraft('stop1', slot)
assert.equal(draft.operatorPriceRequestStatus, '', 'Po chybě nesmí formulář zůstat navždy ve stavu „odesílám“.')
assert.ok(draft.operatorPriceClientKey, 'Opakování musí zachovat idempotentní identifikátor žádosti.')
assert.equal(draft.operatorPriceMailWarning, 'Testovací odmítnutí serveru')

console.log('OK: změna ceny se zachytí, odešle na pozadí a po chybě zůstane opakovatelná')
