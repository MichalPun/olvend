import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')

const extract = name => {
  const start = html.indexOf(`    function ${name}(`)
  assert.ok(start >= 0, `Chybí funkce ${name}`)
  const end = html.indexOf('\n    function ', start + 1)
  return html.slice(start, end)
}

const detail = {
  manualCounterMode: false,
  draft: {
    containers: {
      470: {
        accepted: false,
        packages: 2,
        movedPackages: 2,
        actualBeforeQuantity: 2000
      }
    }
  }
}

const context = vm.createContext({
  getCoffeeDetail: () => detail,
  getCoffeeActualPackages: () => 0,
  Number,
  Boolean,
  String
})

for (const name of ['hasCoffeeContainerRefillWork', 'isCoffeeContainerPendingConfirmation']) {
  vm.runInContext(extract(name), context)
}

const container = { id: 470 }
assert.equal(context.hasCoffeeContainerRefillWork('1851', container), true, 'Přesunutá balení musí zůstat součástí doplnění i po korekci na plný stav')
assert.equal(context.isCoffeeContainerPendingConfirmation('1851', container), true, 'Plný ručně zadaný stav nesmí obejít potvrzení zásobníku')

detail.draft.containers[470].accepted = true
assert.equal(context.isCoffeeContainerPendingConfirmation('1851', container), false, 'Po potvrzení se zásobník smí uzavřít')

assert.match(html, /if \(isCoffeeVisit && !detail\) throw new Error/, 'Dokončení musí odmítnout chybějící detail kávové návštěvy')
assert.match(html, /await saveCoffeePreparation\(stop\.id, 'machine'\)/, 'Před dokončením se musí uložit aktuální příprava')
assert.doesNotMatch(html, /const \[visitResult, stopResult\] = await Promise\.all/, 'Návštěva a zastávka se nesmí uzavírat souběžně')

console.log('OK: coffee container correction remains pending until it is saved and confirmed')
