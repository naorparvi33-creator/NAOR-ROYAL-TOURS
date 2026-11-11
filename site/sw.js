/* NAOR ROYAL TOURS · שמירה במכשיר (Service Worker)
   אחרי הכניסה הראשונה, קבצי האתר נשמרים בדפדפן. בכניסה הבאה האתר נפתח מיד,
   וגם בלי קליטה. הדף עצמו תמיד נבדק קודם מול השרת, כך שעדכונים מגיעים מיד.
   בכל העלאה של גרסה חדשה מעדכנים את VERSION (סקריפט הבנייה עושה את זה לבד). */
const VERSION = 'nrt-2026-11-11-tap1';
const CORE = [
  './', 'index.html', '404.html', 'favicon.svg', 'site.webmanifest',
  'assets/css/fonts.css', 'assets/css/site.css', 'assets/css/additions.css',
  'assets/js/boot.js', 'assets/js/loader.js', 'assets/js/config.js', 'assets/js/art.js',
  'assets/js/main.js', 'assets/js/pack.js', 'assets/js/leads.js',
  'assets/fonts/heebo-300-hebrew.woff2', 'assets/fonts/frankruhllibre-500-hebrew.woff2',
  'img/naor.webp'
];

self.addEventListener('install', e => {
  // cache:'reload' = take the files fresh from the server, never an older copy
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(CORE.map(u => new Request(u, {cache:'reload'})))).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;

  // pages: network first (fresh content), cached copy when offline
  if (req.mode === 'navigate'){
    e.respondWith(
      fetch(req).then(res => { const copy = res.clone(); caches.open(VERSION).then(c => c.put('index.html', copy)); return res; })
        .catch(() => caches.match('index.html').then(r => r || caches.match('404.html')))
    );
    return;
  }

  // files (code, fonts, images): cache first, then network, and keep a copy
  e.respondWith(
    caches.match(req).then(hit => hit || fetch(req).then(res => {
      if (res.ok && res.type === 'basic'){ const copy = res.clone(); caches.open(VERSION).then(c => c.put(req, copy)); }
      return res;
    }))
  );
});
