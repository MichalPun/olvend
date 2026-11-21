import assert from 'node:assert/strict'
import {parseMoneyLiabilitiesXml} from '../money-liabilities-core.mjs'

const xml=`<MoneyData ExpDate="2026-11-21" HospRokOd="2026-01-01" HospRokDo="2026-12-31"><SeznamZavazku>
<Zavazek><Doklad>ZA26001</Doklad><DRada>ZArr</DRada><DCislo>1</DCislo><Popis>Daň</Popis><DatVyst>2026-01-01</DatVyst><DatSpl>2026-01-15</DatSpl><Celkem>1000</Celkem><UhZbyva>1000</UhZbyva><PUZbyva>400</PUZbyva><PrKont>NEIMPORTOVAT</PrKont></Zavazek>
</SeznamZavazku></MoneyData>`
const result=parseMoneyLiabilitiesXml(xml)
assert.equal(result.summary.liabilities,1)
assert.equal(result.summary.ordered_amount,600)
assert.equal(result.rows[0].actual_remaining_amount,1000)
assert.equal(result.rows[0].orderable_remaining_amount,400)
assert.equal(JSON.stringify(result).includes('NEIMPORTOVAT'),false)
console.log('Money liabilities parser tests passed')
