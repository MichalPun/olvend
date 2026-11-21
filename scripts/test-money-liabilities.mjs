import assert from 'node:assert/strict'
import {parseMoneyLiabilitiesXml} from '../money-liabilities-core.mjs'

const xml=`<MoneyData ExpDate="2026-11-21" HospRokOd="2026-01-01" HospRokDo="2026-12-31"><SeznamZavazku>
<Zavazek><Doklad>ZA26001</Doklad><DRada>ZArr</DRada><DCislo>1</DCislo><Popis>Vyúčtování mzdy</Popis><VarSym>012026</VarSym><DatVyst>2026-01-01</DatVyst><DatSpl>2026-01-15</DatSpl><Adresa><ObchNazev>Punčochář Michal</ObchNazev><GUID>{TEST-GUID}</GUID><Ucet>9644498001</Ucet><KodBanky>5500</KodBanky><SeznamBankSpojeni><BankSpojeni Doklad="1"><Ucet>999999</Ucet><KodBanky>0100</KodBanky></BankSpojeni></SeznamBankSpojeni></Adresa><Celkem>1000</Celkem><UhZbyva>1000</UhZbyva><PUZbyva>400</PUZbyva><PrKont>NEIMPORTOVAT</PrKont></Zavazek>
</SeznamZavazku></MoneyData>`
const result=parseMoneyLiabilitiesXml(xml)
assert.equal(result.summary.liabilities,1)
assert.equal(result.summary.ordered_amount,600)
assert.equal(result.rows[0].actual_remaining_amount,1000)
assert.equal(result.rows[0].orderable_remaining_amount,400)
assert.equal(result.rows[0].payee_name,'Punčochář Michal')
assert.equal(result.rows[0].bank_account,'9644498001')
assert.equal(result.rows[0].bank_code,'5500')
assert.equal(result.rows[0].variable_symbol,'012026')
assert.equal(result.rows[0].payee_guid,'{TEST-GUID}')
assert.equal(JSON.stringify(result).includes('NEIMPORTOVAT'),false)
console.log('Money liabilities parser tests passed')
