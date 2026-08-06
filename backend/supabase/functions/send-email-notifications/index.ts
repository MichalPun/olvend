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
  const routeMarkup = sourceName || targetName ? `
    <div style="border:1px solid #d9dee6;margin-top:12px">
      <div style="padding:9px 12px;background:#edf0f4;border-bottom:1px solid #d9dee6;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#48515d">Trasa</div>
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr>
        <td style="padding:15px 14px;width:46%;vertical-align:top"><strong>${escapeHtml(sourceName || "Neuvedeno")}</strong><br><span style="color:#737d8a;font-size:12px">Výchozí místo</span></td>
        <td style="padding:15px 6px;text-align:center;color:#d5101a;font-size:20px;font-weight:700">→</td>
        <td style="padding:15px 14px;width:46%;vertical-align:top"><strong>${escapeHtml(targetName || primaryPlace)}</strong><br><span style="color:#737d8a;font-size:12px">Cílové místo</span></td>
      </tr></table>
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
        <div style="font-weight:800;letter-spacing:.12em;font-size:17px;margin-bottom:20px"><span style="color:#ed1c24">OL</span>VEND</div>
        <div style="font-size:11px;text-transform:uppercase;letter-spacing:.1em;color:#aeb6c2;margin-bottom:7px">${isUpdate ? "Aktualizace přiděleného úkolu" : "Byl vám přidělen nový úkol"}</div>
        <h1 style="font-size:25px;line-height:1.2;margin:0 0 8px;color:#fff">${escapeHtml(title)}</h1>
        <div style="font-size:13px;color:#cbd2dc">TZ-${escapeHtml(metadata.technical_job_id)} · ${escapeHtml(jobTypeLabel(jobType))}${machineName ? ` · ${escapeHtml(machineName)}` : ""}</div>
      </div>
      <div style="padding:24px 28px 28px">
        <p style="font-size:14px;line-height:1.6;margin:0 0 18px">Dobrý den, ${escapeHtml(fullName)},<br>${isUpdate ? "zadání vašeho úkolu bylo aktualizováno." : "byl vám přidělen následující úkol."} Níže máte všechny údaje potřebné k přípravě a provedení.</p>
        ${warning}
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #d9dee6;background:#f7f8fa;margin-bottom:18px"><tr>
          <td style="padding:13px 14px;border-right:1px solid #d9dee6"><span style="display:block;font-size:10px;text-transform:uppercase;color:#7b8491;margin-bottom:5px">Termín</span><strong>${escapeHtml(due)}</strong></td>
          <td style="padding:13px 14px;border-right:1px solid #d9dee6"><span style="display:block;font-size:10px;text-transform:uppercase;color:#7b8491;margin-bottom:5px">Typ</span><strong>${escapeHtml(jobTypeLabel(jobType))}</strong></td>
          <td style="padding:13px 14px"><span style="display:block;font-size:10px;text-transform:uppercase;color:#7b8491;margin-bottom:5px">Místo</span><strong>${escapeHtml(primaryPlace)}</strong></td>
        </tr></table>
        ${routeMarkup}
        <div style="border:1px solid #d9dee6;margin-top:12px">
          <div style="padding:9px 12px;background:#edf0f4;border-bottom:1px solid #d9dee6;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#48515d">Rozsah práce</div>
          <div style="padding:14px;font-size:13px;line-height:1.6"><strong>${escapeHtml(machineName || title)}</strong><br>${escapeHtml(metadata.description || configuration.summary || metadata.workshop_note || "Podrobnosti jsou uvedené v OLVENDu.")}</div>
        </div>
        ${materialsMarkup}${checklistMarkup}${contactMarkup}
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
      .select("id, role, active")
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

    let queueQuery = adminClient
      .from("email_notification_queue")
      .select("id, employee_id, kind, subject, body, action_url, metadata, scheduled_for")
      .eq("status", "queued")
      .lte("scheduled_for", new Date().toISOString());

    if (requestedQueueId) {
      queueQuery = queueQuery.eq("id", requestedQueueId);
    }

    const { data: queueRows, error: queueError } = await queueQuery
      .order("scheduled_for", { ascending: true })
      .limit(requestedQueueId ? 1 : limit);

    if (queueError) {
      return json({ error: queueError.message }, 400);
    }

    const rows = (queueRows ?? []) as QueueRow[];
    if (!rows.length) {
      return json({ processed: 0, sent: 0, failed: 0, message: "No queued notifications." });
    }

    const employeeIds = [...new Set(rows.map((row) => row.employee_id).filter(Boolean))];
    const { data: employees, error: employeesError } = await adminClient
      .from("employees")
      .select("id, name, surname, email")
      .in("id", employeeIds);

    if (employeesError) {
      return json({ error: employeesError.message }, 400);
    }

    const employeeById = new Map((employees ?? []).map((employee) => [String(employee.id), employee]));

    let sent = 0;
    let failed = 0;

    for (const row of rows) {
      const employee = employeeById.get(String(row.employee_id));
      if (!employee?.email) {
        failed += 1;
        await adminClient
          .from("email_notification_queue")
          .update({ status: "failed", last_error: "Employee email is missing." })
          .eq("id", row.id);
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
          subject: row.subject,
          html,
        }),
      });

      if (!resendResponse.ok) {
        failed += 1;
        const errorText = await resendResponse.text();
        await adminClient
          .from("email_notification_queue")
          .update({ status: "failed", last_error: errorText.slice(0, 1200) })
          .eq("id", row.id);
        continue;
      }

      sent += 1;
      await adminClient
        .from("email_notification_queue")
        .update({ status: "sent", last_error: null })
        .eq("id", row.id);
    }

    return json({
      processed: rows.length,
      sent,
      failed,
      message: sent ? "Queued email notifications were processed." : "No emails were sent.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
