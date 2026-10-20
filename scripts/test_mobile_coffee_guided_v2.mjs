import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')

for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier:'mobile.html' })
  else new vm.Script(match[1], { filename:'mobile.html' })
}

for (const required of [
  'coffee-only-flow',
  'linear-gradient(135deg,#bd1220,#df2834)',
  'Zásoby',
  'Výbava',
  'guided-pick-take',
  'guided-pick-skip-reason',
  'guided-pick-select-extra',
  'guided-gear-toggle',
  'Víčka jsou zásoba',
  'guided-zero-refill-check',
  'guided-check-outcome',
  'Bylo čisté / v pořádku',
  'Vyčištěno / opraveno',
  'Nelze dokončit',
  'data-coffee-problem-reason',
  'Na jejich schválení nečekáš',
  'submitCoffeeProblemService',
  'assets/cash-security-bag.png'
]) assert.ok(html.includes(required), `Chybí kávový prvek: ${required}`)

assert.match(html, /isCoffeeCupProduct[\s\S]*?label:\s*isStick\s*\?\s*'tyč'/, 'Kelímky se musí zobrazovat po tyčích')
assert.match(html, /isCoffeeCupProduct\(container\)\s*\?\s*50/, 'Výchozí tyč kelímků musí mít 50 ks')
assert.match(html, /if \(error && navigator\.onLine\) throw error[\s\S]*?persistMobileSnapshot\(\)/, 'Kávové kroky musí mít offline lokální uložení')
assert.match(html, /outcome === 'problem' && !problemReason[\s\S]*?Napiš důvod/, 'Nedokončená povinnost musí vyžadovat důvod')
assert.match(html, /status:'done',[\s\S]*?task_unresolved:outcome === 'problem'/, 'Nahlášený problém musí kontrolní bod uzavřít bez čekání na technika')
assert.doesNotMatch(html, /if \(outcome === 'problem'\) openServiceReportForStop/, 'Nahlášení problému nesmí vyhodit obsluhu z návštěvy do servisu')
assert.match(html, /syncCoffeeOfflineServiceQueue/, 'Závada musí jít bezpečně odeslat i po návratu připojení')
assert.match(html, /if \(correctionOnly\) \{[\s\S]*?await saveCoffeeContainerVisitItem[\s\S]*?final_quantity: actualBefore[\s\S]*?physicalChecked: true[\s\S]*?skutečný stav je uložený v evidenci/, 'Samostatná korekce zásobníku se musí uložit jedním potvrzením, ne jen připravit do dalšího kroku')
assert.match(html, /if \(action === 'save-free-coffee'\)[\s\S]*?if \(detail\.hasTelemetry === false\) \{[\s\S]*?machine_coffee_containers[\s\S]*?Suroviny odečte skutečný výdej z telemetrie/, 'Káva zdarma se na telemetrickém automatu nesmí odečíst ručně podruhé')
assert.match(html, /async function saveGuidedCoffeeTestDrink[\s\S]*?if \(detail\.hasTelemetry === false\) \{[\s\S]*?machine_coffee_containers[\s\S]*?Suroviny odečte skutečný výdej z telemetrie/, 'Povinný test se na telemetrickém automatu nesmí odečíst ručně podruhé')
assert.match(html, /coffee-visit-detail coffee-guided coffee-only-flow/, 'Nový vzhled musí být omezený jen na kávový tok')
assert.doesNotMatch(html, /coffee-visit-detail coffee-guided coffee-only-flow[^\n]*data-food-action/, 'Potravinový tok nesmí dostat coffee-only vzhled')

console.log('OK: guided coffee v2 — approved visuals, stock decisions, gear, sticks, zero refill, cash and non-blocking quality issue')
