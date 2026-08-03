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

function pragueOffsetForIsoDate(value = "") {
  const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!match) return "";
  return pragueOffsetForDateParts(Number(match[1]), Number(match[2]), Number(match[3]));
}

function parseWrapperTimestamp(value: string, offset = "", fallbackOffset = "") {
  const normalizedOffset = normalizeOffset(offset);
  const normalizedFallbackOffset = normalizeOffset(fallbackOffset);
  const rawEffectiveOffset = normalizedOffset === "+00:00" && normalizedFallbackOffset
    ? normalizedFallbackOffset
    : normalizedOffset || normalizedFallbackOffset;
  const pragueOffset = pragueOffsetForIsoDate(value);
  const effectiveOffset = pragueOffset && (!rawEffectiveOffset || rawEffectiveOffset === "+00:00" || rawEffectiveOffset === "+01:00")
    ? pragueOffset
    : rawEffectiveOffset;
  return parseTimestamp(value, effectiveOffset);
}

function pragueOffsetForDateParts(year: number, month: number, day: number) {
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

function pragueOffsetForDexDate(dateValue = "") {
  const match = String(dateValue).match(/^(\d{2})(\d{2})(\d{2})$/);
  if (!match) return "+01:00";
  const year = Number(match[1]) >= 70 ? 1900 + Number(match[1]) : 2000 + Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  return pragueOffsetForDateParts(year, month, day);
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

function parsePaymentCounter(record: DexRecord | null) {
  if (!record) return null;
  return {
    amount: Number(record.fields[0] || 0),
    quantity: Number(record.fields[1] || 0),
    raw: record.raw,
  };
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
  const ca2 = firstRecord(records, "CA2");
  const da2 = firstRecord(records, "DA2");
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
      current.count_total = Number(record.fields[0] || record.fields[2] || 0);
      current.value_total = Number(record.fields[1] || record.fields[3] || 0);
      current.count_cash = 0;
      current.count_cashless = 0;
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
    payment_counters: {
      total: parsePaymentCounter(va1),
      cash: parsePaymentCounter(ca2),
      cashless: parsePaymentCounter(da2),
    },
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

function convertRecipeQuantityToContainerUnit(quantity: number, recipeUnit: unknown, containerUnit: unknown) {
  const from = String(recipeUnit || "").trim().toLowerCase();
  const to = String(containerUnit || "").trim().toLowerCase();
  if (!from || !to || from === to) return quantity;
  if (from === "kg" && to === "g") return quantity * 1000;
  if (from === "g" && to === "kg") return quantity / 1000;
  if (from === "l" && to === "ml") return quantity * 1000;
  if (from === "ml" && to === "l") return quantity / 1000;
  return quantity;
}

async function applyCoffeeRecipeDepletion(
  adminClient: ReturnType<typeof createClient>,
  params: {
    machineId: number;
    deltas: Record<string, unknown>[];
  },
) {
  const positiveDeltas = params.deltas
    .map((delta) => ({
      selection: normalizeSelectionCode(delta.selection_code),
      quantity: Number(delta.vend_delta || 0),
    }))
    .filter((delta) => delta.selection && delta.quantity > 0);

  if (!positiveDeltas.length) return [];

  const selections = uniq(positiveDeltas.map((delta) => delta.selection));
  const { data: buttons, error: buttonsError } = await adminClient
    .from("machine_coffee_buttons")
    .select("id, selection_code")
    .eq("machine_id", params.machineId)
    .eq("active", true)
    .in("selection_code", selections);

  if (buttonsError) throw buttonsError;
  if (!buttons?.length) return [];

  const deltaByButtonId = new Map<number, number>();
  for (const button of buttons) {
    const selection = normalizeSelectionCode(button.selection_code);
    const delta = positiveDeltas.find((item) => item.selection === selection);
    if (delta) deltaByButtonId.set(Number(button.id), delta.quantity);
  }

  const buttonIds = buttons.map((button) => Number(button.id)).filter(Boolean);
  const { data: recipeItems, error: recipeError } = await adminClient
    .from("machine_coffee_recipe_items")
    .select("coffee_button_id, coffee_container_id, quantity_per_vend, unit")
    .eq("machine_id", params.machineId)
    .eq("active", true)
    .in("coffee_button_id", buttonIds);

  if (recipeError) throw recipeError;
  if (!recipeItems?.length) return [];

  const containerIds = uniq(recipeItems.map((item) => item.coffee_container_id)).map(Number).filter(Boolean);
  if (!containerIds.length) return [];

  const { data: containers, error: containersError } = await adminClient
    .from("machine_coffee_containers")
    .select("id, current_quantity, unit")
    .eq("machine_id", params.machineId)
    .eq("active", true)
    .in("id", containerIds);

  if (containersError) throw containersError;

  const containerMap = new Map((containers || []).map((container) => [Number(container.id), container]));
  const usageByContainer = new Map<number, number>();

  for (const recipeItem of recipeItems) {
    const buttonDelta = deltaByButtonId.get(Number(recipeItem.coffee_button_id)) || 0;
    const containerId = Number(recipeItem.coffee_container_id || 0);
    const container = containerMap.get(containerId);
    if (!buttonDelta || !container) continue;
    const quantityPerVend = Number(recipeItem.quantity_per_vend || 0);
    if (!Number.isFinite(quantityPerVend) || quantityPerVend <= 0) continue;
    const usage = convertRecipeQuantityToContainerUnit(quantityPerVend * buttonDelta, recipeItem.unit, container.unit);
    usageByContainer.set(containerId, (usageByContainer.get(containerId) || 0) + usage);
  }

  const applied: Record<string, unknown>[] = [];
  for (const [containerId, usage] of usageByContainer.entries()) {
    const container = containerMap.get(containerId);
    if (!container || usage <= 0) continue;
    const currentQuantity = Number(container.current_quantity ?? 0);
    const nextQuantity = Math.max(0, currentQuantity - usage);
    const { error: updateError } = await adminClient
      .from("machine_coffee_containers")
      .update({ current_quantity: nextQuantity, updated_at: new Date().toISOString() })
      .eq("id", containerId);

    if (updateError) throw updateError;
    applied.push({
      coffee_container_id: containerId,
      previous_quantity: currentQuantity,
      used_quantity: Math.round(usage * 1000) / 1000,
      next_quantity: Math.round(nextQuantity * 1000) / 1000,
      unit: container.unit || null,
    });
  }

  return applied;
}

async function applyTelemetryStockDepletion(
  adminClient: ReturnType<typeof createClient>,
  saleEvents: Record<string, unknown>[],
) {
  const saleEventIds = saleEvents.map((sale) => Number(sale.id || 0)).filter(Boolean);
  if (!saleEventIds.length) return [];
  const { data, error } = await adminClient.rpc("apply_telemetry_stock_depletion", { p_sale_event_ids: saleEventIds });
  if (error) throw error;
  return data || [];
  /* Legacy client-side implementation retained below for rollback readability.
  const applied: Record<string, unknown>[] = [];
  for (const sale of saleEvents) {
    const saleId = Number(sale.id || 0);
    const machineId = Number(sale.machine_id || 0);
    const productSku = String(sale.product_sku || "").trim();
    const quantity = Number(sale.quantity || 0);
    if (!saleId || !machineId || !productSku || quantity <= 0) continue;

    const [{ data: product }, { data: location }] = await Promise.all([
      adminClient.from("products").select("id").eq("sku", productSku).maybeSingle(),
      adminClient.from("stock_locations").select("id").eq("location_type", "machine").eq("machine_id", machineId).maybeSingle(),
    ]);
    if (!product?.id || !location?.id) continue;

    const { data: balances, error: balancesError } = await adminClient
      .from("stock_location_balances")
      .select("batch_id, quantity_on_hand, inventory_batches(use_by_date,best_before_date)")
      .eq("stock_location_id", location.id)
      .eq("product_id", product.id)
      .gt("quantity_on_hand", 0);
    if (balancesError) throw balancesError;
    const ordered = [...(balances || [])].sort((a, b) => {
      const aExpiry = a.inventory_batches?.use_by_date || a.inventory_batches?.best_before_date || "9999-12-31";
      const bExpiry = b.inventory_batches?.use_by_date || b.inventory_batches?.best_before_date || "9999-12-31";
      return String(aExpiry).localeCompare(String(bExpiry));
    });
    let remaining = quantity;
    const movements: Record<string, unknown>[] = [];
    for (const balance of ordered) {
      if (remaining <= 0.0001) break;
      const moved = Math.min(remaining, Number(balance.quantity_on_hand || 0));
      if (moved <= 0) continue;
      movements.push({
        product_id: product.id, batch_id: balance.batch_id || null,
        from_stock_location_id: location.id, to_stock_location_id: null,
        movement_type: "sale", quantity_base_units: moved,
        reference_type: "telemetry_sale", reference_id: `telemetry-sale:${saleId}`,
        note: `Automatický odečet telemetrického prodeje #${saleId}`,
      });
      remaining = Math.round((remaining - moved) * 1000) / 1000;
    }
    if (!movements.length) continue;
    const { error: movementError } = await adminClient.rpc("apply_stock_movements_v13", { movement_rows: movements });
    if (movementError) throw movementError;
    applied.push({ sale_event_id: saleId, product_id: product.id, quantity: quantity - remaining });
  }
  return applied;
  */
}

async function applyAtomicCoffeeRecipeDepletion(
  adminClient: ReturnType<typeof createClient>,
  saleEvents: Record<string, unknown>[],
) {
  const saleEventIds = saleEvents.map((sale) => Number(sale.id || 0)).filter(Boolean);
  if (!saleEventIds.length) return { inserted: 0, containers_updated: 0 };
  const { data, error } = await adminClient.rpc("apply_telemetry_coffee_depletion", { p_sale_event_ids: saleEventIds });
  if (error) throw error;
  return data || { inserted: 0, containers_updated: 0 };
}

async function reconcilePendingUnpaidDispenses(
  adminClient: ReturnType<typeof createClient>,
  params: {
    provider: string;
    machineId: number;
    beforeEventAt: string;
    cashQuantity: number;
    cashlessQuantity: number;
    cashAmount: number;
    cashlessAmount: number;
  },
) {
  const cashQuantity = Math.max(0, Math.floor(params.cashQuantity));
  const cashlessQuantity = Math.max(0, Math.floor(params.cashlessQuantity));
  const paymentQuantity = cashQuantity + cashlessQuantity;
  if (!paymentQuantity || paymentQuantity > 24) return [];

  const { data: pending, error: pendingError } = await adminClient
    .from("telemetry_sales_events")
    .select("id,quantity,unit_price_czk,total_amount_czk,cash_quantity,cashless_quantity,unknown_payment_quantity,unpaid_dispense_quantity,cash_amount_czk,cashless_amount_czk,unknown_payment_amount_czk")
    .eq("provider", params.provider)
    .eq("machine_id", params.machineId)
    .gt("unpaid_dispense_quantity", 0)
    .lt("source_event_at", params.beforeEventAt)
    .order("source_event_at", { ascending: true })
    .order("id", { ascending: true })
    .limit(100);
  if (pendingError) throw pendingError;

  const pendingById = new Map<number, Record<string, unknown>>();
  const unpaidUnits: Array<{ selection: string; priceAmount: number }> = [];
  for (const sale of pending || []) {
    const saleId = Number(sale.id || 0);
    const unpaid = Math.max(0, Math.floor(Number(sale.unpaid_dispense_quantity || 0)));
    const unitPrice = Number(sale.unit_price_czk || 0);
    if (!saleId || !unpaid || unitPrice <= 0) continue;
    pendingById.set(saleId, sale);
    for (let index = 0; index < unpaid && unpaidUnits.length < 24; index += 1) {
      unpaidUnits.push({ selection: String(saleId), priceAmount: priceToPaymentAmount(unitPrice) });
    }
    if (unpaidUnits.length >= 24) break;
  }

  const assignment = findPaymentUnitAssignments(unpaidUnits, {
    cashQuantity,
    cashAmount: Math.round(params.cashAmount),
    cashlessQuantity,
    cashlessAmount: Math.round(params.cashlessAmount),
  });
  if (!assignment) return [];

  const allocations = new Map<number, { cash: number; cashless: number }>();
  unpaidUnits.forEach((unit, index) => {
    const saleId = Number(unit.selection);
    const current = allocations.get(saleId) || { cash: 0, cashless: 0 };
    if (assignment.cash.has(index)) current.cash += 1;
    if (assignment.cashless.has(index)) current.cashless += 1;
    allocations.set(saleId, current);
  });

  const reconciled: Record<string, unknown>[] = [];
  for (const [saleId, allocated] of allocations) {
    if (!allocated.cash && !allocated.cashless) continue;
    const sale = pendingById.get(saleId);
    if (!sale) continue;
    const unpaid = Number(sale.unpaid_dispense_quantity || 0);
    const unitPrice = Number(sale.unit_price_czk || 0);
    const nextUnpaid = Math.max(0, unpaid - allocated.cash - allocated.cashless);
    const nextCashQuantity = Number(sale.cash_quantity || 0) + allocated.cash;
    const nextCashlessQuantity = Number(sale.cashless_quantity || 0) + allocated.cashless;
    const unknownQuantity = Number(sale.unknown_payment_quantity || 0);
    const patch = {
      cash_quantity: nextCashQuantity,
      cashless_quantity: nextCashlessQuantity,
      unpaid_dispense_quantity: nextUnpaid,
      cash_amount_czk: Math.round((Number(sale.cash_amount_czk || 0) + allocated.cash * unitPrice) * 100) / 100,
      cashless_amount_czk: Math.round((Number(sale.cashless_amount_czk || 0) + allocated.cashless * unitPrice) * 100) / 100,
      total_amount_czk: Math.round((nextCashQuantity + nextCashlessQuantity + unknownQuantity) * unitPrice * 100) / 100,
    };
    const { error: updateError } = await adminClient.from("telemetry_sales_events").update(patch).eq("id", saleId);
    if (updateError) throw updateError;
    reconciled.push({ id: saleId, cash_quantity: allocated.cash, cashless_quantity: allocated.cashless });
  }
  return reconciled;
}

async function applyPlanogramDepletion(
  adminClient: ReturnType<typeof createClient>,
  params: {
    provider: string;
    machineId: number;
    ingestId: number | null;
    counters: Record<string, unknown>[];
    eventAt: string;
    paymentCounters?: Record<string, unknown> | null;
    previousPaymentCounters?: Record<string, unknown> | null;
  },
) {
  const selectionTotals = new Map<string, { selection: string; cashCount: number; cashlessCount: number; totalCount: number; eventAt: string }>();

  params.counters.forEach((counter) => {
    const selection = normalizeSelectionCode(counter.selection);
    if (!selection) return;
    const cashCount = numericCounter(counter.count_cash);
    const cashlessCount = numericCounter(counter.count_cashless);
    const explicitTotalCount = numericCounter(counter.count_total);
    const totalCount = explicitTotalCount > 0 ? explicitTotalCount : cashCount + cashlessCount;
    if (totalCount <= 0) return;
    const current = selectionTotals.get(selection);
    if (!current || totalCount > current.totalCount) {
      selectionTotals.set(selection, {
        selection,
        cashCount,
        cashlessCount,
        totalCount,
        eventAt: String(counter.last_vend_at || params.eventAt),
      });
    }
  });

  if (!selectionTotals.size) return [];

  const { data: slots, error: slotsError } = await adminClient
    .from("machine_planogram_slots")
    .select("id, slot_code, product_name, product_sku, current_units, capacity_units, customer_price_czk, dex_price_czk, planned_product_name, planned_product_sku, planned_price_czk, changeover_old_units, changeover_new_units, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, subsidy_amount_czk, subsidy_payer, subsidy_billing_enabled, subsidy_note")
    .eq("machine_id", params.machineId)
    .eq("active", true);

  if (slotsError) throw slotsError;
  if (!slots?.length) return [];

  const paymentDelta = getPaymentDelta(params.previousPaymentCounters, params.paymentCounters);
  const planned: Array<{
    slot: Record<string, unknown>;
    counter: { selection: string; cashCount: number; cashlessCount: number; totalCount: number; eventAt: string };
    previous: Record<string, unknown> | null;
    isInitialCounter: boolean;
    selection: string;
    previousTotal: number;
    delta: number;
  }> = [];

  for (const slot of slots) {
    const selection = normalizeSelectionCode(slot.slot_code);
    const counter = selectionTotals.get(selection);
    if (!counter) continue;

    const { data: previous, error: previousError } = await adminClient
      .from("telemetry_planogram_counters")
      .select("last_total_count, last_cash_count, last_cashless_count, last_ingest_id")
      .eq("provider", params.provider)
      .eq("machine_id", params.machineId)
      .eq("planogram_slot_id", slot.id)
      .eq("selection_code", selection)
      .maybeSingle();

    if (previousError) throw previousError;

    const isManualBaseline = Boolean(previous) && !previous?.last_ingest_id;
    const isInitialCounter = !previous || isManualBaseline;
    const previousTotal = Number(previous?.last_total_count ?? counter.totalCount);
    const delta = isInitialCounter ? 0 : Math.max(0, counter.totalCount - previousTotal);
    planned.push({ slot, counter, previous, isInitialCounter, selection, previousTotal, delta });
  }

  const totalVendDelta = planned.reduce((sum, item) => sum + (item.isInitialCounter ? 0 : item.delta), 0);
  const availablePaymentAmounts = slots
    .map((slot) => priceToPaymentAmount(Number(slot.customer_price_czk ?? slot.dex_price_czk ?? 0)))
    .filter((amount) => amount > 0);
  const paymentAllocations = allocatePaymentDeltas(planned, totalVendDelta, paymentDelta, availablePaymentAmounts);
  const allocatedCash = [...paymentAllocations.values()].reduce((sum, allocation) => sum + allocation.cashDelta, 0);
  const allocatedCashless = [...paymentAllocations.values()].reduce((sum, allocation) => sum + allocation.cashlessDelta, 0);
  const slotPriceBySelection = new Map(planned.map((item) => [
    item.selection,
    priceToPaymentAmount(Number(item.slot.customer_price_czk ?? item.slot.dex_price_czk ?? 0)),
  ]));
  const allocatedCashAmount = [...paymentAllocations.entries()].reduce(
    (sum, [selection, allocation]) => sum + allocation.cashDelta * Number(slotPriceBySelection.get(selection) || 0),
    0,
  );
  const allocatedCashlessAmount = [...paymentAllocations.entries()].reduce(
    (sum, [selection, allocation]) => sum + allocation.cashlessDelta * Number(slotPriceBySelection.get(selection) || 0),
    0,
  );
  const applied: Record<string, unknown>[] = [];

  for (const item of planned) {
    const { slot, counter, isInitialCounter, previousTotal, delta, selection } = item;
    const { cashDelta, cashlessDelta, unknownPaymentDelta, unpaidDispenseDelta } = paymentAllocations.get(selection) ||
      { cashDelta: 0, cashlessDelta: 0, unknownPaymentDelta: delta, unpaidDispenseDelta: 0 };

    const { error: counterError } = await adminClient
      .from("telemetry_planogram_counters")
      .upsert({
        provider: params.provider,
        machine_id: params.machineId,
        planogram_slot_id: slot.id,
        selection_code: selection,
        last_total_count: counter.totalCount,
        last_cash_count: counter.cashCount,
        last_cashless_count: counter.cashlessCount,
        last_event_at: counter.eventAt,
        last_ingest_id: params.ingestId,
      }, { onConflict: "provider,machine_id,planogram_slot_id,selection_code" });

    if (counterError) throw counterError;
    if (isInitialCounter) {
      applied.push({
        slot_id: slot.id,
        selection_code: selection,
        previous_total: previous ? previousTotal : null,
        current_total: counter.totalCount,
        vend_delta: 0,
        baseline_initialized: true,
        manual_baseline: isManualBaseline,
        product_name: slot.product_name ?? null,
        product_sku: slot.product_sku ?? null,
      });
      continue;
    }
    if (delta <= 0) continue;

    const oldUnits = Math.max(0, Number(slot.changeover_old_units ?? slot.current_units ?? 0));
    const newUnits = Math.max(0, Number(slot.changeover_new_units ?? 0));
    const mixedChangeover = newUnits > 0 && String(slot.planned_product_sku || '') !== '';
    const oldSold = mixedChangeover ? Math.min(delta, oldUnits) : delta;
    const newSold = mixedChangeover ? Math.max(0, delta - oldSold) : 0;
    const allocate = (value: number, quantity: number) => delta > 0 ? Math.round(value * quantity / delta * 1000) / 1000 : 0;
    const saleParts = [
      oldSold > 0 ? {
        event_part: 1, product_name: slot.product_name ?? null, product_sku: slot.product_sku ?? null,
        quantity: oldSold, cash_quantity: allocate(cashDelta, oldSold),
        cashless_quantity: allocate(cashlessDelta, oldSold), unknown_payment_quantity: allocate(unknownPaymentDelta, oldSold),
        unpaid_dispense_quantity: allocate(unpaidDispenseDelta, oldSold),
        unit_price_czk: Number(slot.customer_price_czk ?? slot.dex_price_czk ?? 0) || null,
      } : null,
      newSold > 0 ? {
        event_part: 2, product_name: slot.planned_product_name ?? null, product_sku: slot.planned_product_sku ?? null,
        quantity: newSold, cash_quantity: allocate(cashDelta, newSold),
        cashless_quantity: allocate(cashlessDelta, newSold), unknown_payment_quantity: allocate(unknownPaymentDelta, newSold),
        unpaid_dispense_quantity: allocate(unpaidDispenseDelta, newSold),
        unit_price_czk: Number(slot.planned_price_czk ?? slot.customer_price_czk ?? slot.dex_price_czk ?? 0) || null,
      } : null,
    ].filter(Boolean).map((part: any) => ({
        provider: params.provider,
        ingest_id: params.ingestId,
        machine_id: params.machineId,
        planogram_slot_id: slot.id,
        selection_code: selection,
        ...part,
        total_amount_czk: part.unit_price_czk
          ? Math.round((part.cash_quantity + part.cashless_quantity + part.unknown_payment_quantity) * part.unit_price_czk * 100) / 100
          : null,
        cash_amount_czk: part.unit_price_czk ? Math.round(part.cash_quantity * part.unit_price_czk * 100) / 100 : null,
        cashless_amount_czk: part.unit_price_czk ? Math.round(part.cashless_quantity * part.unit_price_czk * 100) / 100 : null,
        unknown_payment_amount_czk: part.unit_price_czk ? Math.round(part.unknown_payment_quantity * part.unit_price_czk * 100) / 100 : null,
        source_event_at: counter.eventAt,
      }));
    const { data: savedSaleParts, error: salesEventError } = await adminClient
      .from("telemetry_sales_events")
      .upsert(saleParts, { onConflict: "provider,ingest_id,machine_id,planogram_slot_id,selection_code,event_part" })
      .select("id,machine_id,product_sku,quantity");

    if (salesEventError) throw salesEventError;
    await applyAtomicCoffeeRecipeDepletion(adminClient, savedSaleParts || []);
    await applyTelemetryStockDepletion(adminClient, savedSaleParts || []);

    const currentUnits = slot.current_units == null ? null : Number(slot.current_units);
    const capacityUnits = slot.capacity_units == null ? null : Number(slot.capacity_units);
    const nextOldUnits = mixedChangeover ? Math.max(0, oldUnits - oldSold) : null;
    const nextNewUnits = mixedChangeover ? Math.max(0, newUnits - newSold) : null;
    const nextUnits = currentUnits == null ? null : Math.max(0, currentUnits - oldSold - newSold);
    const nextFillPercent = nextUnits != null && capacityUnits && capacityUnits > 0
      ? Math.round((nextUnits / capacityUnits) * 10000) / 100
      : null;

    const slotPatch: Record<string, unknown> = {};
    if (nextUnits != null) slotPatch.current_units = nextUnits;
    if (nextFillPercent != null) slotPatch.fill_percent = nextFillPercent;
    if (mixedChangeover) {
      slotPatch.changeover_old_units = nextOldUnits;
      slotPatch.changeover_new_units = nextNewUnits;
      if (nextOldUnits === 0) {
        slotPatch.product_sku = slot.planned_product_sku;
        slotPatch.product_name = slot.planned_product_name || slot.product_name;
        if (slot.planned_price_czk != null) {
          slotPatch.price_czk = slot.planned_price_czk;
          slotPatch.customer_price_czk = slot.planned_price_czk;
          slotPatch.dex_price_czk = slot.planned_price_czk;
        }
        slotPatch.planned_product_sku = null;
        slotPatch.planned_product_name = null;
        slotPatch.planned_price_czk = null;
        slotPatch.changeover_old_units = null;
        slotPatch.changeover_new_units = null;
        slotPatch.changeover_started_at = null;
      }
    }

    if (Object.keys(slotPatch).length) {
      const { error: updateError } = await adminClient
        .from("machine_planogram_slots")
        .update(slotPatch)
        .eq("id", slot.id);

      if (updateError) throw updateError;
    }

    const settlementType = String(
      slot.settlement_type || (Number(slot.subsidy_amount_czk || 0) > 0 ? "subsidy_receivable" : "none"),
    );
    const settlementAmount = Number(slot.settlement_amount_czk ?? slot.subsidy_amount_czk ?? 0);

    if (settlementType !== "none" && settlementAmount > 0) {
      const direction = settlementType === "partner_fee_payable" ? "payable" : "receivable";
      const { error: settlementError } = await adminClient
        .from("telemetry_financial_settlements")
        .upsert({
          provider: params.provider,
          ingest_id: params.ingestId,
          machine_id: params.machineId,
          planogram_slot_id: slot.id,
          selection_code: selection,
          product_name: slot.product_name ?? null,
          product_sku: slot.product_sku ?? null,
          settlement_type: settlementType,
          direction,
          quantity: delta,
          amount_per_unit_czk: settlementAmount,
          total_amount_czk: Math.round(delta * settlementAmount * 100) / 100,
          customer_price_czk: slot.customer_price_czk ?? null,
          partner: slot.settlement_partner || slot.subsidy_payer || null,
          billing_enabled: slot.settlement_billing_enabled === true || slot.subsidy_billing_enabled === true,
          source_event_at: counter.eventAt,
          note: slot.settlement_note || slot.subsidy_note || null,
        }, { onConflict: "provider,ingest_id,machine_id,planogram_slot_id,selection_code,settlement_type" });

      if (settlementError) throw settlementError;
    }

    applied.push({
      slot_id: slot.id,
      selection_code: selection,
      previous_total: previousTotal,
      current_total: counter.totalCount,
      vend_delta: delta,
      cash_delta: cashDelta,
      cashless_delta: cashlessDelta,
      unknown_payment_delta: unknownPaymentDelta,
      unpaid_dispense_delta: unpaidDispenseDelta,
      product_name: slot.product_name ?? null,
      product_sku: slot.product_sku ?? null,
      unit_price_czk: Number.isFinite(unitPrice) && unitPrice > 0 ? unitPrice : null,
      total_amount_czk: Number.isFinite(unitPrice) && unitPrice > 0
        ? Math.round((cashDelta + cashlessDelta + unknownPaymentDelta) * unitPrice * 100) / 100
        : null,
      next_units: nextUnits,
      next_fill_percent: nextFillPercent,
      settlement_type: settlementType,
      settlement_amount_czk: settlementAmount,
    });
  }

  const reconciledPayments = await reconcilePendingUnpaidDispenses(adminClient, {
    provider: params.provider,
    machineId: params.machineId,
    beforeEventAt: params.eventAt,
    cashQuantity: Math.max(0, paymentDelta.cashQuantity - allocatedCash),
    cashlessQuantity: Math.max(0, paymentDelta.cashlessQuantity - allocatedCashless),
    cashAmount: Math.max(0, paymentDelta.cashAmount - allocatedCashAmount),
    cashlessAmount: Math.max(0, paymentDelta.cashlessAmount - allocatedCashlessAmount),
  });
  if (reconciledPayments.length) {
    // A late payment turns a possible stock loss into a confirmed sale. Apply only
    // the newly confirmed inventory delta; the RPCs are incremental and idempotent.
    await applyAtomicCoffeeRecipeDepletion(adminClient, reconciledPayments);
    await applyTelemetryStockDepletion(adminClient, reconciledPayments);
    applied.push({ reconciled_pending_payments: reconciledPayments });
  }

  return applied;
}

function nestedNumber(source: Record<string, unknown> | null | undefined, key: string, nestedKey: string) {
  const value = source?.[key];
  if (!value || typeof value !== "object") return 0;
  return Number((value as Record<string, unknown>)[nestedKey] || 0);
}

function getPaymentDelta(previous: Record<string, unknown> | null | undefined, current: Record<string, unknown> | null | undefined) {
  const cashQuantity = Math.max(0, nestedNumber(current, "cash", "quantity") - nestedNumber(previous, "cash", "quantity"));
  const cashlessQuantity = Math.max(0, nestedNumber(current, "cashless", "quantity") - nestedNumber(previous, "cashless", "quantity"));
  const cashAmount = Math.max(0, nestedNumber(current, "cash", "amount") - nestedNumber(previous, "cash", "amount"));
  const cashlessAmount = Math.max(0, nestedNumber(current, "cashless", "amount") - nestedNumber(previous, "cashless", "amount"));
  return { cashQuantity, cashlessQuantity, cashAmount, cashlessAmount, totalQuantity: cashQuantity + cashlessQuantity };
}

function priceToPaymentAmount(priceCzk: number) {
  return Number.isFinite(priceCzk) && priceCzk > 0 ? Math.round(priceCzk * 100) : 0;
}

function emptyPaymentAllocation() {
  return { cashDelta: 0, cashlessDelta: 0, unknownPaymentDelta: 0, unpaidDispenseDelta: 0 };
}

function findPaymentUnitAssignments(
  saleUnits: Array<{ selection: string; priceAmount: number }>,
  target: { cashQuantity: number; cashAmount: number; cashlessQuantity: number; cashlessAmount: number },
) {
  const cashQuantity = Math.max(0, Math.round(target.cashQuantity));
  const cashlessQuantity = Math.max(0, Math.round(target.cashlessQuantity));
  const cashAmount = Math.max(0, Math.round(target.cashAmount));
  const cashlessAmount = Math.max(0, Math.round(target.cashlessAmount));
  if (cashQuantity + cashlessQuantity > saleUnits.length || saleUnits.length > 24) return null;

  type Assignment = { cash: Set<number>; cashless: Set<number> };
  let states = new Map<string, Assignment>([["0:0:0:0", { cash: new Set(), cashless: new Set() }]]);
  saleUnits.forEach((unit, index) => {
    const next = new Map(states);
    for (const [key, assignment] of states) {
      const [cashCount, cashTotal, cashlessCount, cashlessTotal] = key.split(":").map(Number);
      if (cashCount < cashQuantity && cashTotal + unit.priceAmount <= cashAmount) {
        const nextKey = `${cashCount + 1}:${cashTotal + unit.priceAmount}:${cashlessCount}:${cashlessTotal}`;
        if (!next.has(nextKey)) next.set(nextKey, { cash: new Set([...assignment.cash, index]), cashless: new Set(assignment.cashless) });
      }
      if (cashlessCount < cashlessQuantity && cashlessTotal + unit.priceAmount <= cashlessAmount) {
        const nextKey = `${cashCount}:${cashTotal}:${cashlessCount + 1}:${cashlessTotal + unit.priceAmount}`;
        if (!next.has(nextKey)) next.set(nextKey, { cash: new Set(assignment.cash), cashless: new Set([...assignment.cashless, index]) });
      }
    }
    states = next;
  });
  return states.get(`${cashQuantity}:${cashAmount}:${cashlessQuantity}:${cashlessAmount}`) || null;
}

function canComposePaymentAmount(quantity: number, targetAmount: number, availableAmounts: number[]) {
  const targetQuantity = Math.round(quantity);
  const target = Math.round(targetAmount);
  if (targetQuantity === 0) return target === 0;
  if (targetQuantity < 0 || target <= 0) return false;

  const prices = [...new Set(availableAmounts.map(Math.round).filter((amount) => amount > 0 && amount <= target))];
  if (!prices.length) return false;

  let reachable = new Set([0]);
  for (let count = 0; count < targetQuantity; count += 1) {
    const next = new Set<number>();
    for (const subtotal of reachable) {
      for (const price of prices) {
        const total = subtotal + price;
        if (total <= target) next.add(total);
      }
    }
    reachable = next;
    if (!reachable.size) return false;
  }
  return reachable.has(target);
}

function allocatePaymentDeltas(
  planned: Array<{
    slot: Record<string, unknown>;
    isInitialCounter: boolean;
    selection: string;
    delta: number;
  }>,
  totalVendDelta: number,
  paymentDelta: ReturnType<typeof getPaymentDelta>,
  availablePaymentAmounts: number[],
) {
  const allocations = new Map<string, { cashDelta: number; cashlessDelta: number; unknownPaymentDelta: number; unpaidDispenseDelta: number }>();
  const saleUnits: Array<{ selection: string; priceAmount: number }> = [];

  for (const item of planned) {
    const quantity = item.isInitialCounter ? 0 : Math.max(0, Math.round(Number(item.delta || 0)));
    if (quantity <= 0) continue;
    const unitPrice = Number(item.slot.customer_price_czk ?? item.slot.dex_price_czk ?? 0);
    const priceAmount = priceToPaymentAmount(unitPrice);
    for (let i = 0; i < quantity; i += 1) saleUnits.push({ selection: item.selection, priceAmount });
    allocations.set(item.selection, emptyPaymentAllocation());
  }

  const assign = (selection: string, key: "cashDelta" | "cashlessDelta" | "unknownPaymentDelta" | "unpaidDispenseDelta") => {
    const current = allocations.get(selection) || emptyPaymentAllocation();
    current[key] += 1;
    allocations.set(selection, current);
  };

  if (!saleUnits.length) return allocations;
  if (totalVendDelta <= 0) {
    saleUnits.forEach((unit) => assign(unit.selection, "unknownPaymentDelta"));
    return allocations;
  }
  if (paymentDelta.cashQuantity >= totalVendDelta && paymentDelta.cashlessQuantity === 0) {
    saleUnits.forEach((unit) => assign(unit.selection, "cashDelta"));
    return allocations;
  }
  if (paymentDelta.cashlessQuantity >= totalVendDelta && paymentDelta.cashQuantity === 0) {
    saleUnits.forEach((unit) => assign(unit.selection, "cashlessDelta"));
    return allocations;
  }
  if (paymentDelta.totalQuantity < totalVendDelta) {
    const assignment = findPaymentUnitAssignments(saleUnits, {
      cashQuantity: paymentDelta.cashQuantity,
      cashAmount: paymentDelta.cashAmount,
      cashlessQuantity: paymentDelta.cashlessQuantity,
      cashlessAmount: paymentDelta.cashlessAmount,
    });
    const paidQuantity = Math.max(0, Math.round(paymentDelta.totalQuantity));
    saleUnits.forEach((unit, index) => {
      if (assignment?.cash.has(index)) assign(unit.selection, "cashDelta");
      else if (assignment?.cashless.has(index)) assign(unit.selection, "cashlessDelta");
      else if (!assignment && index < paidQuantity) assign(unit.selection, "unknownPaymentDelta");
      else assign(unit.selection, "unpaidDispenseDelta");
    });
    return allocations;
  }

  const cashTargetQuantity = Math.round(paymentDelta.cashQuantity);
  const cashTargetAmount = Math.round(paymentDelta.cashAmount);
  const cashlessTargetQuantity = Math.round(paymentDelta.cashlessQuantity);
  const cashlessTargetAmount = Math.round(paymentDelta.cashlessAmount);
  const extraPaymentQuantity = Math.max(0, Math.round(paymentDelta.totalQuantity - totalVendDelta));
  const mappedTotalAmount = saleUnits.reduce((sum, unit) => sum + unit.priceAmount, 0);
  let cashIndexes: Set<number> | null = null;

  const search = (index: number, picked: number[], pickedAmount: number) => {
    if (cashIndexes || picked.length > cashTargetQuantity || pickedAmount > cashTargetAmount) return;
    if (index >= saleUnits.length) {
      const mappedCashQuantity = picked.length;
      const mappedCashlessQuantity = saleUnits.length - mappedCashQuantity;
      const extraCashQuantity = cashTargetQuantity - mappedCashQuantity;
      const extraCashlessQuantity = cashlessTargetQuantity - mappedCashlessQuantity;
      if (extraCashQuantity < 0 || extraCashlessQuantity < 0) return;
      if (extraCashQuantity + extraCashlessQuantity !== extraPaymentQuantity) return;

      const mappedCashlessAmount = mappedTotalAmount - pickedAmount;
      const extraCashAmount = cashTargetAmount - pickedAmount;
      const extraCashlessAmount = cashlessTargetAmount - mappedCashlessAmount;
      if (
        canComposePaymentAmount(extraCashQuantity, extraCashAmount, availablePaymentAmounts) &&
        canComposePaymentAmount(extraCashlessQuantity, extraCashlessAmount, availablePaymentAmounts)
      ) {
        cashIndexes = new Set(picked);
      }
      return;
    }

    search(index + 1, [...picked, index], pickedAmount + saleUnits[index].priceAmount);
    search(index + 1, picked, pickedAmount);
  };

  if (
    cashTargetQuantity >= 0 &&
    cashlessTargetQuantity >= 0 &&
    cashTargetAmount >= 0 &&
    cashlessTargetAmount >= 0 &&
    saleUnits.length <= 24 &&
    extraPaymentQuantity <= 12
  ) {
    search(0, [], 0);
  }

  if (
    !cashIndexes &&
    extraPaymentQuantity === 0 &&
    cashTargetQuantity >= 0 &&
    cashTargetQuantity <= saleUnits.length
  ) {
    cashIndexes = new Set(saleUnits.slice(0, cashTargetQuantity).map((_, index) => index));
  }

  if (!cashIndexes) {
    saleUnits.forEach((unit) => assign(unit.selection, "unknownPaymentDelta"));
    return allocations;
  }

  saleUnits.forEach((unit, index) => {
    assign(unit.selection, cashIndexes?.has(index) ? "cashDelta" : "cashlessDelta");
  });

  return allocations;
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
      // The parsed DEX is the canonical short-lived diagnostic source.
      // Keeping the XML wrapper as well duplicates the same payload at fleet scale.
      raw_xml: "",
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
    let previousDexPaymentCounters: Record<string, unknown> | null = null;
    if (ingest?.id && deviceId) {
      const { data: previousIngest, error: previousIngestError } = await adminClient
        .from("telemetry_dex_ingests")
        .select("raw_dex")
        .eq("provider", provider)
        .eq("device_id", deviceId)
        .lt("id", ingest.id)
        .order("id", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (previousIngestError) throw previousIngestError;
      if (previousIngest?.raw_dex) {
        previousDexPaymentCounters = parseDexSummary(String(previousIngest.raw_dex), deviceId).payment_counters as Record<string, unknown>;
      }
    }
    const machineId = await resolveMachineId(adminClient, provider, [
      deviceId,
      parsedDex.external_machine_id,
      parsedDex.terminal_id,
      parsedDex.machine_number,
      parsedDex.dex_serial,
    ]);

    let planogramDepletion: Record<string, unknown>[] = [];
    let coffeeRecipeDepletion: Record<string, unknown>[] = [];

    if (machineId) {
      const { data: previousState, error: previousStateError } = await adminClient
        .from("machine_telemetry_state")
        .select("counters_payload")
        .eq("machine_id", machineId)
        .eq("provider", provider)
        .maybeSingle();

      if (previousStateError) throw previousStateError;

      const previousCountersPayload = previousState?.counters_payload as Record<string, unknown> | null | undefined;
      const previousAllocatedPaymentCounters = previousCountersPayload?.allocated_payment_counters as Record<string, unknown> | null | undefined;
      const nextCountersPayload = {
        ingest_id: ingest?.id ?? null,
        device_id: deviceId,
        terminal_id: parsedDex.terminal_id,
        machine_number: parsedDex.machine_number,
        dex_read_at: parsedDex.dex_read_at,
        record_counts: parsedDex.record_counts,
        product_counter_count: parsedDex.product_counters.length,
        raw_product_counter_count: parsedDex.raw_product_counter_count,
        payment_counters: parsedDex.payment_counters,
        allocated_payment_counters: previousAllocatedPaymentCounters || null,
      };

      const { error: stateError } = await adminClient
        .from("machine_telemetry_state")
        .upsert({
          machine_id: machineId,
          provider,
          last_seen_at: eventAt,
          connectivity_status: "online",
          counters_payload: nextCountersPayload,
          updated_at: new Date().toISOString(),
        }, { onConflict: "machine_id,provider" });

      if (stateError) throw stateError;

      planogramDepletion = await applyPlanogramDepletion(adminClient, {
        provider,
        machineId: Number(machineId),
        ingestId: ingest?.id ?? null,
        counters: parsedDex.product_counters as Record<string, unknown>[],
        eventAt,
        paymentCounters: parsedDex.payment_counters as Record<string, unknown>,
        previousPaymentCounters: previousAllocatedPaymentCounters || previousDexPaymentCounters || previousCountersPayload?.payment_counters as Record<string, unknown> | null | undefined,
      });

      const { error: allocationStateError } = await adminClient
        .from("machine_telemetry_state")
        .update({
          counters_payload: {
            ...nextCountersPayload,
            allocated_payment_counters: parsedDex.payment_counters,
          },
          updated_at: new Date().toISOString(),
        })
        .eq("machine_id", machineId)
        .eq("provider", provider);
      if (allocationStateError) throw allocationStateError;

      coffeeRecipeDepletion = [];
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
      coffee_recipe_depletion_count: coffeeRecipeDepletion.length,
      message: "DEX payload received and parsed.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
