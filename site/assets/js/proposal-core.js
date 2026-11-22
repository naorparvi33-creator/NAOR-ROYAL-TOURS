/* NAOR ROYAL TOURS · הצעה חיה · ליבה משותפת
   ההצעה כולה נמצאת בתוך הקישור (אחרי הסימן #), כך שהיא לא נשמרת בשום שרת.
   כל הצעה חתומה דיגיטלית: דף ההצעה מציג רק הצעות שנחתמו במפתח של נאור,
   ולכן אי אפשר לזייף הצעה בשם העסק או לשנות בה מחיר. */
(function(){
'use strict';
const C = window.NRT_CONFIG || {};
const enc = new TextEncoder(), dec = new TextDecoder();
const subtle = (window.crypto || {}).subtle;
const ALG = {name:'ECDSA', namedCurve:'P-256'}, SIG = {name:'ECDSA', hash:'SHA-256'};

function toB64u(bytes){
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function fromB64u(str){
  const s = atob(str.replace(/-/g, '+').replace(/_/g, '/'));
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}
async function pipe(bytes, stream){
  return new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(stream)).arrayBuffer());
}

/* ---------- אריזה: JSON -> דחיסה -> חתימה -> טקסט לקישור ---------- */
async function pack(data, privateKeyB64){
  const raw = enc.encode(JSON.stringify(data));
  let body = null;
  if ('CompressionStream' in window){
    try { const z = await pipe(raw, new CompressionStream('deflate-raw')); if (z.length < raw.length) body = [1, z]; } catch(e){}
  }
  if (!body) body = [0, raw];
  const payload = new Uint8Array(body[1].length + 1);
  payload[0] = body[0]; payload.set(body[1], 1);
  const key = await subtle.importKey('pkcs8', fromB64u(privateKeyB64), ALG, false, ['sign']);
  const sig = new Uint8Array(await subtle.sign(SIG, key, payload));
  return '1.' + toB64u(payload) + '.' + toB64u(sig);
}

/* ---------- פתיחה: בדיקת חתימה לפני שמציגים משהו ---------- */
async function unpack(token){
  const parts = String(token || '').split('.');
  if (parts.length !== 3 || parts[0] !== '1') throw new Error('format');
  const payload = fromB64u(parts[1]), sig = fromB64u(parts[2]);
  let ok = false;
  for (const pub of (C.proposalKeys || [])){
    try {
      const key = await subtle.importKey('raw', fromB64u(pub), ALG, false, ['verify']);
      if (await subtle.verify(SIG, key, sig, payload)){ ok = true; break; }
    } catch(e){}
  }
  if (!ok) throw new Error('signature');
  let raw = payload.subarray(1);
  if (payload[0] === 1){
    if (!('DecompressionStream' in window)) throw new Error('browser');
    raw = await pipe(raw, new DecompressionStream('deflate-raw'));
  }
  return JSON.parse(dec.decode(raw));
}

/* ---------- קוד הפעלה חדש: נוצר בתוך המכשיר ולא עובר דרך שום שרת ---------- */
async function newKey(){
  const pair = await subtle.generateKey(ALG, true, ['sign', 'verify']);
  const priv = toB64u(new Uint8Array(await subtle.exportKey('pkcs8', pair.privateKey)));
  const pub = toB64u(new Uint8Array(await subtle.exportKey('raw', pair.publicKey)));
  return {priv, pub};
}

async function keyWorks(privateKeyB64){
  try { await subtle.importKey('pkcs8', fromB64u(privateKeyB64), ALG, false, ['sign']); return true; } catch(e){ return false; }
}

/* ---------- עזרי תצוגה משותפים ---------- */
function israelToday(){
  const p = new Intl.DateTimeFormat('en-CA', {timeZone:'Asia/Jerusalem', year:'numeric', month:'2-digit', day:'2-digit'}).format(new Date());
  return p; // YYYY-MM-DD
}
const DAYS = ['ראשון','שני','שלישי','רביעי','חמישי','שישי','שבת'];
function fmtDate(ymd, withDay){
  if (!/^\d{4}-\d{2}-\d{2}/.test(ymd || '')) return '';
  const [y, m, d] = ymd.slice(0, 10).split('-').map(Number);
  const s = String(d).padStart(2, '0') + '/' + String(m).padStart(2, '0') + '/' + y;
  return withDay ? 'יום ' + DAYS[new Date(Date.UTC(y, m - 1, d)).getUTCDay()] + ', ' + s : s;
}
function nights(from, to){
  if (!from || !to) return 0;
  const n = Math.round((Date.parse(to + 'T00:00:00Z') - Date.parse(from + 'T00:00:00Z')) / 864e5);
  return n > 0 ? n : 0;
}
const money = n => new Intl.NumberFormat('he-IL').format(Math.round(Number(n) || 0)) + ' ₪';
const waLink = (text, phone) => 'https://wa.me/' + (phone || C.whatsapp || '972536233816') + '?text=' + encodeURIComponent(text);

const DEST = {ATH:'אתונה', RHO:'רודוס', FCO:'רומא', LCA:'לרנקה', PRG:'פראג', BUD:'בודפשט', DXB:'דובאי', LHR:'לונדון', BER:'ברלין', JFK:'ניו יורק'};

window.NRTP = {pack, unpack, keyWorks, newKey, israelToday, fmtDate, nights, money, waLink, DEST, ok: !!subtle};
})();
