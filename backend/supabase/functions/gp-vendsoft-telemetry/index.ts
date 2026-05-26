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

function parseWrapperTimestamp(value: string, offset = "", fallbackOffset = "") {
  const normalizedOffset = normalizeOffset(offset);
  const normalizedFallbackOffset = normalizeOffset(fallbackOffset);
  const effectiveOffset = normalizedOffset === "+00:00" && normalizedFallbackOffset
    ? normalizedFallbackOffset
    : normalizedOffset || normalizedFallbackOffset;
  return parseTimestamp(value, effectiveOffset);
}

function pragueOffsetForDexDate(dateValue = "") {
  const match = String(dateValue).match(/^(\d{2})(\d{2})(\d{2})$/);
  if (!match) return "+01:00";
  const year = Number(match[1]) >= 70 ? 1900 + Number(match[1]) : 2000 + Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const lastSunday = (targetMonth: number) => {
    const date = new Date(Date.UTC(year, targetMonth, 0));
    date.setUTCDate(date.getUTCDate() - date.getUTCDay());
    return date.getUTCDate();
  };
  const dstStartDay = lastSunday(3);
  const dstEndDay = lastSunday(10);
  const isSummer =
    month > 3 && month < 10 ||
    month === 3 && day >= dstStartDay ||
    month === 10 && day < dstEndDay;
  return isSummer ? "+02:00" : "+01:00";
}

function parseDexDateTime(dateValue = "", timeValue = "", offset = "") {
  const dateMatch = String(dateValue).match(/^(\d{2})(\d{2})(\d{2})$/);
  const timeMatch = String(timeValue).match(/^(\d{2})(\d{2})(\d{2})?$|^(\d{2})(\d{2})$/);
  if (!dateMatch || !timeMatch) return null;
  const year = Number(dateMatch[1]) >= 70 ? `19${dateMatch[1]}` : `20${dateMatch[1]}`;
  const month = dateMatch[2];
  const day = dateMatch[3];
  const hour = timeMatch[1] || timeMatch[4] || "00";
  const minute = timeMatch[2] || timeMatch[5] || "00";
  const second = timeMatch[3] || "00";
  return parseTimestamp(`${year}-${month}-${day}T${hour}:${minute}:${second}`, offset || pragueOffsetForDexDate(dateValue));
}

type DexRecord = {
  code: string;
  fields: string[];
  raw: string;
};

function parseDexRecords(rawDex: string) {
  return rawDex
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((raw) => {
      const parts = raw.split("*");
      return { code: parts[0] || "", fields: parts.slice(1), raw };
    });
}

function firstRecord(records: DexRecord[], code: string) {
  return records.find((record) => record.code === code) || null;
}

function countRecordCodes(records: DexRecord[]) {
  return records.reduce<Record<string, number>>((acc, record) => {
    acc[record.code] = (acc[record.code] || 0) + 1;
    return acc;
  }, {});
}

function parseDexSummary(rawDex: string, fallbackDeviceId = "", fallbackEventAt: string | null = null) {
  const records = parseDexRecords(rawDex);
  const dxs = firstRecord(records, "DXS");
  const ca1 = firstRecord(records, "CA1");
  const id1 = firstRecord(records, "ID1");
  const id5 = firstRecord(records, "ID5");
  const id7 = firstRecord(records, "ID7");
  const ea3 = firstRecord(records, "EA3");
  const va1 = firstRecord(records, "VA1");
  const terminalId = ca1?.fields[0] || id7?.fields[3] || fallbackDeviceId || "";
  const machineNumber = id1?.fields[2] || "";
  const dexReadAt = id5 ? parseDexDateTime(id5.fields[0], id5.fields[1]) : fallbackEventAt;
  const productLabels = new Map<string, Record<string, unknown>>();

  records.filter((record) => record.code === "PP1").forEach((record) => {
    const selection = record.fields[0] || "";
    if (!selection) return;
    productLabels.set(selection, {
      selection,
      price_or_planogram: record.fields[1] || null,
      label: String(record.fields[2] || "").trim() || null,
      raw: record.raw,
    });
  });

  const productCounters: Record<string, unknown>[] = [];
  let current: Record<string, unknown> | null = null;
  records.forEach((record) => {
    if (record.code === "PA1") {
      if (current) productCounters.push(current);
      const selection = record.fields[0] || "";
      current = {
        selection,
        product_index: record.fields[1] || null,
        product_label: productLabels.get(selection)?.label || null,
        raw_records: [record.raw],
      };
      return;
    }
    if (!current || !record.code.startsWith("PA")) return;
    (current.raw_records as string[]).push(record.raw);
    if (record.code === "PA2") {
      current.pa2 = record.fields;
      current.count_cash = Number(record.fields[2] || 0);
      current.count_cashless = Number(record.fields[4] || 0);
    }
    if (record.code === "PA5") {
      current.last_vend_at = parseDexDateTime(record.fields[0], record.fields[1]);
    }
    if (record.code === "PA7") {
      current.pa7 = [...((current.pa7 as unknown[]) || []), record.fields];
    }
  });
  if (current) productCounters.push(current);
  const productCounterMap = new Map<string, Record<string, unknown>>();
  productCounters.forEach((counter) => {
    const key = [
      counter.selection || "",
      counter.product_index || "",
      Array.isArray(counter.pa2) ? counter.pa2.join("|") : "",
      counter.last_vend_at || "",
    ].join(":");
    const existing = productCounterMap.get(key);
    if (existing) {
      existing.occurrence_count = Number(existing.occurrence_count || 1) + 1;
      return;
    }
    productCounterMap.set(key, { ...counter, occurrence_count: 1 });
  });
  const uniqueProductCounters = Array.from(productCounterMap.values());

  return {
    external_machine_id: fallbackDeviceId || terminalId || machineNumber || dxs?.fields[0] || "unknown",
    terminal_id: terminalId || null,
    machine_number: machineNumber || null,
    dex_serial: dxs?.fields[0] || null,
    dex_kind: dxs?.fields[1] || null,
    dex_version: dxs?.fields[2] || null,
    dex_read_at: dexReadAt,
    audit_window: ea3 ? {
      collection_number: ea3.fields[0] || null,
      read_at: parseDexDateTime(ea3.fields[1], ea3.fields[2]),
      previous_read_at: parseDexDateTime(ea3.fields[4], ea3.fields[5]),
    } : null,
    va1: va1?.fields || null,
    product_labels: Array.from(productLabels.values()),
    product_counters: uniqueProductCounters,
    raw_product_counter_count: productCounters.length,
    record_counts: countRecordCodes(records),
  };
}

function uniq(values: Array<string | null | undefined>) {
  return Array.from(new Set(values.map((value) => String(value || "").trim()).filter(Boolean)));
}

async function resolveMachineId(adminClient: ReturnType<typeof createClient>, provider: string, identifiers: string[]) {
  const lookupKeys = uniq(identifiers);
  if (!lookupKeys.length) return null;

  const { data, error } = await adminClient
    .from("machine_external_links")
    .select("machine_id, external_machine_id")
    .eq("provider", provider)
    .eq("telemetry_enabled", true)
    .in("external_machine_id", lookupKeys)
    .limit(1);

  if (error) throw error;
  return data?.[0]?.machine_id ?? null;
}

function normalizeSelectionCode(value: unknown) {
  return String(value || "").trim().replace(/^0+(\d)/, "$1");
}

function numericCounter(value: unknown) {
  const numberValue = Number(value || 0);
  return Number.isFinite(numberValue) ? numberValue : 0;
}

async function applyPlanogramDepletion(
  adminClient: ReturnType<typeof createClient>,
  params: {
    provider: string;
    machineId: number;
    ingestId: number | null;
    counters: Record<string, unknown>[];
    eventAt: string;
  },
) {
  const selectionTotals = new Map<string, { selection: string; totalCount: number; eventAt: string }>();

  params.counters.forEach((counter) => {
    const selection = normalizeSelectionCode(counter.selection);
    if (!selection) return;
    const totalCount = numericCounter(counter.count_cash) + numericCounter(counter.count_cashless);
    if (totalCount <= 0) return;
    const current = selectionTotals.get(selection);
    if (!current || totalCount > current.totalCount) {
      selectionTotals.set(selection, {
        selection,
        totalCount,
        eventAt: String(counter.last_vend_at || params.eventAt),
      });
    }
  });

  if (!selectionTotals.size) return [];

  const { data: slots, error: slotsError } = await adminClient
    .from("machine_planogram_slots")
    .select("id, slot_code, current_units, capacity_units")
    .eq("machine_id", params.machineId)
    .eq("active", true);

  if (slotsError) throw slotsError;
  if (!slots?.length) return [];

  const applied: Record<string, unknown>[] = [];

  for (const slot of slots) {
    const selection = normalizeSelectionCode(slot.slot_code);
    const counter = selectionTotals.get(selection);
    if (!counter) continue;

    const { data: previous, error: previousError } = await adminClient
      .from("telemetry_planogram_counters")
      .select("last_total_count")
      .eq("provider", params.provider)
      .eq("machine_id", params.machineId)
      .eq("planogram_slot_id", slot.id)
      .eq("selection_code", selection)
      .maybeSingle();

    if (previousError) throw previousError;

    const previousTotal = Number(previous?.last_total_count ?? counter.totalCount);
    const delta = Math.max(0, counter.totalCount - previousTotal);

    const { error: counterError } = await adminClient
      .from("telemetry_planogram_counters")
      .upsert({
        provider: params.provider,
        machine_id: params.machineId,
        planogram_slot_id: slot.id,
        selection_code: selection,
        last_total_count: counter.totalCount,
        last_event_at: counter.eventAt,
        last_ingest_id: params.ingestId,
      }, { onConflict: "provider,machine_id,planogram_slot_id,selection_code" });

    if (counterError) throw counterError;
    if (delta <= 0) continue;

    const currentUnits = slot.current_units == null ? null : Number(slot.current_units);
    const capacityUnits = slot.capacity_units == null ? null : Number(slot.capacity_units);
    const nextUnits = currentUnits == null ? null : Math.max(0, currentUnits - delta);
    const nextFillPercent = nextUnits != null && capacityUnits && capacityUnits > 0
      ? Math.round((nextUnits / capacityUnits) * 10000) / 100
      : null;

    const slotPatch: Record<string, unknown> = {};
    if (nextUnits != null) slotPatch.current_units = nextUnits;
    if (nextFillPercent != null) slotPatch.fill_percent = nextFillPercent;

    if (Object.keys(slotPatch).length) {
      const { error: updateError } = await adminClient
        .from("machine_planogram_slots")
        .update(slotPatch)
        .eq("id", slot.id);

      if (updateError) throw updateError;
    }

    applied.push({
      slot_id: slot.id,
      selection_code: selection,
      previous_total: previousTotal,
      current_total: counter.totalCount,
      vend_delta: delta,
      next_units: nextUnits,
      next_fill_percent: nextFillPercent,
    });
  }

  return applied;
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

    const body = await req.text();
    const transactionTag = readOpeningTag(body, "VDITransaction");
    const transmissionTag = readOpeningTag(body, "DexTransmission");
    const dexTag = readOpeningTag(body, "DEX");
    const wrappedRawDex = readRawDex(body);
    const rawDex = wrappedRawDex || body.trim();

    if (!rawDex || !/^DXS\*/m.test(rawDex)) {
      return json({ error: "Invalid DEX payload." }, 400);
    }

    const provider = readAttribute(transactionTag, "ProviderID") || "GP";
    const customerId = readAttribute(transactionTag, "CustomerID") || null;
    const transactionId = readAttribute(transactionTag, "TransactionID") || null;
    const rawTransmissionOffset = readAttribute(transmissionTag, "GMTOffSet");
    const rawDexOffset = readAttribute(dexTag, "GMTOffSet");
    const transactionTime = parseWrapperTimestamp(readAttribute(transactionTag, "TransactionTime"), rawTransmissionOffset);
    const wrapperDeviceId = readAttribute(transmissionTag, "DeviceID") || "";
    const transmitTime = parseWrapperTimestamp(readAttribute(transmissionTag, "TransmitTime"), rawTransmissionOffset);
    const wrapperDexReadDateTime = parseWrapperTimestamp(readAttribute(dexTag, "ReadDateTime"), rawDexOffset, rawTransmissionOffset);
    const dexReason = readAttribute(dexTag, "DexReason") || null;
    const parsedDex = parseDexSummary(rawDex, wrapperDeviceId, wrapperDexReadDateTime || transmitTime || transactionTime);
    const deviceId = wrapperDeviceId || parsedDex.terminal_id || parsedDex.external_machine_id;
    const dexReadDateTime = wrapperDexReadDateTime || parsedDex.dex_read_at;

    if (!deviceId) {
      return json({ error: "DEX device or terminal identifier is required." }, 400);
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
      raw_xml: wrappedRawDex ? body : "",
      raw_dex: rawDex,
      status: "parsed",
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

    const eventAt = dexReadDateTime || transmitTime || transactionTime || new Date().toISOString();
    const rawEvents: Record<string, unknown>[] = [{
      provider,
      external_machine_id: parsedDex.external_machine_id || deviceId,
      event_type: "dex_upload",
      event_at: eventAt,
      payload: {
        ingest_id: ingest?.id ?? null,
        customer_id: customerId,
        transaction_id: transactionId,
        dex_reason: dexReason,
        terminal_id: parsedDex.terminal_id,
        machine_number: parsedDex.machine_number,
        raw_dex_preview: rawDex.slice(0, 1000),
      },
      processed: false,
    }, {
      provider,
      external_machine_id: parsedDex.external_machine_id || deviceId,
      event_type: "dex_snapshot",
      event_at: eventAt,
      payload: {
        ingest_id: ingest?.id ?? null,
        ...parsedDex,
      },
      processed: false,
    }, ...parsedDex.product_counters.map((counter) => ({
      provider,
      external_machine_id: parsedDex.external_machine_id || deviceId,
      event_type: "dex_product_counter",
      event_at: String((counter as Record<string, unknown>).last_vend_at || eventAt),
      payload: {
        ingest_id: ingest?.id ?? null,
        terminal_id: parsedDex.terminal_id,
        machine_number: parsedDex.machine_number,
        ...counter,
      },
      processed: false,
    }))];

    await adminClient.from("telemetry_raw_events").insert(rawEvents);

    const machineId = await resolveMachineId(adminClient, provider, [
      deviceId,
      parsedDex.external_machine_id,
      parsedDex.terminal_id,
      parsedDex.machine_number,
      parsedDex.dex_serial,
    ]);

    let planogramDepletion: Record<string, unknown>[] = [];

    if (machineId) {
      const { error: stateError } = await adminClient
        .from("machine_telemetry_state")
        .upsert({
          machine_id: machineId,
          provider,
          last_seen_at: eventAt,
          connectivity_status: "online",
          counters_payload: {
            ingest_id: ingest?.id ?? null,
            device_id: deviceId,
            terminal_id: parsedDex.terminal_id,
            machine_number: parsedDex.machine_number,
            dex_read_at: parsedDex.dex_read_at,
            record_counts: parsedDex.record_counts,
            product_counter_count: parsedDex.product_counters.length,
            raw_product_counter_count: parsedDex.raw_product_counter_count,
          },
          updated_at: new Date().toISOString(),
        }, { onConflict: "machine_id,provider" });

      if (stateError) throw stateError;

      planogramDepletion = await applyPlanogramDepletion(adminClient, {
        provider,
        machineId: Number(machineId),
        ingestId: ingest?.id ?? null,
        counters: parsedDex.product_counters as Record<string, unknown>[],
        eventAt,
      });
    }

    return json({
      ok: true,
      ingest_id: ingest?.id ?? null,
      provider,
      device_id: deviceId,
      machine_id: machineId,
      machine_number: parsedDex.machine_number,
      terminal_id: parsedDex.terminal_id,
      product_counter_count: parsedDex.product_counters.length,
      planogram_depletion_count: planogramDepletion.length,
      message: "DEX payload received and parsed.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
