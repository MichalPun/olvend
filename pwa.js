if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    (async () => {
      try {
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

        await navigator.serviceWorker.register('./sw.js?v=20260418d');
      } catch (error) {
        console.error('PWA registrace service workeru selhala:', error);
      }
    })();
  });
}
