import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const machinesHtml = fs.readFileSync('machines.html', 'utf8')
const mobileHtml = fs.readFileSync('mobile.html', 'utf8')
const migration = fs.readFileSync('database/telemetry_link_tracking_mode_guard_20261016.sql', 'utf8')

for (const match of machinesHtml.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: 'machines.html' })
  else new vm.Script(match[1], { filename: 'machines.html' })
}

assert.match(machinesHtml, /update\(\{ sales_tracking_mode: 'telemetry' \}\)/,
  'Uložení TID musí přepnout stroj do telemetrického režimu')
assert.match(machinesHtml, /TID se uložilo, ale režim evidence se nepřepnul na telemetrii/,
  'UI musí odmítnout tiché částečné uložení')

assert.match(mobileHtml, /machine_external_links[\s\S]*?\.eq\('machine_id', machine\.id\)[\s\S]*?\.eq\('telemetry_enabled', true\)/,
  'Potravinová trasa musí ověřit aktivní telemetrické napojení')
assert.match(mobileHtml, /manualStockMode: isManualFoodStockMode\(machine, telemetryLinksResult\)/,
  'Aktivní TID musí vyřadit chybný ruční režim i při starším záznamu stroje')

const modeFunction = mobileHtml.match(/function isManualFoodStockMode\(machine, telemetryLinksResult\) \{[\s\S]*?\n    \}/)?.[0]
assert.ok(modeFunction, 'Rozhodovací funkce režimu potravinového automatu musí existovat')
const modeContext = vm.createContext({})
vm.runInContext(modeFunction, modeContext)
assert.equal(modeContext.isManualFoodStockMode(
  { sales_tracking_mode: 'none' },
  { data: [{ id: 1, telemetry_enabled: true }], error: null }
), false, 'Aktivní TID musí mít přednost před starým režimem none')
assert.equal(modeContext.isManualFoodStockMode(
  { sales_tracking_mode: 'none' },
  { data: [], error: null }
), true, 'Skutečný automat bez telemetrie musí zůstat v ručním režimu')
assert.equal(modeContext.isManualFoodStockMode(
  { sales_tracking_mode: 'telemetry' },
  { data: null, error: new Error('temporary lookup failure') }
), false, 'Krátký výpadek dotazu nesmí telemetrický automat přepnout na ruční doplňování')

assert.match(migration, /after insert or update or delete on public\.machine_external_links/,
  'Databáze musí hlídat vložení, přesun i odebrání TID')
assert.match(migration, /\(58::bigint, 78::bigint, 'IMA'::text, '635461'::text\)/,
  'Oprava musí ověřit EV 78 proti správnému TID')
assert.match(migration, /\(66::bigint, 86::bigint, 'IMA'::text, '602224'::text\)/,
  'Oprava musí ověřit EV 86 proti správnému TID')
assert.match(migration, /telemetry\.last_seen_at >= now\(\) - interval '24 hours'/,
  'Datová oprava se nesmí provést bez čerstvé telemetrie')
assert.match(migration, /Plna pozice EV 78 nebo EV 86 ma po oprave stale pozadavek na doplneni/,
  'Migrace musí odmítnout stale požadavky u plných pozic')

console.log('OK: TID atomicky přepíná režim a EV 78/86 mají bezpečné datové guardy')
