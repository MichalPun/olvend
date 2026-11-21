import assert from 'node:assert/strict'
import {classifyDocument,extractInvoiceFields,extractInvoiceLineItems,findUniqueInvoiceMatch,isLikelyInlineImage} from './finance-intake-core.mjs'

const text=`FAKTURA vydaná číslo 2026036928
Dodavatel: SIMANDL s.r.o.
Datum vystavení: 12.11.2026
DUZP: 12.11.2026
Datum splatnosti: 26.11.2026
Variabilní symbol: 2026036928
Bankovní účet: 123456789/5500
Celkem k úhradě 18 456,70 Kč`
const result=extractInvoiceFields(text)
assert.equal(result.document_number,'2026036928')
assert.equal(result.issue_date,'2026-11-12')
assert.equal(result.taxable_date,'2026-11-12')
assert.equal(result.due_date,'2026-11-26')
assert.equal(result.variable_symbol,'2026036928')
assert.equal(result.bank_account,'123456789/5500')
assert.equal(result.total_amount,18456.70)
assert.equal(result.currency,'CZK')
assert.equal(result.document_class,'invoice')
assert.equal(findUniqueInvoiceMatch(result,[{id:1,document_number:'2026036928',variable_symbol:'2026036928',total_amount:18456.70}]).id,1)
assert.equal(findUniqueInvoiceMatch(result,[{id:1,document_number:'2026036928',total_amount:1}]),null)
assert.equal(isLikelyInlineImage({file_name:'barbera_logo_small.png',size_bytes:405}),true)
assert.equal(isLikelyInlineImage({file_name:'scan-faktury.jpg',size_bytes:150000}),false)
const reminder=extractInvoiceFields('1. upomínka k faktuře č. 2026036928. Variabilní symbol 2026036928, dlužná částka 18 456,70 Kč',{file_name:'UPOMINKA-2026036928.pdf'})
assert.equal(reminder.document_class,'reminder')
assert.equal(reminder.document_type,'other')
assert.equal(findUniqueInvoiceMatch(reminder,[{id:1,document_number:'2026036928',total_amount:18456.70}]).id,1)
assert.equal(classifyDocument('Rozvaha po zdanění za rok 2025'),'accounting_report')
const lines=extractInvoiceLineItems([{tables:[[
  ['Kód','Popis položky','Množství','MJ','Jednotková cena','Celkem'],
  ['K01','Káva zrnková 1 kg','12','ks','245,00','2 940,00'],
  ['C02','Kelímek 250 ml EAN 8591234567890','5','bal','480,00','2 400,00']
]]}])
assert.equal(lines.length,2)
assert.equal(lines[0].quantity,12)
assert.equal(lines[0].supplier_item_code,'K01')
assert.equal(lines[1].ean,'8591234567890')
console.log('Finance intake extraction tests passed')
