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
assert.match(html, /class="stock-prerequisite-icon"[\s\S]*?<svg viewBox="0 0 24 24">/, 'stock prerequisite must show a real visible pictogram')
assert.match(html, /function renderStockAvailabilityGate\(\)/, 'stock must evaluate shift and vehicle prerequisites')
assert.match(html, /const blocked = !running \|\| !hasVehicle/, 'stock must stay blocked without an active shift or vehicle')
assert.match(html, /preShiftAllowedScreens = \[[^\]]*'stock'/, 'operators must be able to open the stock prerequisite screen before their shift')
assert.match(html, /if \(renderStockAvailabilityGate\(\)\) return/, 'stock operations must not render while prerequisites are missing')
assert.match(html, /Sklad pracuje se zásobou konkrétního auta/, 'vehicle dependency must be explained in plain language')

assert.match(html, /id="instructionCenter"/, 'daily instructions must have one overview')
assert.match(html, /\.instruction-center-card \{ position: relative; z-index: 1;/, 'instruction cards must render above the dark backdrop')
assert.match(html, /function openInstructionCenter\(\)/, 'the instruction overview must be openable from the app')
assert.match(html, /document\.querySelector\('\.screen\[data-screen="today"\]'\)\?\.addEventListener\('click'/, 'all home instruction cards must share the click handler')
assert.match(html, /<strong>Aktuální<\/strong>/, 'instruction overview must show current instructions')
assert.match(html, /<strong>Potvrzené<\/strong>/, 'instruction overview must retain acknowledged instructions')
assert.match(html, /if \(action === 'instruction'\) return openInstructionCenter\(\)/, 'instruction actions must open the overview instead of an arbitrary first item')
assert.match(html, /state\.instructionReturnToCenter = true/, 'closing an instruction detail must return to the overview')
assert.match(html, /class="shift-editor-icon"[\s\S]*?<svg viewBox="0 0 24 24">/, 'vehicle receipt must use a real vehicle pictogram')
assert.match(html, /data-open-shift-instructions>Otevřít a potvrdit pokyny/, 'vehicle receipt must offer one explicit instruction action')
assert.match(html, /els\.vehicleSelectLabel\.hidden = instructionsBlocked/, 'vehicle selection must stay hidden until required instructions are confirmed')
assert.match(html, /els\.startShiftButton\.hidden = instructionsBlocked/, 'shift start must stay hidden until required instructions are confirmed')
assert.match(html, /if \(missingInstructions\.length\) \{[\s\S]*?openInstructionCenter\(\)/, 'shift start must open the real instruction center when instructions are pending')
assert.doesNotMatch(html, /id="instructionAckSelect"|function acknowledgeRequiredInstructions\(/, 'vehicle receipt must not duplicate or silently confirm instructions')
assert.match(html, /renderShiftState\(\)\s*renderShiftVehicleEditor\(\)/, 'confirming an instruction must immediately unlock the vehicle step')

assert.match(html, /pwa\.js\?v=20261128-shift-instruction-gate-v1/, 'mobile HTML must request the refreshed PWA bootstrap')
assert.match(pwa, /20261128-shift-instruction-gate-v1/, 'PWA bootstrap must refresh installed phones')
assert.match(serviceWorker, /olvend-v280-shift-instruction-gate/, 'service worker cache must be bumped')

console.log('PASS: mobile stock prerequisites and daily instruction center')
