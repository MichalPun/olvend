import assert from 'node:assert/strict'
import {extractInvoiceFields,findUniqueInvoiceMatch,isLikelyInlineImage} from './finance-intake-core.mjs'

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
assert.equal(findUniqueInvoiceMatch(result,[{id:1,document_number:'2026036928',variable_symbol:'2026036928',total_amount:18456.70}]).id,1)
assert.equal(findUniqueInvoiceMatch(result,[{id:1,document_number:'2026036928',total_amount:1}]),null)
assert.equal(isLikelyInlineImage({file_name:'barbera_logo_small.png',size_bytes:405}),true)
assert.equal(isLikelyInlineImage({file_name:'scan-faktury.jpg',size_bytes:150000}),false)
console.log('Finance intake extraction tests passed')
