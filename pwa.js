if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    (async () => {
      try {
        const PWA_BOOTSTRAP_VERSION = '20260811-mail-reading-state-v1';
        const PWA_BOOTSTRAP_KEY = 'olvendPwaBootstrapVersion';
        if (localStorage.getItem(PWA_BOOTSTRAP_KEY) !== PWA_BOOTSTRAP_VERSION) {
          localStorage.setItem(PWA_BOOTSTRAP_KEY, PWA_BOOTSTRAP_VERSION);
        }

        await navigator.serviceWorker.register('./sw.js?v=20260811-mail-reading-state-v1');
      } catch (error) {
        console.error('PWA registrace service workeru selhala:', error);
      }
    })();
  });
}
