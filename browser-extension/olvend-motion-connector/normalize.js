(function exposeNormalizer(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.OlvendMojioNormalize = api;
})(typeof self !== "undefined" ? self : globalThis, function createNormalizer() {
  function finite(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  function vehicleName(vehicle) {
    const details = vehicle?.VinDetails || {};
    return String(vehicle?.Name || [details.Make, details.Model].filter(Boolean).join(" ") || "Vozidlo").trim();
  }

  function odometerKm(odometer) {
    if (!odometer) return null;
    const unit = odometer.BaseUnit || odometer.Unit;
    const value = finite(odometer.BaseUnit ? odometer.BaseValue : odometer.Value);
    if (value == null) return null;
    if (unit === "Meters") return value / 1000;
    if (unit === "Miles") return value * 1.609344;
    if (unit === "Kilometers" || unit === "Kilometres") return value;
    return value;
  }

  function batteryVolts(battery) {
    if (!battery) return null;
    const value = finite(battery.Value);
    if (value == null) return null;
    return battery.Unit === "MilliVolts" ? value / 1000 : value;
  }

  function validTimestamp(value) {
    if (!value) return null;
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
  }

  function normalizeVehicle(vehicle, deviceMap) {
    const location = vehicle?.Location || {};
    const device = deviceMap?.get(String(vehicle?.MojioId || ""));
    const diagnosticCodes = Array.isArray(vehicle?.DiagnosticCodes)
      ? vehicle.DiagnosticCodes.slice(0, 20).map((item) => ({
        code: item?.Code || null,
        description: item?.Description || null,
        severity: item?.Severity || null,
      })).filter((item) => item.code)
      : [];
    const latitude = finite(location.Lat);
    const longitude = finite(location.Lng);
    const sourceUpdatedAt = validTimestamp(
      location.Timestamp || location.UpdatedOn || vehicle?.ParkedState?.Timestamp ||
      vehicle?.Heading?.Timestamp || vehicle?.UpdatedOn || vehicle?.CreatedOn,
    );
    return {
      mojio_vehicle_id: String(vehicle?.Id || "").trim(),
      vehicle_name: vehicleName(vehicle),
      is_online: device ? device.connected === true : Boolean(vehicle?.MojioId),
      is_parked: vehicle?.ParkedState?.Value !== false,
      latitude,
      longitude,
      address: location?.Address?.FormattedAddress || null,
      heading_degrees: finite(vehicle?.Heading?.Value),
      odometer_km: odometerKm(vehicle?.Odometer),
      fuel_value: finite(vehicle?.FuelLevel?.Value),
      fuel_unit: vehicle?.FuelLevel?.Unit || null,
      battery_volts: batteryVolts(vehicle?.Battery),
      issue_count: diagnosticCodes.length + (vehicle?.Battery?.RiskSeverity === "High" ? 1 : 0) + (vehicle?.FuelLevel?.RiskSeverity === "High" ? 1 : 0),
      diagnostic_codes: diagnosticCodes,
      source_updated_at: sourceUpdatedAt,
    };
  }

  function normalizeVehicles(vehiclesResponse, mojiosResponse) {
    const vehicles = Array.isArray(vehiclesResponse) ? vehiclesResponse : vehiclesResponse?.Data || [];
    const mojios = Array.isArray(mojiosResponse) ? mojiosResponse : mojiosResponse?.Data || [];
    const deviceMap = new Map(mojios.map((device) => [String(device?.Id || ""), {
      connected: device?.ConnectedState?.Value === true,
    }]));
    return vehicles.map((vehicle) => normalizeVehicle(vehicle, deviceMap))
      .filter((vehicle) => vehicle.mojio_vehicle_id && vehicle.latitude != null && vehicle.longitude != null);
  }

  return { normalizeVehicle, normalizeVehicles, odometerKm, batteryVolts };
});
