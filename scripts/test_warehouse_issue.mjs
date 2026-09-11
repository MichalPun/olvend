import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../inventory.html', import.meta.url), 'utf8');
const extract = (name, next) => source.slice(source.indexOf(`    async function ${name}(`), source.indexOf(`    async function ${next}(`));
const code = extract('saveSimpleTransfer', 'saveInitialStock') + extract('moveStockPreservingBatches', 'applyStockMovementsAtomically');
async function run(direction, { fail = false, insufficient = false } = {}) {
  let saved, restores = 0;
  const values = { simpleTransferDirection: direction, simpleTransferWarehouseId: '1', simpleTransferVehicleId: direction === 'warehouse_issue' ? '' : '2', simpleTransferNote: '', simpleTransferDate: '2026-09-11' };
  const context = vm.createContext({
    document: { getElementById: id => ({ value: values[id] }) },
    collectSimpleTransferLines: () => [106, 110].map((productId, index) => ({ productId, index, quantity: 30 })),
    getSimpleTransferShortages: () => [], productsV13: [], warehouses: [], vehicles: [], editingTransferDoc: null,
    ensureStockLocation: async type => type === 'warehouse' ? 1 : 2,
    ensureAggregateMachinesStockLocation: async () => 5,
    getBalanceRecords: async () => [{ batch_id: 7, quantity_on_hand: 10 }, { batch_id: null, quantity_on_hand: insufficient ? 0 : 100 }],
    addBalanceToBatch: () => { throw Error('Must not mutate balances before atomic save'); },
    snapshotStockLocationBalances: () => { throw Error('Ordinary transfer must not snapshot unrelated balances'); },
    restoreStockLocationSnapshot: () => { restores++; },
    applyStockMovementsAtomically: async rows => { if (fail) throw Error('RPC rejected'); saved = rows; },
    getStockUnitCost: () => 0, getRecipeForProduct: () => null,
  });
  vm.runInContext(code, context);
  if (fail || insufficient) {
    await assert.rejects(context.saveSimpleTransfer(), fail ? /RPC rejected/ : /dost kusů/);
    assert.equal(saved, undefined);
    assert.equal(restores, 0);
    return;
  }
  await context.saveSimpleTransfer();
  assert.equal(saved.length, 4);
  assert.equal(saved.reduce((n, r) => n + r.quantity_base_units, 0), 60);
  return saved;
}
for (const [direction, from, to] of [['warehouse_issue', 1, null], ['warehouse_to_vehicle', 1, 2], ['vehicle_to_warehouse', 2, 1], ['vehicle_to_machines', 2, 5], ['vehicle_sale', 2, null], ['machines_sale', 5, null]]) {
  const rows = await run(direction);
  for (const row of rows) {
    assert.equal(row.from_stock_location_id, from, direction);
    assert.equal(row.to_stock_location_id, to, direction);
    if (direction === 'warehouse_issue') {
      assert.equal(row.movement_type, 'waste');
      assert.equal(row.reference_type, 'manual_issue');
    }
  }
}
await run('warehouse_issue', { fail: true });
await run('warehouse_issue', { insufficient: true });
console.log('PASS: six transfer directions, batch allocation, insufficient stock and atomic rejection');
