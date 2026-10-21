import assert from 'node:assert/strict'
import fs from 'node:fs'
import {
  getActionableSameLocationSiblings,
  getSameLocationCoverageGaps,
} from '../route-same-location-coverage.js'

const candidates = [
  { key: 'machine-127', machineId: 127, locationId: 60, evidenceNumber: 127, actionable: false, available: true },
  { key: 'machine-128', machineId: 128, locationId: 60, evidenceNumber: 128, actionable: false, available: true },
  { key: 'machine-126', machineId: 126, locationId: 60, evidenceNumber: 126, actionable: false, available: true },
  { key: 'machine-125', machineId: 125, locationId: 60, evidenceNumber: 125, actionable: true, available: true },
  { key: 'machine-92', machineId: 92, locationId: 17, evidenceNumber: 92, actionable: true, available: true },
  { key: 'machine-999', machineId: 999, locationId: 60, evidenceNumber: 999, actionable: true, available: false },
]

const options = {
  isActionable: (candidate) => candidate.actionable,
  isAvailable: (candidate) => candidate.available,
}

assert.deepEqual(
  getActionableSameLocationSiblings(candidates[2], candidates, options).map((candidate) => candidate.evidenceNumber),
  [125],
  'výběr EV126 musí najít kritický EV125 na stejné lokalitě, ale ne stroj už pokrytý jinou trasou',
)

assert.deepEqual(
  getSameLocationCoverageGaps(candidates, new Set(['machine-127', 'machine-128', 'machine-126']), options)
    .map((candidate) => candidate.evidenceNumber),
  [125],
  'Vitar nesmí projít kontrolou, pokud je vybrán některý stroj na místě a kritický EV125 chybí',
)

assert.deepEqual(
  getSameLocationCoverageGaps(candidates, new Set(['machine-125', 'machine-126']), options),
  [],
  'po přidání kritického stroje musí být lokalita pokrytá',
)

const html = fs.readFileSync(new URL('../routes-create.html', import.meta.url), 'utf8')
assert.match(html, /addCandidateWithSameLocationCoverage\(candidate\)/)
assert.match(html, /getUncoveredSameLocationMachines\(\)/)
assert.match(html, /zůstává mimo trasu/)

console.log('OK: plánovač automaticky pokryje doporučené automaty na stejné lokalitě')
