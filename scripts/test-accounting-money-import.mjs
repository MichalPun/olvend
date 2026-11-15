import assert from 'node:assert/strict'
import test from 'node:test'
import {
  parseMoneyS3AccountingXml,
  validateMoneyAccountingPayload,
} from '../accounting-money-import-core.mjs'

const sample = `<?xml version="1.0" encoding="UTF-8"?>
<MoneyData ICAgendy="12345678" KodAgendy="TEST" HospRokOd="2026-01-01" HospRokDo="2026-12-31" ExpDate="2026-11-15" ExpZkratka="_UCT">
  <SeznamUcOsnov>
    <UcOsnova><Ucet>321000</Ucet><Nazev>Dodavatelé</Nazev><DruhUctu>1</DruhUctu><UcetTyp>2</UcetTyp><UcetPodTyp>1</UcetPodTyp></UcOsnova>
    <UcOsnova><Ucet>501000</Ucet><Nazev>Spotřeba materiálu</Nazev><DruhUctu>2</DruhUctu><UcetTyp>3</UcetTyp><UcetPodTyp>3</UcetPodTyp></UcOsnova>
  </SeznamUcOsnov>
  <SeznamPredkontaci>
    <Predkontace><Zkrat>PF001</Zkrat><Typ>PF</Typ><Popis>Nákup materiálu</Popis><UcMD>501000</UcMD><UcD>321000</UcD></Predkontace>
  </SeznamPredkontaci>
  <SeznamFaktVyd>
    <FaktVyd><Doklad>FV260001</Doklad><Vystaveno>2026-11-01</Vystaveno><Popis>Doklad bez rozúčtování</Popis></FaktVyd>
  </SeznamFaktVyd>
  <SeznamFaktPrij>
    <FaktPrij>
      <Doklad>PF260101</Doklad><DatUcPr>2026-11-03</DatUcPr><PlnenoDPH>2026-11-02</PlnenoDPH><Popis>Káva &amp; suroviny</Popis><VarSymbol>260101</VarSymbol><PredKontac>PF001</PredKontac>
      <SeznamRozuctPolozek>
        <RozuctPolozka><Popis>Základ</Popis><UcMD>501000</UcMD><UcD>321000</UcD><Castka>1210,50</Castka><Stred>PROVOZ</Stred><SazbaDPH>21</SazbaDPH></RozuctPolozka>
      </SeznamRozuctPolozek>
    </FaktPrij>
  </SeznamFaktPrij>
</MoneyData>`

test('načte účetní osnovu a předkontace z nativního Money XML', () => {
  const parsed = parseMoneyS3AccountingXml(sample)
  assert.equal(parsed.agenda_id, '12345678')
  assert.equal(parsed.accounting_year_start, '2026-01-01')
  assert.equal(parsed.accounts.length, 2)
  assert.deepEqual(parsed.accounts[0], {
    code: '321000',
    name: 'Dodavatelé',
    kind: 'balance',
    account_type: 'liability',
    kind_code: '1',
    type_code: '2',
    subtype_code: '1',
    tracks_balance: true,
    affects_income_tax: false,
    internal: false,
    technical: false,
    correction: false,
    note: null,
  })
  assert.equal(parsed.preaccountings[0].code, 'PF001')
  assert.equal(parsed.preaccountings[0].debit_account_code, '501000')
})

test('převede rozúčtovací položku Money na vyrovnané řádky MD a Dal', () => {
  const parsed = parseMoneyS3AccountingXml(sample)
  assert.equal(parsed.entries.length, 1)
  assert.equal(parsed.entries[0].source_key, 'FaktPrij:PF260101')
  assert.equal(parsed.entries[0].entry_date, '2026-11-03')
  assert.equal(parsed.entries[0].lines.length, 2)
  assert.equal(parsed.entries[0].lines[0].account_code, '501000')
  assert.equal(parsed.entries[0].lines[0].debit, 1210.5)
  assert.equal(parsed.entries[0].lines[1].account_code, '321000')
  assert.equal(parsed.entries[0].lines[1].credit, 1210.5)
  assert.equal(parsed.summary.debit, parsed.summary.credit)
  assert.deepEqual(validateMoneyAccountingPayload(parsed), [])
})

test('odmítne soubor mimo nativní MoneyData', () => {
  assert.throws(() => parseMoneyS3AccountingXml('<root/>'), /MoneyData/)
})
