/* NAOR ROYAL TOURS · הצעה חיה · הדף שהלקוח רואה */
(function(){
'use strict';
const P = window.NRTP, C = window.NRT_CONFIG || {};
const $ = id => document.getElementById(id);
const el = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; };
const show = id => { $(id).hidden = false; };

function fail(kind){
  $('p-loading').hidden = true;
  const msg = {
    empty: ['אין כאן הצעה', 'הקישור שקיבלתם חסר או נחתך בדרך. בקשו מנאור לשלוח אותו שוב.'],
    browser: ['הדפדפן לא תומך', 'כדי לראות את ההצעה צריך דפדפן מעודכן. נסו לפתוח את הקישור בכרום או בספארי.'],
    bad: ['ההצעה לא תקינה', 'לא הצלחנו לאמת שההצעה הזאת נשלחה מ־NAOR ROYAL TOURS. אל תסתמכו עליה, ופנו לנאור ישירות.']
  }[kind] || [];
  $('p-fail-t').textContent = msg[0]; $('p-fail-s').textContent = msg[1];
  $('p-fail-wa').href = P.waLink('היי נאור, קיבלתי קישור להצעה והוא לא נפתח. אפשר לשלוח שוב?');
  show('p-fail');
}

function row(parent, label, value){
  if (!value) return;
  const r = el('div', 'p-row'); r.append(el('span', 'p-k', label), el('span', 'p-v', value)); parent.append(r);
}

function render(d){
  const today = P.israelToday();
  const expired = !!(d.vu && today > d.vu);
  const n = P.nights(d.f, d.t);
  const dates = [P.fmtDate(d.f), P.fmtDate(d.t)].filter(Boolean).join(' עד ');
  document.title = 'ההצעה שלך ל' + d.d + ' · NAOR ROYAL TOURS';

  /* פתיח */
  if (d.img && P.DEST[d.img]){
    const img = $('p-img'); img.src = '../img/dest/' + d.img.toLowerCase() + '-tall.webp'; img.alt = ''; img.hidden = false;
    $('p-hero').classList.add('has-img');
  }
  $('p-hello').textContent = 'היי ' + d.c + ',';
  $('p-dest').textContent = d.d;
  $('p-id').textContent = d.id;
  const meta = $('p-meta');
  [dates, n ? n + ' לילות' : '', d.n].filter(Boolean).forEach(t => meta.append(el('span', 'p-pill', t)));
  if (d.nt){ $('p-note').textContent = d.nt; show('p-note-box'); }

  /* טיסות */
  if ((d.fl || []).length){
    const box = $('p-flights');
    d.fl.forEach(f => {
      const card = el('div', 'p-card');
      card.append(el('div', 'p-tag', f.k === 'r' ? 'חזור' : 'הלוך'));
      if (f.r) card.append(el('div', 'p-route', f.r));
      row(card, 'חברה וטיסה', f.a);
      row(card, 'המראה', [P.fmtDate(f.dp, true), (f.dp || '').slice(11, 16)].filter(Boolean).join(' · '));
      row(card, 'נחיתה', f.ar);
      row(card, 'כבודה', f.b);
      box.append(card);
    });
    show('p-sec-flights');
  }

  /* מלונות */
  if ((d.ht || []).length){
    const box = $('p-hotels');
    d.ht.forEach(h => {
      const card = el('div', 'p-card');
      card.append(el('div', 'p-hname', h.nm));
      row(card, 'אזור', h.ar);
      row(card, 'חדר', h.rm);
      row(card, 'ארוחות', h.bd);
      row(card, 'לילות', h.ng);
      box.append(card);
    });
    show('p-sec-hotels');
  }

  /* כשרות */
  if (d.ks){ $('p-kosher').textContent = d.ks; show('p-sec-kosher'); }

  /* מה כלול */
  if ((d.inc || []).length){
    const ul = $('p-inc'); d.inc.forEach(t => ul.append(el('li', '', t))); show('p-sec-inc');
  }
  if (d.exc){ $('p-exc').textContent = d.exc; show('p-exc-box'); }

  /* מחיר */
  $('p-price').textContent = P.money(d.pr);
  if (d.pp) { $('p-pp').textContent = P.money(d.pp) + ' לנוסע'; $('p-pp').hidden = false; }
  if (d.pay){ $('p-pay').textContent = d.pay; show('p-pay-box'); }
  if (d.vu){
    $('p-valid').textContent = expired ? 'תוקף ההצעה פג ב־' + P.fmtDate(d.vu) + '. המחיר עשוי להשתנות.' : 'ההצעה בתוקף עד ' + P.fmtDate(d.vu, true) + '.';
    $('p-valid').classList.toggle('late', expired); $('p-valid').hidden = false;
  }

  /* תנאי ביטול */
  $('p-cancel').textContent = d.can;
  if (d.cr) $('p-created').textContent = 'ההצעה הוכנה ב־' + P.fmtDate(d.cr) + '.';

  /* כפתורים */
  const sum = d.d + (dates ? ', ' + dates : '') + ', ' + P.money(d.pr);
  const yes = expired
    ? 'היי נאור, ההצעה ' + d.id + ' (' + sum + ') כבר לא בתוקף. אפשר לבדוק מחיר עדכני?'
    : 'היי נאור, אני מאשר/ת את ההצעה ' + d.id + ': ' + sum + '. בוא נסגור.';
  document.querySelectorAll('[data-yes]').forEach(a => {
    a.href = P.waLink(yes);
    a.querySelector('span').textContent = expired ? 'לבדוק מחיר עדכני' : 'מאשר/ת, בוא נסגור';
  });
  document.querySelectorAll('[data-ask]').forEach(a => { a.href = P.waLink('היי נאור, יש לי שאלה על ההצעה ' + d.id + ' (' + d.d + '):'); });
  document.querySelectorAll('[data-phone]').forEach(n => { n.textContent = C.phoneDisplay || ''; });

  $('p-loading').hidden = true; show('p-body'); show('p-bar');
}

async function start(){
  const token = location.hash.slice(1);
  if (!token) return fail('empty');
  if (!P.ok) return fail('browser');
  let d;
  try { d = await P.unpack(token); }
  catch(e){ return fail(e && e.message === 'browser' ? 'browser' : 'bad'); }
  if (d.tp === 't'){ location.replace('trip.html#' + token); return; }
  render(d);
}
start();
addEventListener('hashchange', () => location.reload());
})();
