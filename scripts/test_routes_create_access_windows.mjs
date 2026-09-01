import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../routes-create.html', import.meta.url), 'utf8')
const migration = fs.readFileSync(new URL('../database/repair_bohumin_school_access_hours_route83_20260901.sql', import.meta.url), 'utf8')

for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: 'routes-create.html' })
  else new vm.Script(match[1], { filename: 'routes-create.html' })
}

assert.ok(html.includes("routeAccess.window?.label ||\n          getPlanningServiceWindow(location)"), 'Uložená trasa musí zobrazit stejné strukturované okno, podle kterého počítá')
assert.equal((html.match(/const effectiveServiceWindow = routeAccess\.window\?\.label/g) || []).length, 2, 'Lokalita i jednotlivý automat musí používat stejné efektivní okno')
assert.equal((html.match(/matchesSelectedDay: routeAccess\.eligible/g) || []).length, 2, 'Výběr dne musí respektovat potvrzený strukturovaný přístup')

for (const required of [
  "service_window = 'Po-Pá 6:00 - 17:00'",
  "'we', jsonb_build_array(jsonb_build_array('06:00', '17:00'))",
  "where id in (4, 5)",
  "where id = 83",
  "'estimated_total_minutes', 443"
]) assert.ok(migration.includes(required), `Oprava Bohumína postrádá ${required}`)

console.log('OK: plánovač zobrazuje a počítá stejné provozní okno; Bohumín 6:00–17:00')
