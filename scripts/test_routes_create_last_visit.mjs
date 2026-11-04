import fs from 'node:fs'
import vm from 'node:vm'
import assert from 'node:assert/strict'

const html = fs.readFileSync(new URL('../routes-create.html', import.meta.url), 'utf8')

function functionSource(name) {
  const start = html.search(new RegExp(`    function ${name}\\(`))
  assert.ok(start >= 0, `Chybí funkce ${name}`)
  const rest = html.slice(start)
  const next = rest.slice(5).search(/\n    function /)
  return next < 0 ? rest : rest.slice(0, next + 5)
}

const context = {
  Date,
  Number,
  Set,
  state: {
    lastCompletedMachineVisits: new Map([
      ['11', { machine_id: 11, status: 'completed', completed_at: '2026-11-02T09:30:00+01:00' }],
      ['12', { machine_id: 12, status: 'completed', completed_at: '2026-11-03T15:00:00+01:00' }],
    ]),
  },
  routeDateInput: { value: '2026-11-04' },
}
vm.createContext(context)
for (const name of ['getVisitTimestamp', 'getCandidateLastCompletedVisit', 'formatCandidateLastVisit', 'daysSince']) {
  vm.runInContext(functionSource(name), context)
}

const machineLabel = context.formatCandidateLastVisit({ machineId: 11 })
assert.equal(machineLabel.missing, false)
assert.match(machineLabel.label, /Poslední návštěva: 2\. 11\. 2026/)
assert.match(machineLabel.label, /před 2 dny/)

const locationLabel = context.formatCandidateLastVisit({
  machineId: null,
  machineServiceEntries: [{ machineId: 11 }, { machineId: 12 }],
})
assert.match(locationLabel.label, /Poslední návštěva: 3\. 11\. 2026/)
assert.match(locationLabel.label, /před 1 dnem/)

const missingLabel = context.formatCandidateLastVisit({ machineId: 99 })
assert.equal(missingLabel.missing, true)
assert.equal(missingLabel.label, 'Poslední návštěva: bez dokončeného záznamu')

assert.match(html, /candidate-card-last-visit/)
assert.match(html, /lastVisit\.missing \? ' no-visit' : ''/)

console.log('OK: plánovač zobrazuje poslední dokončenou návštěvu stroje i lokality a bezpečný stav bez záznamu')
