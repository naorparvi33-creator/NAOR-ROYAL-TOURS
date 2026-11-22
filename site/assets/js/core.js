/* NAOR ROYAL TOURS · הבסיס של האתר.
   כל שאר הקבצים נשענים עליו דרך window.NRT: קישורי וואטסאפ, נתוני היעדים והצבעים,
   תמונות היעדים, חלונות קופצים, והדגל המשותף "בלי אנימציות" (NRT.reduce). */
window.NRT = (function(){
const site = document.getElementById('site');
site.classList.add('js');
const WA = (window.NRT_CONFIG && window.NRT_CONFIG.whatsapp) || '972536233816';
const waLink = t => `https://wa.me/${WA}?text=${encodeURIComponent(t)}`;
const hasG = typeof gsap !== 'undefined';
let reduce = matchMedia('(prefers-reduced-motion: reduce)').matches || !hasG;
document.querySelectorAll('[data-wa]').forEach(a => a.href = waLink(a.dataset.wa));
const store = {get(k){try{return localStorage.getItem(k)}catch(e){return null}}, set(k,v){try{localStorage.setItem(k,v)}catch(e){}}};

/* ---------------- Data ---------------- */
const CITY = {ATH:'אתונה',RHO:'רודוס',FCO:'רומא',LCA:'לרנקה',PRG:'פראג',BUD:'בודפשט',DXB:'דובאי',LHR:'לונדון',BER:'ברלין',JFK:'ניו יורק'};
const COLORS = {
  caramel:{name:'קרמל', body:'#b07a45', band:'#2a1d13', g:['#7a4a2a','#2b1a10','#0b0806']},
  cream:{name:'בז׳ שמנת', body:'#e2d0b0', band:'#7a5531', g:['#6e5434','#291e12','#0c0906']},
  black:{name:'שחור', body:'#15110e', band:'#c9a066', g:['#8a6430','#2c2012','#090705']},
  white:{name:'לבן', body:'#f7f4ef', band:'#b07a45', g:['#4d4037','#1d1814','#070605']}
};
const TYPES = {
  couple:{label:'חופשה זוגית.', line:'שקיעות, מלון בוטיק ונוף לים. טיסות, מלון וכשרות בהודעה אחת.', msg:'היי נאור, אשמח לתכנן חופשה זוגית', color:'caramel', scene:'ATH', dests:['ATH','RHO','FCO','LCA','PRG','BUD','DXB']},
  family:{label:'חופשה משפחתית.', line:'מלון נוח לכולם, טיולים וחוויות לכל הגילאים. אתם נהנים, אני מסדר.', msg:'היי נאור, אשמח לתכנן חופשה משפחתית', color:'cream', scene:'PRG', dests:['PRG','BUD','LCA','RHO','BER','ATH','LHR']},
  kosher:{label:'חופשה כשרה.', line:'אוכל כשר, שבת ובית חב״ד ליד המלון. מתוכנן מראש, בלי הפתעות.', msg:'היי נאור, אשמח לתכנן חופשה כשרה', color:'black', scene:'FCO', dests:['FCO','LHR','JFK','PRG','BUD','ATH','DXB']},
  flight:{label:'טיסה + מלון.', line:'שעות טיסה נוחות ומלון במיקום הנכון. מהיר, פשוט ומסודר.', msg:'היי נאור, אני מחפש טיסה ומלון', color:'white', scene:'DXB', dests:['DXB','BER','LHR','LCA','RHO','FCO','JFK']}
};
const DEST = [
  {code:'ATH', name:'יוון', time:'כ־2 ש׳ טיסה', color:'cream', line:'איים, שקיעות ואוכל טוב. שעתיים מהבית.'},
  {code:'PRG', name:'פראג', time:'כ־4 ש׳ טיסה', color:'caramel', line:'עיר מאגדה, גשרים ושווקים. מושלמת לזוגות ולמשפחות.'},
  {code:'BUD', name:'בודפשט', time:'כ־3.5 ש׳ טיסה', color:'black', line:'מרחצאות חמים, הדנובה ואורות בלילה.'},
  {code:'RHO', name:'רודוס', time:'כ־1.5 ש׳ טיסה', color:'white', line:'ים טורקיז, עיר עתיקה ומלונות על החוף.'},
  {code:'DXB', name:'דובאי', time:'כ־3 ש׳ טיסה', color:'caramel', line:'יוקרה, שופינג ומדבר. שמש כל השנה.'},
  {code:'LHR', name:'לונדון', time:'כ־5.5 ש׳ טיסה', color:'black', line:'מחזות זמר, שופינג ופארקים ירוקים.'},
  {code:'BER', name:'ברלין', time:'כ־4.5 ש׳ טיסה', color:'white', line:'תרבות, היסטוריה ואוכל מצוין.'},
  {code:'LCA', name:'קפריסין', time:'כ־1 ש׳ טיסה', color:'cream', line:'חוף, שקט ושעת טיסה. בטן־גב במיטבו.'},
  {code:'FCO', name:'איטליה', time:'כ־3.5 ש׳ טיסה', color:'black', line:'העיר הנצחית, אתרים ברגל ואוכל כשר מתוכנן מראש.'},
  {code:'JFK', name:'ארצות הברית', time:'כ־12 ש׳ טיסה', color:'caramel', line:'העיר שלא ישנה. שופינג, מופעים וקהילות כשרות.'}
];
const ORDER = ['couple','family','kosher','flight'];

/* ---------------- Destination photos ---------------- */
const arrowSvg = '<svg aria-hidden="true"><use href="#i-arrow"/></svg>';
const PHOTO = {ATH:'photo-1580502304784-8985b7eb7260', PRG:'photo-1600623471616-8c1966c91ff6', BUD:'photo-1761249747656-d0dadc498220', RHO:'photo-1527108097555-a5c5e36f3dd0', DXB:'photo-1748626083682-611d0a66cb50', LHR:'photo-1772339014113-29414e7295b3', BER:'photo-1571662728319-d6265ebfcac9', LCA:'photo-1520279088142-543e6893743c', FCO:'photo-1514896856000-91cb6de818e0', JFK:'photo-1499092346589-b9b6be3e94b2'};
// photos are stored inside the site (img/dest), resized to their display size: no outside service needed
const photoUrl = (code, w, h) => `img/dest/${code.toLowerCase()}-${h > w ? 'tall' : 'card'}.webp`;
const photoTag = (code, name, w = 800, h = 500) => PHOTO[code] ? `<img class="photo" data-photo src="${photoUrl(code, w, h)}" alt="${name}" loading="lazy" decoding="async">` : '';
function armPhotos(root){
  root.querySelectorAll('img[data-photo]').forEach(i => {
    i.removeAttribute('data-photo');
    const ok = () => i.classList.add('ok'), bad = () => i.remove();
    if (i.complete){ i.naturalWidth ? ok() : bad(); }
    i.addEventListener('load', ok); i.addEventListener('error', bad);
  });
}

/* ---------------- Dialogs ---------------- */
function openDlg(d){ if (d.showModal) d.showModal(); else d.setAttribute('open',''); }
document.addEventListener('click', e => {
  const o = e.target.closest('[data-dlg]'); if (o){ openDlg(document.getElementById(o.dataset.dlg)); return; }
  const c = e.target.closest('[data-close]'); if (c){ c.closest('dialog').close(); return; }
  if (e.target.tagName === 'DIALOG') e.target.close();
});

const fine = matchMedia('(pointer:fine)').matches;

// failsafe: if the hero file never arrives (bad network), show the page anyway
setTimeout(() => {
  if (site.classList.contains('ready')) return;
  const i = site.querySelector('.intro'); if (i) i.remove();
  site.classList.add('ready');
}, 6000);

return {
  site, waLink, hasG, store, fine,
  CITY, COLORS, TYPES, DEST, ORDER,
  arrowSvg, photoTag, armPhotos, openDlg,
  // one shared flag: true when animations should stay still (system setting, accessibility menu, or no animation library)
  get reduce(){ return reduce; },
  set reduce(v){ reduce = v; }
};
})();
