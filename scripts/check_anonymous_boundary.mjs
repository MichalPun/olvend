// Read-only production probes. limit=0 prevents downloading rows even on failure.
// An error or an inaccessible server is a failed check, never a successful denial.
import assert from 'node:assert/strict';
import fs from 'node:fs';

export const internalTables = [
  'employees', 'employee_directory', 'employee_location_logs', 'hr_requests',
  'attendance_days', 'machines', 'products', 'stock_movements',
  'telemetry_sales_events', 'service_requests', 'warehouses', 'email_notification_queue',
];

export async function checkAnonymousBoundary(url, key, fetcher = fetch) {
  const failures = [];
  for (const table of internalTables) {
    try {
      const response = await fetcher(`${url}/rest/v1/${table}?select=*&limit=0`, {
        method: 'GET', redirect: 'error', signal: AbortSignal.timeout(15000),
        headers: { apikey: key, authorization: `Bearer ${key}` },
      });
      // A wrong key also returns 401. Require the database's insufficient-privilege
      // code, not merely an HTTP status, to avoid a false pass on invalid credentials.
      const body = await response.json();
      if (![401, 403].includes(response.status) || body.code !== '42501') {
        failures.push(`${table}: expected database denial, received HTTP ${response.status}`);
      }
    } catch {
      failures.push(`${table}: request could not be verified`);
    }
  }
  if (failures.length) throw new Error(failures.join('\n'));
}

if (process.argv.includes('--self-test')) {
  const denied = async () => new Response(JSON.stringify({ code: '42501' }), { status: 401 });
  await checkAnonymousBoundary('https://example.test', 'public-test-key', denied);
  for (const status of [200, 204, 301, 404, 429, 500]) {
    let calls = 0;
    await assert.rejects(checkAnonymousBoundary('https://example.test', 'key', async (url) => {
      assert.equal(new URL(url).searchParams.get('limit'), '0');
      if (++calls > 1) return denied();
      return new Response(status === 204 ? null : '{}', { status });
    }));
  }
  await assert.rejects(checkAnonymousBoundary('https://example.test', 'key', async () => {
    return new Response('{"message":"Invalid API key"}', { status: 401 });
  }));
  await assert.rejects(checkAnonymousBoundary('https://example.test', 'key', async () => { throw Error('offline'); }));
  console.log('PASS: open access, invalid credentials, redirects and network failures fail the check');
} else if (process.argv.includes('--live')) {
  const config = fs.readFileSync(new URL('../supabase.js', import.meta.url), 'utf8');
  const url = config.match(/export const supabaseUrl = '([^']+)'/)?.[1];
  const key = config.match(/export const supabaseAnonKey = '([^']+)'/)?.[1];
  assert.ok(url && key?.startsWith('sb_publishable_'), 'Expected explicit public project configuration');
  await checkAnonymousBoundary(url, key);
  console.log(`PASS: all ${internalTables.length} internal endpoints reject anonymous access; no rows downloaded`);
}
