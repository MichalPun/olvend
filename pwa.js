if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    (async () => {
      try {
        const PWA_BOOTSTRAP_VERSION = '20260713-telemetry-reports-v1';
        const PWA_BOOTSTRAP_KEY = 'olvendPwaBootstrapVersion';
        const registrations = await navigator.serviceWorker.getRegistrations();
        await Promise.all(registrations.map((registration) => registration.unregister()));

        if ('caches' in window) {
          const keys = await caches.keys();
          await Promise.all(
            keys
              .filter((key) => key.startsWith('olvend-'))
              .map((key) => caches.delete(key))
          );
        }

        if (localStorage.getItem(PWA_BOOTSTRAP_KEY) !== PWA_BOOTSTRAP_VERSION) {
          localStorage.setItem(PWA_BOOTSTRAP_KEY, PWA_BOOTSTRAP_VERSION);
          window.location.reload();
          return;
        }

        await navigator.serviceWorker.register('./sw.js?v=20260713telemetry-reports-v1');
      } catch (error) {
        console.error('PWA registrace service workeru selhala:', error);
      }
    })();
  });
}
