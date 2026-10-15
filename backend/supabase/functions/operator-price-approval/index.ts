import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
});

const esc = (value: unknown) => String(value ?? "")
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;").replace(/'/g, "&#039;");

const money = (value: unknown) => {
  const number = Number(value);
  return Number.isFinite(number) ? `${new Intl.NumberFormat("cs-CZ", { maximumFractionDigits: 2 }).format(number)} Kč` : "—";
};

const percent = (value: unknown) => {
  const number = Number(value);
  return Number.isFinite(number) ? `${new Intl.NumberFormat("cs-CZ", { maximumFractionDigits: 1 }).format(number)} %` : "—";
};

function page(title: string, body: string, tone: "neutral" | "good" | "bad" = "neutral") {
  const color = tone === "good" ? "#067647" : tone === "bad" ? "#b42318" : "#17212b";
  return new Response(`<!doctype html><html lang="cs"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title><body style="margin:0;background:#f4f6f8;font-family:Arial,sans-serif;color:#17212b"><main style="max-width:600px;margin:48px auto;padding:18px"><section style="padding:28px;border:1px solid #dfe3e8;border-radius:24px;background:#fff;box-shadow:0 18px 44px rgba(16,24,40,.12)"><div style="font-weight:900;color:#d5101a">OLVEND</div><h1 style="margin:18px 0 10px;font-size:28px;color:${color}">${esc(title)}</h1>${body}</section></main></body></html>`, {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8", "X-OLVEND-Price-Approval": "v51" },
  });
}

function randomToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function comparisonRows(snapshot: Record<string, unknown>) {
  const rows = Array.isArray(snapshot?.prices_elsewhere) ? snapshot.prices_elsewhere as Array<Record<string, unknown>> : [];
  if (!rows.length) return `<p style="color:#667085">Stejný produkt není v jiném aktivním automatu.</p>`;
  return `<table role="presentation" style="width:100%;border-collapse:collapse;font-size:13px"><thead><tr><th style="padding:8px;text-align:left;border-bottom:1px solid #e4e7ec">Lokalita</th><th style="padding:8px;text-align:left;border-bottom:1px solid #e4e7ec">EV / pozice</th><th style="padding:8px;text-align:right;border-bottom:1px solid #e4e7ec">Cena</th></tr></thead><tbody>${rows.map((row) => `<tr><td style="padding:8px;border-bottom:1px solid #f0f1f3">${esc(row.location || "—")}</td><td style="padding:8px;border-bottom:1px solid #f0f1f3">${esc(row.evidence_number || "—")} / ${esc(row.slot_code || "—")}</td><td style="padding:8px;text-align:right;border-bottom:1px solid #f0f1f3;font-weight:800">${esc(money(row.price_czk))}</td></tr>`).join("")}</tbody></table>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const emailFrom = Deno.env.get("EMAIL_FROM");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) return json({ error: "Chybí serverová konfigurace." }, 500);
  const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });

  try {
    const url = new URL(req.url);
    if (req.method === "GET") {
      const token = String(url.searchParams.get("token") || "");
      const decision = String(url.searchParams.get("decision") || "");
      if (!token || !["approve", "reject"].includes(decision)) return page("Neplatný odkaz", "<p>Schvalovací odkaz je neúplný.</p>", "bad");
      const approve = decision === "approve";
      return page(approve ? "Schválit vyšší cenu" : "Zamítnout vyšší cenu", `<p style="color:#667085;line-height:1.55">${approve ? "Po potvrzení se vyšší cena stane novou doporučenou cenou v OLVENDU." : "Po potvrzení dostane operátor při příští návštěvě pokyn vrátit cenu na původní doporučenou hodnotu."}</p><p style="padding:12px;border-radius:12px;background:#fff4e5;color:#7a4b00"><strong>Probíhající trasa operátora nebude tímto rozhodnutím nijak blokována.</strong></p><form method="post"><input type="hidden" name="token" value="${esc(token)}"><input type="hidden" name="decision" value="${esc(decision)}"><button style="width:100%;margin-top:16px;padding:16px;border:0;border-radius:15px;color:#fff;background:${approve ? "#d5101a" : "#344054"};font-size:17px;font-weight:900" type="submit">Potvrdit rozhodnutí</button></form><p style="margin-top:15px;color:#98a2b3;font-size:12px">Pouhé otevření e-mailu rozhodnutí neprovede.</p>`);
    }

    if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);
    const contentType = req.headers.get("content-type") || "";
    if (contentType.includes("application/x-www-form-urlencoded") || contentType.includes("multipart/form-data")) {
      const form = await req.formData();
      const token = String(form.get("token") || "");
      const decision = String(form.get("decision") || "");
      if (!token || !["approve", "reject"].includes(decision)) return page("Neplatné rozhodnutí", "<p>Odkaz je neúplný.</p>", "bad");
      const { data, error } = await admin.rpc("decide_operator_price_change_v51", { p_token: token, p_decision: decision });
      if (error) return page("Rozhodnutí se nepodařilo uložit", `<p>${esc(error.message)}</p>`, "bad");
      const status = String(data?.status || "");
      return page(status === "approved" ? "Vyšší cena byla schválena" : status === "rejected" ? "Vyšší cena byla zamítnuta" : "Žádost už byla vyřízena", `<p style="color:#667085;line-height:1.55">${status === "approved" ? `Nová doporučená cena je ${esc(money(data?.price_czk))}.` : status === "rejected" ? `Operátor při příští návštěvě dostane pokyn vrátit cenu na ${esc(money(data?.return_price_czk))}.` : `Aktuální stav žádosti: ${esc(status || "vyřízeno")}.`}</p><p style="padding:12px;border-radius:12px;background:#ecfdf3;color:#067647"><strong>Operátor mohl po odeslání žádosti okamžitě pokračovat v práci.</strong></p>`, status === "approved" ? "good" : "neutral");
    }

    const body = await req.json();
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Chybí přihlášení." }, 401);
    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Přihlášení není platné." }, 401);
    const { data: operator } = await admin.from("employees").select("id,name,surname,email,active").eq("auth_user_id", user.id).maybeSingle();
    if (!operator || operator.active === false) return json({ error: "Aktivní operátor nebyl nalezen." }, 403);

    const visitId = Number(body?.visit_id || 0);
    const slotId = Number(body?.planogram_slot_id || 0);
    const proposedPrice = Number(body?.proposed_price_czk);
    const clientKey = String(body?.client_request_key || "").trim();
    const note = String(body?.note || "").trim();
    if (!visitId || !slotId || !clientKey || !Number.isFinite(proposedPrice)) return json({ error: "Žádost nemá úplné údaje." }, 400);

    const token = randomToken();
    const tokenHash = await sha256(token);
    const { data, error } = await admin.rpc("create_operator_price_change_request_v51", {
      p_client_request_key: clientKey,
      p_visit_id: visitId,
      p_slot_id: slotId,
      p_operator_employee_id: operator.id,
      p_new_price: proposedPrice,
      p_note: note || null,
      p_token_hash: tokenHash,
    });
    if (error) return json({ error: error.message }, 409);
    if (data?.already_exists && data?.email_sent_at) return json({ ...data, ok: true });
    if (!resendApiKey || !emailFrom) {
      await admin.from("operator_price_change_requests").update({ mail_error: "E-mailová služba není nakonfigurovaná." }).eq("id", data.request_id);
      return json({ ...data, ok: true, email_pending: true, warning: "Žádost je uložená, ale e-mailová služba není nakonfigurovaná." });
    }

    const economics = data?.economics_snapshot || {};
    const comparison = data?.comparison_snapshot || {};
    const endpoint = Deno.env.get("OPERATOR_PRICE_APPROVAL_URL") || `${supabaseUrl}/functions/v1/operator-price-approval`;
    const approveUrl = `${endpoint}?token=${encodeURIComponent(token)}&decision=approve`;
    const rejectUrl = `${endpoint}?token=${encodeURIComponent(token)}&decision=reject`;
    const destination = `${data?.location_name || "Lokalita"} · EV ${data?.evidence_number || "—"} · pozice ${data?.slot_code || "—"}`;
    const html = `<div style="max-width:680px;margin:auto;font-family:Arial,sans-serif;color:#17212b;line-height:1.5"><div style="font-weight:900;color:#d5101a">OLVEND</div><h1 style="font-size:25px">Operátor nastavil vyšší cenu</h1><p><strong>${esc(data?.operator_name || "Operátor")}</strong> fyzicky změnil cenu v automatu. Její schválení probíhá na pozadí a neblokuje další práci.</p><div style="margin:18px 0;border:1px solid #e4e7ec;border-radius:16px;overflow:hidden"><div style="padding:12px 15px;border-bottom:1px solid #e4e7ec"><small>LOKALITA A POZICE</small><br><strong>${esc(destination)}</strong></div><div style="padding:12px 15px;border-bottom:1px solid #e4e7ec"><small>PRODUKT</small><br><strong>${esc(data?.product_name || "Produkt")}</strong>${data?.product_sku ? ` · SKU ${esc(data.product_sku)}` : ""}</div><div style="display:grid;grid-template-columns:1fr 1fr"><div style="padding:14px 15px;border-right:1px solid #e4e7ec"><small>DOPORUČENÁ CENA</small><br><strong style="font-size:22px">${esc(money(data?.recommended_price_czk))}</strong></div><div style="padding:14px 15px"><small>NASTAVENÁ CENA</small><br><strong style="font-size:22px;color:#d5101a">${esc(money(data?.proposed_price_czk))}</strong></div></div></div><h2 style="font-size:18px">Ekonomika změny</h2><table role="presentation" style="width:100%;border-collapse:collapse;background:#f8fafc;border-radius:14px"><tr><td style="padding:10px">Evidovaná nákupní cena</td><td style="padding:10px;text-align:right;font-weight:800">${esc(money(economics.purchase_price_czk))}</td></tr><tr><td style="padding:10px">Rozpětí při doporučené ceně</td><td style="padding:10px;text-align:right;font-weight:800">${esc(money(economics.recommended_spread_czk))} · ${esc(percent(economics.recommended_margin_percent))}</td></tr><tr><td style="padding:10px">Rozpětí při nové ceně</td><td style="padding:10px;text-align:right;font-weight:800;color:#067647">${esc(money(economics.proposed_spread_czk))} · ${esc(percent(economics.proposed_margin_percent))}</td></tr><tr><td style="padding:10px">Cena bez DPH</td><td style="padding:10px;text-align:right;font-weight:800">${esc(money(economics.net_price_after_vat_czk))}</td></tr><tr><td style="padding:10px">Orientační dopad při 30denním objemu</td><td style="padding:10px;text-align:right;font-weight:800">+${esc(money(economics.estimated_30d_revenue_change_czk))}</td></tr></table><p style="font-size:12px;color:#667085">Marže je orientační rozpětí proti evidované nákupní ceně produktu.</p><h2 style="font-size:18px">Ceny stejného produktu jinde</h2><p style="color:#667085">Minimum ${esc(money(comparison.min_price_czk))} · medián ${esc(money(comparison.median_price_czk))} · průměr ${esc(money(comparison.average_price_czk))} · maximum ${esc(money(comparison.max_price_czk))}</p>${comparisonRows(comparison)}<h2 style="font-size:18px">Prodej za posledních 30 dní</h2><p>${esc(comparison.sales_30d_units || 0)} ks · tržba ${esc(money(comparison.sales_30d_revenue_czk))} · průměrná realizovaná cena ${esc(money(comparison.sales_30d_average_price_czk))}</p>${data?.operator_note ? `<h2 style="font-size:18px">Poznámka operátora</h2><p style="padding:12px;border-radius:12px;background:#f8fafc">${esc(data.operator_note)}</p>` : ""}<table role="presentation" style="width:100%;border-spacing:8px;margin-top:18px"><tr><td><a href="${esc(approveUrl)}" style="display:block;padding:14px;border-radius:12px;color:#fff;background:#d5101a;text-align:center;font-weight:900;text-decoration:none">Schválit ${esc(money(data?.proposed_price_czk))}</a></td><td><a href="${esc(rejectUrl)}" style="display:block;padding:14px;border:1px solid #d0d5dd;border-radius:12px;color:#344054;background:#fff;text-align:center;font-weight:900;text-decoration:none">Zamítnout a vrátit cenu</a></td></tr></table><p style="color:#98a2b3;font-size:12px">Odkaz nejprve zobrazí potvrzovací stránku. Samotné otevření e-mailu nic nezmění.</p></div>`;
    const emailFromAddress = emailFrom.match(/<([^>]+)>/)?.[1] || emailFrom;
    const mailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendApiKey}`, "Content-Type": "application/json", "Idempotency-Key": `operator-price-${data.request_id}-${tokenHash.slice(0, 16)}` },
      body: JSON.stringify({
        from: `OLVEND by OLMIKA <${emailFromAddress}>`,
        to: [data.approver_email],
        subject: `Ke schválení: ${data.product_name} ${money(data.recommended_price_czk)} → ${money(data.proposed_price_czk)} · ${data.location_name}`,
        html,
      }),
    });
    if (!mailResponse.ok) {
      const detail = (await mailResponse.text()).slice(0, 1200);
      await admin.from("operator_price_change_requests").update({ mail_error: detail }).eq("id", data.request_id);
      return json({ ...data, ok: true, email_pending: true, warning: "Žádost je uložená, ale e-mail se zatím nepodařilo odeslat." });
    }
    const delivery = await mailResponse.json();
    const sentAt = new Date().toISOString();
    await admin.from("operator_price_change_requests").update({ email_sent_at: sentAt, email_delivery_id: delivery?.id || null, mail_error: null }).eq("id", data.request_id);
    return json({ ...data, ok: true, email_sent_at: sentAt });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Neočekávaná chyba." }, 500);
  }
});
