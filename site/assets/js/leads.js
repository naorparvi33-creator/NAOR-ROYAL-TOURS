/* NAOR ROYAL TOURS · אוטומציות: טופס לידים, מקור הגעה, שעות מענה, פרטי עסק */
(function(){
'use strict';
const C = window.NRT_CONFIG || {};
const WA = C.whatsapp || '972536233816';
const waLink = t => `https://wa.me/${WA}?text=${encodeURIComponent(t)}`;
const $ = id => document.getElementById(id);
const ss = {get(k){try{return sessionStorage.getItem(k)}catch(e){return null}}, set(k,v){try{sessionStorage.setItem(k,v)}catch(e){}}};

/* ---------- ניקוי קלט: בלי תווי בקרה, באורך מוגבל ---------- */
const clean = (s, max = 300) => String(s || '').replace(/[\u0000-\u0008\u000B-\u001F\u007F‪-‮⁦-⁩]/g, '').replace(/\s+\n/g, '\n').trim().slice(0, max);

/* ---------- זמן ישראל ---------- */
function israelNow(){
  const parts = new Intl.DateTimeFormat('en-GB', {timeZone:'Asia/Jerusalem', weekday:'short', hour:'2-digit', minute:'2-digit', hour12:false, year:'numeric', month:'2-digit', day:'2-digit'}).formatToParts(new Date());
  const g = t => (parts.find(p => p.type === t) || {}).value;
  const days = {Sun:0, Mon:1, Tue:2, Wed:3, Thu:4, Fri:5, Sat:6};
  return {day: days[g('weekday')], min: (+g('hour') % 24) * 60 + (+g('minute')), ymd: `${g('year')}-${g('month')}-${g('day')}`};
}
const toMin = hm => { const [h, m] = hm.split(':').map(Number); return h * 60 + m; };

/* ---------- מקור הגעה (UTM / רשת חברתית) ---------- */
(function captureSource(){
  if (ss.get('nrt-src')) return;
  const q = new URLSearchParams(location.search);
  let src = [q.get('utm_source'), q.get('utm_medium'), q.get('utm_campaign')].filter(Boolean).map(v => clean(v, 40)).join(' / ');
  if (!src && document.referrer){
    try { const h = new URL(document.referrer).hostname.replace(/^www\./, ''); if (h && h !== location.hostname) src = h; } catch(e){}
  }
  if (src) ss.set('nrt-src', src);
})();
const source = () => ss.get('nrt-src') || '';

/* ---------- סטטוס זמינות ---------- */
function status(){
  const n = israelNow(), sh = C.shabbat || {fridayFrom:'16:00', saturdayUntil:'20:00'};
  if ((n.day === 5 && n.min >= toMin(sh.fridayFrom)) || (n.day === 6 && n.min < toMin(sh.saturdayUntil)))
    return {cls:'shabbat', t:'שבת שלום', s:'נחזור אליכם במוצאי שבת'};
  const h = (C.hours || {})[n.day];
  if (h && n.min >= toMin(h[0]) && n.min < toMin(h[1])) return {cls:'on', t:'זמין עכשיו בוואטסאפ', s:'מענה אישי בדרך כלל תוך זמן קצר'};
  return {cls:'off', t:'מחוץ לשעות המענה', s:'השאירו הודעה ונחזור אליכם בשעות הפעילות'};
}
function paintStatus(){
  const st = status();
  document.querySelectorAll('[data-status]').forEach(el => {
    el.classList.remove('on', 'off', 'shabbat'); el.classList.add(st.cls);
    const t = el.querySelector('[data-status-t]'), s = el.querySelector('[data-status-s]');
    if (t) t.textContent = st.t; if (s) s.textContent = st.s;
  });
}
paintStatus(); setInterval(paintStatus, 60000);

/* ---------- שנה ופרטי עסק בתחתית ---------- */
document.querySelectorAll('[data-year]').forEach(el => el.textContent = new Date().getFullYear());
document.querySelectorAll('[data-phone]').forEach(el => el.textContent = C.phoneDisplay || '053-623-3816');
(function biz(){
  const b = C.business || {}, el = $('biz'); if (!el) return;
  const bits = [];
  if (b.legalName) bits.push(b.legalName);
  if (b.taxId) bits.push('ע.מ./ח.פ. ' + b.taxId);
  if (b.email) bits.push(b.email);
  if (bits.length){ el.textContent = bits.join(' · '); el.hidden = false; }
})();

/* ---------- שמירה במכשיר: האתר נפתח מהר גם בלי קליטה (רק באתר מאובטח HTTPS) ---------- */
if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')){
  addEventListener('load', () => { navigator.serviceWorker.register('sw.js').catch(() => {}); });
}

/* ---------- טופס התכנון ---------- */
const form = $('plan-form'); if (!form) return;
const CH = ['זוגית','משפחה','שופינג','בטן־גב','טיולים','כשרה','שבת','יוקרה','חיי לילה'];
const chipsEl = $('chips');
chipsEl.innerHTML = CH.map((c, i) => `<button type="button" class="chip" id="chip-${i}" aria-pressed="false">${c}</button>`).join('');
chipsEl.addEventListener('click', e => { const b = e.target.closest('.chip'); if (!b) return; b.setAttribute('aria-pressed', b.getAttribute('aria-pressed') !== 'true'); });

const fFrom = $('f-from'), fTo = $('f-to');
const today = israelNow().ymd;
fFrom.min = today; fTo.min = today;
fFrom.addEventListener('change', () => { fTo.min = fFrom.value || today; if (fTo.value && fTo.value < fFrom.value) fTo.value = ''; });

const fmt = d => d ? d.split('-').reverse().join('/') : '';
const v = id => clean($(id).value, id === 'f-notes' ? 600 : 120);
const picked = () => [...chipsEl.querySelectorAll('[aria-pressed="true"]')].map(b => b.textContent);
function leadId(){
  const n = israelNow(), r = new Uint32Array(1);
  (window.crypto || {}).getRandomValues ? crypto.getRandomValues(r) : (r[0] = Math.random() * 1e9);
  return 'NRT-' + n.ymd.slice(2).replace(/-/g, '') + '-' + String(r[0] % 10000).padStart(4, '0');
}
function buildMsg(id){
  const L = ['היי נאור, אשמח לתכנן חופשה:'];
  if (v('f-name')) L.push('שם: ' + v('f-name'));
  if (v('f-dest')) L.push('יעד: ' + v('f-dest'));
  if (v('f-people')) L.push('נוסעים: ' + v('f-people'));
  if (v('f-from') || v('f-to')) L.push('תאריכים: ' + [fmt(v('f-from')), fmt(v('f-to'))].filter(Boolean).join(' עד '));
  if (v('f-budget')) L.push('תקציב: ' + v('f-budget'));
  if (picked().length) L.push('חשוב לנו: ' + picked().join(', '));
  if (v('f-notes')) L.push('עוד: ' + v('f-notes'));
  L.push('', 'מספר פנייה: ' + id);
  return L.join('\n');
}

const err = $('form-err'), ok = $('form-ok'), send = $('send');
function showErr(msg, field){
  err.textContent = msg; err.hidden = false; ok.hidden = true;
  if (field){ field.setAttribute('aria-invalid', 'true'); field.focus(); }
}
form.addEventListener('input', e => { e.target.removeAttribute('aria-invalid'); err.hidden = true; });

// בלי גיבוי פניות: לא צריך תיבת הסכמה ולא את המשפט על הגיבוי במדיניות
if (!C.leadBackup) document.querySelectorAll('[data-backup-only]').forEach(el => el.hidden = true);

// Enter בטופס = לחיצה על כפתור השליחה (קישור אמיתי, עובד בכל דפדפן ובכל אחסון)
form.addEventListener('submit', e => { e.preventDefault(); send.click(); });

let busy = false;
send.addEventListener('click', e => {
  const stop = (msg, field) => { e.preventDefault(); showErr(msg, field); };
  if (busy){ e.preventDefault(); return; }
  if ($('f-hp').value){ e.preventDefault(); return; } // מלכודת לבוטים
  if (!v('f-name')) return stop('נשמח לדעת איך קוראים לכם.', $('f-name'));
  const tel = v('f-tel');
  if (tel && !/^[+\d][\d\s\-()]{7,18}$/.test(tel)) return stop('מספר הטלפון לא נראה תקין.', $('f-tel'));
  if (fFrom.value && fTo.value && fTo.value < fFrom.value) return stop('תאריך החזרה לפני תאריך היציאה.', fTo);
  if (C.leadBackup && !$('f-consent').checked) return stop('כדי לשלוח צריך לאשר את מדיניות הפרטיות.', $('f-consent'));

  busy = true; send.setAttribute('aria-disabled', 'true');
  const id = leadId();
  // הקישור מתעדכן לפני שהדפדפן פותח אותו, כך שוואטסאפ נפתח עם ההודעה המלאה
  send.href = waLink(buildMsg(id));

  // גיבוי הפנייה (Netlify Forms) ברקע
  if (C.leadBackup && location.protocol.startsWith('http')){
    const data = new URLSearchParams({
      'form-name': 'lead', 'lead-id': id, name: v('f-name'), phone: tel, destination: v('f-dest'),
      travelers: v('f-people'), from: v('f-from'), to: v('f-to'), budget: v('f-budget'),
      interests: picked().join(', '), notes: v('f-notes'), source: source(),
      marketing: $('f-mkt').checked ? 'כן' : 'לא', 'bot-field': ''
    });
    try { fetch('/', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:data.toString(), keepalive:true}).catch(() => {}); } catch(_){}
  }

  $('ok-id').textContent = id; ok.hidden = false; err.hidden = true;
  setTimeout(() => { busy = false; send.removeAttribute('aria-disabled'); }, 4000);
});
})();
