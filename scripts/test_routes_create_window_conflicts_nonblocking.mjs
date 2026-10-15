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

const strictContext = vm.createContext({
  getRouteFeasibility: (plan) => ({
    plan,
    inaccessibleStops: [{ key: 'machine-84', name: 'Europa Snack', serviceWindow: '06:00–14:00', estimatedArrivalAt: '2026-10-16T15:00:00.000Z' }],
  }),
})
vm.runInContext(extract('assertRouteFeasible'), strictContext)

assert.throws(
  () => strictContext.assertRouteFeasible({ orderedStops: [] }),
  /Do otevírací doby se nevejde/,
  'Přísná kontrola má zůstat dostupná pro pokus s Google pořadím'
)
const allowed = strictContext.assertRouteFeasible({ orderedStops: [] }, { allowWindowConflicts: true })
assert.equal(allowed.routeWindowConflicts.length, 1)
assert.equal(allowed.routeWindowConflicts[0].name, 'Europa Snack')

const stops = [
  { key: 'machine-84', name: 'Europa Snack', latitude: 1, longitude: 1, accessWindow: { opensAt: 360, closesAt: 420, intervals: [{ opensAt: 360, closesAt: 420 }] } },
  { key: 'machine-97', name: 'Luce X2 I', latitude: 2, longitude: 2, accessWindow: { opensAt: 360, closesAt: 420, intervals: [{ opensAt: 360, closesAt: 420 }] } },
]
const optimizerContext = vm.createContext({
  state: { candidates: stops, selectedKeys: new Set(stops.map((stop) => stop.key)) },
  determineStartPoint: () => ({ latitude: 0, longitude: 0, label: 'Sklad' }),
  sortBias: { value: 'balanced' },
  routeDateInput: { value: '2026-10-16' },
  routeDepartureTimeInput: { value: '12:00' },
  preparationMinutesInput: { value: '0' },
  returnMode: { value: 'one_way' },
  haversineKm: (from, to) => Math.hypot(Number(to.latitude) - Number(from.latitude), Number(to.longitude) - Number(from.longitude)),
  parseOpeningWindow: () => null,
  estimateServiceMinutes: () => 20,
  calcPriorityBonus: () => 0,
  ROAD_FACTOR: 1,
  AVG_SPEED_KMH: 60,
  assertRouteFeasible: (plan, options) => ({ ...plan, testOptions: options }),
  Date,
  Math,
  Number,
  String,
  Set,
  Error,
})
vm.runInContext(extract('optimizeStops'), optimizerContext)
const plan = optimizerContext.optimizeStops()

assert.equal(plan.orderedStops.length, 2, 'Ani zastávky mimo okno se nesmí z plánované trasy zahodit')
assert.equal(plan.testOptions.allowWindowConflicts, true, 'Ruční plánovač musí konflikt zobrazit, ale nesmí blokovat pokračování')
assert.match(html, /Zastávky zůstaly v trase, můžeš upravit jejich pořadí a pokračovat; uložení není blokované/)

console.log('OK: konflikt otevírací doby je viditelný, ale ruční plánování a uložení dál pokračuje')
