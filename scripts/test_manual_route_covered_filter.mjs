import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../routes-create.html', import.meta.url), 'utf8')

const extract = (name) => {
  const start = html.indexOf(`    function ${name}(`)
  assert.ok(start >= 0, `Chybí funkce ${name}`)
  const rest = html.slice(start + 1)
  const next = rest.search(/\n    (?:async )?function /)
  return html.slice(start, next >= 0 ? start + 1 + next : undefined)
}

const state = {
  editingPlanKey: null,
  scheduledPlansForDate: [
    {
      id: 100,
      execution_status: 'assigned',
      route_plan_stops: [
        { location_id: 10, machine_id: 101, status: 'planned' },
        { location_id: 20, machine_id: null, status: 'planned' },
        { location_id: 30, machine_id: 301, status: 'skipped' },
      ],
    },
    {
      id: 200,
      execution_status: 'cancelled',
      route_plan_stops: [{ location_id: 40, machine_id: 401, status: 'planned' }],
    },
  ],
}

const context = vm.createContext({ state, String, Array })
for (const name of ['getPlanKey', 'getPlanStops', 'isCandidateScheduledElsewhere', 'isCandidateAvailableForManualRoute']) {
  vm.runInContext(extract(name), context)
}

assert.equal(context.isCandidateScheduledElsewhere({ locationId: 10, machineId: 101 }), true, 'Stejný automat na jiné trase musí být pokrytý')
assert.equal(context.isCandidateAvailableForManualRoute({ locationId: 10, machineId: 101 }), false, 'Pokrytý automat se nesmí ručně nabízet')
assert.equal(context.isCandidateScheduledElsewhere({ locationId: 10, machineId: 102 }), false, 'Jiný automat ve stejné lokalitě zůstává při výběru strojů volný')
assert.equal(context.isCandidateScheduledElsewhere({ locationId: 20, machineId: 201 }), true, 'Zastávka celé lokality pokrývá všechny její automaty')
assert.equal(context.isCandidateScheduledElsewhere({ locationId: 10 }), true, 'Lokalita je pokrytá, pokud je na jiné trase její automat')
assert.equal(context.isCandidateScheduledElsewhere({ locationId: 30, machineId: 301 }), false, 'Přeskočená zastávka se smí znovu naplánovat')
assert.equal(context.isCandidateScheduledElsewhere({ locationId: 40, machineId: 401 }), false, 'Zrušená trasa nesmí lokalitu blokovat')

state.editingPlanKey = '100'
assert.equal(context.isCandidateScheduledElsewhere({ locationId: 10, machineId: 101 }), false, 'Upravovaná trasa musí dál zobrazit vlastní zastávky')

assert.match(html, /<option value="all_active">Všechny aktivní nepokryté<\/option>/)
assert.doesNotMatch(html, /Všechny včetně pokrytých/)
assert.match(extract('applyFilters'), /filtered = filtered\.filter\(isCandidateAvailableForManualRoute\)/)
assert.doesNotMatch(extract('applyFilters'), /sourceMode !== 'all_active'[\s\S]*isCandidateScheduledElsewhere/)

console.log('OK: ruční plánování skrývá pokryté zastávky a při úpravě zachová vlastní trasu')
