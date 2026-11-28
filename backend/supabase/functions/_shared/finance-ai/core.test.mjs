import test from 'node:test'
import assert from 'node:assert/strict'
import { applyRules, matchProduct, normalizeExtraction, stateForPlan, validateExtraction } from './core.mjs'

test('normalizes and validates a balanced invoice', () => {
  const doc = normalizeExtraction({
    supplier_name:'Dodavatel',document_number:'FV-1',issue_date:'2026-11-28',due_date:'2026-12-12',
    net_amount:'100,00',vat_amount:21,total_amount:121,category_key:'software',confidence:98,
    lines:[{description:'Licence',quantity:1,net_amount:100,vat_amount:21,total_amount:121,confidence:99}]
  })
  assert.equal(doc.total_amount,121)
  assert.deepEqual(validateExtraction(doc).errors,[])
})

test('detects header total mismatch', () => {
  const doc = normalizeExtraction({supplier_name:'X',document_number:'1',net_amount:100,vat_amount:21,total_amount:150})
  assert.match(validateExtraction(doc).errors.join(' '),/Nesedí součet/)
})

test('applies a verified supplier rule', () => {
  const doc = applyRules(normalizeExtraction({supplier_name:'DKV Mobility',document_number:'1',net_amount:100,vat_amount:21,total_amount:121}), [
    {id:7,active:true,priority:1,matcher:{supplier_name_contains:'DKV'},outcome:{category_key:'fuel',target_kind:'vehicle'}}
  ])
  assert.equal(doc.category_key,'fuel')
  assert.deepEqual(doc.applied_rule_ids,[7])
})

test('matches a supplier item mapping deterministically', () => {
  const result = matchProduct({supplier_item_code:'ABC',description:'Káva'},[{id:1,supplier_id:3,product_id:8,supplier_item_code:'ABC'}],[{id:8,name:'Káva'}],3)
  assert.equal(result.product.id,8)
  assert.equal(result.confidence,100)
})

test('prioritizes questions and physical receipt in state', () => {
  assert.equal(stateForPlan({openQuestions:1,actions:[]}), 'waiting_answer')
  assert.equal(stateForPlan({openQuestions:0,actions:[{action_type:'stock_receipt',status:'waiting_delivery'}]}), 'waiting_delivery')
  assert.equal(stateForPlan({openQuestions:0,actions:[]}), 'accountant_ready')
})
