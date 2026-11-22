import assert from 'node:assert/strict'
import {assessAutoEvidence,classifyDocument,extractInvoiceFields,extractInvoiceLineItems,extractInvoiceTextLineItems,findUniqueInvoiceMatch,isLikelyInlineImage,looksLikeItemizedInvoice} from './finance-intake-core.mjs'
import {createFinanceOcrSession,needsInvoiceOcr} from './finance-intake-ocr.mjs'

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
assert.equal(result.supplier_name,'SIMANDL s.r.o.')
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

const moneyTextRows=`Označení dodávky Katalog Počet M.J. M.J. Cena za M.J. DPH % bez DPH s DPH
200,00 DARKOFF VEN White choco vending 1 Kg 980 ks 12 72,000 16 128,00 14 400,00
200,00 DARKOFF VEN Choco drink 15 1 Kg 983 ks 12 72,000 16 128,00 14 400,00
200,00 DARKOFF VEN. Čaj LEMON 1 Kg 652/A ks 12 45,000 10 080,00 9 000,00`
const moneyLines=extractInvoiceTextLineItems(moneyTextRows)
assert.equal(looksLikeItemizedInvoice(moneyTextRows),true)
assert.equal(moneyLines.length,3)
assert.deepEqual(moneyLines.map(line=>[line.supplier_item_code,line.quantity,line.unit_price,line.net_amount,line.vat_amount,line.total_amount]),[
  ['980',72,200,14400,1728,16128],['983',72,200,14400,1728,16128],['652/A',45,200,9000,1080,10080]
])
assert.equal(moneyLines.reduce((sum,line)=>sum+line.net_amount,0),37800)
assert.equal(moneyLines.reduce((sum,line)=>sum+line.vat_amount,0),4536)
assert.equal(moneyLines.reduce((sum,line)=>sum+line.total_amount,0),42336)

const detailed=extractInvoiceFields(`Dodavatel:\nACME servis s.r.o.\nIČO: 12345678\nDIČ: CZ12345678\nOdběratel: OLMIKA s.r.o.\nIČO: 04579968\nDIČ: CZ04579968\nFaktura číslo FV-2026-991\nDatum splatnosti: 30.11.2026\nCelkem bez DPH 10 000,00 Kč\nDPH celkem 2 100,00 Kč\nCelkem k úhradě 12 100,00 Kč`)
assert.equal(detailed.supplier_name,'ACME servis s.r.o.')
assert.equal(detailed.supplier_company_id,'12345678')
assert.equal(detailed.supplier_tax_id,'CZ12345678')
assert.equal(detailed.document_number,'FV-2026-991')
assert.equal(detailed.net_amount,10000)
assert.equal(detailed.vat_amount,2100)
assert.equal(detailed.total_amount,12100)
assert.equal(extractInvoiceFields('FAKTURA Dodavatel\nDIČ CZ04579968').document_number,null)

const reorderedTaxTable=extractInvoiceFields(`FAKTURA - daňový doklad č. 1102603981
Seyfor, a. s.
IČ:\nFax:\nTel.:\n01572377\nCZ01572377\n+420 549 522 511\nDIČ :\n6253399002/5500
Odběratel: OLMIKA s.r.o.\nIČ: 04579968 DIČ: CZ04579968
Rozpis DPH uveden v měně CZK
0,00 523,95 - 523,95 CELKEM
3 018,95 523,95 2 495,00 základní 21 %
Celková částka 3 019,00 Kč
Zaokrouhlení 0,05 Kč`)
assert.equal(reorderedTaxTable.supplier_company_id,'01572377')
assert.equal(reorderedTaxTable.supplier_tax_id,'CZ01572377')
assert.equal(reorderedTaxTable.net_amount,2495)
assert.equal(reorderedTaxTable.vat_amount,523.95)
assert.equal(reorderedTaxTable.total_amount,3018.95)

const moneySummary=extractInvoiceFields(`SIMANDL, spol. s r.o.\nIČ:\nDIČ:\n63319969\nCZ63319969
Odběratel: OLMIKA s.r.o.\nIČ: 04579968\nDIČ: CZ04579968
Faktura číslo: 26002070
Bankovní účet: CEKO\n104458251 0300
37 800,00\n4 536,00\n42 336,00
0,00\n0,00\n0,00\n0,00\n0,00\n0,00\n0,00\n0,00
Celkem:\nZáklad Výše DPH Včetně DPH`)
assert.equal(moneySummary.supplier_company_id,'63319969')
assert.equal(moneySummary.supplier_tax_id,'CZ63319969')
assert.equal(moneySummary.bank_account,'104458251/0300')
assert.equal(moneySummary.net_amount,37800)
assert.equal(moneySummary.vat_amount,4536)
assert.equal(moneySummary.total_amount,42336)

const roundedTaxSummary=extractInvoiceFields(`DEKOS R, s.r.o.\nIČ: 25097733\nDIČ: CZ25097733
Odběratel: OLMIKA s.r.o.\nDIČ: CZ04579968
DAŇOVÝ DOKLAD - faktura č.\nOLMIKA s.r.o.
DPH 21 %\n12 457,50\n15 074,00\n2 616,08\nZáklad DPH D P H : Sazba`,{file_name:'2026036928.pdf'})
assert.equal(roundedTaxSummary.supplier_company_id,'25097733')
assert.equal(roundedTaxSummary.supplier_tax_id,'CZ25097733')
assert.equal(roundedTaxSummary.document_number,'2026036928')
assert.equal(roundedTaxSummary.net_amount,12457.5)
assert.equal(roundedTaxSummary.vat_amount,2616.08)
assert.equal(roundedTaxSummary.total_amount,15074)

const labeledTaxSummary=extractInvoiceFields(`Dodavatel:\nNEJLEVNĚJŠÍ POLEPY s.r.o.\nIČ: 08336563 DIČ: CZ08336563
Odběratel: OLMIKA s.r.o.\nIČ: 04579968 DIČ: CZ04579968
Sazba DPH Základ Výše DPH Celkem
21 % 9 240,00 Kč 1 940,40 Kč 11 180,40 Kč
CELKEM 9 240,00 Kč 1 940,40 Kč 11 180,40 Kč
Množství 1,00`,{file_name:'Vydana-faktura---20260657.pdf'})
assert.equal(labeledTaxSummary.document_number,'20260657')
assert.equal(labeledTaxSummary.net_amount,9240)
assert.equal(labeledTaxSummary.vat_amount,1940.4)
assert.equal(labeledTaxSummary.total_amount,11180.4)

const datedInvoice=extractInvoiceFields(`Faktura číslo 20260657
Dodavatel: NEJLEVNĚJŠÍ POLEPY s.r.o.
IČ: 08336563 DIČ: CZ08336563
Bankovní účet: 289322907/0300
variabilní: 20260657 vystavení: 23.09.2026
splatnosti: 26.09.2026
CELKEM 9 240,00 Kč 1 940,40 Kč 11 180,40 Kč`)
assert.equal(datedInvoice.issue_date,'2026-09-23')
assert.equal(datedInvoice.due_date,'2026-09-26')

const groupedDatesInvoice=extractInvoiceFields(`FAKTURA-DAŇOVÝ DOKLAD Faktura číslo: 26002070
SIMANDL, spol. s r.o. IČ: 63319969 DIČ: CZ63319969
Datum uskutečnění zdanitelného plnění:
Datum vystavení:
Datum splatnosti:
převodem
11.11.2026
11.12.2026
11.11.2026
Bankovní účet: 104458251 0300
Celkem: 37 800,00 4 536,00 42 336,00`)
assert.equal(groupedDatesInvoice.issue_date,'2026-11-11')
assert.equal(groupedDatesInvoice.taxable_date,'2026-11-11')
assert.equal(groupedDatesInvoice.due_date,'2026-12-11')

const eligibleAssessment=assessAutoEvidence({
  document_class:'invoice',confidence:98,supplier_name:'ACME s.r.o.',supplier_company_id:'12345678',supplier_tax_id:'CZ12345678',
  document_number:'FV-2026-991',issue_date:'2026-11-20',due_date:'2026-12-04',currency:'CZK',net_amount:10000,
  vat_amount:2100,total_amount:12100,bank_account:'123456789/5500',extraction_method:'pdf_text',warnings:[]
},[],{received_at:'2026-11-21T10:00:00Z'})
assert.equal(eligibleAssessment.eligible,true)
assert.equal(assessAutoEvidence({...datedInvoice,warnings:['Doklad obsahuje vyúčtování zálohy; úhradu je potřeba ověřit']},[],{received_at:'2026-09-24T10:00:00Z'}).eligible,false)
assert.equal(assessAutoEvidence({
  document_class:'invoice',confidence:98,supplier_name:'ACME s.r.o.',supplier_company_id:'12345678',document_number:'FV-2026-991',
  issue_date:'2026-11-20',due_date:'2026-12-04',currency:'CZK',net_amount:10000,vat_amount:2100,total_amount:12100,
  bank_account:'123456789/5500',extraction_method:'pdf_text',warnings:[]
},[{document_number:'FV-2026-991',total_amount:12100}],{received_at:'2026-11-21T10:00:00Z'}).eligible,false)

const numberFallback=extractInvoiceFields('DAŇOVÝ DOKLAD - faktura č.\nOLMIKA s.r.o.',{file_name:'2026036928.pdf'})
assert.equal(numberFallback.document_number,'2026036928')
assert.equal(needsInvoiceOcr('jen několik znaků'),true)
assert.equal(needsInvoiceOcr('Faktura '.repeat(30)),false)
let terminated=false
const ocr=createFinanceOcrSession({createWorkerImpl:async languages=>{
  assert.deepEqual(languages,['ces','eng'])
  return {recognize:async()=>({data:{text:'OCR faktura 2026001',confidence:88}}),terminate:async()=>{terminated=true}}
}})
assert.deepEqual(await ocr.recognize(new Uint8Array([1,2,3])),{text:'OCR faktura 2026001',confidence:88})
await ocr.terminate()
assert.equal(terminated,true)
console.log('Finance intake extraction tests passed')
