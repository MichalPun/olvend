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

const escapeHtml = (value: unknown) => String(value ?? "")
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;").replace(/'/g, "&#039;");

const reasonLabels: Record<string, string> = {
  opening_hours: "Nestihnu otevírací dobu",
  time_shortage: "Časový skluz trasy",
  location_closed: "Provozovna je zavřená",
  no_access: "Není možný příjezd nebo přístup",
  machine_unavailable: "Automat není dostupný",
  other: "Jiný důvod",
};

function page(title: string, body: string, tone: "neutral" | "good" | "bad" = "neutral") {
  const color = tone === "good" ? "#067647" : tone === "bad" ? "#b42318" : "#17212b";
  const markup = `<!doctype html><html lang="cs"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)}</title><body style="margin:0;background:#f4f6f8;font-family:Arial,sans-serif;color:#17212b"><main style="max-width:560px;margin:48px auto;padding:18px"><section style="padding:28px;border:1px solid #dfe3e8;border-radius:24px;background:#fff;box-shadow:0 18px 44px rgba(16,24,40,.12)"><div style="font-weight:900;color:#d5101a">OLVEND</div><h1 style="margin:18px 0 10px;font-size:28px;color:${color}">${escapeHtml(title)}</h1>${body}</section></main></body></html>`;
  const headers = new Headers(corsHeaders);
  headers.set("Content-Type", "text/html; charset=utf-8");
  headers.set("X-OLVEND-Route-Approval", "v39");
  return new Response(new TextEncoder().encode(markup), { status: 200, headers });
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
      const label = decision === "approve" ? "Schválit nejetí" : "Zamítnout žádost";
      const copy = decision === "approve" ? "Po potvrzení se zastávka označí jako nejetá a operátorovi se odemkne pokračování." : "Po potvrzení zastávka zůstane v trase a operátor může pokračovat v její obsluze.";
      return page(label, `<p style="color:#667085;line-height:1.55">${copy}</p><form method="post"><input type="hidden" name="token" value="${escapeHtml(token)}"><input type="hidden" name="decision" value="${escapeHtml(decision)}"><button style="width:100%;margin-top:16px;padding:16px;border:0;border-radius:15px;color:#fff;background:${decision === "approve" ? "#d5101a" : "#344054"};font-size:17px;font-weight:900" type="submit">Potvrdit rozhodnutí</button></form><p style="margin-top:15px;color:#98a2b3;font-size:12px">Odkaz je jednorázový. Pouhé otevření e-mailu nic nezmění.</p>`);
    }

    if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);
    const contentType = req.headers.get("content-type") || "";
    if (contentType.includes("application/x-www-form-urlencoded") || contentType.includes("multipart/form-data")) {
      const form = await req.formData();
      const token = String(form.get("token") || "");
      const decision = String(form.get("decision") || "");
      if (!token || !["approve", "reject"].includes(decision)) return page("Neplatné rozhodnutí", "<p>Odkaz je neúplný.</p>", "bad");
      const { data, error } = await admin.rpc("decide_route_stop_skip_v39", { p_token: token, p_decision: decision });
      if (error) return page("Rozhodnutí se nepodařilo uložit", `<p style="line-height:1.5">${escapeHtml(error.message)}</p>`, "bad");
      const approved = data?.status === "approved";
      const rejected = data?.status === "rejected";
      return page(approved ? "Nejetí bylo schváleno" : rejected ? "Žádost byla zamítnuta" : "Žádost už byla vyřízena", `<p style="color:#667085;line-height:1.55">${approved ? "Zastávka je označená jako nejetá. Mobil operátora po obnovení přepočítá pořadí a odemkne další místo." : rejected ? "Zastávka zůstává v trase. Operátor může pokračovat." : `Aktuální stav žádosti: ${escapeHtml(data?.status || "vyřízeno")}.`}</p>`, approved ? "good" : "neutral");
    }

    const body = await req.json();
    if (body?.action === "decision") {
      const token = String(body?.token || "");
      const decision = String(body?.decision || "");
      if (!token || !["approve", "reject"].includes(decision)) return json({ error: "Schvalovací odkaz je neplatný." }, 400);
      const { data, error } = await admin.rpc("decide_route_stop_skip_v39", { p_token: token, p_decision: decision });
      if (error) return json({ error: error.message }, 409);
      return json(data || { ok: true });
    }

    if (!resendApiKey || !emailFrom) return json({ error: "E-mailová služba není nakonfigurovaná." }, 500);
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Chybí přihlášení." }, 401);
    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Přihlášení není platné." }, 401);
    const stopId = Number(body?.route_plan_stop_id || 0);
    const reason = String(body?.reason || "");
    const note = String(body?.note || "").trim();
    if (!stopId || !reasonLabels[reason]) return json({ error: "Vyber platný důvod a zastávku." }, 400);
    if (reason === "other" && !note) return json({ error: "U jiného důvodu napiš krátkou poznámku." }, 400);

    const { data: operator } = await admin.from("employees").select("id,name,surname,email,active").eq("auth_user_id", user.id).maybeSingle();
    if (!operator || operator.active === false) return json({ error: "Aktivní operátor nebyl nalezen." }, 403);
    const { data: stop, error: stopError } = await admin.from("route_plan_stops")
      .select("id,route_plan_id,machine_id,status,completed_at,skipped_at,title,address_snapshot,city_snapshot,route_plans!inner(id,title,planning_date,planned_employee_id,vehicle_id)")
      .eq("id", stopId).maybeSingle();
    if (stopError || !stop) return json({ error: stopError?.message || "Zastávka nebyla nalezena." }, 404);
    const plan = Array.isArray(stop.route_plans) ? stop.route_plans[0] : stop.route_plans;
    if (String(plan?.planned_employee_id || "") !== String(operator.id)) return json({ error: "Zastávka není z trasy přihlášeného operátora." }, 403);
    if (!stop.machine_id) return json({ error: "Zastávka nemá navázaný automat a nelze ji bezpečně uzavřít." }, 409);
    if (["done", "completed", "skipped"].includes(String(stop.status || "")) || stop.completed_at || stop.skipped_at) return json({ error: "Uzavřenou zastávku už nelze označit jako nejetou." }, 409);

    const { data: visit } = await admin.from("route_machine_visits").select("id").eq("route_plan_stop_id", stopId).order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (visit?.id) {
      const [items, checks, cash, counters] = await Promise.all([
        admin.from("route_machine_visit_items").select("id").eq("visit_id", visit.id).not("accepted_at", "is", null).limit(1),
        admin.from("route_machine_visit_checks").select("id").eq("visit_id", visit.id).eq("status", "done").limit(1),
        admin.from("route_machine_cash_reports").select("id").eq("visit_id", visit.id).limit(1),
        admin.from("machine_manual_counter_readings").select("id").eq("visit_id", visit.id).limit(1),
      ]);
      if (items.data?.length || checks.data?.length || cash.data?.length || counters.data?.length) return json({ error: "U automatu už je uložená práce, hotovost nebo kontrolní úkon. Zastávku nelze označit jako nejetou." }, 409);
    }

    const { data: approverRows, error: approverError } = await admin.from("route_skip_approvers").select("employee_id,priority").eq("active", true).order("priority").limit(1);
    if (approverError || !approverRows?.length) return json({ error: "Není nastavený schvalovatel nejetých zastávek." }, 409);
    const approverId = approverRows[0].employee_id;
    const { data: approver } = await admin.from("employees").select("id,name,surname,email,active").eq("id", approverId).maybeSingle();
    if (!approver?.email || approver.active === false) return json({ error: "Schvalovatel nemá aktivní e-mail." }, 409);

    const token = randomToken();
    const tokenHash = await sha256(token);
    const { data: requestRow, error: insertError } = await admin.from("route_stop_skip_requests").insert({
      route_plan_id: plan.id,
      route_plan_stop_id: stop.id,
      operator_employee_id: operator.id,
      approver_employee_id: approver.id,
      reason,
      note: note || null,
      approval_token_hash: tokenHash,
    }).select("id,requested_at").single();
    if (insertError) {
      if (insertError.code === "23505") return json({ error: "U této trasy už jedna žádost čeká na schválení." }, 409);
      return json({ error: insertError.message }, 400);
    }

    const operatorName = [operator.name, operator.surname].filter(Boolean).join(" ") || operator.email || "Operátor";
    const destination = [stop.title, stop.address_snapshot, stop.city_snapshot].filter(Boolean).join(" · ") || `Zastávka #${stop.id}`;
    const approvalPage = Deno.env.get("ROUTE_SKIP_APPROVAL_URL") || "https://olvend.onrender.com/route-skip-approval.html";
    const approveUrl = `${approvalPage}?token=${encodeURIComponent(token)}&decision=approve`;
    const rejectUrl = `${approvalPage}?token=${encodeURIComponent(token)}&decision=reject`;
    const html = `<div style="max-width:620px;margin:auto;font-family:Arial,sans-serif;color:#17212b;line-height:1.5"><div style="font-weight:900;color:#d5101a">OLVEND</div><h1 style="font-size:25px">Schválení nejeté zastávky</h1><p><strong>${escapeHtml(operatorName)}</strong> žádá o vynechání zastávky. Do rozhodnutí je další místo v mobilu uzamčeno.</p><div style="margin:18px 0;border:1px solid #e4e7ec;border-radius:16px;overflow:hidden"><div style="padding:12px 15px;border-bottom:1px solid #e4e7ec"><small>TRASA</small><br><strong>${escapeHtml(plan.title || `Trasa #${plan.id}`)}</strong></div><div style="padding:12px 15px;border-bottom:1px solid #e4e7ec"><small>ZASTÁVKA</small><br><strong>${escapeHtml(destination)}</strong></div><div style="padding:12px 15px;border-bottom:1px solid #e4e7ec"><small>DŮVOD</small><br><strong>${escapeHtml(reasonLabels[reason])}</strong></div><div style="padding:12px 15px"><small>POZNÁMKA</small><br>${escapeHtml(note || "Bez poznámky")}</div></div><table role="presentation" style="width:100%;border-spacing:8px"><tr><td><a href="${escapeHtml(approveUrl)}" style="display:block;padding:14px;border-radius:12px;color:#fff;background:#d5101a;text-align:center;font-weight:900;text-decoration:none">Schválit nejetí</a></td><td><a href="${escapeHtml(rejectUrl)}" style="display:block;padding:14px;border:1px solid #d0d5dd;border-radius:12px;color:#344054;background:#fff;text-align:center;font-weight:900;text-decoration:none">Zamítnout</a></td></tr></table><p style="color:#98a2b3;font-size:12px">Otevření odkazu nejprve zobrazí potvrzovací stránku. Samotný náhled e-mailu rozhodnutí neprovede.</p></div>`;
    const emailFromAddress = emailFrom.match(/<([^>]+)>/)?.[1] || emailFrom;
    const mailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendApiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: `OLVEND by OLMIKA <${emailFromAddress}>`, to: [approver.email], subject: `Ke schválení: ${operatorName} nejel/a ${destination}`, html }),
    });
    if (!mailResponse.ok) {
      const detail = (await mailResponse.text()).slice(0, 1200);
      await admin.from("route_stop_skip_requests").update({ status: "cancelled", decided_at: new Date().toISOString(), decision_note: "E-mail se nepodařilo odeslat.", mail_error: detail }).eq("id", requestRow.id);
      return json({ error: "Žádost se nepodařilo odeslat schvalovateli. Trasa zůstala odemčená.", detail }, 502);
    }
    const delivery = await mailResponse.json();
    const sentAt = new Date().toISOString();
    await admin.from("route_stop_skip_requests").update({ email_sent_at: sentAt, email_delivery_id: delivery?.id || null, mail_error: null }).eq("id", requestRow.id);
    return json({ ok: true, request_id: requestRow.id, requested_at: requestRow.requested_at, email_sent_at: sentAt, approver_name: [approver.name, approver.surname].filter(Boolean).join(" ") });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Neočekávaná chyba." }, 500);
  }
});
