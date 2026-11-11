import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const coffeeDomain = fs.readFileSync(new URL('../mobile-coffee-domain.js', import.meta.url), 'utf8')
const operatorPicklist = fs.readFileSync(new URL('../olvend-operator/index.html', import.meta.url), 'utf8')

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
  'renderCoffeeGuidedCalibration',
  'Povinné první načtení',
  'guided-check-outcome',
  'Bylo čisté / v pořádku',
  'Vyčištěno / opraveno',
  'Nelze dokončit',
  'data-coffee-problem-reason',
  'Na jejich schválení nečekáš',
  'submitCoffeeProblemService',
  'assets/cash-security-bag.png'
]) assert.ok(html.includes(required), `Chybí kávový prvek: ${required}`)

assert.match(html, /from '\.\/mobile-coffee-domain\.js\?v=20261111-operator-pick-v2'/, 'Kávová pravidla musí být oddělená od mobilního UI a změna picklistu musí obejít starou PWA cache')
assert.match(html, /async takePackages\(containerId, packages\)[\s\S]*?await handleCoffeeAction\('guided-pick-take'/, 'Volba množství a potvrzení picklistu se musí uložit atomicky')
assert.match(operatorPicklist, /liveCall\('takePackages',item\.id,item\.prepared\)/, 'Operátorský picklist nesmí mezi změnou množství a potvrzením překreslit položku')
assert.match(html, /pickTouched: Boolean\(draft\.packagesManuallyAdjusted \|\| draft\.pickDecision \|\| draft\.stockShortage\)/, 'Rozpracovaná položka musí po chybě zůstat dohledatelná')
assert.match(operatorPicklist, /item\.prepared>0\|\|item\.picked\|\|item\.accepted\|\|item\.pickTouched/, 'Rozpracovaná položka nesmí po obnovení picklistu zmizet')
assert.match(operatorPicklist, /pickIndex=editingPickFromReview\?items\.length:items\.findIndex/, 'Živé překreslení během opravy nesmí spustit picklist znovu po položkách')
assert.match(operatorPicklist, /pickIndex=returnToReview\?items\.length:nextUndecidedPick\(\)/, 'Po uložení opravy se aplikace musí vrátit na kontrolní souhrn')
assert.match(html, /async saveContainer\(containerId, actualBefore, packages, addOutsidePicklist\)[\s\S]*?await handleCoffeeAction\('accept-container'/, 'Uložení skutečného stavu a potvrzení zásobníku musí být atomické')
assert.match(operatorPicklist, /liveCall\('saveContainer',item\.id,before,packages/, 'Operátorské doplnění musí volat jedinou ukládací operaci')
assert.equal((operatorPicklist.match(/querySelector\('\[data-confirm\]'\)\.addEventListener\('click'/g) || []).length, 1, 'Jedno potvrzení doplnění smí obsluhovat jen jeden click handler')
assert.match(operatorPicklist, /let refillSaveInFlight=false/, 'Doplnění musí držet výslovný zámek jediné ukládací operace')
assert.match(operatorPicklist, /finally\{\s*refillSaveInFlight=false;\s*if\(button\.isConnected\)\{button\.removeAttribute\('aria-busy'\);button\.disabled=false/, 'Po každém výsledku se musí odemknout potvrzení dalšího zásobníku')
assert.match(coffeeDomain, /isCoffeeCupProduct[\s\S]*?label:\s*isStick\s*\?\s*'tyč'/, 'Kelímky se musí zobrazovat po tyčích')
assert.match(coffeeDomain, /isCoffeeCupProduct\(container\)\s*\?\s*50/, 'Výchozí tyč kelímků musí mít 50 ks')
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
