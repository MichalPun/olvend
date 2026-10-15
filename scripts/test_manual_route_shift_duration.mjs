import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../routes-create.html', import.meta.url), 'utf8')

const extract = (name) => {
  const regularStart = html.indexOf(`    function ${name}(`)
  const asyncStart = html.indexOf(`    async function ${name}(`)
  const start = regularStart >= 0 ? regularStart : asyncStart
  assert.ok(start >= 0, `Chybí funkce ${name}`)
  const rest = html.slice(start + 1)
  const next = rest.search(/\n    (?:async )?function /)
  return html.slice(start, next >= 0 ? start + 1 + next : undefined)
}

const requests = []
let plannedRows = [{
  id: 501,
  shift_plan_id: 77,
  employee_id: 'employee-1',
  plan_date: '2026-10-16',
  shift_type: 'route',
  planned_start: '06:30:00',
  planned_end: '14:00:00',
  planned_minutes: 450,
  status: 'published',
}]

const supabase = {
  from(table) {
    const request = { table, filters: [] }
    requests.push(request)
    const builder = {
      select() { return builder },
      eq(column, value) { request.filters.push([column, value]); return builder },
      order() { return builder },
      limit() { return builder },
      then(resolve) {
        return Promise.resolve(table === 'shift_plans'
          ? { data: [{ id: 77 }], error: null }
          : { data: plannedRows, error: null }).then(resolve)
      },
    }
    return builder
  },
}

const state = {
  selectedPublishedShift: null,
  routeTimeBudgetSource: 'missing',
  shiftLookupRevision: 0,
  currentPlan: null,
}
const maxRouteHoursInput = { value: '', disabled: false }
const routeDepartureTimeInput = { value: '07:00' }
const routeDateInput = { value: '2026-10-16' }
const context = vm.createContext({
  Number,
  String,
  Math,
  console,
  supabase,
  state,
  maxRouteHoursInput,
  routeDepartureTimeInput,
  routeDateInput,
  getSelectedEmployee: () => ({ id: 'employee-1', name: 'Operátor' }),
  renderRouteShiftHint: () => {},
  refreshRouteTimingViews: () => {},
})
for (const name of ['getPlannedShiftMinutes', 'formatShiftHoursInput']) {
  vm.runInContext(extract(name), context)
}
vm.runInContext(extract('loadPublishedShiftForSelection'), context)

assert.equal(context.getPlannedShiftMinutes({ planned_minutes: 450, planned_start: '06:00', planned_end: '14:00' }), 450)
assert.equal(context.getPlannedShiftMinutes({ planned_start: '06:15', planned_end: '14:45' }), 510)
assert.equal(context.getPlannedShiftMinutes({ planned_start: '22:00', planned_end: '06:00' }), 480)
assert.equal(context.getPlannedShiftMinutes({ planned_start: null, planned_end: null }), 0)
assert.equal(context.formatShiftHoursInput(450), '7.5')

await context.loadPublishedShiftForSelection()
assert.equal(maxRouteHoursInput.value, '7.5')
assert.equal(maxRouteHoursInput.disabled, false)
assert.equal(routeDepartureTimeInput.value, '06:30')
assert.equal(state.routeTimeBudgetSource, 'published_shift')
assert.equal(state.selectedPublishedShift.id, 501)
assert.deepEqual(requests[1].filters, [
  ['shift_plan_id', 77],
  ['employee_id', 'employee-1'],
  ['plan_date', '2026-10-16'],
  ['status', 'published'],
])

plannedRows = [{
  id: 502,
  shift_plan_id: 77,
  employee_id: 'employee-1',
  plan_date: '2026-10-16',
  shift_type: 'manager_office',
  planned_start: '08:00:00',
  planned_end: '17:30:00',
  planned_minutes: 570,
  status: 'published',
}]
await context.loadPublishedShiftForSelection()
assert.equal(maxRouteHoursInput.value, '9.5')
assert.equal(routeDepartureTimeInput.value, '08:00')

plannedRows = []
maxRouteHoursInput.value = '8'
await context.loadPublishedShiftForSelection()
assert.equal(maxRouteHoursInput.value, '')
assert.equal(state.routeTimeBudgetSource, 'missing')
assert.equal(state.selectedPublishedShift, null)

assert.match(html, /id="maxRouteHoursInput"[^>]*value=""[^>]*placeholder="Načte se ze směny"/)
assert.doesNotMatch(html, /id="maxRouteHoursInput"[^>]*value="8"/)
assert.match(html, /from\('shift_plans'\)[\s\S]*?\.eq\('status', 'published'\)/)
assert.match(html, /from\('shift_plan_days'\)[\s\S]*?\.eq\('employee_id', employee\.id\)[\s\S]*?\.eq\('plan_date', planningDate\)[\s\S]*?\.eq\('status', 'published'\)/)
assert.match(html, /employeeFilter\.addEventListener\('change', async \(\) => \{[\s\S]*?await loadPublishedShiftForSelection\(\)/)
assert.match(html, /routeDateInput\.addEventListener\('change', async \(\) => \{[\s\S]*?loadPublishedShiftForSelection\(\)/)
assert.match(html, /shift_plan_day_id: state\.selectedPublishedShift\?\.id \|\| null/)
assert.match(html, /shift_planned_minutes: getPlannedShiftMinutes\(state\.selectedPublishedShift\) \|\| null/)
assert.match(html, /if \(!getRouteTiming\(\)\.maximumMinutes\)/)
assert.doesNotMatch(extract('getRouteTiming'), /\|\| 8/)

console.log('OK: ruční plánovač načítá délku a začátek publikované směny; bez směny nepoužije skrytý osmihodinový limit')
