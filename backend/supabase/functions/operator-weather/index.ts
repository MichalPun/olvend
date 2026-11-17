import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "private, max-age=900",
};

const CACHE_MS = 3 * 60 * 60 * 1000;

type WeatherRow = {
  cache_key: string;
  latitude: number;
  longitude: number;
  place_name: string | null;
  temperature_c: number;
  condition_code: string;
  condition_label: string;
  observed_at: string | null;
  fetched_at: string;
};

function respond(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), { status, headers: jsonHeaders });
}

function normalizeCoordinate(value: unknown, min: number, max: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) return null;
  return Number(parsed.toFixed(4));
}

function cacheKey(latitude: number, longitude: number) {
  return `${latitude.toFixed(4)},${longitude.toFixed(4)}`;
}

function conditionLabel(symbolCode: string) {
  const code = String(symbolCode || "").replace(/_(day|night|polartwilight)$/, "");
  const labels: Record<string, string> = {
    clearsky: "jasno",
    fair: "polojasno",
    partlycloudy: "oblačno",
    cloudy: "zataženo",
    fog: "mlha",
    lightrain: "slabý déšť",
    rain: "déšť",
    heavyrain: "silný déšť",
    lightrainshowers: "slabé přeháňky",
    rainshowers: "přeháňky",
    heavyrainshowers: "silné přeháňky",
    lightsleet: "slabý déšť se sněhem",
    sleet: "déšť se sněhem",
    heavysleet: "silný déšť se sněhem",
    lightsleetshowers: "slabé smíšené přeháňky",
    sleetshowers: "smíšené přeháňky",
    heavysleetshowers: "silné smíšené přeháňky",
    lightsnow: "slabé sněžení",
    snow: "sněžení",
    heavysnow: "silné sněžení",
    lightsnowshowers: "slabé sněhové přeháňky",
    snowshowers: "sněhové přeháňky",
    heavysnowshowers: "silné sněhové přeháňky",
    rainandthunder: "déšť a bouřky",
    heavyrainandthunder: "silný déšť a bouřky",
    rainshowersandthunder: "přeháňky a bouřky",
    snowandthunder: "sněžení a bouřky",
  };
  return labels[code] || "proměnlivo";
}

function weatherPayload(row: WeatherRow, cached: boolean, stale = false) {
  return {
    place: row.place_name || null,
    temperature_c: Number(row.temperature_c),
    condition: row.condition_label,
    symbol_code: row.condition_code,
    observed_at: row.observed_at,
    fetched_at: row.fetched_at,
    cached,
    stale,
    provider: "MET Norway",
    attribution_url: "https://api.met.no/",
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return respond({ message: "Použijte metodu POST." }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const authHeader = req.headers.get("Authorization") || "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authHeader) {
    return respond({ message: "Chybí oprávnění k načtení počasí." }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: active, error: activeError } = await userClient.rpc("security_active_employee");
  if (activeError || active !== true) return respond({ message: "Přístup je povolen pouze aktivnímu zaměstnanci." }, 403);

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch (_) { return respond({ message: "Neplatná data požadavku." }, 400); }

  const latitude = normalizeCoordinate(body.latitude, -90, 90);
  const longitude = normalizeCoordinate(body.longitude, -180, 180);
  if (latitude == null || longitude == null) return respond({ message: "Chybí platné souřadnice." }, 400);

  const place = String(body.place || "").trim().slice(0, 100) || null;
  const key = cacheKey(latitude, longitude);
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: cachedRow } = await admin
    .from("operator_weather_cache")
    .select("cache_key,latitude,longitude,place_name,temperature_c,condition_code,condition_label,observed_at,fetched_at")
    .eq("cache_key", key)
    .maybeSingle<WeatherRow>();

  if (cachedRow && Date.now() - new Date(cachedRow.fetched_at).getTime() < CACHE_MS) {
    return respond(weatherPayload({ ...cachedRow, place_name: place || cachedRow.place_name }, true));
  }

  const upstreamUrl = new URL("https://api.met.no/weatherapi/locationforecast/2.0/compact");
  upstreamUrl.searchParams.set("lat", latitude.toFixed(4));
  upstreamUrl.searchParams.set("lon", longitude.toFixed(4));

  try {
    const upstream = await fetch(upstreamUrl, {
      headers: {
        "User-Agent": "OLVEND-Operator/2.0 https://www.olmika.cz",
        "Accept": "application/json",
      },
    });
    if (!upstream.ok) throw new Error(`MET Norway HTTP ${upstream.status}`);
    const forecast = await upstream.json();
    const current = forecast?.properties?.timeseries?.[0];
    const temperature = Number(current?.data?.instant?.details?.air_temperature);
    const symbolCode = String(
      current?.data?.next_1_hours?.summary?.symbol_code
      || current?.data?.next_6_hours?.summary?.symbol_code
      || current?.data?.next_12_hours?.summary?.symbol_code
      || "unknown",
    );
    if (!Number.isFinite(temperature)) throw new Error("MET Norway nevrátil teplotu.");

    const now = new Date().toISOString();
    const row: WeatherRow = {
      cache_key: key,
      latitude,
      longitude,
      place_name: place,
      temperature_c: Math.round(temperature * 10) / 10,
      condition_code: symbolCode,
      condition_label: conditionLabel(symbolCode),
      observed_at: current?.time || null,
      fetched_at: now,
    };
    const { error: saveError } = await admin.from("operator_weather_cache").upsert({ ...row, updated_at: now });
    if (saveError) console.error("operator-weather cache save failed", saveError.message);
    return respond(weatherPayload(row, false));
  } catch (error) {
    console.error("operator-weather upstream failed", error);
    if (cachedRow) return respond(weatherPayload({ ...cachedRow, place_name: place || cachedRow.place_name }, true, true));
    return respond({ message: "Počasí nyní není dostupné." }, 503);
  }
});
