import assert from 'node:assert/strict'
import fs from 'node:fs'
import { hasAcceptedCoffeeContainerState } from '../mobile-route-completion.js'
import { createCoffeeDomain } from '../mobile-coffee-domain.js'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')

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

const domain = createCoffeeDomain({
  getDetail: () => detail,
  getProducts: () => [],
  getProductPackages: () => [],
  normalizeText: (value) => String(value || '').toLowerCase(),
  convertQuantity: (value) => Number(value || 0),
  formatNumber: (value) => String(value)
})

const container = { id: 470, capacity_quantity: 0 }
assert.equal(domain.hasCoffeeContainerRefillWork('1851', container), true, 'Přesunutá balení musí zůstat součástí doplnění i po korekci na plný stav')
assert.equal(domain.isCoffeeContainerPendingConfirmation('1851', container), true, 'Plný ručně zadaný stav nesmí obejít potvrzení zásobníku')

detail.draft.containers[470].accepted = true
assert.equal(domain.isCoffeeContainerPendingConfirmation('1851', container), false, 'Po potvrzení se zásobník smí uzavřít')

detail.visitItems = []
assert.equal(hasAcceptedCoffeeContainerState(detail, container), false, 'Pouhé lokální potvrzení bez uloženého stavu nesmí stačit databázi')
detail.visitItems = [{
  item_kind: 'coffee_container',
  coffee_container_id: 470,
  accepted_at: '2026-10-21T12:00:00Z',
  final_quantity: 2000,
  actual_add_quantity: 0,
  issue_type: 'none'
}]
assert.equal(hasAcceptedCoffeeContainerState(detail, container), true, 'Uložený konečný stav se nesmí zapisovat podruhé')

assert.match(html, /if \(isCoffeeVisit && !detail\) throw new Error/, 'Dokončení musí odmítnout chybějící detail kávové návštěvy')
assert.match(html, /await saveCoffeePreparation\(stop\.id, 'machine'\)/, 'Před dokončením se musí uložit aktuální příprava')
assert.match(html, /await persistUnchangedCoffeeContainerStates\(\{/, 'Dokončení musí hromadně uložit fyzicky zkontrolované zásobníky beze změny')
assert.doesNotMatch(html, /const \[visitResult, stopResult\] = await Promise\.all/, 'Návštěva a zastávka se nesmí uzavírat souběžně')

console.log('OK: coffee container correction remains pending until it is saved and confirmed')
