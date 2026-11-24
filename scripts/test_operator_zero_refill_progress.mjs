import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const mobile = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const operator = fs.readFileSync(new URL('../olvend-operator/index.html', import.meta.url), 'utf8')

for (const match of operator.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (match[1].trim()) new vm.Script(match[1], { filename: 'olvend-operator/index.html' })
}

assert.match(
  mobile,
  /detail\.draft\.containers\[String\(container\.id\)\] = \{[\s\S]*?accepted: true,[\s\S]*?physicalChecked: true[\s\S]*?saveCoffeePreparation\(stopId, 'machine'\)/,
  'Potvrzený zásobník musí být uložený jako fyzicky zkontrolovaný.'
)
assert.match(
  mobile,
  /async saveContainer\(containerId, actualBefore, packages, addOutsidePicklist\)[\s\S]*?allPhysicallyChecked[\s\S]*?refillReviewed = true[\s\S]*?saveCoffeePreparation\(operatorRouteStopId, 'machine'\)/,
  'Poslední fyzická kontrola bez doplnění musí uzavřít refill krok.'
)
assert.match(
  mobile,
  /async completeZeroRefillReview\(\)[\s\S]*?guided-confirm-no-refill/,
  'Rozpracovaná návštěva z doby před opravou musí umět dokončit už provedenou fyzickou kontrolu.'
)
assert.match(
  operator,
  /prepared:container\.picked\?Number\(container\.packages\|\|0\)[\s\S]*?physicalChecked:Boolean\(container\.physicalChecked\)[\s\S]*?zeroRefillReview=snapshot\.stage==='refill'&&!mapped\.some\(item=>item\.prepared>0\)[\s\S]*?zeroRefillReview\?items\.findIndex\(item=>!item\.physicalChecked\)[\s\S]*?completeZeroRefillReview/,
  'OLVEND Operátor musí po potvrzení otevřít další fyzicky nezkontrolovaný zásobník.'
)

console.log('PASS: OLVEND Operátor advances after a zero-refill container confirmation')
