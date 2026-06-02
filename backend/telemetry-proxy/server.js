import http from 'node:http'

const PORT = Number(process.env.PORT || 10000)
const PROXY_PATH = process.env.TELEMETRY_PROXY_PATH || '/gp-vendsoft-telemetry'
const TARGET_URL = process.env.SUPABASE_TELEMETRY_URL || 'https://rerjlkrhiytgscjerqgs.supabase.co/functions/v1/gp-vendsoft-telemetry'
const INGEST_TOKEN = process.env.TELEMETRY_INGEST_TOKEN || ''
const PROXY_TOKEN = process.env.TELEMETRY_PROXY_TOKEN || ''
const BODY_LIMIT_BYTES = Number(process.env.TELEMETRY_BODY_LIMIT_BYTES || 5 * 1024 * 1024)

function send(res, status, body, headers = {}) {
  const text = typeof body === 'string' ? body : JSON.stringify(body)
  res.writeHead(status, {
    'Content-Type': typeof body === 'string' ? 'text/plain; charset=utf-8' : 'application/json; charset=utf-8',
    ...headers
  })
  res.end(text)
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = []
    let size = 0
    req.on('data', (chunk) => {
      size += chunk.length
      if (size > BODY_LIMIT_BYTES) {
        reject(new Error(`Payload is too large. Limit is ${BODY_LIMIT_BYTES} bytes.`))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on('end', () => resolve(Buffer.concat(chunks)))
    req.on('error', reject)
  })
}

function isAuthorized(req, url) {
  if (!PROXY_TOKEN) return true
  const provided = req.headers['x-olvend-proxy-token'] || url.searchParams.get('proxy_token') || ''
  return String(provided) === PROXY_TOKEN
}

function hasDexShape(body) {
  const text = body.toString('utf8')
  return /<RawDEX\b/i.test(text) || /^DXS\*/m.test(text.trim())
}

async function forwardToSupabase(body, req) {
  if (!INGEST_TOKEN) {
    throw new Error('Missing TELEMETRY_INGEST_TOKEN environment variable.')
  }

  const response = await fetch(TARGET_URL, {
    method: 'POST',
    headers: {
      'Content-Type': req.headers['content-type'] || 'application/xml; charset=utf-8',
      'x-olvend-telemetry-token': INGEST_TOKEN
    },
    body
  })

  const responseBody = await response.text()
  return {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('content-type') || 'application/json; charset=utf-8'
    },
    body: responseBody
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`)

  if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/healthz')) {
    return send(res, 200, {
      ok: true,
      service: 'olvend-telemetry-proxy',
      target: TARGET_URL,
      path: PROXY_PATH
    })
  }

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'content-type, x-olvend-proxy-token',
      'Access-Control-Allow-Methods': 'POST, OPTIONS'
    })
    return res.end()
  }

  if (url.pathname !== PROXY_PATH) {
    return send(res, 404, { error: 'Not found.' })
  }

  if (req.method !== 'POST') {
    return send(res, 405, { error: 'Method not allowed.' })
  }

  if (!isAuthorized(req, url)) {
    return send(res, 401, { error: 'Unauthorized telemetry proxy request.' })
  }

  try {
    const body = await readBody(req)
    if (!body.length) {
      return send(res, 400, { error: 'Empty telemetry payload.' })
    }
    if (!hasDexShape(body)) {
      return send(res, 400, { error: 'Payload does not look like VDI/DEX telemetry.' })
    }

    const upstream = await forwardToSupabase(body, req)
    res.writeHead(upstream.status, upstream.headers)
    return res.end(upstream.body)
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown telemetry proxy error.'
    return send(res, 502, { error: message })
  }
})

server.listen(PORT, () => {
  console.log(`OLVEND telemetry proxy listening on ${PORT}, path ${PROXY_PATH}`)
})
