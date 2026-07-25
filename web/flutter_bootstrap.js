// Custom Flutter web bootstrap for Tayra.
//
// Keeps the #tayra-splash element (see web/index.html) visible until the
// engine paints its first frame, then fades it out. Logic lives in this
// external file so Funkwhale CSP `script-src 'self'` is not violated
// (no inline scripts in index.html).
//
// Flutter's web build substitutes the two placeholder tokens below with
// FlutterLoader setup and build metadata. Do not put those brace-brace
// placeholders in comments — substitution is global and would mangle them.

{{flutter_js}}
{{flutter_build_config}}

(function () {
  var splash = document.getElementById('tayra-splash');
  var statusEl = document.getElementById('tayra-splash-status');
  var removed = false;
  var SLOW_LOAD_MS = 20000;
  var FADE_MS = 220;

  function removeSplash() {
    if (removed) {
      return;
    }
    removed = true;
    if (!splash) {
      return;
    }
    splash.classList.add('tayra-splash-hidden');
    window.setTimeout(function () {
      if (splash && splash.parentNode) {
        splash.parentNode.removeChild(splash);
      }
      splash = null;
    }, FADE_MS);
  }

  // Non-blocking still-loading status if WASM/assets take a long time.
  window.setTimeout(function () {
    if (removed || !statusEl) {
      return;
    }
    statusEl.textContent = 'Still loading…';
    statusEl.classList.add('tayra-status-visible');
  }, SLOW_LOAD_MS);

  window.addEventListener('flutter-first-frame', removeSplash, { once: true });

  _flutter.loader.load();
})();
