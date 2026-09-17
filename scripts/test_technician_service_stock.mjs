import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../technician-mobile.html', import.meta.url), 'utf8')
const migration = fs.readFileSync(new URL('../database/technician_service_container_stock_v51.sql', import.meta.url), 'utf8')

const moduleScript = html.match(/<script type="module">([\s\S]*?)<\/script>/)?.[1]
assert.ok(moduleScript, 'Technician mobile module is missing')
new vm.SourceTextModule(moduleScript, { identifier:'technician-mobile.html' })

for (const required of [
  '+ Upravit zásobník',
  'data-open-containers',
  'data-select-container',
  'serviceContainerDrafts',
  'Skutečně před zásahem',
  'Doplněno z auta',
  'collectServiceStockItems',
  'apply_technician_service_container_stock_v51'
]) assert.ok(html.includes(required), `Mobilní servis postrádá selektivní zásobníkový krok: ${required}`)

assert.match(
  html,
  /state\.serviceContainerDrafts\.map\(/,
  'Editor smí vykreslit jen technikem vybrané zásobníky'
)
assert.match(
  html,
  /if\(Math\.abs\(actual-Number\(container\.current_quantity\|\|0\)\)<\.0001&&added<\.0001\)continue/,
  'Nezměněný vybraný zásobník se nesmí uložit'
)
assert.match(
  html,
  /requestedByProduct.*vehicleAvailable/s,
  'Dostupnost v autě se musí kontrolovat souhrnně za produkt'
)

for (const required of [
  'create table if not exists public.service_request_container_actions',
  'pg_advisory_xact_lock',
  'for update',
  "location.location_type = 'vehicle'",
  "attendance.status = 'open'",
  'public.apply_stock_movements_v13',
  "'movement_type', 'fill_machine'",
  'update public.machine_coffee_containers',
  "'already_applied', true",
  'revoke all on function',
  'grant execute on function'
]) assert.ok(migration.toLowerCase().includes(required.toLowerCase()), `Atomický zápis zásobníku postrádá: ${required}`)

console.log('PASS: selective technician container correction/refill, vehicle stock guard, idempotency, and audit trail')
