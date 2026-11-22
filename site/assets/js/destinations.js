/* NAOR ROYAL TOURS · יעדים: פס היעדים הרץ, כרטיסי היעדים (בנייה, פתיחה וסגירה) והטיית הכרטיס מול העכבר.
   לחיצה על "צבע מזוודה" מעבירה את היעד לסצנה הראשית (hero.js) דרך NRT.goDest. */
(function(){
const NRT = window.NRT; if (!NRT) return;
const {CITY, COLORS, DEST, waLink, arrowSvg, photoTag, armPhotos} = NRT;

/* ---------------- Ticker ---------------- */
const tickHTML = DEST.map(d => `<span>TLV <svg><use href="#i-plane"/></svg> ${d.code} <em>${CITY[d.code]}</em></span>`).join('');
document.getElementById('ticker').innerHTML = tickHTML + tickHTML;

/* ---------------- Build tickets ---------------- */
document.getElementById('tickets').innerHTML = DEST.map((d,i) => `
  <div class="ticket rv" style="--i:${i%4}" data-code="${d.code}">
    <button class="t-hit" aria-expanded="false" aria-controls="act-${d.code}"><span class="sr">${d.name}: פתיחת אפשרויות</span></button>
    <span class="tilt">
      <span class="t-img">${ART(d.code)}${photoTag(d.code, d.name)}<span class="code-badge">TLV → ${d.code}</span></span>
      <span class="t-body">
        <span class="t-row"><b>${d.name}</b><span class="t-code">${d.code}</span></span>
        <span class="t-bottom"><span>${d.time}</span><span class="t-swatch"><i style="background:${COLORS[d.color].body}"></i>${COLORS[d.color].name}</span><span class="t-go">לחצו ${arrowSvg}</span></span>
      </span>
    </span><span class="glare"></span>
    <div class="t-actions" id="act-${d.code}" role="group" aria-label="אפשרויות ל${d.name}">
      <a class="t-act wa" href="${waLink('היי נאור, אשמח לסגור חופשה ב' + d.name)}" target="_blank" rel="noopener"><svg aria-hidden="true"><use href="#i-wa"/></svg>לסגור איתי על ${d.name}</a>
      <button class="t-act color" data-code="${d.code}"><i style="background:${COLORS[d.color].body}" aria-hidden="true"></i>צבע מזוודה<span class="sr">: ${COLORS[d.color].name}</span></button>
    </div>
  </div>`).join('') + `
  <a class="ticket other rv" style="--i:2" href="#plan"><span class="tilt"><span class="t-img"><strong>???</strong></span><span class="t-body"><span class="t-row"><b>יעד אחר</b><span class="t-code">ANY</span></span><span class="t-bottom"><span>ספרו לי לאן</span><span class="t-go">לטופס ${arrowSvg}</span></span></span></span><span class="glare"></span></a>
  <a class="ticket other rv" style="--i:3" href="${waLink('היי נאור, יש לי שאלה על חופשה')}" target="_blank" rel="noopener"><span class="tilt"><span class="t-img"><strong>HI!</strong></span><span class="t-body"><span class="t-row"><b>סתם לשאול</b><span class="t-code">24/6</span></span><span class="t-bottom"><span>וואטסאפ</span><span class="t-go">לשיחה ${arrowSvg}</span></span></span></span><span class="glare"></span></a>`;

armPhotos(document.getElementById('tickets'));

/* ---------------- Open / close a ticket ---------------- */
const tk = document.getElementById('tickets');
function closeTickets(except){
  tk.querySelectorAll('.ticket.open').forEach(t => { if (t !== except){ t.classList.remove('open'); t.querySelector('.t-hit').setAttribute('aria-expanded','false'); } });
}
tk.addEventListener('click', e => {
  const hit = e.target.closest('.t-hit');
  if (hit){
    const t = hit.closest('.ticket'), open = !t.classList.contains('open');
    closeTickets(t); t.classList.toggle('open', open); hit.setAttribute('aria-expanded', open);
    if (open && e.detail === 0) setTimeout(() => t.querySelector('.t-act').focus(), 60);
    return;
  }
  const c = e.target.closest('.t-act.color');
  if (c){ closeTickets(); if (NRT.goDest) NRT.goDest(c.dataset.code); return; }
  if (e.target.closest('.t-act.wa')) setTimeout(() => closeTickets(), 400);
});
document.addEventListener('click', e => { if (!e.target.closest('.ticket')) closeTickets(); });
addEventListener('keydown', e => { if (e.key === 'Escape'){ const o = tk.querySelector('.ticket.open'); if (o){ closeTickets(); o.querySelector('.t-hit').focus(); } } });

/* ---------------- Ticket tilt ---------------- */
document.getElementById('tickets').addEventListener('pointermove', e => {
  const t = e.target.closest('.ticket'); if (!t || NRT.reduce) return;
  const r = t.getBoundingClientRect(), x = (e.clientX - r.left)/r.width, y = (e.clientY - r.top)/r.height;
  t.style.setProperty('--ry', ((x - .5)*14).toFixed(2) + 'deg'); t.style.setProperty('--rx', ((.5 - y)*12).toFixed(2) + 'deg');
  t.style.setProperty('--mx', (x*100).toFixed(1) + '%'); t.style.setProperty('--my', (y*100).toFixed(1) + '%');
});
document.getElementById('tickets').addEventListener('pointerout', e => { const t = e.target.closest('.ticket'); if (t && !t.contains(e.relatedTarget)){ t.style.setProperty('--rx','0deg'); t.style.setProperty('--ry','0deg'); } });
})();
