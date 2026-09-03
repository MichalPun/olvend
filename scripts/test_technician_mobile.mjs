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
const technicalJobs = read('technical-jobs.html')
const index = read('index.html')
const operator = read('mobile.html')
const migration = read('database/technician_mobile_v45.sql')
const transferMigration = read('database/technician_transfer_atomic_v46.sql')
const serviceRequests = read('service-requests.html')

parseInlineScripts('technician-mobile.html', technician)
parseInlineScripts('technical-overview.html', overview)
parseInlineScripts('technical-jobs.html', technicalJobs)
parseInlineScripts('index.html', index)

for (const required of [
  'technician_day_plan_items',
  "sourceType:'service_request'",
  "sourceType:'technical_job'",
  'data-open-parts',
  'consume_technician_part_v45',
  'data-pickup-job',
  'data-deliver-job',
  'complete_technician_transport_v46',
  'Předáno na nové lokalitě',
  'Přijato na sklad / dílnu',
  'data-block-job',
  'data-open-end',
  "event_type:'break_start'",
  "event_type:'break_end'"
]) assert.ok(technician.includes(required), `Technický mobil postrádá ${required}`)

for (const required of [
  'data-screen="new-service"',
  'Založit a převzít servis',
  'async function createService()',
  "supabase.from('service_requests').insert",
  'assigned_employee_id:state.employee.id',
  'assigned_employee_id.is.null',
  'Hlášení bylo převzato a servis zahájen.'
]) assert.ok(technician.includes(required), `Technik nemůže založit vlastní servis: ${required}`)

for (const required of [
  'renderTechnicalInstructions',
  'technical_job_material_availability_v29',
  'Zásobníky a suroviny',
  'Volby a ceny',
  'Fotky a přílohy'
]) assert.ok(technician.includes(required), `Mobil technika neukazuje úplné zadání: ${required}`)

assert.match(index, /technik.*technician-mobile\.html/s, 'Technik musí po přihlášení vstoupit do samostatného mobilu')
assert.match(index, /return 'mobile\.html'/, 'Operátorské role musí dál vstupovat do původního mobilu')

assert.ok(overview.includes('service_requests') && overview.includes('technical_jobs'), 'PC přehled musí spojovat oba zdroje práce')
assert.ok(overview.includes('service-requests.html') && overview.includes('technical-jobs.html'), 'PC přehled musí zachovat vstup do plných modulů')

for (const required of [
  'PŘENOS DO MOBILU TECHNIKA',
  'NEPŘENÁŠÍ SE',
  'saveMobileAssignment',
  'renderConfigurationTables',
  'Stejné strukturované údaje se zobrazí technikovi v mobilu'
]) assert.ok(technicalJobs.includes(required), `PC karta neobjasňuje přenos do mobilu: ${required}`)

assert.ok(migration.includes('unique (plan_date, employee_id, source_type, source_id)'), 'Denní plán nesmí duplikovat stejnou zakázku')
assert.ok(migration.includes('apply_stock_movements_v13'), 'Spotřeba dílu musí použít stávající atomický skladový pohyb')
assert.ok(migration.includes('Zakázka není přiřazená tomuto technikovi'), 'Odpis dílu musí kontrolovat přiřazení technika')

for (const required of [
  'technical_job_id',
  'from_stock_location_id',
  'to_stock_location_id',
  'for update',
  'update public.machines',
  'insert into public.machine_transfers',
  "'already_applied', true"
]) assert.ok(transferMigration.toLowerCase().includes(required.toLowerCase()), `Atomický přesun postrádá ${required}`)

assert.ok(!technicalJobs.includes('await ensureChecklist(data)'), 'Nová technická karta nesmí automaticky vytvářet povinný checklist')
assert.ok(technicalJobs.includes("service-requests.html?action=new"), 'Nový servis se musí zakládat v jediném servisním formuláři')
assert.ok(serviceRequests.includes('new-request-mode') && serviceRequests.includes('lifecycle-field'), 'Nový servisní požadavek má používat zjednodušený formulář')

for (const operatorGuard of [
  'getFoodRouteAllocatedQuantity',
  'getFoodGuidedWorkSlots',
  'applyStockMovementsAtomically',
  'renderAssignedRoute',
  'handleServiceAction'
]) assert.ok(operator.includes(operatorGuard), `Operátorská funkce ${operatorGuard} nesmí zmizet`)

for (const required of [
  'Nahlásit závadu na tomto automatu',
  'openServiceReportForStop',
  "status: technician ? 'assigned' : 'new'",
  'Závada je nahlášená do fronty techniků.'
]) assert.ok(operator.includes(required), `Operátorka nemá funkční hlášení servisu: ${required}`)

console.log('OK: technický mobil, jednotný plán, PC přehled a ochranné body operátorského workflow')
