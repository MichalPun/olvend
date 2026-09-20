import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
for (const file of ['inventory.html', 'mobile.html']) {
  const html=fs.readFileSync(new URL('../'+file,import.meta.url),'utf8');
  const start=html.indexOf('    async function moveStockPreservingBatches(');
  const end=html.indexOf('    async function applyStockMovementsAtomically(',start);
  const context=vm.createContext({
    getBalanceRecords:async()=>[{batch_id:7,quantity_on_hand:5}],
    addBalanceToBatch:()=>{throw Error('No mutation before atomic save');},
    productsV13:[{id:1,name:'Test'}],state:{products:[{id:1,name:'Test'}],employee:{id:1}},
    normalizeFoodExpiryDate:()=>null,
  });
  vm.runInContext(html.slice(start,end),context);
  const args={productId:1,quantity:12,fromStockLocationId:1,toStockLocationId:2,movementType:'load_vehicle',referenceType:'mobile_stock_request',referenceId:'rollback-test',applyBalances:false};
  await assert.rejects(context.moveStockPreservingBatches({...args,allowNegative:false}),/dost kusů/);
  for(const selectedBatchId of [null,7]) {
    const rows=await context.moveStockPreservingBatches({...args,allowNegative:true,selectedBatchId});
    assert.equal(rows.reduce((n,r)=>n+r.quantity_base_units,0),12);
    assert.equal(rows[0].batch_id,7);
    assert.equal(rows[0].quantity_base_units,5);
    assert.equal(rows[1].batch_id,null,'Do not invent a dated batch for unrecorded stock');
    assert.equal(rows[1].quantity_base_units,7);
    assert.equal(rows[1].allow_negative_source,true);
  }
}
console.log('PASS: desktop/mobile preserve full quantity and known batches; only permitted deficits go negative');
