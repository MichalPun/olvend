import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type LatLngPoint = {
  latitude: number;
  longitude: number;
};

type RouteStopPayload = {
  id?: string | number | null;
  name?: string | null;
  city?: string | null;
  address?: string | null;
  latitude: number;
  longitude: number;
  estimatedServiceMinutes?: number | null;
  effectivePriority?: string | null;
  serviceWindow?: string | null;
  routeNote?: string | null;
  openRequestCount?: number | null;
};

type RoutePlanPayload = {
  origin: LatLngPoint & { label?: string; note?: string };
  stops: RouteStopPayload[];
  returnToStart?: boolean;
  departureTime?: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function parseDurationSeconds(input?: string | null) {
  if (!input) return 0;
  const match = String(input).match(/^(\d+(?:\.\d+)?)s$/);
  return match ? Math.round(Number(match[1])) : 0;
}

function latLng(point: LatLngPoint) {
  return {
    location: {
      latLng: {
        latitude: point.latitude,
        longitude: point.longitude,
      },
    },
  };
}

function normalizeStop(stop: RouteStopPayload, index: number) {
  return {
    ...stop,
    id: stop.id ?? `stop-${index + 1}`,
    name: stop.name || `Zastávka ${index + 1}`,
    city: stop.city || "",
    address: stop.address || "",
    routeNote: stop.routeNote || "",
    serviceWindow: stop.serviceWindow || "",
    estimatedServiceMinutes: Number(stop.estimatedServiceMinutes || 0),
    openRequestCount: Number(stop.openRequestCount || 0),
    effectivePriority: stop.effectivePriority || "normal",
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const googleMapsApiKey = Deno.env.get("GOOGLE_MAPS_API_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Missing Supabase environment variables." }, 500);
    }

    if (!googleMapsApiKey) {
      return json({ error: "Missing GOOGLE_MAPS_API_KEY environment variable." }, 500);
    }

    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return json({ error: "Missing Authorization header." }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await userClient.auth.getUser();

    if (currentUserError || !currentUser) {
      return json({ error: "Unauthorized user." }, 401);
    }

    const { data: currentEmployee, error: currentEmployeeError } = await adminClient
      .from("employees")
      .select("id, active")
      .eq("auth_user_id", currentUser.id)
      .maybeSingle();

    if (currentEmployeeError) {
      return json({ error: currentEmployeeError.message }, 400);
    }

    if (!currentEmployee || currentEmployee.active === false) {
      return json({ error: "Current user is not linked to an active employee." }, 403);
    }

    const payload = (await req.json()) as RoutePlanPayload;
    const origin = payload?.origin;
    const rawStops = Array.isArray(payload?.stops) ? payload.stops : [];

    if (!origin || Number.isNaN(Number(origin.latitude)) || Number.isNaN(Number(origin.longitude))) {
      return json({ error: "Origin latitude and longitude are required." }, 400);
    }

    if (!rawStops.length) {
      return json({ error: "At least one stop is required." }, 400);
    }

    if (payload.returnToStart === false) {
      return json({
        error: "Google Routes pilot zatím podporuje jen okruh se startem a cílem ve stejném bodě. Pro jednosměrnou trasu zatím použij fallback v aplikaci.",
      }, 400);
    }

    const stops = rawStops.map(normalizeStop);

    const googleRequest = {
      origin: latLng(origin),
      destination: latLng(origin),
      intermediates: stops.map((stop) => latLng(stop)),
      travelMode: "DRIVE",
      routingPreference: "TRAFFIC_AWARE",
      optimizeWaypointOrder: true,
      languageCode: "cs",
      units: "METRIC",
      polylineQuality: "OVERVIEW",
      departureTime: payload.departureTime || new Date().toISOString(),
    };

    const response = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": googleMapsApiKey,
        "X-Goog-FieldMask":
          "routes.optimizedIntermediateWaypointIndex,routes.distanceMeters,routes.duration,routes.staticDuration,routes.polyline.encodedPolyline,routes.legs.distanceMeters,routes.legs.duration",
      },
      body: JSON.stringify(googleRequest),
    });

    const responseText = await response.text();
    const data = responseText ? JSON.parse(responseText) : {};

    if (!response.ok) {
      return json({
        error: data?.error?.message || "Google Routes API request failed.",
        google_status: response.status,
      }, 400);
    }

    const route = Array.isArray(data?.routes) ? data.routes[0] : null;

    if (!route) {
      return json({ error: "Google Routes API returned no route." }, 400);
    }

    const optimizedIndices = Array.isArray(route.optimizedIntermediateWaypointIndex)
      ? route.optimizedIntermediateWaypointIndex.map((value: unknown) => Number(value))
      : stops.map((_, index) => index);

    const orderedStops = optimizedIndices.map((originalIndex, orderedIndex) => {
      const stop = stops[originalIndex];
      const leg = Array.isArray(route.legs) ? route.legs[orderedIndex] : null;

      return {
        ...stop,
        originalIndex,
        googleLegDistanceMeters: Number(leg?.distanceMeters || 0),
        googleLegDurationSeconds: parseDurationSeconds(leg?.duration),
      };
    });

    return json({
      provider: "google_routes",
      routingPreference: "TRAFFIC_AWARE",
      orderedStops,
      optimizedIntermediateWaypointIndex: optimizedIndices,
      route: {
        distanceMeters: Number(route.distanceMeters || 0),
        durationSeconds: parseDurationSeconds(route.duration),
        staticDurationSeconds: parseDurationSeconds(route.staticDuration),
        encodedPolyline: route?.polyline?.encodedPolyline || null,
      },
      note:
        "Pouzity je Google Routes API Compute Routes s optimizeWaypointOrder=true a routingPreference=TRAFFIC_AWARE. Google docs uvadeji, ze optimizeWaypointOrder neni kompatibilni s TRAFFIC_AWARE_OPTIMAL.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
