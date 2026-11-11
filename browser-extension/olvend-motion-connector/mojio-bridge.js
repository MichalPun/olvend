(function publishMojioToken() {
  let lastToken = "";
  const publish = () => {
    const token = localStorage.getItem("jwt_token") || "";
    if (!token || token === lastToken) return;
    lastToken = token;
    chrome.runtime.sendMessage({ type: "mojio-token", token }).catch(() => {});
  };
  publish();
  window.setInterval(publish, 30_000);
  window.addEventListener("storage", publish);
})();
