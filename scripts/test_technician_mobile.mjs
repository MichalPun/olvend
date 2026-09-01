import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

function read(path) { return fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8') }
function parseInlineScripts(path, html) {
  for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
    if (!match[1].trim()) continue
    if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: path })
    else new vm.Script(match[1], { filename: path })
  }
}

const technician = read('technician-mobile.html')
const overview = read('technical-overview.html')
const index = read('index.html')
const operator = read('mobile.html')
const migration = read('database/technician_mobile_v45.sql')

parseInlineScripts('technician-mobile.html', technician)
parseInlineScripts('technical-overview.html', overview)
parseInlineScripts('index.html', index)

for (const required of [
  'technician_day_plan_items',
  "sourceType:'service_request'",
  "sourceType:'technical_job'",
  'data-open-parts',
  'consume_technician_part_v45',
  'data-pickup-job',
  'data-deliver-job',
  'data-open-end',
  "event_type:'break_start'",
  "event_type:'break_end'"
]) assert.ok(technician.includes(required), `Technický mobil postrádá ${required}`)

assert.match(index, /technik.*technician-mobile\.html/s, 'Technik musí po přihlášení vstoupit do samostatného mobilu')
assert.match(index, /return 'mobile\.html'/, 'Operátorské role musí dál vstupovat do původního mobilu')

assert.ok(overview.includes('service_requests') && overview.includes('technical_jobs'), 'PC přehled musí spojovat oba zdroje práce')
assert.ok(overview.includes('service-requests.html') && overview.includes('technical-jobs.html'), 'PC přehled musí zachovat vstup do plných modulů')

assert.ok(migration.includes('unique (plan_date, employee_id, source_type, source_id)'), 'Denní plán nesmí duplikovat stejnou zakázku')
assert.ok(migration.includes('apply_stock_movements_v13'), 'Spotřeba dílu musí použít stávající atomický skladový pohyb')
assert.ok(migration.includes('Zakázka není přiřazená tomuto technikovi'), 'Odpis dílu musí kontrolovat přiřazení technika')

for (const operatorGuard of [
  'getFoodRouteAllocatedQuantity',
  'getFoodGuidedWorkSlots',
  'applyStockMovementsAtomically',
  'renderAssignedRoute',
  'handleServiceAction'
]) assert.ok(operator.includes(operatorGuard), `Operátorská funkce ${operatorGuard} nesmí zmizet`)

console.log('OK: technický mobil, jednotný plán, PC přehled a ochranné body operátorského workflow')
