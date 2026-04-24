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

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Missing Supabase environment variables." }, 500);
    }

    if (!resendApiKey || !emailFrom) {
      return json({ error: "Missing email provider configuration." }, 500);
    }

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

    const { data: queueRows, error: queueError } = await adminClient
      .from("email_notification_queue")
      .select("id, employee_id, kind, subject, body, action_url, metadata, scheduled_for")
      .eq("status", "queued")
      .lte("scheduled_for", new Date().toISOString())
      .order("scheduled_for", { ascending: true })
      .limit(limit);

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
      const html = `
        <div style="font-family:Arial,Helvetica,sans-serif;line-height:1.6;color:#111">
          <h2 style="margin:0 0 16px">OLVEND</h2>
          <p style="margin:0 0 12px">Dobrý den, ${fullName},</p>
          <p style="margin:0 0 12px; white-space:pre-line;">${row.body}</p>
          ${row.action_url ? `<p style="margin:20px 0"><a href="${row.action_url}" style="display:inline-block;padding:10px 16px;border-radius:10px;background:#d5101a;color:#fff;text-decoration:none;font-weight:700">Otevřít v OLVENDu</a></p>` : ""}
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
          from: emailFrom,
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
