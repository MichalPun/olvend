import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-olvend-telemetry-token",
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

function readAttribute(source: string, name: string) {
  const match = source.match(new RegExp(`${name}\\s*=\\s*"([^"]*)"`, "i"));
  return match?.[1] ?? "";
}

function readOpeningTag(xml: string, tagName: string) {
  return xml.match(new RegExp(`<${tagName}\\b[^>]*>`, "i"))?.[0] ?? "";
}

function decodeXml(value: string) {
  return value
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

function readRawDex(xml: string) {
  const match = xml.match(/<RawDEX\b[^>]*>([\s\S]*?)<\/RawDEX>/i);
  if (!match) return "";
  const raw = match[1] ?? "";
  const cdata = raw.match(/^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/);
  return decodeXml((cdata?.[1] ?? raw).trim());
}

function normalizeOffset(value: string) {
  const raw = String(value || "").trim();
  if (raw === "0") return "+00:00";
  const match = raw.match(/^([+-])(\d{1,2})(?::?(\d{2}))?$/);
  if (!match) return "";
  return `${match[1]}${match[2].padStart(2, "0")}:${match[3] || "00"}`;
}

function parseTimestamp(value: string, offset = "") {
  if (!value) return null;
  const hasTimezone = /(?:z|[+-]\d{2}:?\d{2})$/i.test(value);
  const parsed = new Date(hasTimezone || !offset ? value : `${value}${normalizeOffset(offset)}`);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function assertIngestToken(req: Request) {
  const expectedToken = Deno.env.get("TELEMETRY_INGEST_TOKEN")?.trim();
  if (!expectedToken) return true;

  const url = new URL(req.url);
  const providedToken = req.headers.get("x-olvend-telemetry-token") || url.searchParams.get("token") || "";
  return providedToken === expectedToken;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  if (!assertIngestToken(req)) {
    return json({ error: "Unauthorized telemetry ingest." }, 401);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Missing Supabase environment variables." }, 500);
    }

    const xml = await req.text();
    const transactionTag = readOpeningTag(xml, "VDITransaction");
    const transmissionTag = readOpeningTag(xml, "DexTransmission");
    const dexTag = readOpeningTag(xml, "DEX");
    const rawDex = readRawDex(xml);

    if (!transactionTag || !transmissionTag || !dexTag || !rawDex) {
      return json({ error: "Invalid VDI DEX payload." }, 400);
    }

    const provider = readAttribute(transactionTag, "ProviderID") || "GP";
    const customerId = readAttribute(transactionTag, "CustomerID") || null;
    const transactionId = readAttribute(transactionTag, "TransactionID") || null;
    const transmissionOffset = normalizeOffset(readAttribute(transmissionTag, "GMTOffSet"));
    const dexOffset = normalizeOffset(readAttribute(dexTag, "GMTOffSet")) || transmissionOffset;
    const transactionTime = parseTimestamp(readAttribute(transactionTag, "TransactionTime"), transmissionOffset);
    const deviceId = readAttribute(transmissionTag, "DeviceID") || null;
    const transmitTime = parseTimestamp(readAttribute(transmissionTag, "TransmitTime"), transmissionOffset);
    const dexReadDateTime = parseTimestamp(readAttribute(dexTag, "ReadDateTime"), dexOffset);
    const dexReason = readAttribute(dexTag, "DexReason") || null;

    if (!deviceId) {
      return json({ error: "DeviceID is required." }, 400);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const ingestPayload = {
      provider,
      device_id: deviceId,
      customer_id: customerId,
      transaction_id: transactionId,
      transaction_time: transactionTime,
      transmit_time: transmitTime,
      dex_read_datetime: dexReadDateTime,
      dex_reason: dexReason,
      raw_xml: xml,
      raw_dex: rawDex,
      status: "received",
      parse_error: null,
    };

    const { data: ingest, error: ingestError } = await adminClient
      .from("telemetry_dex_ingests")
      .upsert(ingestPayload, { onConflict: "provider,transaction_id,device_id" })
      .select("id")
      .single();

    if (ingestError) {
      return json({ error: ingestError.message }, 400);
    }

    await adminClient.from("telemetry_raw_events").insert([{
      provider,
      external_machine_id: deviceId,
      event_type: "dex_upload",
      event_at: dexReadDateTime || transmitTime || transactionTime || new Date().toISOString(),
      payload: {
        ingest_id: ingest?.id ?? null,
        customer_id: customerId,
        transaction_id: transactionId,
        dex_reason: dexReason,
        raw_dex_preview: rawDex.slice(0, 1000),
      },
      processed: false,
    }]);

    return json({
      ok: true,
      ingest_id: ingest?.id ?? null,
      provider,
      device_id: deviceId,
      message: "DEX payload received.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
