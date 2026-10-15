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
let plannedRows = [
  {
    id: 501,
    shift_plan_id: 77,
    employee_id: 'employee-1',
    plan_date: '2026-10-16',
    shift_type: 'route',
    planned_start: '06:30:00',
    planned_end: '14:00:00',
    planned_minutes: 450,
    status: 'published',
  },
  {
    id: 503,
    shift_plan_id: 77,
    employee_id: 'employee-1',
    plan_date: '2026-10-20',
    shift_type: 'route',
    planned_start: '06:00:00',
    planned_end: '14:00:00',
    planned_minutes: 480,
    status: 'published',
  },
]
const attendanceRows = [{ attendance_date: '2026-10-16', payable_minutes: 510, status: 'closed' }]
const routeRows = [{
  id: 900,
  planning_date: '2026-10-20',
  execution_status: 'assigned',
  estimated_drive_minutes: 180,
  estimated_service_minutes: 330,
  route_payload: { route_time_budget: { preparation_minutes: 30, estimated_total_minutes: 540 } },
}]

const supabase = {
  from(table) {
    const request = { table, filters: [] }
    requests.push(request)
    const builder = {
      select() { return builder },
      eq(column, value) { request.filters.push([column, value]); return builder },
      gte(column, value) { request.filters.push([`${column}>=`, value]); return builder },
      lte(column, value) { request.filters.push([`${column}<=`, value]); return builder },
      order() { return builder },
      limit() { return builder },
      then(resolve) {
        const data = table === 'shift_plans'
          ? [{ id: 77 }]
          : table === 'shift_plan_days'
            ? plannedRows
            : table === 'attendance_days'
              ? attendanceRows
              : table === 'route_plans'
                ? routeRows
                : []
        return Promise.resolve({ data, error: null }).then(resolve)
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
  editingPlanKey: null,
  selectedMonthShiftRows: [],
  monthlyOvertime: { status: 'idle', employeeId: null, monthKey: '', monthLabel: '', attendanceRows: [], routeRows: [] },
}
const maxRouteHoursInput = { value: '', disabled: false }
const routeDepartureTimeInput = { value: '07:00' }
const routeDateInput = { value: '2026-10-16' }
const routeOvertimeHint = { textContent: '' }
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
  routeOvertimeHint,
  getSelectedEmployee: () => ({ id: 'employee-1', name: 'Operátor' }),
  renderRouteShiftHint: () => {},
  refreshRouteTimingViews: () => {},
  getRouteTiming: () => ({ totalMinutes: 600 }),
})
for (const name of [
  'getPlannedShiftMinutes',
  'formatShiftHoursInput',
  'getPlanningMonth',
  'getSavedRouteTotalMinutes',
  'formatDuration',
  'getMonthlyOvertimeSummary',
  'renderRouteMonthlyOvertimeHint',
  'loadMonthlyOvertimeForSelection',
]) {
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
assert.equal(state.monthlyOvertime.status, 'ready')
assert.equal(state.selectedMonthShiftRows.length, 2)
assert.deepEqual(requests[1].filters, [
  ['shift_plan_id', 77],
  ['employee_id', 'employee-1'],
  ['status', 'published'],
])
const overtime = context.getMonthlyOvertimeSummary({ orderedStops: [] })
assert.equal(overtime.recordedMinutes, 60)
assert.equal(overtime.plannedRouteMinutes, 60)
assert.equal(overtime.currentRouteMinutes, 150)
assert.equal(overtime.projectedMinutes, 270)
assert.match(routeOvertimeHint.textContent, /Pouze informace, uložení není blokované/)

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
assert.match(html, /from\('shift_plan_days'\)[\s\S]*?\.eq\('employee_id', employee\.id\)[\s\S]*?\.eq\('status', 'published'\)[\s\S]*?find\(\(row\) => row\.plan_date === planningDate\)/)
assert.match(html, /from\('attendance_days'\)[\s\S]*?\.eq\('employee_id', employee\.id\)[\s\S]*?\.gte\('attendance_date', month\.from\)/)
assert.match(html, /from\('route_plans'\)[\s\S]*?\.eq\('planned_employee_id', employee\.id\)[\s\S]*?\.gte\('planning_date', month\.from\)/)
assert.match(html, /employeeFilter\.addEventListener\('change', async \(\) => \{[\s\S]*?await loadPublishedShiftForSelection\(\)/)
assert.match(html, /routeDateInput\.addEventListener\('change', async \(\) => \{[\s\S]*?loadPublishedShiftForSelection\(\)/)
assert.match(html, /shift_plan_day_id: state\.selectedPublishedShift\?\.id \|\| null/)
assert.match(html, /shift_planned_minutes: getPlannedShiftMinutes\(state\.selectedPublishedShift\) \|\| null/)
assert.match(html, /if \(!getRouteTiming\(\)\.maximumMinutes\)/)
assert.doesNotMatch(extract('getRouteTiming'), /\|\| 8/)
assert.doesNotMatch(extract('assertRouteFeasible'), /fitsShift|remainingMinutes/)
assert.match(html, /Překročení je povolené a uložení neblokuje/)
assert.match(html, /monthly_overtime_projected_minutes/)

console.log('OK: ruční plánovač načítá směnu a měsíční přesčasy; denní překročení zůstává pouze informační')
