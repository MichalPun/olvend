import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { normalizeVehicles, odometerKm, batteryVolts } = require("../browser-extension/olvend-motion-connector/normalize.js");

assert.equal(odometerKm({ Unit: "Meters", Value: 12500 }), 12.5);
assert.equal(odometerKm({ Unit: "Miles", Value: 10 }), 16.09344);
assert.equal(batteryVolts({ Unit: "MilliVolts", Value: 12600 }), 12.6);

const rows = normalizeVehicles({ Data: [{
  Id: "vehicle-1",
  Name: "Renault Kangoo",
  MojioId: "device-1",
  Location: { Lat: 49.1, Lng: 16.6, Address: { FormattedAddress: "Brno" }, Timestamp: "2026-11-11T18:00:00Z" },
  ParkedState: { Value: false },
  Odometer: { BaseUnit: "Meters", BaseValue: 100500 },
  Battery: { Unit: "MilliVolts", Value: 12400 },
  DiagnosticCodes: [{ Code: "P0001", Description: "Test", Severity: "Low" }],
}] }, { Data: [{ Id: "device-1", ConnectedState: { Value: true } }] });

assert.equal(rows.length, 1);
assert.deepEqual(rows[0], {
  mojio_vehicle_id: "vehicle-1",
  vehicle_name: "Renault Kangoo",
  is_online: true,
  is_parked: false,
  latitude: 49.1,
  longitude: 16.6,
  address: "Brno",
  heading_degrees: null,
  odometer_km: 100.5,
  fuel_value: null,
  fuel_unit: null,
  battery_volts: 12.4,
  issue_count: 1,
  diagnostic_codes: [{ code: "P0001", description: "Test", severity: "Low" }],
  source_updated_at: "2026-11-11T18:00:00.000Z",
});

console.log("Mojio normalization tests passed.");
