if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js?v=20260418c').catch((error) => {
      console.error('PWA registrace service workeru selhala:', error);
    });
  });
}
