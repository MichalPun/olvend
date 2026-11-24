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
assert.match(html, /create_operational_request_v18/, 'vehicle requests must use the production operational request flow')
assert.match(html, /function saveMobileVehicleFuel\(/, 'vehicle overview tanking form must save data')
assert.match(html, /function saveMobileVehicleKilometres\(/, 'vehicle overview mileage form must save data')
assert.match(html, /function loadVehicleOverviewData\(/, 'vehicle overview must load live production data')
assert.match(moduleScript, /const currentOdometer = Number\(state\.vehicleLog\?\.end_odometer_km \?\? state\.vehicleLog\?\.start_odometer_km \?\? vehicle\.current_odometer_km \?\? 0\)/, 'displayed mileage must prefer operator-entered values')
assert.doesNotMatch(moduleScript, /const currentOdometer = Number\(live\?\.odometer_km/, 'telematics must not override operator-entered mileage')

const vehicleSection = html.match(/<section class="screen" data-screen="vehicle-overview">([\s\S]*?)<section class="screen" data-screen="vehicle">/)?.[1] || ''
assert.doesNotMatch(vehicleSection, /Kontrola před výjezdem/i, 'cancelled pre-departure check must not return')

assert.match(moduleScript, /function renderMobileHeader\(\) \{\s*els\.mobileHeaderEyebrow\.textContent = 'Dnešní směna'\s*els\.screenTitle\.innerHTML = '<b>OLVEND<\/b> Operátor'/, 'all tabs must keep the same approved header')
assert.match(html, /pwa\.js\?v=20261124-mobile-vehicle-v2/, 'mobile HTML must request the new PWA bootstrap')
assert.match(pwa, /20261124-mobile-vehicle-v2/, 'PWA bootstrap must refresh the service worker')
assert.match(serviceWorker, /olvend-v267-mobile-vehicle-operator-km/, 'service worker cache must be bumped for production phones')

console.log('PASS: production mobile vehicle overview, navigation, header and actions')
