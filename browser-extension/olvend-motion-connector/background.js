importScripts("normalize.js");

const MOJIO_API = "https://tmobile-cz-api.moj.io/v2";
const MOJIO_WEB = "https://tmobile-cz-web.moj.io/live-view";
const OLVEND_WEB = "https://olvend.onrender.com/dashboard.html";
const INGEST_URL = "https://rerjlkrhiytgscjerqgs.supabase.co/functions/v1/mojio-fleet-ingest";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S";
const SYNC_ALARM = "olvend-motion-sync";
const REFRESH_ALARM = "olvend-motion-refresh";

async function setStatus(patch) {
  await chrome.storage.local.set({ status: { ...(await chrome.storage.local.get("status")).status, ...patch } });
}

function jwtExpiry(token) {
  try {
    const payload = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return Number(JSON.parse(atob(payload)).exp || 0) * 1000;
  } catch (_) {
    return 0;
  }
}

async function fetchJson(url, token) {
  const response = await fetch(url, { headers: { Authorization: `Bearer ${token}`, Accept: "application/json" } });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return response.json();
}

async function syncFleet() {
  const state = await chrome.storage.local.get(["mojioToken", "olvendToken"]);
  if (!state.mojioToken) {
    await setStatus({ state: "needs_mojio", message: "Otevřete jednou T-Mobile Motion.", lastAttemptAt: new Date().toISOString() });
    return;
  }
  if (!state.olvendToken) {
    await setStatus({ state: "needs_olvend", message: "Otevřete jednou nástěnku OLVEND.", lastAttemptAt: new Date().toISOString() });
    return;
  }
  if (jwtExpiry(state.mojioToken) <= Date.now()) {
    await setStatus({ state: "needs_mojio", message: "Přihlášení T-Mobile Motion vypršelo.", lastAttemptAt: new Date().toISOString() });
    await ensureBackgroundTab(MOJIO_WEB, "temporaryMojioTabId");
    return;
  }
  if (jwtExpiry(state.olvendToken) <= Date.now()) {
    await setStatus({ state: "needs_olvend", message: "Přihlášení OLVEND vypršelo.", lastAttemptAt: new Date().toISOString() });
    await ensureBackgroundTab(OLVEND_WEB, "temporaryOlvendTabId");
    return;
  }

  await setStatus({ state: "syncing", message: "Aktualizuji polohy…", lastAttemptAt: new Date().toISOString() });
  try {
    const [vehicles, mojios] = await Promise.all([
      fetchJson(`${MOJIO_API}/vehicles?top=25`, state.mojioToken),
      fetchJson(`${MOJIO_API}/mojios?top=25`, state.mojioToken),
    ]);
    const rows = self.OlvendMojioNormalize.normalizeVehicles(vehicles, mojios);
    if (!rows.length) throw new Error("T-Mobile Motion nevrátil polohy vozidel.");
    const response = await fetch(INGEST_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${state.olvendToken}`,
        apikey: SUPABASE_PUBLISHABLE_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ rows }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(result.error || `${response.status} ${response.statusText}`);
    await setStatus({
      state: "connected",
      message: `${rows.length} vozidel synchronizováno.`,
      vehicleCount: rows.length,
      lastSyncAt: new Date().toISOString(),
      mojioExpiresAt: new Date(jwtExpiry(state.mojioToken)).toISOString(),
      error: null,
    });
  } catch (error) {
    await setStatus({ state: "error", message: String(error?.message || error), error: String(error?.message || error) });
  }
}

async function ensureBackgroundTab(url, storageKey) {
  const stored = await chrome.storage.local.get(storageKey);
  if (stored[storageKey]) {
    try {
      const existing = await chrome.tabs.get(stored[storageKey]);
      if (existing) return existing.id;
    } catch (_) {
      await chrome.storage.local.remove(storageKey);
    }
  }
  const tab = await chrome.tabs.create({ url, active: false });
  await chrome.storage.local.set({ [storageKey]: tab.id });
  return tab.id;
}

async function closeTemporaryTab(storageKey) {
  const stored = await chrome.storage.local.get(storageKey);
  const tabId = stored[storageKey];
  if (!tabId) return;
  await chrome.storage.local.remove(storageKey);
  try { await chrome.tabs.remove(tabId); } catch (_) {}
}

async function refreshSessionsIfNeeded() {
  const state = await chrome.storage.local.get(["mojioToken", "olvendToken"]);
  if (!state.mojioToken || jwtExpiry(state.mojioToken) - Date.now() < 2 * 60 * 60 * 1000) {
    await ensureBackgroundTab(MOJIO_WEB, "temporaryMojioTabId");
  }
  if (!state.olvendToken || jwtExpiry(state.olvendToken) - Date.now() < 10 * 60 * 1000) {
    await ensureBackgroundTab(OLVEND_WEB, "temporaryOlvendTabId");
  }
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type === "mojio-token" && message.token) {
    chrome.storage.local.set({ mojioToken: message.token }).then(async () => {
      await closeTemporaryTab("temporaryMojioTabId");
      await syncFleet();
      sendResponse({ ok: true });
    });
    return true;
  }
  if (message?.type === "olvend-token" && message.token) {
    chrome.storage.local.set({ olvendToken: message.token }).then(async () => {
      await closeTemporaryTab("temporaryOlvendTabId");
      await syncFleet();
      sendResponse({ ok: true });
    });
    return true;
  }
  if (message?.type === "sync-now") {
    syncFleet().then(() => sendResponse({ ok: true }));
    return true;
  }
  return false;
});

chrome.runtime.onInstalled.addListener(async () => {
  chrome.alarms.create(SYNC_ALARM, { periodInMinutes: 1 });
  chrome.alarms.create(REFRESH_ALARM, { periodInMinutes: 30 });
  await setStatus({ state: "starting", message: "Navazuji přihlášené relace…" });
  await refreshSessionsIfNeeded();
});

chrome.runtime.onStartup.addListener(async () => {
  chrome.alarms.create(SYNC_ALARM, { periodInMinutes: 1 });
  chrome.alarms.create(REFRESH_ALARM, { periodInMinutes: 30 });
  await refreshSessionsIfNeeded();
  await syncFleet();
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === SYNC_ALARM) syncFleet();
  if (alarm.name === REFRESH_ALARM) refreshSessionsIfNeeded();
});

syncFleet();
