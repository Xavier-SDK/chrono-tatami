/* Chrono Tatami : fonctionnement hors ligne (tout est mis en cache à l'installation) */
const CACHE = 'chrono-tatami-v2';
const FILES = [
  './', 'index.html', 'app.css', 'fonts.css', 'app.js', 'parse-cours.js', 'seances.js', 'musique.js', 'manifest.webmanifest',
  'fonts/BigShouldersDisplay-800.woff2', 'fonts/BigShouldersDisplay-900.woff2',
  'fonts/Barlow-500.woff2', 'fonts/Barlow-600.woff2', 'fonts/Barlow-700.woff2',
  'icons/apple-touch-icon.png', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/icon-maskable-512.png', 'icons/favicon-64.png'
];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then(hit => hit || fetch(e.request).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
      return res;
    }).catch(() => caches.match('index.html')))
  );
});
