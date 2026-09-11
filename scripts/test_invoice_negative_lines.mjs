import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html = fs.readFileSync(new URL('../issued-invoices.html', import.meta.url), 'utf8');
function fn(name) {
  const start = html.search(new RegExp(`    (?:async )?function ${name}\\(`));
  assert.ok(start >= 0, name);
  const end = html.slice(start + 1).search(/\n    (?:async )?function /);
  return html.slice(start, start + 1 + end);
}
for (const field of ['price', 'cost']) {
  const input = html.match(new RegExp(`<input data-line-unit-${field}[^>]+>`))[0];
  assert.ok(!input.includes('min="0"'), field);
}
const context = vm.createContext({
  invoiceVatMode: { value: 'domestic' }, roundingMode: { value: 'none' },
  roundMoney: n => Math.round((n + Number.EPSILON) * 100) / 100,
  productById: () => null, productLabel: () => '', normalizeText: s => s.toLowerCase(),
  productUnit: () => 'ks', productUnitCost: () => 0,
});
for (const name of ['currentVatMode', 'isNoVatMode', 'effectiveVatRate', 'taxVatRate', 'lineKind', 'vatBreakdown', 'roundingForTotal', 'documentTotals', 'mergeInvoiceLines', 'stockLinesForSalesLines']) vm.runInContext(fn(name), context);
const original = [-85625, 171250, 10000, 5000].map((unitPrice, i) => ({ lineType: 'non_stock', productName: i < 2 ? 'FLESSY' : `Item ${i}`, quantity: 1, unitPrice, unitCost: [-71325, 142650, 3000, 2800][i], vatRate: 21 }));
const lines = context.mergeInvoiceLines(original);
assert.equal(lines.length, 4);
assert.equal(lines[0].net, -85625);
assert.equal(lines[0].gross, -103606.25);
assert.equal(lines[0].unitCost, -71325);
const totals = context.documentTotals(lines);
assert.equal(totals.net, 100625);
assert.equal(totals.total, 121756.25);
assert.equal(totals.vatRows[0].vat, 21131.25);
assert.equal(context.stockLinesForSalesLines(lines).length, 0);
// Exercise the real save validation up to the first persistence operation.
Object.assign(context, {
  getModalLines: () => original, customerName: { value: 'Test' }, documentStatus: { value: 'issued' },
  documentType: { value: 'invoice' }, invoiceCurrency: { value: 'CZK' }, issuedDate: { value: '2026-09-11' },
  currentDocumentId: null, isStockImpactStatus: () => true, isStockImpactDocumentType: () => true,
  nextDocumentSeriesNumber: async () => { throw Error('VALIDATION_PASSED'); },
});
vm.runInContext(fn('saveDocument'), context);
await assert.rejects(context.saveDocument(), /VALIDATION_PASSED/);
assert.equal(context.documentTotals(context.mergeInvoiceLines(original, 'export'), 'export').total, 100625);
console.log('PASS: negative invoice line, cost, VAT, totals, non-stock isolation and save validation');
