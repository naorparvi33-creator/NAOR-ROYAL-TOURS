/* NAOR ROYAL TOURS · תיק נסיעה · דף הבנייה (רק לנאור)
   משתמש באותו קוד הפעלה של דף הצעות המחיר, שנשמר בדפדפן של המכשיר. */
(function(){
'use strict';
const P = window.NRTP;
const $ = id => document.getElementById(id);
const store = {
  get(k){ try { return localStorage.getItem(k); } catch(e){ return null; } },
  set(k, v){ try { localStorage.setItem(k, v); return true; } catch(e){ return false; } },
  del(k){ try { localStorage.removeItem(k); } catch(e){} }
};
const K_KEY = 'nrtp-key', K_DRAFT = 'nrtt-draft', K_HIST = 'nrtt-history';
const clean = (s, max) => String(s || '').replace(/[\u0000-\u0008\u000B-\u001F\u007F‪-‮⁦-⁩]/g, '').trim().slice(0, max || 300);
const CHECKS = ['דרכון בתוקף לפחות 6 חודשים מיום החזרה', 'ביטוח נסיעות', 'צ\'ק־אין אונליין (נפתח 24 עד 48 שעות לפני)', 'צילום של הדרכון בטלפון', 'כרטיס אשראי שעובד בחו"ל', 'מתאם לשקע חשמל', 'תרופות קבועות בתיק היד'];

async function boot(){
  const k = store.get(K_KEY);
  let ok = false;
  if (P.ok && k){
    try { ok = await P.keyWorks(k) && !!(await P.unpack(await P.pack({t:1}, k))); } catch(e){ ok = false; }
  }
  if (ok) startApp(k); else $('b-gate').hidden = false;
}

function startApp(key){
  $('b-app').hidden = false;
  const form = $('b-form');
  const fields = [...form.querySelectorAll('[data-f]')], flags = [...form.querySelectorAll('[data-c]')];
  let editingId = null;

  const sel = $('b-img');
  Object.keys(P.DEST).forEach(c => { const o = document.createElement('option'); o.value = c; o.textContent = P.DEST[c]; sel.append(o); });
  const ckBox = $('b-ck');
  CHECKS.forEach((t, i) => {
    const l = document.createElement('label'); l.className = 'b-check';
    const c = document.createElement('input'); c.type = 'checkbox'; c.id = 'ck-' + i; c.value = t; c.checked = true;
    l.append(c, document.createTextNode(' ' + t)); ckBox.append(l);
  });
  const checks = () => [...ckBox.querySelectorAll('input')];

  /* טיוטה */
  const snapshot = () => {
    const o = {}; fields.forEach(f => { if (f.value) o[f.id] = f.value; });
    flags.forEach(f => { o[f.id] = f.checked; });
    o._ck = checks().filter(c => c.checked).map(c => c.value); return o;
  };
  const restore = o => {
    fields.forEach(f => { f.value = (o && o[f.id]) || ''; });
    flags.forEach(f => { f.checked = o && f.id in o ? !!o[f.id] : true; });
    checks().forEach(c => { c.checked = o && o._ck ? o._ck.includes(c.value) : true; });
    $('b-h2').open = !!(o && o['h2-nm']);
  };
  try { restore(JSON.parse(store.get(K_DRAFT) || 'null')); } catch(e){}
  form.addEventListener('input', () => { store.set(K_DRAFT, JSON.stringify(snapshot())); $('b-err').hidden = true; });
  form.addEventListener('change', () => store.set(K_DRAFT, JSON.stringify(snapshot())));
  $('b-clear').addEventListener('click', () => { restore(null); store.del(K_DRAFT); editingId = null; $('b-out').hidden = true; $('b-client').focus(); });

  const v = (id, max) => clean($(id).value, max);
  function newId(){
    const r = new Uint32Array(1); crypto.getRandomValues(r);
    return 'TRP-' + P.israelToday().slice(2).replace(/-/g, '') + '-' + String(r[0] % 10000).padStart(4, '0');
  }
  function collect(){
    const d = {tp: 't', v: 1, id: editingId || newId(), cr: P.israelToday(), c: v('b-client', 40), d: v('b-dest', 60)};
    const put = (k, val) => { if (val) d[k] = val; };
    put('img', v('b-img', 3)); put('f', v('b-from', 10)); put('t', v('b-to', 10)); put('n', v('b-people', 40));
    put('bk', v('b-bk', 30)); put('nt', v('b-note', 500));
    const fl = [];
    [['o', 'fo'], ['r', 'fr']].forEach(([k, p]) => {
      const f = {k, a: v(p + '-a', 40), r: v(p + '-r', 60), dp: v(p + '-dp', 16), ar: v(p + '-ar', 5), tm: v(p + '-tm', 10), b: v(p + '-b', 60)};
      if (f.a || f.r || f.dp){ Object.keys(f).forEach(x => { if (!f[x]) delete f[x]; }); fl.push(f); }
    });
    if (fl.length) d.fl = fl;
    const ht = [];
    ['h1', 'h2'].forEach(p => {
      const h = {nm: v(p + '-nm', 60), ad: v(p + '-ad', 100), ci: v(p + '-ci', 20), co: v(p + '-co', 20), bd: v(p + '-bd', 40), ph: v(p + '-ph', 24)};
      if (h.nm){ Object.keys(h).forEach(x => { if (!h[x]) delete h[x]; }); ht.push(h); }
    });
    if (ht.length) d.ht = ht;
    put('tr', v('b-tr', 500)); put('ks', v('b-kosher', 600)); put('ad', v('b-ad', 700));
    if ($('b-sh').checked) d.sh = 1;
    const ck = checks().filter(c => c.checked).map(c => c.value)
      .concat(v('b-ck-more', 400).split('\n').map(s => clean(s, 80)).filter(Boolean)).slice(0, 14);
    if (ck.length) d.ck = ck;
    return d;
  }
  function problem(d){
    if (!d.c) return ['חסר שם הלקוח.', 'b-client'];
    if (!d.d) return ['חסר יעד.', 'b-dest'];
    if (!d.f) return ['חסר תאריך יציאה. ממנו נספרים הימים עד הטיסה.', 'b-from'];
    if (d.t && d.t < d.f) return ['תאריך החזרה לפני תאריך היציאה.', 'b-to'];
    return null;
  }
  const sendTo = (msg, phone) => phone ? P.waLink(msg, phone) : 'https://wa.me/?text=' + encodeURIComponent(msg);
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
    const link = new URL('trip.html', location.href).href.split('#')[0] + '#' + token;
    editingId = d.id;
    showOut(d, link);
    saveHist({id: d.id, c: d.c, d: d.d, f: d.f, cr: d.cr, link, phone: phoneIntl($('b-phone').value), form: snapshot()});
  });

  function showOut(d, link, phone){
    $('b-out-id').textContent = d.id;
    $('b-link').value = link;
    $('b-open').href = link;
    const msg = 'היי ' + d.c + ', תיק הנסיעה שלך ל' + d.d + ' מוכן. יש בו את כל הפרטים של הטיסות והמלון, ואני שם בלחיצה אחת אם צריך משהו:\n' + link;
    $('b-send').href = sendTo(msg, phone != null ? phone : phoneIntl($('b-phone').value));
    $('b-out').hidden = false;
    $('b-out').scrollIntoView({behavior: 'smooth', block: 'start'});
  }
  async function copy(text, btn){
    let ok = false;
    try { await navigator.clipboard.writeText(text); ok = true; }
    catch(e){ const t = $('b-link'); t.value = text; t.select(); try { ok = document.execCommand('copy'); } catch(_){} }
    const s = btn.querySelector('span') || btn, old = s.textContent;
    s.textContent = ok ? 'הועתק' : 'סמנו והעתיקו ידנית';
    setTimeout(() => { s.textContent = old; }, 1800);
  }
  $('b-copy').addEventListener('click', () => copy($('b-link').value, $('b-copy')));

  /* היסטוריה במכשיר */
  const hist = () => { try { return JSON.parse(store.get(K_HIST) || '[]'); } catch(e){ return []; } };
  function saveHist(item){
    const list = hist().filter(x => x.id !== item.id); list.unshift(item);
    store.set(K_HIST, JSON.stringify(list.slice(0, 80))); paintHist();
  }
  function paintHist(){
    const list = hist(), ul = $('b-hist'); ul.textContent = '';
    $('b-hist-empty').hidden = !!list.length;
    list.forEach(x => {
      const li = document.createElement('li');
      const t = document.createElement('div'); t.className = 'b-hist-t';
      t.textContent = x.c + ' · ' + x.d + (x.f ? ' · ' + P.fmtDate(x.f) : '');
      const s = document.createElement('div'); s.className = 'b-hist-s'; s.textContent = x.id + ' · עודכן ' + P.fmtDate(x.cr);
      const acts = document.createElement('div'); acts.className = 'b-hist-a';
      const btn = (label, fn) => { const b = document.createElement('button'); b.type = 'button'; b.className = 'b-mini'; const sp = document.createElement('span'); sp.textContent = label; b.append(sp); b.addEventListener('click', () => fn(b)); acts.append(b); };
      btn('שליחה שוב', () => window.open(sendTo('היי ' + x.c + ', תיק הנסיעה שלך ל' + x.d + ':\n' + x.link, x.phone), '_blank', 'noopener'));
      btn('העתקת קישור', b => copy(x.link, b));
      btn('פתיחה', () => window.open(x.link, '_blank', 'noopener'));
      btn('עריכה', () => { restore(x.form); editingId = x.id; store.set(K_DRAFT, JSON.stringify(x.form || {})); $('b-out').hidden = true; scrollTo({top: 0, behavior: 'smooth'}); });
      btn('מחיקה', () => { if (confirm('למחוק את התיק מהרשימה? הקישור שכבר נשלח ימשיך לעבוד.')){ store.set(K_HIST, JSON.stringify(hist().filter(y => y.id !== x.id))); paintHist(); } });
      li.append(t, s, acts); ul.append(li);
    });
  }
  paintHist();
}

boot();
})();
