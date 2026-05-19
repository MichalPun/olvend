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

function cleanEmail(value: unknown) {
  return String(value ?? "").trim();
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
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const emailFrom = Deno.env.get("EMAIL_FROM");

    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Missing Supabase environment variables." }, 500);
    }
    if (!resendApiKey || !emailFrom) {
      return json({ error: "Missing email provider configuration." }, 500);
    }

    const payload = await req.json().catch(() => ({}));
    const to = cleanEmail(payload?.to);
    const cc = cleanEmail(payload?.cc);
    const bcc = cleanEmail(payload?.bcc);
    const subject = String(payload?.subject || "Faktura OLVEND").trim();
    const html = String(payload?.html || "").trim();
    const pdfBase64 = String(payload?.pdfBase64 || "").trim();
    const fileName = String(payload?.fileName || "faktura.pdf").replace(/[^\w.\-]+/g, "_");
    const documentId = payload?.documentId ? Number(payload.documentId) : null;

    if (!to || !to.includes("@")) return json({ error: "Recipient email is required." }, 400);
    if (!pdfBase64) return json({ error: "PDF attachment is required." }, 400);

    const mailPayload: Record<string, unknown> = {
      from: emailFrom,
      to: [to],
      subject,
      html: html || "<p>Dobrý den,<br>v příloze zasíláme fakturu.</p>",
      attachments: [{
        filename: fileName,
        content: pdfBase64,
      }],
    };
    if (cc) mailPayload.cc = [cc];
    if (bcc) mailPayload.bcc = [bcc];

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(mailPayload),
    });

    const resendData = await resendResponse.json().catch(async () => ({ raw: await resendResponse.text() }));
    if (!resendResponse.ok) {
      return json({ error: "Email provider rejected the message.", detail: resendData }, 502);
    }

    if (documentId) {
      const adminClient = createClient(supabaseUrl, serviceRoleKey, {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      });
      await adminClient.from("sales_documents").update({ updated_at: new Date().toISOString() }).eq("id", documentId);
    }

    return json({
      ok: true,
      provider_id: resendData?.id || null,
      sent_to: to,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
