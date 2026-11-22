/* NAOR ROYAL TOURS · תיק נסיעה · הדף שהלקוח רואה
   כמו בהצעת מחיר: כל התיק בתוך הקישור, וחתום, כך שאי אפשר לזייף תיק בשם העסק
   (למשל עם מספר חירום אחר). */
(function(){
'use strict';
const P = window.NRTP, C = window.NRT_CONFIG || {};
const $ = id => document.getElementById(id);
const el = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; };
const show = id => { $(id).hidden = false; };
const store = {
  get(k){ try { return localStorage.getItem(k); } catch(e){ return null; } },
  set(k, v){ try { localStorage.setItem(k, v); } catch(e){} }
};

/* ערים שיש להן תמונה באתר: מיקום לזמני שבת, אזור זמן ומספר חירום מקומי */
const CITY = {
  ATH:{lat:37.98, lon:23.73, tz:'Europe/Athens', sos:'112'},
  RHO:{lat:36.43, lon:28.22, tz:'Europe/Athens', sos:'112'},
  FCO:{lat:41.90, lon:12.50, tz:'Europe/Rome', sos:'112'},
  LCA:{lat:34.92, lon:33.63, tz:'Asia/Nicosia', sos:'112'},
  PRG:{lat:50.08, lon:14.44, tz:'Europe/Prague', sos:'112'},
  BUD:{lat:47.50, lon:19.04, tz:'Europe/Budapest', sos:'112'},
  DXB:{lat:25.20, lon:55.27, tz:'Asia/Dubai', sos:'999'},
  LHR:{lat:51.51, lon:-0.13, tz:'Europe/London', sos:'999 או 112'},
  BER:{lat:52.52, lon:13.40, tz:'Europe/Berlin', sos:'112'},
  JFK:{lat:40.71, lon:-74.01, tz:'America/New_York', sos:'911'}
};

/* ---------- זמני שבת ---------- */
const RAD = Math.PI / 180;
// הרגע (UTC) שבו השמש יורדת ל־alt מעלות מתחת לאופק בערב
function sunDown(ymd, lat, lon, alt){
  const [y, m, d] = ymd.split('-').map(Number);
  const n = Math.round(Date.UTC(y, m - 1, d, 12) / 864e5 + 2440587.5 - 2451545.0 + 0.0008);
  const js = n - lon / 360;
  const M = (357.5291 + 0.98560028 * js) % 360;
  const Cc = 1.9148 * Math.sin(M * RAD) + 0.02 * Math.sin(2 * M * RAD) + 0.0003 * Math.sin(3 * M * RAD);
  const L = (M + Cc + 180 + 102.9372) % 360;
  const jt = 2451545.0 + js + 0.0053 * Math.sin(M * RAD) - 0.0069 * Math.sin(2 * L * RAD);
  const sd = Math.sin(L * RAD) * Math.sin(23.4397 * RAD), cd = Math.cos(Math.asin(sd));
  const cw = (Math.sin(alt * RAD) - Math.sin(lat * RAD) * sd) / (Math.cos(lat * RAD) * cd);
  if (cw < -1 || cw > 1) return NaN;
  return (jt + Math.acos(cw) / RAD / 360 - 2440587.5) * 864e5;
}
const addDays = (ymd, k) => new Date(Date.parse(ymd + 'T12:00:00Z') + k * 864e5).toISOString().slice(0, 10);
const dow = ymd => new Date(ymd + 'T12:00:00Z').getUTCDay();
function hhmm(ms, tz, roundUp){
  const t = Math.floor(ms / 6e4) * 6e4 + (roundUp ? 6e4 : 0); // הדלקה מעוגלת למטה, צאת שבת למעלה
  return new Intl.DateTimeFormat('he-IL', {timeZone: tz, hour: '2-digit', minute: '2-digit', hour12: false}).format(t);
}
function shabbatTimes(from, to, city){
  if (!from || !city) return [];
  const end = to || addDays(from, 14), out = [];
  for (let day = from; day <= end && out.length < 4; day = addDays(day, 1)){
    if (dow(day) !== 5) continue;
    const sat = addDays(day, 1);
    const candle = sunDown(day, city.lat, city.lon, -0.833) - 18 * 6e4;
    const havdala = sat <= end ? sunDown(sat, city.lat, city.lon, -8.5) + 3 * 6e4 : NaN;
    if (isNaN(candle)) continue;
    out.push({day, candle: hhmm(candle, city.tz), havdala: isNaN(havdala) ? '' : hhmm(havdala, city.tz, true)});
  }
  return out;
}

/* ---------- ספירה לאחור ---------- */
function countdown(d){
  const today = P.israelToday();
  if (!d.f) return {text: '', phase: 'before'};
  const left = P.nights(today, d.f);
  if (today < d.f) return {text: left === 1 ? 'מחר טסים!' : 'עוד ' + left + ' ימים לטיסה', phase: 'before'};
  if (today === d.f) return {text: 'היום טסים! נסיעה טובה', phase: 'during'};
  if (!d.t || today <= d.t){
    const n = P.nights(d.f, today) + 1, all = d.t ? P.nights(d.f, d.t) + 1 : 0;
    return {text: all ? 'יום ' + n + ' מתוך ' + all + ' · תהנו!' : 'תהנו!', phase: 'during'};
  }
  return {text: 'ברוכים השבים', phase: 'after'};
}

/* ---------- יומן: קובץ ics לטיסות ---------- */
function icsFile(d, city){
  const esc = s => String(s || '').replace(/[\\;,]/g, m => '\\' + m).replace(/\n/g, '\\n');
  const stamp = new Date().toISOString().replace(/[-:]/g, '').slice(0, 15) + 'Z';
  const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//NAOR ROYAL TOURS//Trip//HE', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH'];
  (d.fl || []).forEach((f, i) => {
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(f.dp || '')) return;
    const tz = f.k === 'r' ? (city && city.tz) : 'Asia/Jerusalem';
    const start = f.dp.replace(/[-:]/g, '').slice(0, 13) + '00';
    const endMs = Date.parse(f.dp + ':00Z') + 3 * 36e5;
    const end = new Date(endMs).toISOString().replace(/[-:]/g, '').slice(0, 15);
    const title = (f.k === 'r' ? 'טיסה חזרה' : 'טיסה ל' + d.d) + (f.a ? ' · ' + f.a : '');
    const desc = [f.r, f.tm ? 'טרמינל ' + f.tm : '', f.b ? 'כבודה: ' + f.b : '', d.bk ? 'מספר הזמנה: ' + d.bk : '', 'NAOR ROYAL TOURS'].filter(Boolean).join('\n');
    lines.push('BEGIN:VEVENT', 'UID:' + d.id + '-' + i + '@naor-royal-tours', 'DTSTAMP:' + stamp,
      (tz ? 'DTSTART;TZID=' + tz + ':' : 'DTSTART:') + start,
      (tz ? 'DTEND;TZID=' + tz + ':' : 'DTEND:') + end,
      'SUMMARY:' + esc(title), 'DESCRIPTION:' + esc(desc),
      'BEGIN:VALARM', 'TRIGGER:-PT24H', 'ACTION:DISPLAY', 'DESCRIPTION:' + esc('מחר טסים. לבדוק צ\'ק־אין אונליין'), 'END:VALARM',
      'BEGIN:VALARM', 'TRIGGER:-PT4H', 'ACTION:DISPLAY', 'DESCRIPTION:' + esc('הגיע הזמן לצאת לשדה'), 'END:VALARM',
      'END:VEVENT');
  });
  lines.push('END:VCALENDAR');
  return lines.length > 6 ? lines.join('\r\n') : '';
}

function fail(kind){
  $('p-loading').hidden = true;
  const msg = {
    empty: ['אין כאן תיק נסיעה', 'הקישור שקיבלתם חסר או נחתך בדרך. בקשו מנאור לשלוח אותו שוב.'],
    browser: ['הדפדפן לא תומך', 'כדי לראות את התיק צריך דפדפן מעודכן. נסו לפתוח את הקישור בכרום או בספארי.'],
    bad: ['תיק הנסיעה לא תקין', 'לא הצלחנו לאמת שהתיק הזה נשלח מ־NAOR ROYAL TOURS. אל תסתמכו עליו, ופנו לנאור ישירות.']
  }[kind] || [];
  $('p-fail-t').textContent = msg[0]; $('p-fail-s').textContent = msg[1];
  $('p-fail-wa').href = P.waLink('היי נאור, קיבלתי קישור לתיק הנסיעה והוא לא נפתח. אפשר לשלוח שוב?');
  show('p-fail');
}
function row(parent, label, value, ltr){
  if (!value) return;
  const r = el('div', 'p-row'), v = el('span', 'p-v', value);
  if (ltr) v.dir = 'ltr';
  r.append(el('span', 'p-k', label), v); parent.append(r);
}
function linkBtn(parent, label, href){
  const a = el('a', 'b-mini'); a.href = href; a.target = '_blank'; a.rel = 'noopener noreferrer'; a.textContent = label; parent.append(a);
}

function render(d){
  const city = CITY[d.img] || null;
  const cd = countdown(d);
  const dates = [P.fmtDate(d.f), P.fmtDate(d.t)].filter(Boolean).join(' עד ');
  const n = P.nights(d.f, d.t);
  const hotel0 = (d.ht || [])[0] || {};
  document.title = 'תיק הנסיעה שלך ל' + d.d + ' · NAOR ROYAL TOURS';

  /* פתיח */
  if (d.img && P.DEST[d.img]){
    const img = $('p-img'); img.src = '../img/dest/' + d.img.toLowerCase() + '-tall.webp'; img.alt = ''; img.hidden = false;
    $('p-hero').classList.add('has-img');
  }
  $('t-hello').textContent = 'היי ' + d.c + ',';
  $('t-dest').textContent = d.d;
  $('t-id').textContent = d.id;
  $('t-count').textContent = cd.text;
  [dates, n ? n + ' לילות' : '', d.n, d.bk ? 'הזמנה ' + d.bk : ''].filter(Boolean).forEach(t => $('t-meta').append(el('span', 'p-pill', t)));
  if (d.nt){ $('t-note').textContent = d.nt; show('t-note-box'); }

  /* אחרי החזרה */
  if (cd.phase === 'after'){
    $('t-tell').href = P.waLink('היי נאור, חזרנו מ' + d.d + '! רציתי לספר לך איך היה:');
    $('t-refer').href = 'https://wa.me/?text=' + encodeURIComponent('חזרנו עכשיו מ' + d.d + ' עם נאור מ־NAOR ROYAL TOURS. הוא סידר לנו הכול וליווה אותנו עד החזרה. ממליץ/ה בחום: https://wa.me/' + (C.whatsapp || '972536233816'));
    show('t-sec-back');
  }

  /* טיסות */
  if ((d.fl || []).length){
    const box = $('t-flights');
    d.fl.forEach(f => {
      const card = el('div', 'p-card');
      card.append(el('div', 'p-tag', f.k === 'r' ? 'חזור' : 'הלוך'));
      if (f.r) card.append(el('div', 'p-route', f.r));
      row(card, 'חברה וטיסה', f.a);
      row(card, 'המראה', [P.fmtDate(f.dp, true), (f.dp || '').slice(11, 16)].filter(Boolean).join(' · '));
      row(card, 'נחיתה', f.ar);
      row(card, 'טרמינל', f.tm);
      row(card, 'כבודה', f.b);
      box.append(card);
    });
    show('t-sec-flights');
    const ics = icsFile(d, city);
    if (ics){
      const b = $('t-cal'); b.hidden = false;
      b.addEventListener('click', () => {
        const url = URL.createObjectURL(new Blob([ics], {type: 'text/calendar;charset=utf-8'}));
        const a = el('a'); a.href = url; a.download = 'trip-' + d.id + '.ics'; document.body.append(a); a.click(); a.remove();
        setTimeout(() => URL.revokeObjectURL(url), 4000);
      });
    }
  }

  /* מלונות */
  if ((d.ht || []).length){
    const box = $('t-hotels');
    d.ht.forEach(h => {
      const card = el('div', 'p-card');
      card.append(el('div', 'p-hname', h.nm));
      row(card, 'כתובת', h.ad);
      row(card, 'כניסה לחדר', h.ci);
      row(card, 'יציאה מהחדר', h.co);
      row(card, 'ארוחות', h.bd);
      row(card, 'טלפון המלון', h.ph, true);
      const q = [h.nm, h.ad].filter(Boolean).join(', ');
      const acts = el('div', 'b-hist-a t-nav');
      linkBtn(acts, 'ניווט ב־Waze', 'https://waze.com/ul?q=' + encodeURIComponent(q) + '&navigate=yes');
      linkBtn(acts, 'גוגל מפות', 'https://www.google.com/maps/search/?api=1&query=' + encodeURIComponent(q));
      if (h.ph) linkBtn(acts, 'להתקשר למלון', 'tel:' + h.ph.replace(/[^\d+]/g, ''));
      card.append(acts);
      box.append(card);
    });
    show('t-sec-hotels');
  }

  if (d.tr){ $('t-tr').textContent = d.tr; show('t-sec-tr'); }

  /* כשרות ושבת */
  const sh = d.sh ? shabbatTimes(d.f, d.t, city) : [];
  if (d.ks){ $('t-kosher').textContent = d.ks; show('t-kosher'); }
  if (sh.length){
    $('t-city').textContent = P.DEST[d.img];
    const box = $('t-shabbat');
    sh.forEach(s => {
      const card = el('div', 'p-card');
      card.append(el('div', 'p-tag', 'שבת'));
      row(card, 'הדלקת נרות', P.fmtDate(s.day, true) + ' · ' + s.candle);
      if (s.havdala) row(card, 'צאת שבת', s.havdala);
      box.append(card);
    });
    show('t-shabbat-box');
  }
  if (d.ks || sh.length) show('t-sec-kosher');

  if (d.ad){ $('t-notes').textContent = d.ad; show('t-sec-notes'); }

  /* רשימה לפני טיסה: הסימונים נשמרים במכשיר של הלקוח */
  if ((d.ck || []).length && cd.phase === 'before'){
    const key = 'nrtt-chk-' + d.id;
    let done = []; try { done = JSON.parse(store.get(key) || '[]'); } catch(e){}
    const box = $('t-chk');
    d.ck.forEach((t, i) => {
      const l = el('label', 'b-check'), c = el('input');
      c.type = 'checkbox'; c.checked = done.includes(i);
      c.addEventListener('change', () => {
        done = done.filter(x => x !== i); if (c.checked) done.push(i);
        store.set(key, JSON.stringify(done));
      });
      l.append(c, document.createTextNode(' ' + t)); box.append(l);
    });
    show('t-sec-chk');
  }

  /* עזרה */
  const where = hotel0.nm ? 'במלון ' + hotel0.nm + ', ' + d.d : 'ב' + d.d;
  $('t-sos').href = P.waLink('נאור, זה ' + d.c + ' (' + d.id + '). אני ' + where + ' וצריך/ה עזרה:');
  $('t-bar-wa').href = P.waLink('היי נאור, זה ' + d.c + ' לגבי הטיול ל' + d.d + ' (' + d.id + '):');
  const tel = 'tel:+' + (C.whatsapp || '972536233816');
  document.querySelectorAll('a[href^="tel:+972"]').forEach(a => { a.href = tel; });
  if (city){ $('t-emerg').textContent = 'מקרה חירום רפואי או משטרה ב' + P.DEST[d.img] + ': חייגו ' + city.sos + ', ואז עדכנו אותי.'; show('t-emerg'); }
  document.querySelectorAll('[data-phone]').forEach(x => { x.textContent = C.phoneDisplay || ''; });
  if (d.cr) $('t-created').textContent = 'עודכן ב־' + P.fmtDate(d.cr) + '.';

  $('p-loading').hidden = true; show('p-body'); show('p-bar');
}

async function start(){
  const token = location.hash.slice(1);
  if (!token) return fail('empty');
  if (!P.ok) return fail('browser');
  let d;
  try { d = await P.unpack(token); }
  catch(e){ return fail(e && e.message === 'browser' ? 'browser' : 'bad'); }
  if (d.tp !== 't'){ location.replace('./#' + token); return; } // זו הצעת מחיר, לא תיק נסיעה
  render(d);
}
start();
addEventListener('hashchange', () => location.reload());
})();
