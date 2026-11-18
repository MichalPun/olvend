import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
});

const text = (value: unknown, maxLength = 500) => {
  const normalized = String(value ?? "").trim();
  return normalized ? normalized.slice(0, maxLength) : null;
};

const numberOrNull = (value: unknown, minimum: number, maximum: number) => {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < minimum || parsed > maximum) return null;
  return parsed;
};

const dateOrNull = (value: unknown) => {
  if (!value) return null;
  const parsed = new Date(String(value));
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
};

const normalizeVehicleKey = (value: unknown) => String(value ?? "")
  .normalize("NFD")
  .replace(/[\u0300-\u036f]/g, "")
  .toUpperCase()
  .replace(/[^A-Z0-9]/g, "");

type FleetRow = Record<string, unknown>;
type IngestedFleetRow = {
  mojio_vehicle_id: string;
  vehicle_name: string;
  is_online: boolean;
  is_parked: boolean;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  heading_degrees: number | null;
  odometer_km: number | null;
  fuel_value: number | null;
  fuel_unit: string | null;
  battery_volts: number | null;
  issue_count: number;
  diagnostic_codes: Array<{ code: string | null; description: string | null; severity: string | null }>;
  source_updated_at: string;
  ingested_at: string;
  updated_by: string;
  vehicle_id: number | null;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) return json({ error: "Chybí serverová konfigurace." }, 500);

  const authHeader = req.headers.get("Authorization") || "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "Chybí přihlášení do OLVENDU." }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json({ error: "Přihlášení do OLVENDU není platné." }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: employee, error: employeeError } = await admin
    .from("employees")
    .select("id, role, active")
    .eq("auth_user_id", user.id)
    .maybeSingle();
  if (employeeError || !employee || employee.active === false) return json({ error: "Aktivní účet zaměstnance nebyl nalezen." }, 403);
  if (!["admin", "manager", "vedoucí", "vedouci"].includes(String(employee.role || "").toLowerCase())) {
    return json({ error: "Živá poloha vozidel je dostupná pouze vedení." }, 403);
  }

  const body = await req.json().catch(() => ({})) as { rows?: FleetRow[] };
  if (!Array.isArray(body.rows) || body.rows.length === 0) return json({ error: "Chybí data vozidel." }, 400);
  if (body.rows.length > 25) return json({ error: "Příliš mnoho vozidel v jednom přenosu." }, 413);

  const { data: vehicles, error: vehiclesError } = await admin
    .from("vehicles")
    .select("id, name, plate, mojio_vehicle_id")
    .eq("active", true);
  if (vehiclesError) return json({ error: vehiclesError.message }, 500);

  const resolveVehicleId = (row: FleetRow) => {
    const mojioId = text(row.mojio_vehicle_id, 120);
    const sourceKey = normalizeVehicleKey(row.vehicle_name);
    const exact = (vehicles || []).find((vehicle) => String(vehicle.mojio_vehicle_id || "") === String(mojioId || ""));
    if (exact) return exact.id;
    const byPlate = (vehicles || []).find((vehicle) => {
      const plate = normalizeVehicleKey(vehicle.plate);
      return plate && sourceKey.includes(plate);
    });
    if (byPlate) return byPlate.id;
    const byName = (vehicles || []).find((vehicle) => {
      const name = normalizeVehicleKey(vehicle.name);
      return name && (sourceKey === name || sourceKey.includes(name) || name.includes(sourceKey));
    });
    return byName?.id || null;
  };

  const ingestedAt = new Date().toISOString();
  const rows = body.rows.map((row): IngestedFleetRow | null => {
    const vehicleId = text(row.mojio_vehicle_id, 120);
    const vehicleName = text(row.vehicle_name, 180);
    if (!vehicleId || !vehicleName) return null;
    const diagnosticCodes = Array.isArray(row.diagnostic_codes)
      ? row.diagnostic_codes.slice(0, 20).map((entry) => ({
        code: text((entry as FleetRow)?.code, 50),
        description: text((entry as FleetRow)?.description, 240),
        severity: text((entry as FleetRow)?.severity, 40),
      })).filter((entry) => entry.code)
      : [];
    return {
      mojio_vehicle_id: vehicleId,
      vehicle_name: vehicleName,
      is_online: row.is_online === true,
      is_parked: row.is_parked !== false,
      latitude: numberOrNull(row.latitude, -90, 90),
      longitude: numberOrNull(row.longitude, -180, 180),
      address: text(row.address, 500),
      heading_degrees: numberOrNull(row.heading_degrees, 0, 360),
      odometer_km: numberOrNull(row.odometer_km, 0, 10_000_000),
      fuel_value: numberOrNull(row.fuel_value, 0, 100_000),
      fuel_unit: text(row.fuel_unit, 30),
      battery_volts: numberOrNull(row.battery_volts, 0, 1000),
      issue_count: Math.min(1000, Math.max(0, Math.trunc(Number(row.issue_count || 0)))),
      diagnostic_codes: diagnosticCodes,
      source_updated_at: dateOrNull(row.source_updated_at) || ingestedAt,
      ingested_at: ingestedAt,
      updated_by: user.id,
      vehicle_id: resolveVehicleId(row),
    };
  }).filter((row): row is IngestedFleetRow => row !== null);

  if (!rows.length) return json({ error: "Žádný platný záznam vozidla." }, 400);
  const { error: upsertError } = await admin.from("vehicle_live_positions").upsert(rows, { onConflict: "mojio_vehicle_id" });
  if (upsertError) return json({ error: upsertError.message }, 500);

  const mappedRows = rows.filter((row) => row && row.vehicle_id);
  if (mappedRows.length) {
    const mappingRows = mappedRows.map((row) => ({ id: row.vehicle_id, mojio_vehicle_id: row.mojio_vehicle_id }));
    for (const mapping of mappingRows) {
      const { error: mappingError } = await admin
        .from("vehicles")
        .update({ mojio_vehicle_id: mapping.mojio_vehicle_id })
        .eq("id", mapping.id);
      if (mappingError) return json({ error: mappingError.message }, 500);
    }
  }

  const historyRows = rows.map((row) => ({
    mojio_vehicle_id: row.mojio_vehicle_id,
    vehicle_id: row.vehicle_id,
    odometer_km: row.odometer_km,
    fuel_value: row.fuel_value,
    fuel_unit: row.fuel_unit,
    source_updated_at: row.source_updated_at,
    ingested_at: row.ingested_at,
  }));
  const { error: historyError } = await admin
    .from("vehicle_live_position_history")
    .upsert(historyRows, { onConflict: "mojio_vehicle_id,source_updated_at", ignoreDuplicates: true });
  if (historyError) return json({ error: historyError.message }, 500);

  return json({ ok: true, accepted: rows.length, mapped: mappedRows.length, ingested_at: ingestedAt });
});
