if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    (async () => {
      try {
        const PWA_BOOTSTRAP_VERSION = '20260731-live-api-v3';
        const PWA_BOOTSTRAP_KEY = 'olvendPwaBootstrapVersion';
        if (localStorage.getItem(PWA_BOOTSTRAP_KEY) !== PWA_BOOTSTRAP_VERSION) {
          localStorage.setItem(PWA_BOOTSTRAP_KEY, PWA_BOOTSTRAP_VERSION);
        }

        await navigator.serviceWorker.register('./sw.js?v=20260731-live-api-v3');
      } catch (error) {
        console.error('PWA registrace service workeru selhala:', error);
      }
    })();
  });
}
