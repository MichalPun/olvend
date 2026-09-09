import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
for (const name of ['mobile.html', 'vehicles.html']) {
  const source = fs.readFileSync(new URL(`../${name}`, import.meta.url), 'utf8')
  for (const match of source.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
    if (!match[1].trim()) continue
    if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: name })
    else new vm.Script(match[1], { filename: name })
  }
}
function between(start, end) {
  const begin = html.indexOf(start)
  const finish = html.indexOf(end, begin)
  assert.ok(begin >= 0 && finish > begin)
  return html.slice(begin, finish)
}
const verify = between('    async function verifyCurrentShiftVehicle()', '    async function loadAttendanceEvents()')
for (const [cachedVehicle, serverVehicle, changed] of [[1, 1, false], [1, 2, true]]) {
  let reloads = 0
  const query = {
    select() { return this }, eq() { return this },
    async single() { return { data: { vehicle_id: serverVehicle, actual_end: null } } }
  }
  const context = vm.createContext({
    state: { attendanceDay: { id: 9, vehicle_id: cachedVehicle } },
    supabase: { from: () => query },
    reloadData: async () => { reloads++ }
  })
  vm.runInContext(verify, context)
  if (changed) await assert.rejects(context.verifyCurrentShiftVehicle(), /změnilo auto/)
  else await context.verifyCurrentShiftVehicle()
  assert.equal(reloads, changed ? 1 : 0)
}
const compare = between('    function getRouteKmComparison(', '    function formatSignedRouteKm(')
const context = vm.createContext({
  state: { vehicleLog: { vehicle_id: 2, start_odometer_km: 152009, end_odometer_km: 152010 } },
  getAssignedRoutePlan: () => ({ vehicle_id: 1, estimated_distance_km: 124.6 })
})
vm.runInContext(compare, context)
assert.equal(context.getRouteKmComparison(), null, 'New vehicle must not be compared against old route mileage')
assert.equal(context.getRouteKmComparison({ vehicle_id: 2, estimated_distance_km: 1 }).differenceKm, 0)
console.log('PASS: inline JavaScript syntax; stale mobile state reloads and rejects write; mileage stays with its vehicle')
