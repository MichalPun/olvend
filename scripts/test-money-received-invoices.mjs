import assert from 'node:assert/strict'
import { parseMoneyReceivedInvoicesXml } from '../money-received-invoices-core.mjs'

const xml = `<?xml version="1.0" encoding="utf-8"?>
<MoneyData ICagendy="12345678" HospRokOd="2026-01-01" HospRokDo="2026-12-31" ExpDate="2026-11-21">
  <SeznamFaktPrij>
    <FaktPrij>
      <GUID>{11111111-1111-1111-1111-111111111111}</GUID>
      <Doklad>FP260001</Doklad><Rada>FP</Rada><CisRada>1</CisRada>
      <PrijatDokl>FV-2026-001</PrijatDokl><VarSymbol>2026001</VarSymbol>
      <Vystaveno>2026-01-02</Vystaveno><PlnenoDPH>2026-01-02</PlnenoDPH><Splatno>2026-01-16</Splatno>
      <Celkem>1210.00</Celkem><PriUhrZbyv>210.00</PriUhrZbyv>
      <SouhrnDPH><DPH22>210.00</DPH22></SouhrnDPH>
      <DodOdb><ObchNazev>Dodavatel &amp; syn</ObchNazev><ICO>87654321</ICO><DIC>CZ87654321</DIC><Ucet>123456789</Ucet><KodBanky>5500</KodBanky></DodOdb>
      <Predkontace>NEIMPORTOVAT</Predkontace><MD>501000</MD><D>321000</D>
    </FaktPrij>
  </SeznamFaktPrij>
</MoneyData>`

const result = parseMoneyReceivedInvoicesXml(xml)
assert.equal(result.summary.invoices, 1)
assert.equal(result.summary.unpaid, 1)
assert.equal(result.rows[0].money_guid, '11111111-1111-1111-1111-111111111111')
assert.equal(result.rows[0].supplier_name, 'Dodavatel & syn')
assert.equal(result.rows[0].net_amount, 1000)
assert.equal(result.rows[0].vat_amount, 210)
assert.equal(result.rows[0].remaining_amount, 210)
assert.equal('debit_account' in result.rows[0], false)
assert.equal(JSON.stringify(result).includes('501000'), false)
assert.equal(JSON.stringify(result).includes('321000'), false)

assert.throws(() => parseMoneyReceivedInvoicesXml('<root/>'), /Money S3/)
console.log('Money S3 received-invoice parser tests passed')
