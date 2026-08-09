import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json" },
});

const escapeHtml = (value: unknown) => String(value ?? "")
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;").replace(/'/g, "&#039;");

const money = (value: unknown) => `${new Intl.NumberFormat("cs-CZ", { minimumFractionDigits: 0, maximumFractionDigits: 2 }).format(Number(value || 0))} Kč`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const emailFrom = Deno.env.get("EMAIL_FROM");
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !resendApiKey || !emailFrom) {
      return json({ error: "Missing server configuration." }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing Authorization header." }, 401);
    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
    const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Unauthorized user." }, 401);

    const { data: manager } = await admin.from("employees").select("id, name, surname, role, active").eq("auth_user_id", user.id).maybeSingle();
    const role = String(manager?.role || "").toLocaleLowerCase("cs-CZ");
    if (!manager || manager.active === false || !["admin", "management", "mana", "jednatel"].some((part) => role.includes(part))) {
      return json({ error: "Only an active manager can send an inventory result." }, 403);
    }

    const body = await req.json();
    const auditId = Number(body?.audit_id || 0);
    const recipient = String(body?.recipient || "").trim();
    const subject = String(body?.subject || `OLVEND · Výsledek inventury #${auditId}`).trim();
    const message = String(body?.message || "").trim();
    const protocol = body?.protocol && typeof body.protocol === "object" ? body.protocol : null;
    if (!auditId || !recipient.includes("@") || !protocol || !Array.isArray(protocol.items)) {
      return json({ error: "Invalid inventory result payload." }, 400);
    }

    const { data: audit, error: auditError } = await admin.from("inventory_audits").select("id, assigned_employee_id, status, resolution_status").eq("id", auditId).maybeSingle();
    if (auditError || !audit) return json({ error: auditError?.message || "Inventory audit not found." }, 404);
    if (audit.status !== "closed") {
      return json({ error: "Inventory must be reconciled and closed before the result is sent." }, 409);
    }
    if (audit.resolution_status !== "ready_to_send" && audit.resolution_status !== "sent") {
      return json({ error: "Inventory resolution is not ready to send." }, 409);
    }

    const rows = protocol.items.map((item: Record<string, unknown>) => `<tr>
      <td style="padding:8px;border:1px solid #d7dde5"><strong>${escapeHtml(item.product)}</strong><br><small>${escapeHtml(item.sku)}</small></td>
      <td style="padding:8px;border:1px solid #d7dde5">${escapeHtml(item.difference_quantity)} ${escapeHtml(item.unit)}</td>
      <td style="padding:8px;border:1px solid #d7dde5">${escapeHtml(item.resolution_label)}${item.resolution_note ? `<br><small>${escapeHtml(item.resolution_note)}</small>` : ""}</td>
      <td style="padding:8px;border:1px solid #d7dde5;text-align:right">${escapeHtml(money(item.charge_amount))}</td>
    </tr>`).join("");
    const managerName = [manager.name, manager.surname].filter(Boolean).join(" ").trim();
    const html = `<div style="font-family:Arial,Helvetica,sans-serif;color:#18202b;line-height:1.5;max-width:900px;margin:auto">
      <h2 style="margin:0 0 6px">OL<span style="color:#dc111b">VEND</span> · Výsledek inventury #${auditId}</h2>
      <p style="white-space:pre-line">${escapeHtml(message)}</p>
      <div style="display:grid;grid-template-columns:repeat(3,1fr);border:1px solid #d7dde5;margin:18px 0">
        <div style="padding:10px;border-right:1px solid #d7dde5"><small>DATUM</small><br><strong>${escapeHtml(protocol.audit_date)}</strong></div>
        <div style="padding:10px;border-right:1px solid #d7dde5"><small>MÍSTO</small><br><strong>${escapeHtml(protocol.target)}</strong></div>
        <div style="padding:10px"><small>NAVRŽENO K ÚHRADĚ</small><br><strong>${escapeHtml(money(protocol.charge_total))}</strong></div>
      </div>
      <table style="width:100%;border-collapse:collapse"><thead><tr><th style="padding:8px;border:1px solid #d7dde5;text-align:left;background:#e8eef5">Položka</th><th style="padding:8px;border:1px solid #d7dde5;text-align:left;background:#e8eef5">Rozdíl</th><th style="padding:8px;border:1px solid #d7dde5;text-align:left;background:#e8eef5">Rozhodnutí</th><th style="padding:8px;border:1px solid #d7dde5;text-align:right;background:#e8eef5">Částka</th></tr></thead><tbody>${rows}</tbody></table>
      <h3 style="margin-bottom:4px">Vyjádření manažera</h3><p>${escapeHtml(protocol.manager_note || "Bez doplňujícího vyjádření.")}</p>
      <p style="color:#697587;font-size:12px">Vyhodnotil: ${escapeHtml(managerName)} · Výsledek je uložen také v OLVENDu.</p>
    </div>`;

    const emailFromAddress = emailFrom.match(/<([^>]+)>/)?.[1] || emailFrom;
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendApiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: `OLVEND by OLMIKA <${emailFromAddress}>`, to: [recipient], subject, html }),
    });
    if (!response.ok) return json({ error: await response.text() }, 502);
    const delivery = await response.json();
    const sentAt = new Date().toISOString();
    const { error: updateError } = await admin.from("inventory_audits").update({
      resolution_status: "sent",
      resolution_protocol: protocol,
      resolution_sent_at: sentAt,
      resolution_sent_to: recipient,
    }).eq("id", auditId);
    if (updateError) return json({ error: updateError.message }, 400);

    if (audit.assigned_employee_id) {
      await admin.from("daily_instructions").insert({
        title: `Výsledek inventury #${auditId}`,
        message: `Vyhodnocení inventury je dokončeno. Navržená částka k úhradě: ${money(protocol.charge_total)}. Detail najdeš v Mobil > Sklad > Inventury.`,
        target_type: "employee",
        target_employee_id: audit.assigned_employee_id,
        valid_from: new Date().toISOString().slice(0, 10),
        valid_to: new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10),
        priority: "important",
        requires_acknowledgement: true,
        is_active: true,
      });
    }
    return json({ sent: true, id: delivery?.id || null, sent_at: sentAt });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unexpected error." }, 500);
  }
});
