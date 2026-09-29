import assert from 'node:assert/strict'
import {jipQuantity, mergeJipProfiles} from '../jip-demand.js'
assert.equal(jipQuantity(null),null)
assert.equal(jipQuantity({recommended_order_qty:null}),null)
assert.equal(jipQuantity({recommended_order_qty:0}),0)
assert.equal(jipQuantity({recommended_order_qty:'288'}),288)
assert.equal(jipQuantity({recommended_order_qty:-1}),null)
assert.equal(jipQuantity({recommended_order_qty:12,calculation_error:'unknown unit'}),null)
const existing=[{id:7,supplier_id:3,product_id:10,pilot_scope:'general',active:true},{id:8,supplier_id:3,product_id:52,pilot_scope:'general',active:false}]
const rows=[{supplier_id:3,product_id:10,package_quantity:48},{supplier_id:3,product_id:113,name:'Pepsi',package_quantity:24}]
const merged=mergeJipProfiles(existing,rows)
assert.equal(merged.length,3)
assert.equal(merged[1].active,false)
assert.equal(merged[2].product_name,'Pepsi')
assert.equal(merged[2].package_quantity,24)
assert.equal(merged[2].auto_from_mapping,true)
assert.deepEqual(mergeJipProfiles(merged,rows),merged)
assert.equal(existing.length,2)
console.log('PASS: missing JIP profiles included once; disabled profiles preserved; unknown quantity fails closed; zero stays zero')
const {receiptShortfalls}=await import('../jip-demand.js')
assert.deepEqual(receiptShortfalls({status:'received',items:[{product_name:'Pepsi',ordered_quantity:96,received_quantity:72}]}),[{name:'Pepsi',quantity:24}])
assert.deepEqual(receiptShortfalls({status:'ordered',items:[{ordered_quantity:96,received_quantity:0}]}),[])
assert.deepEqual(receiptShortfalls({status:'received',items:[{ordered_quantity:24,received_quantity:24}]}),[])
console.log('PASS: partial received delivery shows actual shortfall, pending delivery is not mislabelled')
