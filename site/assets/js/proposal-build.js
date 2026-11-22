/* NAOR ROYAL TOURS · הצעה חיה · דף הבנייה (רק לנאור)
   הדף עובד רק במכשיר שהופעל עם קוד ההפעלה. הקוד נשמר בדפדפן של המכשיר בלבד. */
(function(){
'use strict';
const P = window.NRTP;
const $ = id => document.getElementById(id);
const store = {
  get(k){ try { return localStorage.getItem(k); } catch(e){ return null; } },
  set(k, v){ try { localStorage.setItem(k, v); return true; } catch(e){ return false; } },
  del(k){ try { localStorage.removeItem(k); } catch(e){} }
};
const K_KEY = 'nrtp-key', K_NEW = 'nrtp-new-key', K_DRAFT = 'nrtp-draft', K_HIST = 'nrtp-history';
const clean = (s, max) => String(s || '').replace(/[\u0000-\u0008\u000B-\u001F\u007F‪-‮⁦-⁩]/g, '').trim().slice(0, max || 300);
const num = s => { const n = parseInt(String(s || '').replace(/[^\d]/g, ''), 10); return n > 0 ? n : 0; };
const INCLUDED = ['טיסות הלוך ושוב', 'כבודה לפי הפירוט', 'לינה במלון', 'ארוחות לפי הפירוט', 'העברות משדה התעופה ואליו', 'ליווי אישי של נאור עד החזרה'];

/* ---------- הפעלה ---------- */
async function tryKey(k){
  k = String(k || '').trim();
  if (!k || !(await P.keyWorks(k))) return false;
  try { await P.unpack(await P.pack({t:1}, k)); } catch(e){ return false; } // must match the site's public key
  return true;
}
async function boot(){
  if (!P.ok){ gate('הדפדפן הזה לא תומך. פתחו את הדף בכרום או בספארי מעודכנים.'); return; }
  const m = location.hash.match(/^#k=([\w-]+)$/);
  if (m){
    history.replaceState(null, '', location.pathname); // the code never stays in the address bar
    if (await tryKey(m[1])) store.set(K_KEY, m[1]);
  }
  const k = store.get(K_KEY);
  if (k && await tryKey(k)) return startApp(k);
  // a code made on this device starts working as soon as its public key is on the site
  const n = pendingKey();
  if (n && await tryKey(n.priv)){ store.set(K_KEY, n.priv); store.del(K_NEW); return startApp(n.priv); }
  gate();
}
function pendingKey(){
  try { const n = JSON.parse(store.get(K_NEW) || 'null'); return n && n.priv && n.pub ? n : null; } catch(e){ return null; }
}
async function copyText(text, btn){
  let ok = false;
  try { await navigator.clipboard.writeText(text); ok = true; } catch(e){}
  const s = btn.querySelector('span'), old = s.textContent;
  s.textContent = ok ? 'הועתק' : 'סמנו והעתיקו ידנית';
  setTimeout(() => { s.textContent = old; }, 1800);
}
function showNew(n){
  $('b-new').hidden = true;
  $('b-new-out').hidden = false;
  $('b-pub').value = n.pub;
}
function gate(msg){
  $('b-gate').hidden = false;
  addEventListener('hashchange', () => location.reload()); // activation link opened in this same tab
  if (msg){ $('b-key-err').textContent = msg; $('b-key-err').hidden = false; }
  const n = pendingKey();
  if (n) showNew(n);
  $('b-new-go').addEventListener('click', async () => {
    if (pendingKey() && !confirm('כבר יצרתם קוד במכשיר הזה. ליצור במקומו קוד אחר?')) return;
    const fresh = await P.newKey();
    if (!store.set(K_NEW, JSON.stringify(fresh))){ $('b-key-err').textContent = 'הדפדפן לא מאפשר לשמור. צאו ממצב גלישה בסתר ונסו שוב.'; $('b-key-err').hidden = false; return; }
    showNew(fresh);
  });
  $('b-new-again').addEventListener('click', () => $('b-new-go').click());
  $('b-pub-copy').addEventListener('click', () => copyText($('b-pub').value, $('b-pub-copy')));
  $('b-dev-copy').addEventListener('click', () => {
    const k = pendingKey() || {};
    copyText(location.origin + location.pathname + '#k=' + k.priv, $('b-dev-copy'));
  });
  $('b-key-go').addEventListener('click', async () => {
    const k = $('b-key').value.trim().replace(/^.*#k=/, '');
    if (await tryKey(k)){ store.set(K_KEY, k); location.reload(); }
    else { $('b-key-err').textContent = 'הקוד לא תואם. בדקו שהעתקתם את כולו.'; $('b-key-err').hidden = false; }
  });
}

/* ---------- האפליקציה ---------- */
function startApp(key){
  $('b-app').hidden = false;
  const form = $('b-form'), fields = [...form.querySelectorAll('[data-f]')];
  let editingId = null;

  // תמונות היעדים שכבר קיימות באתר
  const sel = $('b-img');
  Object.keys(P.DEST).forEach(c => { const o = document.createElement('option'); o.value = c; o.textContent = P.DEST[c]; sel.append(o); });
  // תיבות "מה כלול"
  const incBox = $('b-inc');
  INCLUDED.forEach((t, i) => {
    const l = document.createElement('label'); l.className = 'b-check';
    const c = document.createElement('input'); c.type = 'checkbox'; c.id = 'inc-' + i; c.value = t;
    l.append(c, document.createTextNode(' ' + t)); incBox.append(l);
  });
  const checks = () => [...incBox.querySelectorAll('input')];

  /* טיוטה: נשמרת במכשיר תוך כדי כתיבה */
  const snapshot = () => { const o = {}; fields.forEach(f => { if (f.value) o[f.id] = f.value; }); o._inc = checks().filter(c => c.checked).map(c => c.value); return o; };
  const restore = o => {
    fields.forEach(f => { f.value = (o && o[f.id]) || ''; });
    checks().forEach(c => { c.checked = !!(o && (o._inc || []).includes(c.value)); });
    $('b-h2').open = !!(o && o['h2-nm']);
  };
  try { restore(JSON.parse(store.get(K_DRAFT) || 'null')); } catch(e){}
  form.addEventListener('input', () => { store.set(K_DRAFT, JSON.stringify(snapshot())); $('b-err').hidden = true; });
  $('b-clear').addEventListener('click', () => { restore(null); store.del(K_DRAFT); editingId = null; $('b-out').hidden = true; $('b-client').focus(); });

  const v = (id, max) => clean($(id).value, max);
  function newId(){
    const r = new Uint32Array(1); crypto.getRandomValues(r);
    return 'NRT-' + P.israelToday().slice(2).replace(/-/g, '') + '-' + String(r[0] % 10000).padStart(4, '0');
  }
  function collect(){
    const d = {v:1, id: editingId || newId(), cr: P.israelToday(), c: v('b-client', 40), d: v('b-dest', 60)};
    const put = (k, val) => { if (val) d[k] = val; };
    put('img', v('b-img', 3)); put('f', v('b-from', 10)); put('t', v('b-to', 10)); put('n', v('b-people', 40)); put('nt', v('b-note', 500));
    const fl = [];
    [['o', 'fo'], ['r', 'fr']].forEach(([k, p]) => {
      const f = {k, a: v(p + '-a', 40), r: v(p + '-r', 60), dp: v(p + '-dp', 16), ar: v(p + '-ar', 5), b: v(p + '-b', 60)};
      if (f.a || f.r || f.dp){ Object.keys(f).forEach(x => { if (!f[x]) delete f[x]; }); fl.push(f); }
    });
    if (fl.length) d.fl = fl;
    const ht = [];
    ['h1', 'h2'].forEach(p => {
      const h = {nm: v(p + '-nm', 60), ar: v(p + '-ar', 60), rm: v(p + '-rm', 60), bd: v(p + '-bd', 40), ng: v(p + '-ng', 20)};
      if (h.nm){ Object.keys(h).forEach(x => { if (!h[x]) delete h[x]; }); ht.push(h); }
    });
    if (ht.length) d.ht = ht;
    put('ks', v('b-kosher', 600));
    const inc = checks().filter(c => c.checked).map(c => c.value)
      .concat(v('b-inc-more', 500).split('\n').map(s => clean(s, 80)).filter(Boolean)).slice(0, 14);
    if (inc.length) d.inc = inc;
    put('exc', v('b-exc', 400));
    d.pr = num($('b-price').value);
    put('pp', num($('b-pp').value)); put('vu', v('b-valid', 10)); put('pay', v('b-pay', 300));
    d.can = v('b-cancel', 900);
    return d;
  }
  function problem(d){
    if (!d.c) return ['חסר שם הלקוח.', 'b-client'];
    if (!d.d) return ['חסר יעד או כותרת להצעה.', 'b-dest'];
    if (d.f && d.t && d.t < d.f) return ['תאריך החזרה לפני תאריך היציאה.', 'b-to'];
    if (!d.pr) return ['חסר מחיר סופי בשקלים.', 'b-price'];
    if (d.vu && d.vu < P.israelToday()) return ['תאריך התוקף כבר עבר.', 'b-valid'];
    if (!d.can) return ['חסרים תנאי הביטול. הצעת מחיר חייבת לכלול אותם.', 'b-cancel'];
    return null;
  }
  function phoneIntl(s){
    let p = String(s || '').replace(/[^\d]/g, '');
    if (!p) return '';
    if (p.startsWith('0')) p = '972' + p.slice(1);
    return p.length >= 10 ? p : '';
  }

  form.addEventListener('submit', async e => {
    e.preventDefault();
    const d = collect(), bad = problem(d);
    if (bad){ $('b-err').textContent = bad[0]; $('b-err').hidden = false; $(bad[1]).focus(); return; }
    let token;
    try { token = await P.pack(d, key); }
    catch(err){ $('b-err').textContent = 'לא הצלחתי ליצור את הקישור. נסו לרענן את הדף.'; $('b-err').hidden = false; return; }
    const link = new URL('./', location.href).href.split('#')[0] + '#' + token;
    editingId = d.id;
    showOut(d, link);
    saveHist({id: d.id, c: d.c, d: d.d, pr: d.pr, cr: d.cr, link, phone: phoneIntl($('b-phone').value), form: snapshot()});
  });

  function showOut(d, link, phone){
    $('b-out-id').textContent = d.id;
    $('b-link').value = link;
    $('b-open').href = link;
    const msg = 'היי ' + d.c + ', ההצעה שלך ל' + d.d + ' מוכנה. כל הפרטים כאן:\n' + link;
    $('b-send').href = P.waLink(msg, phone != null ? phone : phoneIntl($('b-phone').value));
    $('b-out').hidden = false;
    $('b-out').scrollIntoView({behavior: 'smooth', block: 'start'});
  }
  async function copy(text, btn){
    let ok = false;
    try { await navigator.clipboard.writeText(text); ok = true; }
    catch(e){ const t = $('b-link'); t.value = text; t.select(); try { ok = document.execCommand('copy'); } catch(_){} }
    const s = btn.querySelector('span'), old = s.textContent;
    s.textContent = ok ? 'הועתק' : 'סמנו והעתיקו ידנית';
    setTimeout(() => { s.textContent = old; }, 1800);
  }
  $('b-copy').addEventListener('click', () => copy($('b-link').value, $('b-copy')));

  /* ---------- היסטוריה במכשיר ---------- */
  const hist = () => { try { return JSON.parse(store.get(K_HIST) || '[]'); } catch(e){ return []; } };
  function saveHist(item){
    const list = hist().filter(x => x.id !== item.id); list.unshift(item);
    store.set(K_HIST, JSON.stringify(list.slice(0, 60))); paintHist();
  }
  function paintHist(){
    const list = hist(), ul = $('b-hist'); ul.textContent = '';
    $('b-hist-empty').hidden = !!list.length;
    list.forEach(x => {
      const li = document.createElement('li');
      const t = document.createElement('div'); t.className = 'b-hist-t';
      t.textContent = x.c + ' · ' + x.d + ' · ' + P.money(x.pr);
      const s = document.createElement('div'); s.className = 'b-hist-s'; s.textContent = x.id + ' · ' + P.fmtDate(x.cr);
      const acts = document.createElement('div'); acts.className = 'b-hist-a';
      const btn = (label, fn) => { const b = document.createElement('button'); b.type = 'button'; b.className = 'b-mini'; const sp = document.createElement('span'); sp.textContent = label; b.append(sp); b.addEventListener('click', () => fn(b)); acts.append(b); };
      btn('העתקת קישור', b => copy(x.link, b));
      btn('פתיחה', () => window.open(x.link, '_blank', 'noopener'));
      btn('עריכה', () => { restore(x.form); editingId = x.id; store.set(K_DRAFT, JSON.stringify(x.form || {})); $('b-out').hidden = true; scrollTo({top: 0, behavior: 'smooth'}); });
      btn('מחיקה', () => { if (confirm('למחוק את ההצעה מהרשימה? הקישור שכבר נשלח ימשיך לעבוד.')){ store.set(K_HIST, JSON.stringify(hist().filter(y => y.id !== x.id))); paintHist(); } });
      li.append(t, s, acts); ul.append(li);
    });
  }
  paintHist();
}

boot();
})();
