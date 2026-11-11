(function publishOlvendToken() {
  let lastToken = "";
  function findToken() {
    for (let index = 0; index < localStorage.length; index += 1) {
      const key = localStorage.key(index) || "";
      if (!/^sb-.*-auth-token$/.test(key)) continue;
      try {
        const value = JSON.parse(localStorage.getItem(key) || "null");
        const token = value?.access_token || value?.currentSession?.access_token || value?.session?.access_token;
        if (token) return token;
      } catch (_) {}
    }
    return "";
  }
  const publish = () => {
    const token = findToken();
    if (!token || token === lastToken) return;
    lastToken = token;
    chrome.runtime.sendMessage({ type: "olvend-token", token }).catch(() => {});
  };
  publish();
  window.setInterval(publish, 30_000);
  window.addEventListener("storage", publish);
})();
