const statusElement = document.getElementById("status");
const syncButton = document.getElementById("sync");

function formatTime(value) {
  if (!value) return "";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "" : date.toLocaleTimeString("cs-CZ", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

async function render() {
  const { status = {} } = await chrome.storage.local.get("status");
  statusElement.className = `status ${status.state === "connected" ? "ok" : status.state === "error" ? "error" : ""}`;
  statusElement.querySelector("strong").textContent = status.state === "connected" ? "Připojeno" : status.state === "error" ? "Chyba připojení" : "Navazuji připojení";
  statusElement.querySelector("span").textContent = `${status.message || "Čekám na přihlášené relace."}${status.lastSyncAt ? ` Naposledy ${formatTime(status.lastSyncAt)}.` : ""}`;
}

syncButton.addEventListener("click", async () => {
  syncButton.disabled = true;
  syncButton.textContent = "Synchronizuji…";
  await chrome.runtime.sendMessage({ type: "sync-now" }).catch(() => {});
  await render();
  syncButton.disabled = false;
  syncButton.textContent = "Synchronizovat teď";
});

chrome.storage.onChanged.addListener(render);
render();
