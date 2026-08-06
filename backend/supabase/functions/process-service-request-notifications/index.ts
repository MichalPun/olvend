import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const escapeHtml = (value: unknown) => String(value ?? "")
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;").replace(/'/g, "&#039;");

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json" },
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const emailFrom = Deno.env.get("EMAIL_FROM");
    const appUrl = String(Deno.env.get("PUBLIC_APP_URL") || "").replace(/\/$/, "");
    if (!supabaseUrl || !serviceRoleKey || !resendApiKey || !emailFrom) {
      return json({ error: "Missing server email configuration." }, 500);
    }

    const payload = await req.json().catch(() => ({}));
    const requestId = Number(payload?.service_request_id);
    if (!Number.isInteger(requestId) || requestId <= 0) {
      return json({ error: "Valid service_request_id is required." }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: requestRow } = await admin
      .from("service_requests")
      .select("id, created_at")
      .eq("id", requestId)
      .maybeSingle();
    if (!requestRow) return json({ error: "Service request not found." }, 404);

    const createdAt = new Date(requestRow.created_at).getTime();
    if (!Number.isFinite(createdAt) || Date.now() - createdAt > 15 * 60 * 1000) {
      return json({ processed: 0, sent: 0, failed: 0, message: "Notification window has expired." });
    }

    const { data: queued, error: queueError } = await admin
      .from("email_notification_queue")
      .select("id, employee_id, subject, body, action_url")
      .eq("kind", "qr_service_request")
      .eq("status", "queued")
      .filter("metadata->>service_request_id", "eq", String(requestId));
    if (queueError) return json({ error: queueError.message }, 400);
    if (!queued?.length) return json({ processed: 0, sent: 0, failed: 0 });

    const queueIds = queued.map((row) => row.id);
    const { data: claimed, error: claimError } = await admin
      .from("email_notification_queue")
      .update({ status: "processing", last_error: null })
      .in("id", queueIds)
      .eq("status", "queued")
      .select("id, employee_id, subject, body, action_url");
    if (claimError) return json({ error: claimError.message }, 400);

    const employeeIds = [...new Set((claimed ?? []).map((row) => row.employee_id))];
    const { data: employees } = await admin
      .from("employees")
      .select("id, name, surname, email")
      .in("id", employeeIds);
    const employeeById = new Map((employees ?? []).map((employee) => [String(employee.id), employee]));

    let sent = 0;
    let failed = 0;
    for (const row of claimed ?? []) {
      const employee = employeeById.get(String(row.employee_id));
      if (!employee?.email) {
        failed += 1;
        await admin.from("email_notification_queue").update({ status: "failed", last_error: "Employee email is missing." }).eq("id", row.id);
        continue;
      }

      const fullName = [employee.name, employee.surname].filter(Boolean).join(" ").trim();
      const actionUrl = row.action_url && appUrl
        ? `${appUrl}/${String(row.action_url).replace(/^\//, "")}`
        : null;
      const html = `
        <div style="font-family:Arial,Helvetica,sans-serif;line-height:1.6;color:#181b23;max-width:620px;margin:auto">
          <div style="padding:22px 24px;background:#1c2029;border-radius:16px 16px 0 0;color:#fff">
            <div style="font-size:12px;letter-spacing:.1em;color:#ffb7bb;font-weight:700">NOVÉ SERVISNÍ HLÁŠENÍ</div>
            <h2 style="margin:6px 0 0">OLVEND</h2>
          </div>
          <div style="padding:24px;border:1px solid #e5e8ef;border-top:0;border-radius:0 0 16px 16px">
            <p style="margin:0 0 14px">Dobrý den${fullName ? `, ${escapeHtml(fullName)}` : ""},</p>
            <p style="margin:0 0 18px">z QR kódu právě dorazilo nové hlášení poruchy:</p>
            <div style="padding:16px;background:#f7f8fb;border-radius:12px;white-space:pre-line">${escapeHtml(row.body)}</div>
            ${actionUrl ? `<p style="margin:22px 0 0"><a href="${escapeHtml(actionUrl)}" style="display:inline-block;padding:11px 17px;border-radius:10px;background:#d5101a;color:#fff;text-decoration:none;font-weight:700">Otevřít servisní požadavek</a></p>` : ""}
          </div>
        </div>`;

      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${resendApiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from: emailFrom, to: [employee.email], subject: row.subject, html }),
      });
      if (!response.ok) {
        failed += 1;
        const detail = await response.text();
        await admin.from("email_notification_queue").update({ status: "failed", last_error: detail.slice(0, 1200) }).eq("id", row.id);
      } else {
        sent += 1;
        await admin.from("email_notification_queue").update({ status: "sent", last_error: null }).eq("id", row.id);
      }
    }

    return json({ processed: claimed?.length ?? 0, sent, failed });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown server error." }, 500);
  }
});
