import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://olvend.onrender.com",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

function addresses(value: unknown) {
  const rows = (Array.isArray(value) ? value : String(value || "").split(","))
    .map((item) => String(item || "").trim())
    .filter(Boolean);
  if (rows.some((item) => !/^\S+@\S+\.\S+$/.test(item))) throw new Error("Neplatná e-mailová adresa příjemce.");
  return rows;
}

function headerText(value: unknown, max = 500) {
  return String(value || "").replace(/[\r\n]+/g, " ").trim().slice(0, max);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !resendApiKey) return json({ error: "Chybí konfigurace e-mailové služby." }, 500);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Nejste přihlášeni." }, 401);
    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
    const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Neplatné přihlášení." }, 401);

    const { data: employee, error: employeeError } = await admin.from("employees")
      .select("id,name,surname,active").eq("auth_user_id", user.id).maybeSingle();
    if (employeeError) return json({ error: employeeError.message }, 400);
    if (!employee || employee.active === false) return json({ error: "Uživatel není propojený s aktivním zaměstnancem." }, 403);

    const { data: account, error: accountError } = await admin.from("mail_accounts")
      .select("email_address,display_name,active").eq("employee_id", employee.id).eq("active", true).limit(1).maybeSingle();
    if (accountError) return json({ error: accountError.message }, 400);
    if (!account) return json({ error: "Schránka není připojená." }, 404);
    const sender = String(account.email_address || "").trim().toLowerCase();
    if (!sender.endsWith("@olmika.cz")) return json({ error: "Osobní odesílání je povoleno pouze z ověřené domény @olmika.cz." }, 403);

    const payload = await req.json().catch(() => ({}));
    const to = addresses(payload.to);
    const cc = addresses(payload.cc);
    const bcc = addresses(payload.bcc);
    if (!to.length) return json({ error: "Doplňte příjemce." }, 400);
    const displayName = headerText(account.display_name || [employee.name, employee.surname].filter(Boolean).join(" "), 120);
    const attachments = (Array.isArray(payload.attachments) ? payload.attachments : []).slice(0, 15).map((item: Record<string, unknown>, index: number) => ({
      filename: headerText(item.filename || `priloha-${index + 1}`, 120),
      content: String(item.content || ""),
      content_type: headerText(item.content_type || "application/octet-stream", 120),
    })).filter((item: { content: string }) => item.content);

    const resendPayload: Record<string, unknown> = {
      from: `${displayName || sender} <${sender}>`,
      reply_to: sender,
      to,
      subject: headerText(payload.subject || "(bez předmětu)"),
      html: String(payload.html || ""),
      text: String(payload.text || ""),
      attachments,
    };
    if (cc.length) resendPayload.cc = cc;
    if (bcc.length) resendPayload.bcc = bcc;
    if (payload.in_reply_to) resendPayload.headers = { "In-Reply-To": headerText(payload.in_reply_to), "References": headerText(payload.references || payload.in_reply_to, 1000) };

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendApiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify(resendPayload),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) return json({ error: String(result?.message || result?.error?.message || "Resend zprávu odmítl."), detail: result }, 502);
    return json({ ok: true, provider_id: result?.id || null, from: sender });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Odeslání se nezdařilo." }, 500);
  }
});
