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

function normalizeVatId(value: unknown) {
  const raw = String(value ?? "").trim().toUpperCase().replace(/\s/g, "");
  const stripped = raw.startsWith("CZ") ? raw.slice(2) : raw;
  return stripped.replace(/\D/g, "").slice(0, 10);
}

function escapeXml(value: string) {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function readAttribute(source: string, name: string) {
  const match = source.match(new RegExp(`${name}="([^"]*)"`, "i"));
  return match?.[1] ?? "";
}

function parseVatResponse(xml: string, dic: string) {
  const statusMatch = xml.match(/<status\b([^>]*)\/?>/i);
  const status = {
    code: Number(readAttribute(statusMatch?.[1] || "", "statusCode") || 0),
    text: readAttribute(statusMatch?.[1] || "", "statusText") || "OK",
    generatedAt: readAttribute(statusMatch?.[1] || "", "odpovedGenerovana") || null,
  };
  const payerMatch = xml.match(/<statusPlatceDPH\b([^>]*)>([\s\S]*?)<\/statusPlatceDPH>/i);
  if (!payerMatch) {
    return {
      dic: `CZ${dic}`,
      payerFound: false,
      unreliable: null,
      accounts: [],
      checkedAt: status.generatedAt,
      status,
    };
  }
  const attrs = payerMatch[1] || "";
  const body = payerMatch[2] || "";
  const unreliableRaw = readAttribute(attrs, "nespolehlivyPlatce");
  const accounts = Array.from(body.matchAll(/<ucet\b([^>]*)>([\s\S]*?)<\/ucet>/gi)).map((match) => {
    const accountAttrs = match[1] || "";
    const accountBody = match[2] || "";
    const standard = accountBody.match(/<standardniUcet\b([^>]*)\/?>/i);
    if (standard) {
      const standardAttrs = standard[1] || "";
      const prefix = readAttribute(standardAttrs, "predcisli");
      const number = readAttribute(standardAttrs, "cislo");
      const bankCode = readAttribute(standardAttrs, "kodBanky");
      return {
        type: "standard",
        accountNumber: prefix ? `${prefix}-${number}` : number,
        bankCode,
        iban: "",
        publishedAt: readAttribute(accountAttrs, "datumZverejneni") || null,
        endedAt: readAttribute(accountAttrs, "datumZverejneniUkonceni") || null,
      };
    }
    const nonStandard = accountBody.match(/<nestandardniUcet\b([^>]*)\/?>/i);
    const nonStandardNumber = readAttribute(nonStandard?.[1] || "", "cislo");
    return {
      type: "nonstandard",
      accountNumber: "",
      bankCode: "",
      iban: nonStandardNumber.startsWith("CZ") ? nonStandardNumber : "",
      rawAccount: nonStandardNumber,
      publishedAt: readAttribute(accountAttrs, "datumZverejneni") || null,
      endedAt: readAttribute(accountAttrs, "datumZverejneniUkonceni") || null,
    };
  }).filter((account) => !account.endedAt);
  return {
    dic: `CZ${dic}`,
    payerFound: unreliableRaw !== "NENALEZEN",
    unreliable: unreliableRaw === "ANO" ? true : unreliableRaw === "NE" ? false : null,
    accounts,
    checkedAt: status.generatedAt,
    status,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  try {
    const payload = await req.json().catch(() => ({}));
    const dic = normalizeVatId(payload?.dic || payload?.ico);
    if (!dic) return json({ error: "DIČ nebo IČO je povinné." }, 400);

    const soapBody = `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:roz="http://adis.mfcr.cz/rozhraniCRPDPH/"><soapenv:Header/><soapenv:Body><roz:StatusNespolehlivyPlatceRequest><roz:dic>${escapeXml(dic)}</roz:dic></roz:StatusNespolehlivyPlatceRequest></soapenv:Body></soapenv:Envelope>`;
    const response = await fetch("https://mojedane.gov.cz/dpr/axis2/services/rozhraniCRPDPH.rozhraniCRPDPHSOAP", {
      method: "POST",
      headers: {
        "Content-Type": "text/xml; charset=utf-8",
        SOAPAction: "http://adis.mfcr.cz/rozhraniCRPDPH/getStatusNespolehlivyPlatce",
      },
      body: soapBody,
    });
    const xml = await response.text();
    if (!response.ok) {
      return json({ error: `Registr DPH vrátil chybu ${response.status}.`, detail: xml.slice(0, 500) }, 502);
    }
    return json(parseVatResponse(xml, dic));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
