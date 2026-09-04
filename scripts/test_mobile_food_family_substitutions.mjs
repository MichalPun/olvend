import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const mobile = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
for (const match of mobile.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim() || /^\s*import\s/m.test(match[1])) continue
  new vm.Script(match[1], { filename: 'mobile.html' })
}

assert.match(mobile, /function isFoodProductFamilyAlternative/)
assert.match(mobile, /getFoodProductFamily\(product\) === configuredFamily/)
assert.match(mobile, /isFoodProductFamilyAlternative\(option, planogramChange\.nextProduct\)/)
assert.match(mobile, /fullSwap && isFoodProductFamilyAlternative\(selectedProduct, planogramChange\.nextProduct\)/)
assert.match(mobile, /kompletní výměna vyžaduje produkt z rodiny/)

console.log('OK: mobile food family alternatives')
