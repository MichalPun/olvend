import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const pwa = fs.readFileSync(new URL('../pwa.js', import.meta.url), 'utf8')
const serviceWorker = fs.readFileSync(new URL('../sw.js', import.meta.url), 'utf8')
const moduleScript = html.match(/<script type="module">([\s\S]*?)<\/script>/)?.[1]

assert.ok(moduleScript, 'mobile.html must contain its inline module script')
new vm.SourceTextModule(moduleScript, { identifier: 'mobile.html' })

assert.match(html, /data-screen="vehicle-overview"/, 'vehicle overview screen must exist')
assert.match(html, /data-open-screen="vehicle-overview"[^>]*>[\s\S]*?<span>Vozidlo<\/span>/, 'bottom navigation must open vehicle overview')
assert.match(html, /data-open-screen="vehicle"[^>]*>[\s\S]*?<span>Trasa<\/span>/, 'route must stay a separate bottom navigation item')
assert.match(html, /id="mobileVehicleFuel"/, 'vehicle overview must show live fuel')
assert.match(html, /id="mobileVehicleTelemetry"/, 'vehicle overview must show telemetry')
assert.match(html, /id="mobileVehiclePhoto"/, 'vehicle overview must show the vehicle image')
assert.match(html, /id="mobileVehicleStockDetail"/, 'vehicle overview must expose the actual product stock list')
assert.match(html, /id="mobileVehicleStockList"/, 'vehicle stock detail must have a rendered item list')
assert.match(html, /id="mobileVehicleMileageSummary"/, 'vehicle ride tab must compare planned, actual and allowed extra mileage')
assert.match(html, /create_operational_request_v18/, 'vehicle requests must use the production operational request flow')
assert.match(html, /get_my_vehicle_mileage_summary_v61/, 'vehicle overview must load the production mileage allowance summary')
assert.match(html, /function saveMobileVehicleFuel\(/, 'vehicle overview tanking form must save data')
assert.match(html, /function saveMobileVehicleKilometres\(/, 'vehicle overview mileage form must save data')
assert.match(html, /function loadVehicleOverviewData\(/, 'vehicle overview must load live production data')
assert.match(moduleScript, /const currentOdometer = Number\(state\.vehicleLog\?\.end_odometer_km \?\? state\.vehicleLog\?\.start_odometer_km \?\? vehicle\.current_odometer_km \?\? 0\)/, 'displayed mileage must prefer operator-entered values')
assert.doesNotMatch(moduleScript, /const currentOdometer = Number\(live\?\.odometer_km/, 'telematics must not override operator-entered mileage')

const aggregateStart = html.indexOf('    function getVehicleStockProduct(')
const aggregateEnd = html.indexOf('    function renderVehicleStockDetail()', aggregateStart)
assert.ok(aggregateStart >= 0 && aggregateEnd > aggregateStart, 'vehicle stock aggregation helpers must exist')
const aggregateContext = vm.createContext({
  state: {
    products: [{ id: 7, sku: 'PEPSI', name: 'Pepsi', base_unit: 'ks', product_category: 'beverage_ready', usage_type: 'ready_goods' }],
    vehicleStockBalances: [
      { products: { id: 7 }, quantity_on_hand: 3, reserved_quantity: 1 },
      { products: { id: 7 }, quantity_on_hand: 2, reserved_quantity: 0 },
      { products: { id: 7 }, quantity_on_hand: -1, reserved_quantity: 0 }
    ]
  },
  normalizeText: (value) => String(value || '').toLowerCase()
})
vm.runInContext(html.slice(aggregateStart, aggregateEnd), aggregateContext)
const aggregated = aggregateContext.getAggregatedVehicleStockBalances()
assert.equal(aggregated.length, 1, 'one product split across batches must render once')
assert.equal(aggregated[0].quantity_on_hand, 4, 'all batch balances must be netted into one product total')
assert.equal(aggregated[0].balance_record_count, 3, 'aggregation must retain the number of source balance rows')
assert.equal(aggregateContext.getVehicleStockGroup(aggregated[0]).key, 'drinks', 'aggregated product must stay in its readable stock group')
assert.match(moduleScript, /\.neq\('quantity_on_hand', 0\)/, 'vehicle stock loader must include negative batch rows before net aggregation')

const vehicleSection = html.match(/<section class="screen" data-screen="vehicle-overview">([\s\S]*?)<section class="screen" data-screen="vehicle">/)?.[1] || ''
assert.doesNotMatch(vehicleSection, /Kontrola před výjezdem/i, 'cancelled pre-departure check must not return')

assert.match(moduleScript, /function renderMobileHeader\(\) \{\s*els\.mobileHeaderEyebrow\.textContent = 'Dnešní směna'\s*els\.screenTitle\.innerHTML = '<b>OLVEND<\/b> Operátor'/, 'all tabs must keep the same approved header')
assert.match(html, /pwa\.js\?v=20261126-vehicle-stock-groups-v1/, 'mobile HTML must request the new PWA bootstrap')
assert.match(pwa, /20261126-vehicle-stock-groups-v1/, 'PWA bootstrap must refresh the service worker')
assert.match(serviceWorker, /olvend-v271-vehicle-stock-groups/, 'service worker cache must be bumped for production phones')

console.log('PASS: production mobile vehicle overview, navigation, header and actions')
