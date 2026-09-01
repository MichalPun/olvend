import fs from 'node:fs'
import assert from 'node:assert/strict'

const source = fs.readFileSync(new URL('../routes-create.html', import.meta.url), 'utf8')

assert.match(source, /id="planningModeSwitch"/)
assert.match(source, /data-planning-mode="location"/)
assert.match(source, /data-planning-mode="machine"/)
assert.match(source, /data-source-filter="all_active"[^>]*>Všechny</)
assert.match(source, /from\('operator_territory_assignments'\)/)
assert.match(source, /function candidateMatchesTerritoryView\(/)
assert.match(source, /state\.territoryView === 'secondary'/)
assert.match(source, /type: isSingleProductNotice \? 'stock_info' : 'stock'/)
assert.match(source, /quiet-stock-note/)
assert.match(source, /class="modern-candidate-card/)
assert.match(source, /class="modern-route-card/)
assert.match(source, /state\.filteredCandidates\.forEach\(\(candidate\) => state\.selectedKeys\.add\(candidate\.key\)\)/)
assert.match(source, /function isPlanningEligibleMachine\(machine\)/)
assert.match(source, /\['removed', 'deinstalled', 'inactive', 'retired', 'scrapped'\]\.includes\(status\)/)
assert.match(source, /\.filter\(\(location\) => \(machinesByLocation\.get\(String\(location\.id\)\) \|\| \[\]\)\.length > 0\)/)
assert.match(source, /function reconcileInventoryEvidence\(\)/)
assert.match(source, /state\.lastMachineVisits\.forEach\(\(_visit, machineId\) => inventoriedMachineIds\.add\(String\(machineId\)\)\)/)
assert.match(source, /reconcileInventoryEvidence\(\)\s+\n\s*applyPreferredWarehouseDefaults\(\)/)

console.log('OK: moderní plánovač drží rajóny, platné automaty a skutečné inventurní důkazy')
