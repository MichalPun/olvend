import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
});

const escapeHtml = (value: unknown) => String(value ?? "")
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;").replace(/'/g, "&#039;");

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
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const emailFrom = Deno.env.get("EMAIL_FROM");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) return json({ error: "Chybí serverová konfigurace." }, 500);
  const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });

  try {
    const body = await req.json();
    if (body?.action === "decision") {
      const token = String(body?.token || "");
      const decision = String(body?.decision || "");
      if (!token || !["approve", "reject"].includes(decision)) return json({ error: "Schvalovací odkaz je neplatný." }, 400);
      const { data, error } = await admin.rpc("decide_route_add_machine_v52", { p_token: token, p_decision: decision });
      if (error) return json({ error: error.message }, 409);
      return json(data || { ok: true });
    }

    if (!resendApiKey || !emailFrom) return json({ error: "E-mailová služba není nakonfigurovaná." }, 500);
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Chybí přihlášení." }, 401);
    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Přihlášení není platné." }, 401);

    const routePlanId = Number(body?.route_plan_id || 0);
    const machineId = Number(body?.machine_id || 0);
    const note = String(body?.note || "").trim().slice(0, 500);
    if (!routePlanId || !machineId) return json({ error: "Vyber trasu a automat." }, 400);

    const { data: operator } = await admin.from("employees").select("id,name,surname,email,active").eq("auth_user_id", user.id).maybeSingle();
    if (!operator || operator.active === false) return json({ error: "Aktivní operátor nebyl nalezen." }, 403);
    const { data: plan, error: planError } = await admin.from("route_plans")
      .select("id,title,planning_date,planned_employee_id,execution_status,completed_at")
      .eq("id", routePlanId).maybeSingle();
    if (planError || !plan) return json({ error: planError?.message || "Trasa nebyla nalezena." }, 404);
    if (String(plan.planned_employee_id || "") !== String(operator.id)) return json({ error: "Trasa není přiřazena přihlášenému operátorovi." }, 403);
    if (["completed", "cancelled"].includes(String(plan.execution_status || "")) || plan.completed_at) return json({ error: "Uzavřenou trasu už nelze rozšířit." }, 409);

    const { data: machine, error: machineError } = await admin.from("machines")
      .select("id,name,evidence_number,machine_type,location_id,active,locations(id,name,city,address,active)")
      .eq("id", machineId).maybeSingle();
    if (machineError || !machine || machine.active === false) return json({ error: machineError?.message || "Aktivní automat nebyl nalezen." }, 404);
    const location = Array.isArray(machine.locations) ? machine.locations[0] : machine.locations;
    if (!location || location.active === false) return json({ error: "Lokalita automatu není aktivní." }, 409);

    const { data: existingStop } = await admin.from("route_plan_stops").select("id,status")
      .eq("route_plan_id", routePlanId).eq("machine_id", machineId).neq("status", "skipped").limit(1).maybeSingle();
    if (existingStop) return json({ error: "Tento automat už v trase je." }, 409);

    const { data: approverRows, error: approverError } = await admin.from("route_skip_approvers")
      .select("employee_id,priority").eq("active", true).order("priority").limit(1);
    if (approverError || !approverRows?.length) return json({ error: "Není nastavený schvalovatel změn trasy." }, 409);
    const { data: approver } = await admin.from("employees").select("id,name,surname,email,active").eq("id", approverRows[0].employee_id).maybeSingle();
    if (!approver?.email || approver.active === false) return json({ error: "Schvalovatel nemá aktivní e-mail." }, 409);

    const token = randomToken();
    const tokenHash = await sha256(token);
    const { data: requestRow, error: insertError } = await admin.from("route_add_machine_requests").insert({
      route_plan_id: routePlanId,
      machine_id: machineId,
      operator_employee_id: operator.id,
      approver_employee_id: approver.id,
      note: note || null,
      approval_token_hash: tokenHash,
    }).select("id,requested_at").single();
    if (insertError) {
      if (insertError.code === "23505") return json({ error: "Žádost o tento automat už čeká na schválení." }, 409);
      return json({ error: insertError.message }, 400);
    }

    const operatorName = [operator.name, operator.surname].filter(Boolean).join(" ") || operator.email || "Operátor";
    const machineLabel = [`EV ${machine.evidence_number || "—"}`, location.name, machine.name].filter(Boolean).join(" · ");
    const approvalPage = Deno.env.get("ROUTE_ADD_APPROVAL_URL") || "https://olvend.onrender.com/route-add-approval.html";
    const approveUrl = `${approvalPage}?token=${encodeURIComponent(token)}&decision=approve`;
    const rejectUrl = `${approvalPage}?token=${encodeURIComponent(token)}&decision=reject`;
    const html = `<div style="max-width:620px;margin:auto;font-family:Arial,sans-serif;color:#17212b;line-height:1.5"><div style="font-weight:900;color:#d5101a">OLVEND</div><h1 style="font-size:25px">Přidání automatu do trasy</h1><p><strong>${escapeHtml(operatorName)}</strong> potřebuje doplnit automat, který v dnešní trase chybí.</p><div style="margin:18px 0;border:1px solid #e4e7ec;border-radius:16px;overflow:hidden"><div style="padding:12px 15px;border-bottom:1px solid #e4e7ec"><small>TRASA</small><br><strong>${escapeHtml(plan.title || `Trasa #${plan.id}`)}</strong></div><div style="padding:12px 15px;border-bottom:1px solid #e4e7ec"><small>AUTOMAT</small><br><strong>${escapeHtml(machineLabel)}</strong></div><div style="padding:12px 15px"><small>POZNÁMKA</small><br>${escapeHtml(note || "Bez poznámky")}</div></div><table role="presentation" style="width:100%;border-spacing:8px"><tr><td><a href="${escapeHtml(approveUrl)}" style="display:block;padding:14px;border-radius:12px;color:#fff;background:#d5101a;text-align:center;font-weight:900;text-decoration:none">Schválit přidání</a></td><td><a href="${escapeHtml(rejectUrl)}" style="display:block;padding:14px;border:1px solid #d0d5dd;border-radius:12px;color:#344054;background:#fff;text-align:center;font-weight:900;text-decoration:none">Zamítnout</a></td></tr></table><p style="color:#98a2b3;font-size:12px">Po schválení se automat přidá do zbývající části trasy. Mobil ho po obnovení zařadí do pořadí.</p></div>`;
    const emailFromAddress = emailFrom.match(/<([^>]+)>/)?.[1] || emailFrom;
    const mailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendApiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: `OLVEND by OLMIKA <${emailFromAddress}>`, to: [approver.email], subject: `Ke schválení: přidat ${machineLabel} do trasy`, html }),
    });
    if (!mailResponse.ok) {
      const detail = (await mailResponse.text()).slice(0, 1200);
      await admin.from("route_add_machine_requests").update({ status: "cancelled", decided_at: new Date().toISOString(), decision_note: "E-mail se nepodařilo odeslat.", mail_error: detail }).eq("id", requestRow.id);
      return json({ error: "Žádost se nepodařilo odeslat schvalovateli.", detail }, 502);
    }
    const delivery = await mailResponse.json();
    const sentAt = new Date().toISOString();
    await admin.from("route_add_machine_requests").update({ email_sent_at: sentAt, email_delivery_id: delivery?.id || null, mail_error: null }).eq("id", requestRow.id);
    return json({ ok: true, request_id: requestRow.id, requested_at: requestRow.requested_at, email_sent_at: sentAt, approver_name: [approver.name, approver.surname].filter(Boolean).join(" ") });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Neočekávaná chyba." }, 500);
  }
});
