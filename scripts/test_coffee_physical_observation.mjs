import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const root = resolve(here, '..')
const mobile = readFileSync(resolve(root, 'mobile.html'), 'utf8')
const routeCompletion = readFileSync(resolve(root, 'mobile-route-completion.js'), 'utf8')
const coffeeVisit = readFileSync(resolve(root, 'mobile-coffee-visit.js'), 'utf8')
const migration = readFileSync(resolve(root, 'database/coffee_physical_observation_watermark_v53.sql'), 'utf8')
const routeStateMigration = readFileSync(resolve(root, 'database/route_visit_completion_consistency_v54.sql'), 'utf8')

const visitSave = mobile.slice(
  mobile.indexOf('async function saveCoffeeContainerVisitItem'),
  mobile.indexOf('async function saveCoffeeContainerCalibration')
)
const calibrationSave = mobile.slice(
  mobile.indexOf('async function saveCoffeeContainerCalibration'),
  mobile.indexOf('async function loadCoffeeNetMovedQuantity')
)

assert.match(visitSave, /await persistCoffeeVisitItem\(\{/)
assert.match(visitSave, /createUuid:\s*\(\)\s*=>\s*crypto\.randomUUID\(\)/)
assert.match(visitSave, /await saveCoffeePreparation\(stopId, 'machine'\)/)
assert.doesNotMatch(visitSave, /from\('machine_coffee_containers'\)\s*\.update/s)

assert.match(calibrationSave, /await persistCoffeeVisitItem\(\{/)
assert.match(calibrationSave, /createUuid:\s*\(\)\s*=>\s*crypto\.randomUUID\(\)/)
assert.doesNotMatch(calibrationSave, /from\('machine_coffee_containers'\)\s*\.update/s)

assert.match(coffeeVisit, /client_uuid:\s*existing\.client_uuid/)
assert.match(coffeeVisit, /onConflict:\s*'client_uuid'/)
assert.match(coffeeVisit, /existing\?\.client_uuid\s*&&\s*\(existing\._offlinePending/)
assert.match(coffeeVisit, /getPendingRequestCount\(\)\s*>\s*pendingBeforeSave/)
assert.doesNotMatch(coffeeVisit, /offlineRow\s*=\s*\{\s*\.\.\.row,\s*id:\s*createUuid\(\)/)

assert.match(mobile, /čeká na synchronizaci se serverem/)
assert.doesNotMatch(mobile, /route_machine_visit_items'\)\.upsert\(\[\{[^\n]*[,\s]id:\s*crypto\.randomUUID\(\)/)
assert.doesNotMatch(mobile, /route_machine_cash_reports'\)\.upsert\(\[\{[^\n]*[,\s]id:\s*crypto\.randomUUID\(\)/)
assert.match(mobile, /route_machine_cash_reports'\)\.upsert\(\[offlineCash\], \{ onConflict: 'visit_id' \}\)/)

const completeStop = mobile.slice(
  mobile.indexOf('async function completeRouteStop'),
  mobile.indexOf('async function prepareOpenedStopForSkip')
)
assert.doesNotMatch(completeStop, /from\('route_plan_stops'\)/)
assert.match(completeStop, /completeRouteVisitRecord/)
assert.match(routeCompletion, /from\('route_machine_visits'\)/)
assert.match(routeCompletion, /Server nepotvrdil dokončení návštěvy/)
assert.match(mobile, /from '\.\/mobile-coffee-visit\.js\?v=20261021-coffee-visit-v1'/)

assert.match(migration, /physical_counted_at timestamptz/)
assert.match(migration, /trg_route_visit_item_coffee_observation/)
assert.match(migration, /sale\.source_event_at\s*>\s*coalesce\(container\.physical_counted_at/)
assert.match(migration, /sale\.source_event_at\s*>\s*v_observed_at/)

assert.match(routeStateMigration, /trg_route_stop_sync_machine_visit_state/)
assert.match(routeStateMigration, /trg_machine_visit_sync_route_stop_state/)
assert.match(routeStateMigration, /visit\.status is distinct from 'completed'/)
assert.match(routeStateMigration, /stop\.status is distinct from 'done'/)

function reconcilePhysicalObservation(finalQuantity, observedAt, recordedDepletions) {
  const usedAfterObservation = recordedDepletions
    .filter((entry) => entry.sourceEventAt > observedAt)
    .reduce((sum, entry) => sum + entry.quantity, 0)
  return Math.max(0, finalQuantity - usedAfterObservation)
}

function applyTelemetry(currentQuantity, physicalCountedAt, event) {
  if (physicalCountedAt && event.sourceEventAt <= physicalCountedAt) return currentQuantity
  return Math.max(0, currentQuantity - event.quantity)
}

const observedAt = Date.parse('2026-10-15T12:00:00Z')
const delayedOldSale = { sourceEventAt: Date.parse('2026-10-15T11:50:00Z'), quantity: 18 }
const saleAfterVisit = { sourceEventAt: Date.parse('2026-10-15T12:10:00Z'), quantity: 21 }

assert.equal(applyTelemetry(1500, observedAt, delayedOldSale), 1500)
assert.equal(applyTelemetry(1500, observedAt, saleAfterVisit), 1479)
assert.equal(reconcilePhysicalObservation(1500, observedAt, [delayedOldSale, saleAfterVisit]), 1479)

console.log('coffee physical observation checks passed')
