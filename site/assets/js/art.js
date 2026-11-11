/* Destination illustrations — golden-hour travel-poster style, drawn in code */
const ART = (() => {
  let uid = 0;
  const rnd = seed => () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  function frame(stops, inner, label){
    const id = 'a' + (++uid);
    const s = stops.map((c, i) => `<stop offset="${(i / (stops.length - 1)).toFixed(2)}" stop-color="${c}"/>`).join('');
    return `<svg viewBox="0 0 400 260" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${label}">
<defs><linearGradient id="${id}s" x1="0" y1="0" x2="0" y2="1">${s}</linearGradient>
<radialGradient id="${id}g"><stop offset="0" stop-color="#fff4dc" stop-opacity=".85"/><stop offset="1" stop-color="#fff4dc" stop-opacity="0"/></radialGradient>
<linearGradient id="${id}gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f3cf8e"/><stop offset="1" stop-color="#b9783f"/></linearGradient></defs>
<rect width="400" height="260" fill="url(#${id}s)"/>${inner(id)}</svg>`;
  }
  const sun = (id, x, y, r, c = '#fff3d6') => `<circle cx="${x}" cy="${y}" r="${r * 2.8}" fill="url(#${id}g)"/><circle cx="${x}" cy="${y}" r="${r}" fill="${c}"/>`;
  const sea = (y, c, l = '#fff', n = 7) => `<rect y="${y}" width="400" height="${260 - y}" fill="${c}"/>` +
    Array.from({length: n}, (_, i) => `<rect x="${(i * 71 + 24) % 340}" y="${y + 7 + i * 8}" width="${26 + (i * 37) % 44}" height="1.6" rx=".8" fill="${l}" opacity="${(.42 - i * .045).toFixed(2)}"/>`).join('');
  const birds = (x, y, c) => `<g fill="none" stroke="${c}" stroke-width="1.6" stroke-linecap="round"><path d="M${x} ${y}q5-5 10 0q5-5 10 0"/><path d="M${x + 26} ${y - 10}q4-4 8 0q4-4 8 0"/><path d="M${x + 14} ${y - 22}q3-3 6 0q3-3 6 0"/></g>`;
  const tri = (x, y, w, h, c) => `<polygon points="${x - w / 2},${y} ${x},${y - h} ${x + w / 2},${y}" fill="${c}"/>`;

  const S = {
    SKY: () => frame(['#f7dcae', '#eeae7c', '#9a604a'], id => {
      const cloud = (x, y, s, o, d) => `<g opacity="${o}"><g><ellipse cx="${x}" cy="${y}" rx="${60 * s}" ry="${16 * s}" fill="#fff6ea"/><ellipse cx="${x - 22 * s}" cy="${y - 10 * s}" rx="${30 * s}" ry="${16 * s}" fill="#fff6ea"/><ellipse cx="${x + 18 * s}" cy="${y - 14 * s}" rx="${26 * s}" ry="${18 * s}" fill="#fff6ea"/><animateTransform attributeName="transform" type="translate" values="0 0;${d} 0;0 0" dur="${18 + d / 2}s" repeatCount="indefinite"/></g></g>`;
      return sun(id, 210, 150, 30) + cloud(90, 190, 1.4, .9, 20) + cloud(320, 210, 1.7, .95, -24) + cloud(220, 238, 2.2, 1, 14) + cloud(300, 90, .7, .6, 30) + cloud(70, 70, .6, .5, -20);
    }, 'שמיים מעל העננים'),

    ATH: () => frame(['#f9d8a2', '#ef9c63', '#a24f36'], id => {
      const ink = '#2a1810', cols = Array.from({length: 8}, (_, i) => `<rect x="${141 + i * 16.6}" y="106" width="7.5" height="35" fill="${ink}"/>`).join('');
      return sun(id, 296, 120, 26) + birds(70, 70, '#6a3324') +
        `<path d="M0 178 Q70 150 140 168 T270 160 T400 172 V260 H0Z" fill="#c06c4f" opacity=".7"/>` + sea(194, '#5c2e25', '#ffd8a6') +
        `<path d="M30 260 L40 204 Q110 152 200 150 Q300 150 370 206 L380 260Z" fill="#3a2117"/>` +
        `<rect x="128" y="141" width="144" height="7" fill="${ink}"/><rect x="134" y="136" width="132" height="6" fill="${ink}"/>${cols}<rect x="134" y="98" width="132" height="9" fill="${ink}"/><polygon points="134,98 200,79 266,98" fill="${ink}"/>`;
    }, 'האקרופוליס באתונה בשקיעה'),

    RHO: () => frame(['#a7d4e2', '#e3eee8', '#f6e4c7'], id => {
      const mill = (x, y, d) => `<polygon points="${x - 10},${y} ${x + 10},${y} ${x + 7},${y - 40} ${x - 7},${y - 40}" fill="#fbf9f4"/><path d="M${x - 8} ${y - 40} Q${x} ${y - 54} ${x + 8} ${y - 40}Z" fill="#8a5d3a"/><rect x="${x - 2}" y="${y - 12}" width="4" height="8" fill="#2f6fa0"/>` +
        `<g transform="translate(${x} ${y - 42})"><g>${[0, 90, 180, 270].map(a => `<g transform="rotate(${a})"><rect x="-1" y="-30" width="2" height="30" fill="#5b4a3a"/><polygon points="1,-29 10,-26 10,-6 1,-6" fill="#fffaf2" opacity=".9"/></g>`).join('')}<animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="${d}s" repeatCount="indefinite"/></g><circle r="2.5" fill="#5b4a3a"/></g>`;
      const houses = [[214, 168, 34, 28], [250, 156, 30, 40], [284, 166, 40, 30], [330, 152, 30, 44], [366, 162, 40, 34]].map(([x, y, w, h]) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#fcfbf7"/><rect x="${x + w - 6}" y="${y}" width="6" height="${h}" fill="#e7dfd1"/><rect x="${x + w / 2 - 3}" y="${y + h - 11}" width="6" height="11" fill="#2f6fa0"/>`).join('');
      return sun(id, 330, 56, 16, '#fffbf1') + `<path d="M0 152 Q80 134 170 148 T330 140 T400 150 V160 H0Z" fill="#88aeb0" opacity=".75"/>` + sea(156, '#2d87a6', '#eafcff') +
        `<path d="M170 260 L190 196 Q250 176 310 180 L400 170 V260Z" fill="#e8d9bf"/>` + houses + `<path d="M330 152 q15 -16 30 0z" fill="#2f6fa0"/>` +
        `<path d="M0 260 L0 200 Q60 186 150 206 L176 260Z" fill="#e0cfb0"/>` + mill(60, 196, 9) + mill(112, 200, 12);
    }, 'טחנות רוח ובתים לבנים ברודוס'),

    PRG: () => frame(['#f5c38c', '#bb6c6b', '#3e2b3f'], id => {
      const far = '#6c4559', ink = '#2a1b26';
      const spires = [222, 238, 252, 340, 356, 372].map((x, i) => tri(x, 150, 7, 18 + (i % 3) * 6, far)).join('');
      const piers = Array.from({length: 7}, (_, i) => `<rect x="${18 + i * 60}" y="190" width="12" height="26" fill="${ink}"/>`).join('');
      const lamps = Array.from({length: 9}, (_, i) => `<circle cx="${30 + i * 44}" cy="178" r="1.8" fill="#ffd89a"/>`).join('');
      return sun(id, 120, 120, 20, '#ffe9c8') +
        `<path d="M190 168 Q260 132 400 142 V200 H190Z" fill="${far}"/><rect x="282" y="106" width="40" height="46" fill="${far}"/>` + tri(290, 106, 12, 46, far) + tri(314, 106, 12, 52, far) + spires +
        `<rect x="34" y="112" width="18" height="78" fill="${ink}"/><rect x="60" y="112" width="18" height="78" fill="${ink}"/>` + tri(43, 112, 22, 40, ink) + tri(69, 112, 22, 44, ink) +
        `<rect x="128" y="128" width="30" height="56" fill="${ink}"/>` + tri(143, 128, 36, 34, ink) +
        sea(210, '#3a2638', '#f5c38c') + `<rect x="0" y="180" width="400" height="11" fill="${ink}"/>` + piers + lamps;
    }, 'גשר קארל ומגדלי פראג'),

    BUD: () => frame(['#141226', '#3a2b47', '#b77d55'], id => {
      const r = rnd(7), stars = Array.from({length: 22}, () => `<circle cx="${(r() * 400).toFixed(0)}" cy="${(r() * 90).toFixed(0)}" r="${(r() * 1.1 + .3).toFixed(2)}" fill="#fff" opacity="${(r() * .6 + .2).toFixed(2)}"/>`).join('');
      const g = `url(#${id}gold)`;
      const sp = Array.from({length: 15}, (_, i) => 78 + i * 17.5).filter(x => x < 168 || x > 232).map(x => tri(x, 160, 6, 18, g)).join('');
      const win = [168, 180].map(y => Array.from({length: 24}, (_, i) => `<rect x="${76 + i * 10.6}" y="${y}" width="4" height="7" fill="#7a4a24" opacity=".8"/>`).join('')).join('');
      const bld = `<rect x="70" y="160" width="260" height="36" fill="${g}"/><rect x="66" y="150" width="62" height="12" fill="${g}"/><rect x="272" y="150" width="62" height="12" fill="${g}"/><rect x="178" y="138" width="44" height="22" fill="${g}"/><path d="M174 140 Q176 108 200 104 Q224 108 226 140Z" fill="${g}"/>` + tri(200, 106, 7, 30, g) + sp + win;
      return stars + `<circle cx="330" cy="54" r="12" fill="#f8ecd2"/>` + sea(196, '#151020', '#e8c690', 0) +
        `<g transform="translate(0 392) scale(1 -1)" opacity=".28">${bld}</g>` + bld +
        Array.from({length: 7}, (_, i) => `<rect x="${(i * 61 + 30) % 380}" y="${206 + i * 7}" width="${30 + (i * 23) % 40}" height="1.4" fill="#f3cf8e" opacity=".5"/>`).join('');
    }, 'בניין הפרלמנט בבודפשט בלילה'),

    DXB: () => frame(['#fbe4b9', '#efa86c', '#b9613f'], id => {
      const ink = '#2b1a12', far = '#a3613f';
      return sun(id, 140, 128, 40, '#fff1d2') +
        `<rect x="40" y="150" width="18" height="70" fill="${far}" opacity=".6"/><rect x="62" y="170" width="14" height="50" fill="${far}" opacity=".6"/><rect x="300" y="160" width="20" height="60" fill="${far}" opacity=".6"/>` +
        `<rect x="170" y="150" width="20" height="76" fill="${ink}"/><rect x="194" y="172" width="16" height="54" fill="${ink}"/><rect x="258" y="140" width="22" height="86" fill="${ink}"/>` +
        `<polygon points="214,226 214,150 219,150 219,112 223,112 223,82 226,82 226,56 228.5,56 230,18 231.5,56 234,56 234,82 237,82 237,112 241,112 241,150 246,150 246,226" fill="${ink}"/>` +
        `<path d="M318 226 L318 150 Q346 162 350 226Z" fill="${ink}"/><rect x="316" y="134" width="2.5" height="92" fill="${ink}"/>` +
        `<path d="M0 260 L0 224 Q100 204 200 226 T400 218 V260Z" fill="#cf9259"/><path d="M0 260 L0 240 Q150 222 280 244 T400 238 V260Z" fill="#a96a3e"/>`;
    }, 'בורג׳ ח׳ליפה בדובאי בשקיעה'),

    LHR: () => frame(['#f0e2c8', '#d8b68b', '#9c7858'], id => {
      const ink = '#2b1f17', mid = '#3a2b20';
      const spokes = Array.from({length: 12}, (_, i) => { const a = i * Math.PI / 6; return `<line x1="0" y1="0" x2="${(52 * Math.cos(a)).toFixed(1)}" y2="${(52 * Math.sin(a)).toFixed(1)}" stroke="${mid}" stroke-width="1"/><circle cx="${(54 * Math.cos(a)).toFixed(1)}" cy="${(54 * Math.sin(a)).toFixed(1)}" r="3.4" fill="${mid}"/>`; }).join('');
      const wsp = Array.from({length: 9}, (_, i) => tri(150 + i * 15, 166, 5, 14, mid)).join('');
      return sun(id, 210, 70, 15, '#fff7e6') +
        `<g transform="translate(330 146)"><g><circle r="52" fill="none" stroke="${mid}" stroke-width="2.4"/>${spokes}<animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="70s" repeatCount="indefinite"/></g><circle r="6" fill="${mid}"/></g><path d="M314 206 L330 146 L346 206" fill="none" stroke="${mid}" stroke-width="3"/>` +
        `<rect x="140" y="166" width="150" height="42" fill="${mid}"/>` + wsp + `<rect x="270" y="146" width="16" height="62" fill="${mid}"/>` + tri(278, 146, 18, 16, mid) +
        `<rect x="96" y="98" width="30" height="110" fill="${ink}"/><rect x="92" y="74" width="38" height="26" fill="${ink}"/><circle cx="111" cy="87" r="10" fill="#f3e3c2"/><path d="M111 87 V80 M111 87 L116 89" stroke="${ink}" stroke-width="1.6" stroke-linecap="round"/>` + tri(111, 74, 38, 32, ink) + `<rect x="110" y="20" width="2" height="24" fill="${ink}"/>` +
        sea(206, '#5b4636', '#f5e6cc');
    }, 'ביג בן ועין לונדון'),

    BER: () => frame(['#f6ddb4', '#dca26f', '#7c5141'], id => {
      const ink = '#2b1d15';
      const cols = Array.from({length: 6}, (_, i) => `<rect x="${96 + i * 30}" y="140" width="12" height="76" fill="${ink}"/>`).join('');
      return sun(id, 220, 96, 22) + birds(150, 60, '#7c5141') +
        `<rect x="306" y="40" width="6" height="180" fill="${ink}"/><circle cx="309" cy="98" r="14" fill="${ink}"/><rect x="299" y="112" width="20" height="4" fill="${ink}"/><rect x="308" y="12" width="2" height="30" fill="${ink}"/>` +
        `<rect x="88" y="118" width="170" height="22" fill="${ink}"/><rect x="140" y="108" width="66" height="11" fill="${ink}"/><path d="M156 108 q4 -14 14 -8 q6 -10 14 0 q8 -6 10 8z" fill="${ink}"/>` + cols +
        `<rect x="84" y="214" width="178" height="6" fill="${ink}"/><rect y="220" width="400" height="40" fill="#3a2a20"/><ellipse cx="30" cy="214" rx="40" ry="20" fill="#3a2a20"/><ellipse cx="380" cy="212" rx="44" ry="22" fill="#3a2a20"/>`;
    }, 'שער ברנדנבורג ומגדל הטלוויזיה בברלין'),

    LCA: () => frame(['#ffedd1', '#ffc79b', '#f39b77'], id => {
      const palm = (x, y, s) => `<g transform="translate(${x} ${y}) scale(${s})"><path d="M0 0 Q8 -50 -10 -100" fill="none" stroke="#3a2618" stroke-width="6" stroke-linecap="round"/>` +
        [[-60, -6], [-25, -18], [10, -14], [40, -2], [-90, 14], [70, 16]].map(([a, b]) => `<path d="M-10 -100 Q${-10 + a * .55} ${-118 + b} ${-10 + a} ${-96 + b * 1.6} Q${-10 + a * .5} ${-104 + b} -10 -100Z" fill="#2e2417"/>`).join('') + `</g>`;
      return sun(id, 250, 150, 30, '#fff5de') + sea(160, '#2f7690', '#ffe8c8') +
        `<polygon points="182,152 182,118 198,152" fill="#fffaf2"/><path d="M172 154 H204 L198 160 H178Z" fill="#3a2618"/>` +
        `<path d="M0 260 L0 206 Q120 186 260 202 T400 196 V260Z" fill="#edd4a9"/>` + palm(76, 240, 1) + palm(344, 236, .78);
    }, 'חוף ודקלים בקפריסין'),

    FCO: () => frame(['#f8d097', '#e08954', '#6c3425'], id => {
      const ink = '#3a2116', hole = '#e9a46b';
      const arches = [[132, 296], [160, 296], [188, 268]].map(([y, end]) => Array.from({length: 11}, (_, i) => 84 + i * 21).filter(x => x < end).map(x => `<path d="M${x} ${y + 20} V${y + 6} Q${x + 6} ${y} ${x + 12} ${y + 6} V${y + 20}Z" fill="${hole}" opacity=".9"/>`).join('')).join('');
      const cyp = (x, ry) => `<ellipse cx="${x}" cy="${222 - ry}" rx="${ry * .22}" ry="${ry}" fill="#2a1a10"/>`;
      return sun(id, 316, 104, 24) +
        `<path d="M70 222 L70 120 Q200 96 312 116 L312 136 Q296 128 286 140 L286 222Z" fill="${ink}"/>` + arches +
        `<rect x="70" y="155" width="216" height="2" fill="#5a3424"/><rect x="70" y="183" width="216" height="2" fill="#5a3424"/>` +
        cyp(28, 44) + cyp(48, 32) + cyp(352, 46) + cyp(374, 34) + `<rect y="220" width="400" height="40" fill="#2a1a10"/>`;
    }, 'הקולוסיאום ברומא'),

    JFK: () => frame(['#f6d0a0', '#9b6b73', '#2c2238'], id => {
      const r = rnd(11), back = '#4a3650', ink = '#1f1726';
      let b = '', w = '';
      for (let x = 70; x < 400; x += 16) { const h = 40 + r() * 70; b += `<rect x="${x}" y="${214 - h}" width="14" height="${h}" fill="${back}"/>`; }
      [[120, 70, 18], [188, 96, 22], [212, 60, 16], [300, 84, 20], [330, 54, 18], [356, 76, 22]].forEach(([x, h, wd]) => {
        b += `<rect x="${x}" y="${214 - h}" width="${wd}" height="${h}" fill="${ink}"/>`;
        for (let yy = 220 - h; yy < 208; yy += 9) for (let xx = x + 3; xx < x + wd - 3; xx += 6) if (r() > .55) w += `<rect x="${xx}" y="${yy}" width="2.4" height="3.6" fill="#f3cf8e" opacity=".85"/>`;
      });
      b += `<rect x="146" y="120" width="28" height="94" fill="${ink}"/><rect x="150" y="104" width="20" height="17" fill="${ink}"/><rect x="155" y="92" width="10" height="13" fill="${ink}"/><rect x="159" y="62" width="2" height="31" fill="${ink}"/>`;
      b += `<polygon points="244,214 249,92 265,92 270,214" fill="${ink}"/><rect x="256" y="58" width="2" height="35" fill="${ink}"/>`;
      return sun(id, 90, 150, 22, '#ffe6c2') + b + w + sea(214, '#211a2b', '#f6d0a0') +
        `<ellipse cx="40" cy="214" rx="26" ry="5" fill="${ink}"/><rect x="32" y="188" width="16" height="26" fill="${ink}"/><polygon points="34,188 40,150 46,188" fill="${ink}"/><circle cx="40" cy="147" r="4" fill="${ink}"/><rect x="43" y="128" width="2.6" height="20" fill="${ink}"/><circle cx="44.3" cy="126" r="3.2" fill="#f3cf8e"/>`;
    }, 'קו הרקיע של ניו יורק'),
  };
  return code => (S[code] || S.SKY)();
})();

