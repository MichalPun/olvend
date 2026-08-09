import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as XLSX from "npm:xlsx@0.18.5";

const VENDSOFT_BASE_URL = "https://secure.vendsoft.com";
const REPORT_NAME = "usat-transaction-log";
const PROVIDER_TIME_ZONE = "Europe/Prague";
const SESSION_REUSE_MS = 20 * 60 * 1000;

type ReportRow = Record<string, unknown>;

let cachedVendSoftCookie = "";
let cachedVendSoftCookieAt = 0;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function assertIngestToken(req: Request) {
  const expectedToken = Deno.env.get("TELEMETRY_INGEST_TOKEN")?.trim();
  const expectedCronToken = Deno.env.get("VENDSOFT_CRON_TOKEN")?.trim();
  const providedToken = req.headers.get("x-olvend-telemetry-token") || "";
  const providedCronToken = req.headers.get("x-olvend-cron-token") || "";
  if (expectedToken && providedToken === expectedToken) return true;
  if (expectedCronToken && providedCronToken === expectedCronToken) return true;
  return !expectedToken && !expectedCronToken;
}

function localDateString(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: PROVIDER_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function asText(value: unknown) {
  return String(value ?? "").trim();
}

function asNumber(value: unknown) {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  const normalized = asText(value).replace(/\s/g, "").replace(",", ".");
  if (!normalized) return null;
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseMachine(value: unknown) {
  const raw = asText(value);
  const match = raw.match(/^\[(\d+)\]\s*(.*)$/);
  return {
    code: match?.[1] || "",
    name: (match?.[2] || raw).trim(),
  };
}

function wallClockInProviderZoneToIso(parts: {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}) {
  const localTimestamp = [
      String(parts.year).padStart(4, "0"),
      String(parts.month).padStart(2, "0"),
      String(parts.day).padStart(2, "0"),
    ].join("-") + "T" + [
      String(parts.hour).padStart(2, "0"),
      String(parts.minute).padStart(2, "0"),
      String(Math.floor(parts.second)).padStart(2, "0"),
    ].join(":");
  const utcGuess = new Date(`${localTimestamp}Z`);
  const localParts = new Intl.DateTimeFormat("en-CA", {
    timeZone: PROVIDER_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(utcGuess);
  const values = Object.fromEntries(localParts.map((part) => [part.type, part.value]));
  const representedAsUtc = Date.UTC(
    Number(values.year),
    Number(values.month) - 1,
    Number(values.day),
    Number(values.hour),
    Number(values.minute),
    Number(values.second),
  );
  return new Date(utcGuess.getTime() - (representedAsUtc - utcGuess.getTime())).toISOString();
}

function parseVendSoftTimestamp(value: unknown) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return wallClockInProviderZoneToIso({
      year: value.getUTCFullYear(),
      month: value.getUTCMonth() + 1,
      day: value.getUTCDate(),
      hour: value.getUTCHours(),
      minute: value.getUTCMinutes(),
      second: value.getUTCSeconds(),
    });
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    const parts = XLSX.SSF.parse_date_code(value);
    if (!parts) return null;
    return wallClockInProviderZoneToIso({
      year: parts.y,
      month: parts.m,
      day: parts.d,
      hour: parts.H,
      minute: parts.M,
      second: parts.S,
    });
  }
  const raw = asText(value);
  if (!raw) return null;

  const normalized = raw.includes("T") ? raw : raw.replace(" ", "T");
  const withZone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(normalized)
    ? normalized
    : `${normalized}+02:00`;
  const date = new Date(withZone);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

async function sha256(value: string) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function getSetCookieValues(headers: Headers) {
  const extended = headers as Headers & { getSetCookie?: () => string[] };
  if (typeof extended.getSetCookie === "function") return extended.getSetCookie();
  const combined = headers.get("set-cookie");
  return combined ? [combined] : [];
}

function cookieHeader(setCookieValues: string[]) {
  return setCookieValues
    .map((cookie) => cookie.split(";")[0]?.trim())
    .filter(Boolean)
    .join("; ");
}

async function loginToVendSoft(email: string, password: string) {
  const form = new FormData();
  form.append("email", email);
  form.append("pass", password);

  const response = await fetch(`${VENDSOFT_BASE_URL}/login`, {
    method: "POST",
    body: form,
    redirect: "manual",
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok || payload?.success !== true) {
    throw new Error(`VendSoft login failed (${response.status}).`);
  }

  const cookie = cookieHeader(getSetCookieValues(response.headers));
  if (!cookie) throw new Error("VendSoft login did not return a session cookie.");
  cachedVendSoftCookie = cookie;
  cachedVendSoftCookieAt = Date.now();
  return cookie;
}

async function getVendSoftCookie(email: string, password: string, force = false) {
  if (!force && cachedVendSoftCookie && Date.now() - cachedVendSoftCookieAt < SESSION_REUSE_MS) {
    return cachedVendSoftCookie;
  }
  return loginToVendSoft(email, password);
}

async function downloadReport(cookie: string, fromDate: string, toDate = fromDate) {
  const response = await fetch(`${VENDSOFT_BASE_URL}/report/v3`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Cookie": cookie,
    },
    body: JSON.stringify({
      routes: "",
      report_name: REPORT_NAME,
      products: "",
      report_format: "xlsx",
      drivers: "",
      from_date: fromDate,
      locations: "",
      machines: "",
      to_date: toDate,
    }),
  });

  if (response.status === 401 || response.status === 403) {
    throw new Error("VENDSOFT_SESSION_EXPIRED");
  }
  if (!response.ok) throw new Error(`VendSoft report failed (${response.status}).`);
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (!bytes.length) throw new Error("VendSoft report is empty.");
  return bytes;
}

function parseReport(bytes: Uint8Array) {
  const workbook = XLSX.read(bytes, { type: "array", cellDates: true });
  const sheetName = workbook.SheetNames[0];
  if (!sheetName) return [];
  const sheet = workbook.Sheets[sheetName];
  const rows = XLSX.utils.sheet_to_json<unknown[]>(sheet, {
    header: 1,
    raw: true,
    defval: "",
    range: 3,
  });
  return rows.map((row) => ({
    Timestamp: row[0],
    Location: row[1],
    Machine: row[2],
    Product: row[3],
    Selection: row[4],
    Price: row[5],
    Quantity: row[6],
    Total: row[7],
    "Credit Card": row[8],
  }));
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);
  if (!assertIngestToken(req)) return json({ error: "Unauthorized." }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const email = Deno.env.get("VENDSOFT_SYNC_EMAIL")?.trim();
  const password = Deno.env.get("VENDSOFT_SYNC_PASSWORD") || "";

  if (!supabaseUrl || !serviceRoleKey || !email || !password) {
    return json({ error: "Missing sync environment variables." }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const requestBody = await req.json().catch(() => ({})) as Record<string, unknown>;
  const historyMode = requestBody.mode === "history";
  const dryRun = requestBody.dry_run === true;
  const requestedFrom = asText(requestBody.from_date);
  const requestedTo = asText(requestBody.to_date || requestBody.from_date);
  const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;
  if (historyMode && (!isoDatePattern.test(requestedFrom) || !isoDatePattern.test(requestedTo))) {
    return json({ error: "History mode requires from_date and to_date in YYYY-MM-DD format." }, 400);
  }

  const attemptAt = new Date().toISOString();
  await admin
    .from("vendsoft_food_sync_state")
    .upsert({ singleton: true, last_attempt_at: attemptAt, updated_at: attemptAt }, { onConflict: "singleton" });

  try {
    const { data: state, error: stateError } = await admin
      .from("vendsoft_food_sync_state")
      .select("started_at")
      .eq("singleton", true)
      .single();
    if (stateError) throw stateError;

    const startedAt = new Date(state.started_at);
    const day = localDateString();
    const reportFrom = historyMode ? requestedFrom : day;
    const reportTo = historyMode ? requestedTo : day;
    let cookie = await getVendSoftCookie(email, password);
    let report: Uint8Array;
    try {
      report = await downloadReport(cookie, reportFrom, reportTo);
    } catch (error) {
      if (!(error instanceof Error) || error.message !== "VENDSOFT_SESSION_EXPIRED") throw error;
      cookie = await getVendSoftCookie(email, password, true);
      report = await downloadReport(cookie, reportFrom, reportTo);
    }
    const rows = parseReport(report);

    const candidates = [];
    for (const row of rows) {
      const machine = parseMachine(row.Machine);
      const eventAt = parseVendSoftTimestamp(row.Timestamp);
      const selection = asText(row.Selection);
      const quantity = asNumber(row.Quantity) ?? 0;
      if (!machine.code || !eventAt || !selection || quantity <= 0) continue;
      if (!historyMode && new Date(eventAt) <= startedAt) continue;

      candidates.push({
        machine,
        eventAt,
        selection,
        quantity,
        location: asText(row.Location),
        product: asText(row.Product),
        unitPrice: asNumber(row.Price),
        totalAmount: asNumber(row.Total),
        creditCardAmount: asNumber(row["Credit Card"]),
      });
    }

    candidates.sort((a, b) => a.eventAt.localeCompare(b.eventAt));

    if (historyMode) {
      const { data: machines, error: machinesError } = await admin
        .from("machines")
        .select("id, evidence_number, machine_type");
      if (machinesError) throw machinesError;

      const machineByCode = new Map<string, Record<string, unknown>>(
        (machines || []).map((machine) => [asText(machine.evidence_number), machine]),
      );
      const machineIds = (machines || []).map((machine) => Number(machine.id)).filter(Boolean);
      const missingMachineExamples = [...new Map(
        candidates
          .filter((item) => !machineByCode.has(item.machine.code))
          .map((item) => [item.machine.code, { code: item.machine.code, name: item.machine.name }]),
      ).values()];

      if (!dryRun && missingMachineExamples.length) {
        const { data: legacyMachines, error: legacyMachinesError } = await admin
          .from("machines")
          .insert(missingMachineExamples.map((machine) => ({
            evidence_number: Number(machine.code),
            qr_token: `vendsoft-${machine.code}`,
            name: machine.name || `VendSoft automat ${machine.code}`,
            machine_type: "Legacy",
            status: "removed",
            active: false,
            sales_tracking_mode: "none",
            note: "Historický automat vytvořený při migraci prodejů z VendSoftu; není součástí aktivního provozu.",
          })))
          .select("id, evidence_number, machine_type");
        if (legacyMachinesError) throw legacyMachinesError;
        for (const machine of legacyMachines || []) {
          machineByCode.set(asText(machine.evidence_number), machine);
          machineIds.push(Number(machine.id));
        }
      }
      const { data: slots, error: slotsError } = await admin
        .from("machine_planogram_slots")
        .select("id, machine_id, slot_code, product_name, product_sku, customer_price_czk, dex_price_czk")
        .eq("active", true)
        .in("machine_id", machineIds);
      if (slotsError) throw slotsError;
      const slotByMachineAndCode = new Map(
        (slots || []).map((slot) => [`${slot.machine_id}|${asText(slot.slot_code)}`, slot]),
      );

      const rangeStart = `${reportFrom}T00:00:00+02:00`;
      const rangeEndDate = new Date(`${reportTo}T00:00:00Z`);
      rangeEndDate.setUTCDate(rangeEndDate.getUTCDate() + 1);
      const rangeEnd = rangeEndDate.toISOString();
      const { data: imaSales, error: imaSalesError } = await admin
        .from("telemetry_sales_events")
        .select("machine_id, source_event_at")
        .ilike("provider", "ima")
        .gte("source_event_at", rangeStart)
        .lt("source_event_at", rangeEnd)
        .order("source_event_at", { ascending: true });
      if (imaSalesError) throw imaSalesError;
      const firstImaAtByMachine = new Map<number, string>();
      for (const sale of imaSales || []) {
        const machineId = Number(sale.machine_id);
        if (!firstImaAtByMachine.has(machineId)) firstImaAtByMachine.set(machineId, sale.source_event_at);
      }

      const { data: existingImports, error: existingImportsError } = await admin
        .from("vendsoft_food_sales_imports")
        .select("event_key")
        .gte("source_event_at", rangeStart)
        .lt("source_event_at", rangeEnd);
      if (existingImportsError) throw existingImportsError;
      const existingKeys = new Set((existingImports || []).map((row) => row.event_key));

      const importRows = [];
      const telemetryRows = [];
      let duplicates = 0;
      let skippedDirectIma = 0;
      let unmatchedMachines = 0;
      let unmatchedSlots = 0;

      for (const item of candidates) {
        const eventKey = await sha256([
          item.machine.code, item.eventAt, item.selection, item.product, item.quantity,
          item.totalAmount ?? "", item.creditCardAmount ?? "",
        ].join("|"));
        if (existingKeys.has(eventKey)) {
          duplicates += 1;
          continue;
        }
        existingKeys.add(eventKey);

        const machine = machineByCode.get(item.machine.code);
        if (!machine) {
          unmatchedMachines += 1;
          importRows.push({
            event_key: eventKey, vendsoft_machine_code: item.machine.code,
            selection_code: item.selection, location_name: item.location || null,
            machine_name: item.machine.name || null, product_name: item.product || null,
            quantity: item.quantity, unit_price_czk: item.unitPrice,
            total_amount_czk: item.totalAmount, credit_card_amount_czk: item.creditCardAmount,
            source_event_at: item.eventAt, status: "unmatched_machine",
            note: "Historický import: automat s tímto VendSoft kódem nebyl nalezen.",
          });
          continue;
        }

        const firstImaAt = firstImaAtByMachine.get(Number(machine.id));
        if (firstImaAt && item.eventAt >= firstImaAt) {
          skippedDirectIma += 1;
          continue;
        }

        const slot = slotByMachineAndCode.get(`${machine.id}|${item.selection}`);
        if (!slot) unmatchedSlots += 1;
        importRows.push({
          event_key: eventKey, machine_id: machine.id, planogram_slot_id: slot?.id || null,
          vendsoft_machine_code: item.machine.code, selection_code: item.selection,
          location_name: item.location || null, machine_name: item.machine.name || null,
          product_name: item.product || slot?.product_name || null, quantity: item.quantity,
          unit_price_czk: item.unitPrice, total_amount_czk: item.totalAmount,
          credit_card_amount_czk: item.creditCardAmount, source_event_at: item.eventAt,
          status: "applied",
          note: slot ? "Historický import z VendSoftu; stav zásobníku nebyl změněn."
            : "Historický import: původní pozice již není v aktivním planogramu; prodej byl zachován bez skladové vazby.",
        });

        const totalAmount = item.totalAmount ?? (item.unitPrice == null ? null : item.unitPrice * item.quantity);
        telemetryRows.push({
          provider: "VendSoft", ingest_id: null, machine_id: machine.id,
          source_event_key: eventKey,
          source_location_name: item.location || null,
          source_machine_name: item.machine.name || null,
          planogram_slot_id: slot?.id || null, selection_code: item.selection,
          product_name: item.product || slot?.product_name || "Historický prodej",
          product_sku: slot?.product_sku || null,
          quantity: item.quantity, cash_quantity: 0, cashless_quantity: 0,
          unknown_payment_quantity: item.quantity,
          unit_price_czk: item.unitPrice ?? slot?.customer_price_czk ?? slot?.dex_price_czk ?? null,
          total_amount_czk: totalAmount, cash_amount_czk: null, cashless_amount_czk: null,
          unknown_payment_amount_czk: totalAmount, source_event_at: item.eventAt,
        });
      }

      if (!dryRun) {
        for (let offset = 0; offset < importRows.length; offset += 500) {
          const { error } = await admin.from("vendsoft_food_sales_imports")
            .upsert(importRows.slice(offset, offset + 500), { onConflict: "event_key", ignoreDuplicates: true });
          if (error) throw error;
        }
        for (let offset = 0; offset < telemetryRows.length; offset += 500) {
          const { error } = await admin.from("telemetry_sales_events")
            .upsert(telemetryRows.slice(offset, offset + 500), {
              onConflict: "provider,source_event_key",
              ignoreDuplicates: true,
            });
          if (error) throw error;
        }
      }

      return json({
        ok: true, mode: "history", dry_run: dryRun, report_from: reportFrom, report_to: reportTo,
        report_rows: rows.length, candidates: candidates.length, importable: telemetryRows.length,
        duplicates, skipped_direct_ima: skippedDirectIma,
        unmatched_machines: unmatchedMachines, unmatched_slots: unmatchedSlots,
        unmatched_machine_examples: missingMachineExamples.slice(0, 50),
      });
    }

    // VendSoft is only a temporary fallback for food machines that do not yet
    // deliver usable sales through IMA. A machine is protected as soon as it
    // has produced at least one direct IMA sale and its IMA connection is
    // currently fresh. This prevents the same vend from decrementing stock a
    // second time when it later appears in the VendSoft transaction report.
    const freshImaCutoff = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const { data: freshImaStates, error: freshImaStatesError } = await admin
      .from("machine_telemetry_state")
      .select("machine_id")
      .ilike("provider", "ima")
      .gte("last_seen_at", freshImaCutoff);
    if (freshImaStatesError) throw freshImaStatesError;

    const freshImaMachineIds = [...new Set(
      (freshImaStates || []).map((row) => Number(row.machine_id)).filter(Boolean),
    )];
    const directImaMachineIds = new Set<number>();
    if (freshImaMachineIds.length) {
      const { data: directImaSales, error: directImaSalesError } = await admin
        .from("telemetry_sales_events")
        .select("machine_id")
        .ilike("provider", "ima")
        .in("machine_id", freshImaMachineIds)
        .gte("source_event_at", startedAt.toISOString());
      if (directImaSalesError) throw directImaSalesError;
      (directImaSales || []).forEach((row) => directImaMachineIds.add(Number(row.machine_id)));
    }

    const protectedVendSoftCodes = new Set<string>();
    if (directImaMachineIds.size) {
      const { data: protectedMachines, error: protectedMachinesError } = await admin
        .from("machines")
        .select("id, evidence_number")
        .in("id", [...directImaMachineIds]);
      if (protectedMachinesError) throw protectedMachinesError;
      (protectedMachines || []).forEach((machine) => {
        const code = asText(machine.evidence_number);
        if (code) protectedVendSoftCodes.add(code);
      });
    }

    let imported = 0;
    let skipped = 0;
    let skippedDirectIma = 0;
    let unmatched = 0;
    let lastSeenEventAt: string | null = null;

    for (const item of candidates) {
      if (protectedVendSoftCodes.has(item.machine.code)) {
        skipped += 1;
        skippedDirectIma += 1;
        if (!lastSeenEventAt || item.eventAt > lastSeenEventAt) lastSeenEventAt = item.eventAt;
        continue;
      }

      const eventKey = await sha256([
        item.machine.code,
        item.eventAt,
        item.selection,
        item.product,
        item.quantity,
        item.totalAmount ?? "",
        item.creditCardAmount ?? "",
      ].join("|"));

      const { data, error } = await admin.rpc("apply_vendsoft_food_sale", {
        p_event_key: eventKey,
        p_vendsoft_machine_code: item.machine.code,
        p_selection_code: item.selection,
        p_location_name: item.location || null,
        p_machine_name: item.machine.name || null,
        p_product_name: item.product || null,
        p_quantity: item.quantity,
        p_unit_price_czk: item.unitPrice,
        p_total_amount_czk: item.totalAmount,
        p_credit_card_amount_czk: item.creditCardAmount,
        p_source_event_at: item.eventAt,
      });

      if (error) throw error;
      const status = String(data?.status || "");
      if (status === "applied") imported += 1;
      else if (status === "duplicate" || status === "ignored_non_food") skipped += 1;
      else unmatched += 1;
      if (!lastSeenEventAt || item.eventAt > lastSeenEventAt) lastSeenEventAt = item.eventAt;
    }

    const successAt = new Date().toISOString();
    const { error: updateError } = await admin
      .from("vendsoft_food_sync_state")
      .update({
        last_success_at: successAt,
        last_seen_event_at: lastSeenEventAt,
        last_imported_count: imported,
        last_skipped_count: skipped,
        last_unmatched_count: unmatched,
        last_error: null,
        updated_at: successAt,
      })
      .eq("singleton", true);
    if (updateError) throw updateError;

    return json({
      ok: true,
      report_day: day,
      report_rows: rows.length,
      candidates: candidates.length,
      imported,
      skipped,
      skipped_direct_ima: skippedDirectIma,
      unmatched,
      last_seen_event_at: lastSeenEventAt,
    });
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : typeof error === "object" && error !== null
        ? JSON.stringify(error)
        : String(error || "Unknown VendSoft sync error.");
    const failedAt = new Date().toISOString();
    await admin
      .from("vendsoft_food_sync_state")
      .update({ last_error: message, updated_at: failedAt })
      .eq("singleton", true);
    return json({ error: message }, 500);
  }
});
