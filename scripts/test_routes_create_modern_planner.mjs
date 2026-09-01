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

console.log('OK: moderní plánovač zachovává lokality i automaty, filtruje rajóny a ztišuje výpadek jednoho produktu')
