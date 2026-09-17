import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const report = fs.readFileSync(new URL('../report-telemetry.html', import.meta.url), 'utf8')
const migration = fs.readFileSync(new URL('../database/normalize_hot_drink_catalog_20260917.sql', import.meta.url), 'utf8')

for (const match of report.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: 'report-telemetry.html' })
  else new vm.Script(match[1], { filename: 'report-telemetry.html' })
}

assert.ok(report.includes('function indexProductCatalog'), 'Report musi indexovat kanonicky katalog produktu')
assert.ok(report.includes('function canonicalizeTelemetryRow'), 'Telemetricke nazvy musi byt nahrazeny kanonickym nazvem podle SKU')
assert.ok(report.includes('function telemetryProductKey'), 'Agregace produktu musi pouzivat stabilni SKU, ne historicky nazev')
assert.match(report, /\.map\(canonicalizeTelemetryRow\)/, 'Kanonizace musi byt aplikovana na nactene prodeje')
assert.match(report, /replace\(\/\\s\+NEW\$\/i, ''\)/, 'Historicky priznak NEW nesmi zustat v nazvu reportu')
assert.ok(report.includes('Zdrojový typ:\\s*Teplé nápoje'), 'Stare teple napoje musi mit bezpecny fallback kategorie')
assert.ok(migration.includes("product_category = 'beverage_ready'"), 'Migrace musi opravit chybnou kategorii napoje')
assert.ok(migration.includes('[olvend_product_kind:hot_drink]'), 'Migrace musi sjednotit typ teplych napoju')

console.log('OK: telemetrie sjednocuje historicke nazvy podle SKU a teple napoje do jedne kategorie')
