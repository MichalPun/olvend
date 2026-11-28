import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const pwa = fs.readFileSync(new URL('../pwa.js', import.meta.url), 'utf8')
const serviceWorker = fs.readFileSync(new URL('../sw.js', import.meta.url), 'utf8')
const edge = fs.readFileSync(new URL('../backend/supabase/functions/google-route-plan/index.ts', import.meta.url), 'utf8')
const moduleScript = [...html.matchAll(/<script type="module">([\s\S]*?)<\/script>/g)].at(-1)?.[1]

assert.ok(moduleScript, 'mobile.html must contain its module script')
new vm.SourceTextModule(moduleScript, { identifier: 'mobile.html' })

assert.match(html, /function renderRoutePendingHero\(/, 'route must have a dedicated pre-acceptance state')
assert.match(html, /Trasa je připravená/, 'pre-acceptance state must explain that the route is ready')
assert.match(html, /Převzít trasu a začít/, 'route acceptance must remain an explicit operator action')
assert.match(html, /Prohlédnout pořadí zastávek/, 'route order must be reviewable before acceptance')
assert.match(html, /function renderRouteActiveHero\(/, 'active route must have a dedicated next-stop state')
assert.match(html, />Navigovat</, 'next stop must offer direct navigation')
assert.match(html, /Jsem na místě/, 'next stop must retain the arrival workflow')
assert.match(html, /travelmode=driving&dir_action=navigate/, 'Google Maps URL must start driving navigation')
assert.match(html, /function getMobileMachineImageUrl\(/, 'machine photos must use the approved model assets')
assert.match(html, /assets\/machine-overview\/models\/jetinno-jl300\.jpg/, 'Jetinno machine photo must be available in the route')
assert.match(html, /mode:'preview'/, 'route hero must load live map and traffic data')
assert.match(html, /api\.open-meteo\.com/, 'next-stop weather must use live Open-Meteo data')
assert.match(html, /brand, model, sales_tracking_mode/, 'machine brand and model must be loaded for reliable photos')

assert.match(edge, /mode\?: "optimize" \| "ordered" \| "distance" \| "matrix" \| "preview"/, 'route edge function must support preview mode')
assert.match(edge, /requireAuthenticated\(req\)/, 'route preview must be protected by an authenticated session')
assert.match(edge, /maps\.googleapis\.com\/maps\/api\/staticmap/, 'map preview must come from Google Static Maps')
assert.match(edge, /TRAFFIC_AWARE_OPTIMAL/, 'preview travel time must include current traffic')
assert.match(edge, /mapDataUrl/, 'edge function must return the protected map image')

assert.match(html, /route-stop-machine/, 'every stop card must contain a machine photo row')
assert.match(html, /route-stop-time-compact/, 'stop timing must remain compact on a phone')
assert.match(html, /route-machine-photo-shell/, 'machine images and fallbacks must occupy one grid cell')
assert.match(html, /pwa\.js\?v=20261128-route-home-v5/, 'mobile must request the refreshed PWA bootstrap')
assert.match(pwa, /20261128-route-home-v5/, 'PWA bootstrap must refresh installed phones')
assert.match(serviceWorker, /olvend-v300-route-photo-shell/, 'service worker cache must be bumped')

console.log('PASS: production route home states, map, weather, machine photos and Google navigation')
