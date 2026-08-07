import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

type QueueRow = {
  id: number;
  employee_id: string;
  kind: string;
  subject: string;
  body: string;
  action_url: string | null;
  metadata: Record<string, unknown> | null;
};

const escapeHtml = (value: unknown) => String(value ?? "")
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;").replace(/'/g, "&#039;");

const valueRecord = (value: unknown): Record<string, unknown> => (
  value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {}
);

const valueArray = (value: unknown): Array<Record<string, unknown>> => (
  Array.isArray(value) ? value.map(valueRecord) : []
);

const formatDate = (value: unknown, withTime = false) => {
  if (!value) return "Bez termínu";
  const parsed = new Date(String(value));
  if (Number.isNaN(parsed.getTime())) return escapeHtml(value);
  return parsed.toLocaleString("cs-CZ", {
    timeZone: "Europe/Prague",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}),
  });
};

const formatPrice = (value: unknown) => {
  const text = String(value ?? "").trim();
  return text ? `${escapeHtml(text)} Kč` : "—";
};

type ConfigDiffRow = {
  current: Record<string, unknown> | null;
  baseline: Record<string, unknown> | null;
  status: "added" | "removed" | "changed" | "unchanged";
  changedFields: Set<string>;
};

const comparableConfigValue = (value: unknown) => String(value ?? "").trim().toLocaleLowerCase("cs-CZ");

const configValuesEqual = (left: unknown, right: unknown) => {
  const a = comparableConfigValue(left);
  const b = comparableConfigValue(right);
  if (!a && !b) return true;
  const numeric = /^-?\d+(?:[.,]\d+)?$/;
  if (numeric.test(a) && numeric.test(b)) return Number(a.replace(",", ".")) === Number(b.replace(",", "."));
  return a.replace(/\s+/g, " ") === b.replace(/\s+/g, " ");
};

function buildConfigDiff(
  currentRows: Array<Record<string, unknown>>,
  baselineRows: Array<Record<string, unknown>>,
  keyFields: string[],
  trackedFields: string[],
): ConfigDiffRow[] {
  const rowKey = (row: Record<string, unknown>, index: number) => {
    for (const field of keyFields) {
      const value = comparableConfigValue(row[field]);
      if (value) return `${field}:${value}`;
    }
    return `row:${index}`;
  };
  const baselineMap = new Map(baselineRows.map((row, index) => [rowKey(row, index), row]));
  const seen = new Set<string>();
  const rows: ConfigDiffRow[] = currentRows.map((current, index) => {
    const key = rowKey(current, index);
    const baseline = baselineMap.get(key) || null;
    seen.add(key);
    if (!baseline) return { current, baseline: null, status: "added", changedFields: new Set(trackedFields) };
    const changedFields = new Set(trackedFields.filter((field) => !configValuesEqual(current[field], baseline[field])));
    return { current, baseline, status: changedFields.size ? "changed" : "unchanged", changedFields };
  });
  baselineMap.forEach((baseline, key) => {
    if (!seen.has(key)) rows.push({ current: null, baseline, status: "removed", changedFields: new Set(trackedFields) });
  });
  return rows;
}

const configDiffBadge = (status: ConfigDiffRow["status"]) => {
  if (status === "added") return '<span style="display:inline-block;margin-left:4px;padding:2px 4px;border:1px solid #9ed7b3;background:#edf9f1;color:#17693a;font-size:7px;font-weight:800">NOVÉ</span>';
  if (status === "removed") return '<span style="display:inline-block;margin-left:4px;padding:2px 4px;border:1px solid #efb5ba;background:#fff1f2;color:#991b1b;font-size:7px;font-weight:800">ODEBRÁNO</span>';
  if (status === "changed") return '<span style="display:inline-block;margin-left:4px;padding:2px 4px;border:1px solid #f4c67a;background:#fff7e8;color:#8a5200;font-size:7px;font-weight:800">ZMĚNA</span>';
  return "";
};

const configDiffRowStyle = (status: ConfigDiffRow["status"]) => status === "added"
  ? "border-left:3px solid #16a34a"
  : status === "removed"
    ? "border-left:3px solid #d5101a;background:#fff1f2"
    : status === "changed"
      ? "border-left:3px solid #f59e0b"
      : "";

const configDiffCellStyle = (diff: ConfigDiffRow, ...fields: string[]) => fields.some((field) => diff.changedFields.has(field))
  ? "background:#fff7e8;color:#7c4a03"
  : "";

const formatChangeCount = (count: number, one: string, few: string, many: string) => {
  if (count === 1) return `${count} ${one}`;
  if (count >= 2 && count <= 4) return `${count} ${few}`;
  return `${count} ${many}`;
};

const renderConfigDiffValue = (diff: ConfigDiffRow, field: string, formatter: (value: unknown) => string = (value) => escapeHtml(String(value ?? "").trim() || "—")) => {
  const currentValue = diff.current?.[field];
  const baselineValue = diff.baseline?.[field];
  if (diff.status === "removed") return `<span style="display:block;color:#8a929e;font-size:8px;text-decoration:line-through">${formatter(baselineValue)}</span><strong style="display:block;color:#991b1b">odebráno</strong>`;
  if (diff.status === "changed" && diff.changedFields.has(field)) return `<span style="display:block;color:#8a929e;font-size:8px;text-decoration:line-through">původně ${formatter(baselineValue)}</span><strong style="display:block;color:#7c4a03">nově ${formatter(currentValue)}</strong>`;
  return formatter(currentValue);
};

const jobTypeLabel = (value: unknown) => ({
  service: "Servis",
  installation: "Nová instalace",
  deinstallation: "Odvoz / deinstalace",
  transfer: "Přesun",
  revision: "Revize / kontrola",
  workshop_prep: "Chystání na dílně",
  delivery: "Závoz / odvoz",
  general: "Všeobecný požadavek",
}[String(value)] || "Technický požadavek");

const priorityLabel = (value: unknown) => ({
  critical: "Kritická",
  high: "Vysoká",
  normal: "Běžná",
  low: "Nízká",
}[String(value)] || "Běžná");

function technicalJobEmailHtml(row: QueueRow, fullName: string, actionUrl: string | null) {
  const metadata = valueRecord(row.metadata);
  const jobType = String(metadata.job_type || "general");
  const machine = valueRecord(metadata.machine);
  const location = valueRecord(metadata.location);
  const source = valueRecord(metadata.source_location);
  const target = valueRecord(metadata.target_location);
  const sourceStock = valueRecord(metadata.source_stock_location);
  const targetStock = valueRecord(metadata.target_stock_location);
  const customer = valueRecord(metadata.customer);
  const configuration = valueRecord(metadata.configuration);
  const transferChanges = valueRecord(configuration.transfer_changes);
  const planogramRows = valueArray(configuration.planogram_rows);
  const ingredientRows = valueArray(configuration.ingredients);
  const machineBaseline = valueRecord(configuration.machine_baseline);
  const hasMachineBaseline = Object.keys(machineBaseline).length > 0;
  const baselinePlanogramRows = valueArray(machineBaseline.planogram_rows);
  const baselineIngredientRows = valueArray(machineBaseline.ingredients);
  const planogramDiffRows = hasMachineBaseline
    ? buildConfigDiff(planogramRows, baselinePlanogramRows, ["choice", "column"], ["product_id", "product_name", "cash_price", "card_price", "loyalty_price", "active"])
    : planogramRows.map((current) => ({ current, baseline: null, status: "unchanged" as const, changedFields: new Set<string>() }));
  const ingredientDiffRows = hasMachineBaseline
    ? buildConfigDiff(ingredientRows, baselineIngredientRows, ["container", "column"], ["product_id", "product_name", "max_capacity", "unit"])
    : ingredientRows.map((current) => ({ current, baseline: null, status: "unchanged" as const, changedFields: new Set<string>() }));
  const changedPlanogramCount = planogramDiffRows.filter((item) => item.status !== "unchanged").length;
  const changedIngredientCount = ingredientDiffRows.filter((item) => item.status !== "unchanged").length;
  const materials = valueArray(metadata.materials);
  const checklist = valueArray(metadata.checklist).filter((item) => item.required !== false);
  const title = String(metadata.title || row.subject || "Technický požadavek");
  const isUpdate = row.kind === "technical_job_update";
  const due = metadata.due_at ? formatDate(metadata.due_at, true) : formatDate(metadata.planned_date);
  const machineName = [machine.evidence_number ? `EV ${machine.evidence_number}` : "", machine.name, machine.brand, machine.model].filter(Boolean).join(" · ");
  const locationName = [location.name, location.city].filter(Boolean).join(" · ");
  const sourceName = [source.name || sourceStock.name, source.address, source.city].filter(Boolean).join(" · ");
  const targetName = [target.name || targetStock.name, target.address, target.city].filter(Boolean).join(" · ");
  const primaryPlace = locationName || targetName || sourceName || "Místo nebylo zadáno";
  const emailKicker = ({
    service: "Přidělený servisní zásah",
    installation: "Přidělená nová instalace",
    deinstallation: "Přidělený odvoz automatu",
    transfer: "Přidělený přesun automatu",
    revision: "Přidělená revize automatu",
    workshop_prep: "Příprava automatu na dílně",
    delivery: "Přidělený závoz / odvoz",
    general: "Přidělený všeobecný požadavek",
  } as Record<string, string>)[jobType] || "Přidělený technický úkol";
  const routeMarkup = sourceName || targetName ? `
    <div style="border:1px solid #d9dee6;margin-top:12px">
      <div style="padding:9px 12px;background:#edf0f4;border-bottom:1px solid #d9dee6;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#48515d">${jobType === "transfer" ? "Trasa přesunu" : "Trasa"}</div>
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr>
        <td style="padding:15px 12px;width:${jobType === "transfer" ? "31%" : "46%"};vertical-align:top"><span style="display:block;color:#737d8a;font-size:9px;font-weight:700;text-transform:uppercase;margin-bottom:5px">Odkud</span><strong>${escapeHtml(sourceName || "Neuvedeno")}</strong></td>
        <td style="padding:15px 4px;text-align:center;color:#d5101a;font-size:20px;font-weight:700">→</td>
        ${jobType === "transfer" ? `<td style="padding:15px 12px;width:31%;vertical-align:top;background:#f7f8fa"><span style="display:block;color:#737d8a;font-size:9px;font-weight:700;text-transform:uppercase;margin-bottom:5px">Automat</span><strong>${escapeHtml(machineName || "Neuvedeno")}</strong></td><td style="padding:15px 4px;text-align:center;color:#d5101a;font-size:20px;font-weight:700">→</td>` : ""}
        <td style="padding:15px 12px;width:${jobType === "transfer" ? "31%" : "46%"};vertical-align:top"><span style="display:block;color:#737d8a;font-size:9px;font-weight:700;text-transform:uppercase;margin-bottom:5px">Kam</span><strong>${escapeHtml(targetName || primaryPlace)}</strong></td>
      </tr></table>
    </div>` : "";
  const transferChangeLabels = [
    transferChanges.prices ? "Ceny" : "",
    transferChanges.planogram ? "Planogram" : "",
    transferChanges.hoppers ? "Zásobníky" : "",
    transferChanges.telemetry ? "Telemetrie" : "",
  ].filter(Boolean);
  const planogramDetailsMarkup = planogramDiffRows.length ? `
    <div style="margin-top:11px;border:1px solid #d9dee6">
      <div style="padding:7px 9px;background:#f7f8fa;border-bottom:1px solid #d9dee6;font-size:10px;font-weight:700;text-transform:uppercase;color:#596270">Cílové volby a ceny</div>
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;font-size:10px">
        <tr style="background:#fbfcfd;color:#737d8a;text-transform:uppercase"><th style="padding:6px;text-align:left">Volba</th><th style="padding:6px;text-align:left">Nápoj / produkt</th><th style="padding:6px;text-align:right">Hotovost</th><th style="padding:6px;text-align:right">Karta</th><th style="padding:6px;text-align:right">Věrnostní</th></tr>
        ${planogramDiffRows.map((diff) => { const item = diff.current || diff.baseline || {}; return `<tr style="${configDiffRowStyle(diff.status)}"><td style="padding:6px;border-top:1px solid #edf0f4;font-weight:700">${escapeHtml(item.choice || item.column)}${configDiffBadge(diff.status)}</td><td style="padding:6px;border-top:1px solid #edf0f4;${configDiffCellStyle(diff, "product_id", "product_name")}">${renderConfigDiffValue(diff, "product_name", (value) => escapeHtml(String(value ?? "").trim() || "Neuvedeno"))}</td><td style="padding:6px;border-top:1px solid #edf0f4;text-align:right;${configDiffCellStyle(diff, "cash_price")}">${renderConfigDiffValue(diff, "cash_price", formatPrice)}</td><td style="padding:6px;border-top:1px solid #edf0f4;text-align:right;${configDiffCellStyle(diff, "card_price")}">${renderConfigDiffValue(diff, "card_price", formatPrice)}</td><td style="padding:6px;border-top:1px solid #edf0f4;text-align:right;${configDiffCellStyle(diff, "loyalty_price")}">${renderConfigDiffValue(diff, "loyalty_price", formatPrice)}</td></tr>`; }).join("")}
      </table>
    </div>` : "";
  const ingredientDetailsMarkup = ingredientDiffRows.length ? `
    <div style="margin-top:11px;border:1px solid #d9dee6">
      <div style="padding:7px 9px;background:#f7f8fa;border-bottom:1px solid #d9dee6;font-size:10px;font-weight:700;text-transform:uppercase;color:#596270">Cílové zásobníky</div>
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;font-size:10px">
        <tr style="background:#fbfcfd;color:#737d8a;text-transform:uppercase"><th style="padding:6px;text-align:left">Zásobník</th><th style="padding:6px;text-align:left">Surovina</th><th style="padding:6px;text-align:right">Kapacita</th></tr>
        ${ingredientDiffRows.map((diff) => { const item = diff.current || diff.baseline || {}; return `<tr style="${configDiffRowStyle(diff.status)}"><td style="padding:6px;border-top:1px solid #edf0f4;font-weight:700">${escapeHtml(item.container || item.column || "—")}${configDiffBadge(diff.status)}</td><td style="padding:6px;border-top:1px solid #edf0f4;${configDiffCellStyle(diff, "product_id", "product_name")}">${renderConfigDiffValue(diff, "product_name", (value) => escapeHtml(String(value ?? "").trim() || "Neuvedeno"))}</td><td style="padding:6px;border-top:1px solid #edf0f4;text-align:right;${configDiffCellStyle(diff, "max_capacity", "unit")}">${renderConfigDiffValue(diff, "max_capacity", (value) => `${escapeHtml(String(value ?? "").trim() || "—")} ${escapeHtml(String((diff.current || diff.baseline)?.unit || ""))}`.trim())}</td></tr>`; }).join("")}
      </table>
    </div>` : "";
  const transferRulesMarkup = configuration.pricing || configuration.telemetry_mapping_raw ? `
    <div style="margin-top:10px;padding:9px 10px;background:#f7f8fa;border-left:3px solid #d5101a;font-size:10px;line-height:1.5">
      ${configuration.pricing ? `<strong>Platební pravidla:</strong> ${escapeHtml(Array.isArray(configuration.pricing) ? configuration.pricing.join(" · ") : configuration.pricing)}<br>` : ""}
      ${configuration.telemetry_mapping_raw ? `<strong>Telemetrie:</strong> ${escapeHtml(configuration.telemetry_mapping_raw)}` : ""}
    </div>` : "";
  const configurationMarkup = jobType === "transfer" && (transferChangeLabels.length || planogramRows.length || ingredientRows.length) ? `
    <div style="border:1px solid #d9dee6;margin-top:12px">
      <div style="padding:9px 12px;background:#edf0f4;border-bottom:1px solid #d9dee6;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#48515d">Co se při přesunu mění</div>
      <div style="padding:13px 14px;font-size:12px;line-height:1.6">
        ${transferChangeLabels.map((label) => `<span style="display:inline-block;margin:0 5px 5px 0;padding:5px 8px;background:#fff1f2;border:1px solid #f0c4c7;color:#991b1b;font-size:10px;font-weight:700">${escapeHtml(label)}</span>`).join("")}
        ${configuration.summary ? `<div style="margin-top:7px">${escapeHtml(configuration.summary)}</div>` : ""}
        ${(planogramRows.length || ingredientRows.length) ? `<div style="margin-top:7px;color:#687281">Cílová konfigurace: ${planogramRows.length} voleb · ${ingredientRows.length} zásobníků</div>` : ""}
        ${hasMachineBaseline ? `<div style="margin-top:8px;padding:7px 9px;background:#fff7e8;border-left:3px solid #f59e0b;color:#7c4a03;font-size:10px;font-weight:700">Označené změny proti načtenému stavu: ${formatChangeCount(changedPlanogramCount, "volba", "volby", "voleb")} · ${formatChangeCount(changedIngredientCount, "zásobník", "zásobníky", "zásobníků")}</div>` : ""}
        ${planogramDetailsMarkup}${ingredientDetailsMarkup}${transferRulesMarkup}
      </div>
    </div>` : "";
  const materialsMarkup = materials.length ? `
    <div style="border:1px solid #d9dee6;margin-top:12px">
      <div style="padding:9px 12px;background:#edf0f4;border-bottom:1px solid #d9dee6;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#48515d">Materiál a zásoby</div>
      <table width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;font-size:12px">
        ${materials.map((item) => `<tr><td style="padding:9px 12px;border-bottom:1px solid #edf0f4">${escapeHtml(item.product_name)}</td><td style="padding:9px 12px;border-bottom:1px solid #edf0f4;color:#687281">${escapeHtml(item.stock_location || "Bez skladu")}</td><td style="padding:9px 12px;border-bottom:1px solid #edf0f4;text-align:right;font-weight:700">${escapeHtml(item.quantity)} ${escapeHtml(item.unit || "ks")}</td></tr>`).join("")}
      </table>
    </div>` : "";
  const checklistMarkup = checklist.length ? `
    <div style="border:1px solid #d9dee6;margin-top:12px">
      <div style="padding:9px 12px;background:#edf0f4;border-bottom:1px solid #d9dee6;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#48515d">Co je potřeba udělat</div>
      <div style="padding:9px 14px 13px;font-size:12px;color:#4b5563">${checklist.map((item) => `<div style="padding:5px 0">□ ${escapeHtml(item.label)}</div>`).join("")}</div>
    </div>` : "";
  const contactName = location.contact_person || customer.contact_name;
  const contactPhone = location.contact_phone || customer.phone;
  const contactEmail = location.contact_email || customer.email;
  const contactMarkup = contactName || contactPhone || contactEmail ? `
    <div style="border:1px solid #d9dee6;margin-top:12px">
      <div style="padding:9px 12px;background:#edf0f4;border-bottom:1px solid #d9dee6;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#48515d">Kontakt na místě</div>
      <div style="padding:13px 14px;font-size:12px"><strong>${escapeHtml(contactName || customer.name || "Kontakt")}</strong><br><span style="color:#687281">${escapeHtml([contactPhone, contactEmail].filter(Boolean).join(" · "))}</span></div>
    </div>` : "";
  const warning = String(metadata.priority) === "critical" || String(metadata.priority) === "high" ? `
    <div style="border-left:4px solid #d5101a;background:#fff1f2;padding:12px 14px;margin-bottom:16px;color:#8f1118;font-size:12px"><strong>${escapeHtml(priorityLabel(metadata.priority))} priorita</strong>${metadata.due_at ? ` · dokončit do ${escapeHtml(due)}` : ""}</div>` : "";

  return `<div style="margin:0;background:#eef1f5;padding:24px;font-family:Arial,Helvetica,sans-serif;color:#20242d">
    <div style="max-width:680px;margin:0 auto;background:#fff;border:1px solid #d9dee6">
      <div style="background:#20242d;color:#fff;padding:24px 28px;border-top:5px solid #d5101a">
        <div style="font-weight:800;letter-spacing:.12em;font-size:17px;margin-bottom:20px"><span style="color:#ed1c24">OL</span>VEND <span style="font-size:9px;color:#aeb6c2;letter-spacing:.04em">by OLMIKA</span></div>
        <div style="font-size:11px;text-transform:uppercase;letter-spacing:.1em;color:#aeb6c2;margin-bottom:7px">${isUpdate ? `Aktualizace · ${emailKicker}` : emailKicker}</div>
        <h1 style="font-size:25px;line-height:1.2;margin:0 0 8px;color:#fff">${escapeHtml(title)}</h1>
        <div style="font-size:13px;color:#cbd2dc">TZ-${escapeHtml(metadata.technical_job_id)} · ${escapeHtml(jobTypeLabel(jobType))}${machineName ? ` · ${escapeHtml(machineName)}` : ""}</div>
      </div>
      <div style="padding:24px 28px 28px">
        <p style="font-size:14px;line-height:1.6;margin:0 0 18px">Dobrý den, ${escapeHtml(fullName)},<br>${isUpdate ? "zadání vašeho úkolu bylo aktualizováno." : "byl vám přidělen následující úkol."} Níže máte všechny údaje potřebné k přípravě a provedení.</p>
        ${warning}
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #d9dee6;background:#f7f8fa;margin-bottom:18px"><tr>
          <td style="padding:13px 14px;border-right:1px solid #d9dee6"><span style="display:block;font-size:10px;text-transform:uppercase;color:#7b8491;margin-bottom:5px">Termín</span><strong>${escapeHtml(due)}</strong></td>
          <td style="padding:13px 14px;border-right:1px solid #d9dee6"><span style="display:block;font-size:10px;text-transform:uppercase;color:#7b8491;margin-bottom:5px">Priorita</span><strong>${escapeHtml(priorityLabel(metadata.priority))}</strong></td>
          <td style="padding:13px 14px"><span style="display:block;font-size:10px;text-transform:uppercase;color:#7b8491;margin-bottom:5px">${jobType === "transfer" ? "Cíl" : "Místo"}</span><strong>${escapeHtml(jobType === "transfer" ? (targetName || "Neuvedeno") : primaryPlace)}</strong></td>
        </tr></table>
        ${routeMarkup}
        <div style="border:1px solid #d9dee6;margin-top:12px">
          <div style="padding:9px 12px;background:#edf0f4;border-bottom:1px solid #d9dee6;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#48515d">Rozsah práce</div>
          <div style="padding:14px;font-size:13px;line-height:1.6"><strong>${escapeHtml(machineName || title)}</strong><br>${escapeHtml(metadata.description || configuration.summary || metadata.workshop_note || "Podrobnosti jsou uvedené v OLVENDu.")}</div>
        </div>
        ${configurationMarkup}${materialsMarkup}${checklistMarkup}${contactMarkup}
        ${actionUrl ? `<div style="text-align:center;padding:23px 0 9px"><a href="${escapeHtml(actionUrl)}" style="display:inline-block;background:#d5101a;color:#fff;text-decoration:none;font-size:13px;font-weight:700;padding:12px 22px;border-radius:4px">Otevřít úkol v OLVENDu</a></div>` : ""}
      </div>
      <div style="border-top:1px solid #e2e6ec;padding:15px 28px;color:#8a929e;font-size:10px;line-height:1.5;background:#fafbfc">Automatická zpráva systému OLVEND · OLMIKA s.r.o.<br>Na tento e-mail není potřeba odpovídat.</div>
    </div>
  </div>`;
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
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const emailFrom = Deno.env.get("EMAIL_FROM");
    const appUrl = String(Deno.env.get("PUBLIC_APP_URL") || "https://olvend.onrender.com").replace(/\/$/, "");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Missing Supabase environment variables." }, 500);
    }

    if (!resendApiKey || !emailFrom) {
      return json({ error: "Missing email provider configuration." }, 500);
    }
    const emailFromAddress = emailFrom.match(/<([^>]+)>/)?.[1]
      || emailFrom.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0]
      || emailFrom;
    const brandedEmailFrom = `OLVEND by OLMIKA <${emailFromAddress}>`;

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
      .select("id, name, surname, email, role, active")
      .eq("auth_user_id", currentUser.id)
      .maybeSingle();

    if (currentEmployeeError) {
      return json({ error: currentEmployeeError.message }, 400);
    }

    if (!currentEmployee || currentEmployee.active === false) {
      return json({ error: "Current user is not linked to an active employee." }, 403);
    }

    if (!["admin", "manager"].includes(String(currentEmployee.role ?? "").toLowerCase())) {
      return json({ error: "Only admin or manager can send queued notifications." }, 403);
    }

    const payload = await req.json().catch(() => ({}));
    const limit = Math.max(1, Math.min(Number(payload?.limit ?? 20), 100));
    const requestedQueueIdValue = Number(payload?.queue_id ?? 0);
    const requestedQueueId = Number.isInteger(requestedQueueIdValue) && requestedQueueIdValue > 0
      ? requestedQueueIdValue
      : null;
    const previewQueueIdValue = Number(payload?.preview_queue_id ?? 0);
    const previewQueueId = Number.isInteger(previewQueueIdValue) && previewQueueIdValue > 0
      ? previewQueueIdValue
      : null;

    let queueQuery = adminClient
      .from("email_notification_queue")
      .select("id, employee_id, kind, subject, body, action_url, metadata, scheduled_for");

    if (previewQueueId) {
      queueQuery = queueQuery.eq("id", previewQueueId);
    } else {
      queueQuery = queueQuery
        .eq("status", "queued")
        .lte("scheduled_for", new Date().toISOString());
    }

    if (requestedQueueId && !previewQueueId) {
      queueQuery = queueQuery.eq("id", requestedQueueId);
    }

    const { data: queueRows, error: queueError } = await queueQuery
      .order("scheduled_for", { ascending: true })
      .limit(requestedQueueId || previewQueueId ? 1 : limit);

    if (queueError) {
      return json({ error: queueError.message }, 400);
    }

    const rows = (queueRows ?? []) as QueueRow[];
    if (!rows.length) {
      return json({ processed: 0, sent: 0, failed: 0, message: "No queued notifications." });
    }

    let employees: Array<{ id: string; name: string | null; surname: string | null; email: string | null }> = [];
    if (!previewQueueId) {
      const employeeIds = [...new Set(rows.map((row) => row.employee_id).filter(Boolean))];
      const { data, error } = await adminClient
        .from("employees")
        .select("id, name, surname, email")
        .in("id", employeeIds);
      if (error) {
        return json({ error: error.message }, 400);
      }
      employees = data ?? [];
    }

    const employeeById = new Map(employees.map((employee) => [String(employee.id), employee]));

    let sent = 0;
    let failed = 0;

    for (const row of rows) {
      const employee = previewQueueId ? currentEmployee : employeeById.get(String(row.employee_id));
      if (!employee?.email) {
        failed += 1;
        if (!previewQueueId) {
          await adminClient
            .from("email_notification_queue")
            .update({ status: "failed", last_error: "Employee email is missing." })
            .eq("id", row.id);
        }
        continue;
      }

      const fullName = [employee.name, employee.surname].filter(Boolean).join(" ").trim() || employee.email;
      const actionUrl = row.action_url
        ? (/^https?:\/\//i.test(row.action_url) ? row.action_url : `${appUrl}/${row.action_url.replace(/^\//, "")}`)
        : null;
      const html = ["technical_job_assignment", "technical_job_update"].includes(row.kind)
        ? technicalJobEmailHtml(row, fullName, actionUrl)
        : `
        <div style="font-family:Arial,Helvetica,sans-serif;line-height:1.6;color:#111">
          <h2 style="margin:0 0 16px">OLVEND</h2>
          <p style="margin:0 0 12px">Dobrý den, ${escapeHtml(fullName)},</p>
          <p style="margin:0 0 12px; white-space:pre-line;">${escapeHtml(row.body)}</p>
          ${actionUrl ? `<p style="margin:20px 0"><a href="${escapeHtml(actionUrl)}" style="display:inline-block;padding:10px 16px;border-radius:10px;background:#d5101a;color:#fff;text-decoration:none;font-weight:700">Otevřít v OLVENDu</a></p>` : ""}
          <p style="margin:16px 0 0;color:#667085;font-size:13px">Toto upozornění bylo odesláno z interního systému OLVEND.</p>
        </div>
      `;

      const resendResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: brandedEmailFrom,
          to: [employee.email],
          subject: previewQueueId ? `[NÁHLED] ${row.subject}` : row.subject,
          html,
        }),
      });

      if (!resendResponse.ok) {
        failed += 1;
        const errorText = await resendResponse.text();
        if (!previewQueueId) {
          await adminClient
            .from("email_notification_queue")
            .update({ status: "failed", last_error: errorText.slice(0, 1200) })
            .eq("id", row.id);
        }
        continue;
      }

      sent += 1;
      if (!previewQueueId) {
        await adminClient
          .from("email_notification_queue")
          .update({ status: "sent", last_error: null })
          .eq("id", row.id);
      }
    }

    return json({
      processed: rows.length,
      sent,
      failed,
      preview: Boolean(previewQueueId),
      recipient: previewQueueId ? currentEmployee.email : null,
      message: sent
        ? previewQueueId ? "Email preview was sent to the current user." : "Queued email notifications were processed."
        : "No emails were sent.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
