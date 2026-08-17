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
  mode?: "optimize" | "ordered" | "distance";
  origin: LatLngPoint;
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
