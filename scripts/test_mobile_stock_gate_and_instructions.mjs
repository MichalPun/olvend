import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const pwa = fs.readFileSync(new URL('../pwa.js', import.meta.url), 'utf8')
const serviceWorker = fs.readFileSync(new URL('../sw.js', import.meta.url), 'utf8')
const moduleScript = [...html.matchAll(/<script type="module">([\s\S]*?)<\/script>/g)].at(-1)?.[1]

assert.ok(moduleScript, 'mobile.html must contain its module script')
new vm.SourceTextModule(moduleScript, { identifier: 'mobile.html' })

assert.match(html, /id="stockPrerequisite"/, 'stock must provide a readable prerequisite screen')
assert.match(html, /function renderStockAvailabilityGate\(\)/, 'stock must evaluate shift and vehicle prerequisites')
assert.match(html, /const blocked = !running \|\| !hasVehicle/, 'stock must stay blocked without an active shift or vehicle')
assert.match(html, /preShiftAllowedScreens = \[[^\]]*'stock'/, 'operators must be able to open the stock prerequisite screen before their shift')
assert.match(html, /if \(renderStockAvailabilityGate\(\)\) return/, 'stock operations must not render while prerequisites are missing')
assert.match(html, /Sklad pracuje se zásobou konkrétního auta/, 'vehicle dependency must be explained in plain language')

assert.match(html, /id="instructionCenter"/, 'daily instructions must have one overview')
assert.match(html, /function openInstructionCenter\(\)/, 'the instruction overview must be openable from the app')
assert.match(html, /<strong>Aktuální<\/strong>/, 'instruction overview must show current instructions')
assert.match(html, /<strong>Potvrzené<\/strong>/, 'instruction overview must retain acknowledged instructions')
assert.match(html, /if \(action === 'instruction'\) return openInstructionCenter\(\)/, 'instruction actions must open the overview instead of an arbitrary first item')
assert.match(html, /state\.instructionReturnToCenter = true/, 'closing an instruction detail must return to the overview')

assert.match(html, /pwa\.js\?v=20261128-stock-gate-instructions-v1/, 'mobile HTML must request the refreshed PWA bootstrap')
assert.match(pwa, /20261128-stock-gate-instructions-v1/, 'PWA bootstrap must refresh installed phones')
assert.match(serviceWorker, /olvend-v277-stock-gate-instructions/, 'service worker cache must be bumped')

console.log('PASS: mobile stock prerequisites and daily instruction center')
