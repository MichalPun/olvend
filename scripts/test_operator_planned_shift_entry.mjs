import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const home = readFileSync(new URL('../olvend-operator/approved-home-v35.js', import.meta.url), 'utf8')
const page = readFileSync(new URL('../olvend-operator/uvod.html', import.meta.url), 'utf8')
const serviceWorker = readFileSync(new URL('../olvend-operator/sw-v44.js', import.meta.url), 'utf8')

assert.match(home, /Promise\.all\(\[loadRoute\(\), loadInstruction\(\), loadAttendance\(\), loadVehicles\(\), loadVehicleAvailability\(\)\]\)/)
assert.doesNotMatch(home, /entry=no-shift/)
assert.doesNotMatch(home, /Přesměrování do sekce Moje/)
assert.match(page, /approved-home-v35\.js\?v=20261119-unrestricted-shift-start-v1/)
assert.match(serviceWorker, /olvend-operator-v47-unrestricted-shift-start/)
assert.match(serviceWorker, /approved-home-v35\.js\?v=20261119-unrestricted-shift-start-v1/)

console.log('Operator planned shift entry checks passed')
