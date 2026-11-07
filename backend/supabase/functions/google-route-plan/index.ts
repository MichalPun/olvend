type LatLngPoint = {
  latitude?: number;
  longitude?: number;
  address?: string;
  label?: string;
  note?: string;
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
  mode?: "optimize" | "ordered" | "distance" | "matrix";
  origin: LatLngPoint;
  points?: LatLngPoint[];
  destination?: LatLngPoint;
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

function hasLatLng(point?: LatLngPoint | null) {
  return point
    && !Number.isNaN(Number(point.latitude))
    && !Number.isNaN(Number(point.longitude));
}

function waypoint(point: LatLngPoint) {
  if (hasLatLng(point)) {
    return {
      location: {
        latLng: {
          latitude: Number(point.latitude),
          longitude: Number(point.longitude),
        },
      },
    };
  }

  if (point?.address) {
    return { address: point.address };
  }

  return null;
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

function businessPriorityRank(stop: RouteStopPayload) {
  const priority = String(stop.effectivePriority || "normal").toLowerCase();
  if (["critical", "sold_out", "fixed_window"].includes(priority)) return 0;
  if (["high", "stockout_risk", "urgent"].includes(priority)) return 1;
  return 2;
}

async function computeGoogleRoute(apiKey: string, request: Record<string, unknown>) {
  const response = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask":
        "routes.optimizedIntermediateWaypointIndex,routes.distanceMeters,routes.duration,routes.staticDuration,routes.polyline.encodedPolyline,routes.legs.distanceMeters,routes.legs.duration",
    },
    body: JSON.stringify(request),
  });
  const responseText = await response.text();
  const data = responseText ? JSON.parse(responseText) : {};
  if (!response.ok) throw new Error(data?.error?.message || "Google Routes API request failed.");
  const route = Array.isArray(data?.routes) ? data.routes[0] : null;
  if (!route) throw new Error("Google Routes API returned no route.");
  return route;
}

async function requireManager(req: Request) {
  const authorization = req.headers.get("Authorization") || "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
  if (!authorization || !supabaseUrl || !anonKey) return false;
  const headers = { apikey: anonKey, Authorization: authorization };
  const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, { headers });
  if (!userResponse.ok) return false;
  const user = await userResponse.json();
  if (!user?.id) return false;
  const params = new URLSearchParams({ select: "role,active", auth_user_id: `eq.${user.id}`, limit: "1" });
  const profileResponse = await fetch(`${supabaseUrl}/rest/v1/employees?${params}`, { headers });
  if (!profileResponse.ok) return false;
  const [profile] = await profileResponse.json();
  return profile?.active !== false && /admin|manager|manaž|manaz|vedouc|majitel/i.test(String(profile?.role || ""));
}

function parseMatrixEntries(text: string) {
  try {
    const parsed = JSON.parse(text || "[]");
    return Array.isArray(parsed) ? parsed : [parsed];
  } catch (_) {
    return text.split("\n")
      .map((line) => line.trim().replace(/^\[/, "").replace(/,$/, "").replace(/\]$/, ""))
      .filter(Boolean)
      .map((line) => JSON.parse(line));
  }
}

async function computeGoogleMatrix(apiKey: string, points: LatLngPoint[], departureTime?: string | null) {
  const size = points.length;
  const durationSeconds = Array.from({ length: size }, () => Array(size).fill(0));
  const distanceMeters = Array.from({ length: size }, () => Array(size).fill(0));
  const jobs: Array<() => Promise<void>> = [];
  const chunkSize = 20;
  for (let originStart = 0; originStart < size; originStart += chunkSize) {
    for (let destinationStart = 0; destinationStart < size; destinationStart += chunkSize) {
      jobs.push(async () => {
        const origins = points.slice(originStart, originStart + chunkSize);
        const destinations = points.slice(destinationStart, destinationStart + chunkSize);
        const response = await fetch("https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask": "originIndex,destinationIndex,duration,staticDuration,distanceMeters,status,condition",
          },
          body: JSON.stringify({
            origins: origins.map((point) => ({ waypoint: waypoint(point) })),
            destinations: destinations.map((point) => ({ waypoint: waypoint(point) })),
            travelMode: "DRIVE",
            routingPreference: "TRAFFIC_AWARE",
            departureTime: departureTime || new Date(Date.now() + 120000).toISOString(),
          }),
        });
        const text = await response.text();
        if (!response.ok) {
          let message = "Google Route Matrix request failed.";
          try { message = JSON.parse(text)?.error?.message || message; } catch (_) {}
          throw new Error(message);
        }
        parseMatrixEntries(text).forEach((entry) => {
          const from = originStart + Number(entry?.originIndex || 0);
          const to = destinationStart + Number(entry?.destinationIndex || 0);
          if (from >= size || to >= size) return;
          if (entry?.condition && entry.condition !== "ROUTE_EXISTS") {
            durationSeconds[from][to] = 86_400;
            distanceMeters[from][to] = 2_000_000;
            return;
          }
          durationSeconds[from][to] = from === to ? 0 : parseDurationSeconds(entry?.duration || entry?.staticDuration);
          distanceMeters[from][to] = from === to ? 0 : Number(entry?.distanceMeters || 0);
        });
      });
    }
  }
  for (let index = 0; index < jobs.length; index += 4) await Promise.all(jobs.slice(index, index + 4).map((job) => job()));
  return { durationSeconds, distanceMeters };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  try {
    const googleMapsApiKey = Deno.env.get("GOOGLE_MAPS_API_KEY");

    if (!googleMapsApiKey) {
      return json({ error: "Missing GOOGLE_MAPS_API_KEY environment variable." }, 500);
    }

    const payload = (await req.json()) as RoutePlanPayload;
    const origin = payload?.origin;
    const rawStops = Array.isArray(payload?.stops) ? payload.stops : [];

    if (payload.mode === "matrix") {
      if (!await requireManager(req)) return json({ error: "Silniční matici smí počítat pouze přihlášené vedení." }, 403);
      const points = Array.isArray(payload.points) ? payload.points : [];
      if (points.length < 2 || points.length > 90 || points.some((point) => !waypoint(point))) {
        return json({ error: "Pro matici je potřeba 2 až 90 platných bodů." }, 400);
      }
      const matrix = await computeGoogleMatrix(googleMapsApiKey, points, payload.departureTime);
      return json({ provider: "google_routes_matrix", mode: "matrix", ...matrix });
    }

    if (!origin || !waypoint(origin)) {
      return json({ error: "Origin coordinates or address are required." }, 400);
    }

    if (payload.mode === "distance") {
      const destination = payload.destination;

      if (!destination || !waypoint(destination)) {
        return json({ error: "Destination coordinates or address are required." }, 400);
      }

      const googleRequest = {
        origin: waypoint(origin),
        destination: waypoint(destination),
        travelMode: "DRIVE",
        routingPreference: "TRAFFIC_AWARE_OPTIMAL",
        languageCode: "cs",
        units: "METRIC",
        departureTime: payload.departureTime || new Date(Date.now() + 120000).toISOString(),
      };

      const response = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": googleMapsApiKey,
          "X-Goog-FieldMask": "routes.distanceMeters,routes.duration,routes.staticDuration",
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

      return json({
        provider: "google_routes",
        mode: "distance",
        routingPreference: "TRAFFIC_AWARE_OPTIMAL",
        route: {
          distanceMeters: Number(route.distanceMeters || 0),
          durationSeconds: parseDurationSeconds(route.duration),
          staticDurationSeconds: parseDurationSeconds(route.staticDuration),
        },
      });
    }

    if (!rawStops.length) {
      return json({ error: "At least one stop is required." }, 400);
    }

    const stops = rawStops.map(normalizeStop);

    const destinationPoint = payload.destination && waypoint(payload.destination)
      ? payload.destination
      : payload.returnToStart !== false
        ? origin
        : null;
    if (!destinationPoint || !waypoint(destinationPoint)) {
      return json({ error: "Destination coordinates or address are required for a one-way route." }, 400);
    }

    const preserveOrder = payload.mode === "ordered";
    const googleRequest = {
      origin: waypoint(origin),
      destination: waypoint(destinationPoint),
      intermediates: stops.map((stop) => waypoint(stop)).filter(Boolean),
      travelMode: "DRIVE",
      routingPreference: "TRAFFIC_AWARE",
      optimizeWaypointOrder: !preserveOrder,
      languageCode: "cs",
      units: "METRIC",
      polylineQuality: "OVERVIEW",
      departureTime: payload.departureTime || new Date(Date.now() + 120000).toISOString(),
    };

    let route;
    try {
      route = await computeGoogleRoute(googleMapsApiKey, googleRequest);
    } catch (error) {
      return json({ error: error instanceof Error ? error.message : "Google Routes API request failed." }, 400);
    }

    const optimizedIndices = !preserveOrder && Array.isArray(route.optimizedIntermediateWaypointIndex)
      ? route.optimizedIntermediateWaypointIndex.map((value: unknown) => Number(value))
      : stops.map((_, index) => index);

    let orderedStops = optimizedIndices.map((originalIndex, orderedIndex) => {
      const stop = stops[originalIndex];
      const leg = Array.isArray(route.legs) ? route.legs[orderedIndex] : null;

      return {
        ...stop,
        originalIndex,
        googleLegDistanceMeters: Number(leg?.distanceMeters || 0),
        googleLegDurationSeconds: parseDurationSeconds(leg?.duration),
      };
    });

    let businessPriorityApplied = false;
    // Priority decides which stops belong in a route. It must not globally sort an
    // already optimized route and create cross-region zigzags. Keep the legacy
    // behavior available only for explicit callers that really need it.
    if (!preserveOrder && payload.applyBusinessPriority === true && orderedStops.some((stop) => businessPriorityRank(stop) < 2 || String(stop.serviceWindow || "").trim())) {
      let prioritizedStops = orderedStops
        .map((stop, index) => ({ stop, index }))
        .sort((a, b) => businessPriorityRank(a.stop) - businessPriorityRank(b.stop) || a.index - b.index)
        .map(({ stop }) => stop);
      const fixedWindows = stops
        .map((stop, index) => ({ stop, index }))
        .filter(({ stop }) => String(stop.serviceWindow || "").trim());
      if (fixedWindows.length) {
        const fixedIds = new Set(fixedWindows.map(({ stop }) => String(stop.id)));
        prioritizedStops = prioritizedStops.filter((stop) => !fixedIds.has(String(stop.id)));
        fixedWindows.forEach(({ stop, index }) => prioritizedStops.splice(Math.min(index, prioritizedStops.length), 0, stop));
      }
      businessPriorityApplied = prioritizedStops.some((stop, index) => String(stop.id) !== String(orderedStops[index]?.id));
      if (businessPriorityApplied) {
        try {
          route = await computeGoogleRoute(googleMapsApiKey, {
            ...googleRequest,
            intermediates: prioritizedStops.map((stop) => waypoint(stop)).filter(Boolean),
            optimizeWaypointOrder: false,
          });
          orderedStops = prioritizedStops.map((stop, orderedIndex) => {
            const leg = Array.isArray(route.legs) ? route.legs[orderedIndex] : null;
            return {
              ...stop,
              googleLegDistanceMeters: Number(leg?.distanceMeters || 0),
              googleLegDurationSeconds: parseDurationSeconds(leg?.duration),
            };
          });
        } catch (error) {
          return json({ error: error instanceof Error ? error.message : "Google Routes API priority recalculation failed." }, 400);
        }
      }
    }

    return json({
      provider: "google_routes",
      mode: preserveOrder ? "ordered" : "optimize",
      routingPreference: "TRAFFIC_AWARE",
      orderedStops,
      optimizedIntermediateWaypointIndex: orderedStops.map((stop) => Number(stop.originalIndex)),
      businessPriorityApplied,
      route: {
        distanceMeters: Number(route.distanceMeters || 0),
        durationSeconds: parseDurationSeconds(route.duration),
        staticDurationSeconds: parseDurationSeconds(route.staticDuration),
        encodedPolyline: route?.polyline?.encodedPolyline || null,
      },
      note:
        preserveOrder
          ? "Poradi zastavek bylo zachovano; Google prepocital vzdalenosti a cas jednotlivych useku."
          : businessPriorityApplied
            ? "Google optimalizoval živou dopravu a kilometry; potvrzená vyprodanost, riziko vyprodání a pevná okna byla následně upřednostněna a finální pořadí bylo znovu přepočítáno."
            : "Pouzity je Google Routes API Compute Routes s optimizeWaypointOrder=true a routingPreference=TRAFFIC_AWARE. Google docs uvadeji, ze optimizeWaypointOrder neni kompatibilni s TRAFFIC_AWARE_OPTIMAL.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
