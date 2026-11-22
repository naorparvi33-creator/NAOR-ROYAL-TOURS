/* NAOR ROYAL TOURS · "מה לארוז": בניית המזוודה הפתוחה בתלת־ממד (חומרים, גוף, מכסה, בגדים מקופלים).
   הקובץ רק בונה ומחזיר את החלקים. התנועה נמצאת ב-pack.js. */
(function(){
const P = window.NRT_PACK; if (!P) return;
P.buildSuitcase = function(kit, scene){
const {tex, lin, M, slabGeo, shellGeo, FONT} = kit;

/* ---------- materials ---------- */
const grain = tex(256, 256, (g, w, h) => { const d = g.createImageData(w, h); for (let i = 0; i < d.data.length; i += 4){ const v = 118 + Math.random() * 20; d.data[i] = d.data[i + 1] = d.data[i + 2] = v; d.data[i + 3] = 255; } g.putImageData(d, 0, 0); }, {repeat:[5, 5]});
const bodyMat = new THREE.MeshPhysicalMaterial({color:lin('#9c6a3d'), roughness:.46, metalness:.02, clearcoat:.45, clearcoatRoughness:.28, bumpMap:grain, bumpScale:.0025, sheen:0});
const bandMat = new THREE.MeshStandardMaterial({color:lin('#2a1d13'), roughness:.5, metalness:.25});
const metal = new THREE.MeshStandardMaterial({color:lin('#dcd6cc'), roughness:.18, metalness:1});
const rubber = new THREE.MeshStandardMaterial({color:lin('#141110'), roughness:.8});
const leather = new THREE.MeshStandardMaterial({color:lin('#8a5a32'), roughness:.55});
const goldM = new THREE.MeshStandardMaterial({color:lin('#e2bd84'), roughness:.24, metalness:1});
const lining = (w, h) => tex(w, h, (g, W, H) => {
  g.fillStyle = '#ede1cd'; g.fillRect(0, 0, W, H);
  g.strokeStyle = 'rgba(150,110,70,.13)'; g.lineWidth = 2;
  for (let i = -H; i < W + H; i += 46){ g.beginPath(); g.moveTo(i, 0); g.lineTo(i + H, H); g.stroke(); g.beginPath(); g.moveTo(i + H, 0); g.lineTo(i, H); g.stroke(); }
  g.fillStyle = 'rgba(176,122,69,.30)'; g.font = `700 22px ${FONT.serif}`; g.textAlign = 'center'; g.textBaseline = 'middle';
  for (let y = 23, r = 0; y < H; y += 46, r++) for (let x = (r % 2 ? 46 : 23); x < W; x += 92) g.fillText('N', x, y);
  const edge = (x0, y0, x1, y1) => { const gr = g.createLinearGradient(x0, y0, x1, y1); gr.addColorStop(0, 'rgba(70,45,25,.42)'); gr.addColorStop(1, 'rgba(70,45,25,0)'); g.fillStyle = gr; g.fillRect(0, 0, W, H); };
  const e = Math.min(W, H) * .16; edge(0, 0, e, 0); edge(W, 0, W - e, 0); edge(0, 0, 0, e); edge(0, H, 0, H - e);
}, {text:true});
const liningTex = lining(1024, 680); // painted once, shared by the floor and the lid
const floorMat = new THREE.MeshStandardMaterial({map:liningTex, roughness:.9});
const ceilMat = new THREE.MeshStandardMaterial({map:liningTex, roughness:.9, side:THREE.DoubleSide});
const wallMat = new THREE.MeshStandardMaterial({color:lin('#d9c8ad'), roughness:.92});
const netMat = new THREE.MeshStandardMaterial({map:tex(256, 256, (g, w, h) => {
  g.strokeStyle = 'rgba(120,85,50,.85)'; g.lineWidth = 2.5;
  for (let i = -h; i < w + h; i += 18){ g.beginPath(); g.moveTo(i, 0); g.lineTo(i + h, h); g.stroke(); g.beginPath(); g.moveTo(i + h, 0); g.lineTo(i, h); g.stroke(); }
}, {repeat:[7, 3]}), transparent:true, alphaTest:.04, roughness:.8, side:THREE.DoubleSide});
const shadowTex = tex(128, 128, (g) => { const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64); gr.addColorStop(0, 'rgba(0,0,0,.75)'); gr.addColorStop(.55, 'rgba(0,0,0,.35)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 128, 128); });
function blob(w, d, opacity){
  const m = M(new THREE.PlaneGeometry(w, d), new THREE.MeshBasicMaterial({map:shadowTex, transparent:true, depthWrite:false, opacity}));
  m.rotation.x = -Math.PI / 2; m.renderOrder = 1; return m;
}

/* ---------- suitcase ---------- */
let fitParts = [];
const W = 2.3, D = 1.55, Hb = .38, Hl = .38, T = .045, RAD = .26, Hc = (Hb + Hl) / 2, Y0 = .046;
const display = new THREE.Group(), stand = new THREE.Group(), tilt = new THREE.Group(), body = new THREE.Group();
scene.add(display); display.add(stand); stand.add(tilt); tilt.add(body); body.position.y = -Hc;

body.add(M(shellGeo(W, D, Hb, T, RAD), bodyMat));
body.add(M(slabGeo(W, D, .04, RAD), bodyMat));
const rimB = M(shellGeo(W + .02, D + .02, .05, T + .01, RAD + .01, .01), bandMat); rimB.position.y = Hb - .05; body.add(rimB);
const floor = M(new THREE.PlaneGeometry(W - 2 * T, D - 2 * T), floorMat); floor.rotation.x = -Math.PI / 2; floor.position.y = Y0; body.add(floor);
const wallB = M(shellGeo(W - 2 * T - .004, D - 2 * T - .004, Hb - .06, .01, RAD - T, 0), wallMat); wallB.position.y = .04; body.add(wallB);
const ribGeo = new THREE.CylinderGeometry(.011, .011, W * .7, 16); ribGeo.rotateZ(Math.PI / 2);
for (let z = -.54; z <= .55; z += .18){ const r = M(ribGeo, bodyMat); r.position.set(-.06, -.002, z); r.scale.y = .6; body.add(r); }
const carry = M(new THREE.TorusGeometry(.19, .036, 14, 40, Math.PI), rubber); carry.rotation.x = Math.PI / 2; carry.position.set(0, Hb * .52, D / 2 + .012); body.add(carry);
function wheels(parent, y, z){
  const house = M(new THREE.CylinderGeometry(.07, .085, .11, 22), bandMat); house.rotation.z = Math.PI / 2; house.position.set(-W / 2 - .045, y, z); parent.add(house);
  [-.042, .042].forEach(o => { const w = M(new THREE.CylinderGeometry(.08, .08, .046, 26), rubber); w.rotation.x = Math.PI / 2; w.position.set(-W / 2 - .16, y, z + o); parent.add(w);
    const hub = M(new THREE.CylinderGeometry(.03, .03, .05, 16), metal); hub.rotation.x = Math.PI / 2; hub.position.copy(w.position); parent.add(hub); });
}
wheels(body, Hb * .5, D / 2 - .24); wheels(body, Hb * .5, -D / 2 + .24);
const tele = new THREE.Group(); tele.position.set(W / 2, Hb * .55, 0); body.add(tele);
const posts = [-.4, .4].map(z => { const p = M(new THREE.CylinderGeometry(.028, .028, 1, 16), metal); p.rotation.z = Math.PI / 2; p.position.z = z; tele.add(p);
  const cap = M(new THREE.BoxGeometry(.04, .09, .11), bandMat); cap.position.set(.018, 0, z); tele.add(cap); return p; });
const grip = M(new THREE.CylinderGeometry(.055, .055, .94, 24), rubber); grip.rotation.x = Math.PI / 2; tele.add(grip);
function setTele(len){ posts.forEach(p => { p.scale.y = len; p.position.x = len / 2; }); grip.position.x = len + .03; }
setTele(.05);
fitParts.push(body.children[0], tele);

// lid
const lidPivot = new THREE.Group(); lidPivot.position.set(0, Hb, -D / 2); body.add(lidPivot);
const lid = new THREE.Group(); lid.position.z = D / 2; lidPivot.add(lid);
fitParts.push(lid);
lid.add(M(shellGeo(W, D, Hl, T, RAD), bodyMat));
const lidTop = M(slabGeo(W, D, .04, RAD), bodyMat); lidTop.position.y = Hl - .04; lid.add(lidTop);
lid.add(M(shellGeo(W + .02, D + .02, .05, T + .01, RAD + .01, .01), bandMat));
const ceil = M(new THREE.PlaneGeometry(W - 2 * T, D - 2 * T), ceilMat); ceil.rotation.x = Math.PI / 2; ceil.position.y = Hl - .042; lid.add(ceil);
const wallL = M(shellGeo(W - 2 * T - .004, D - 2 * T - .004, Hl - .06, .01, RAD - T, 0), wallMat); wallL.position.y = .02; lid.add(wallL);
const net = M(new THREE.PlaneGeometry(W - .3, D * .46), netMat); net.rotation.x = Math.PI / 2; net.position.set(0, Hl - .07, D * .2); lid.add(net);
const zip = M(new THREE.BoxGeometry(W - .3, .012, .028), bandMat); zip.position.set(0, Hl - .074, D * .2 - D * .23); lid.add(zip);
const pull = M(new THREE.BoxGeometry(.05, .01, .09), goldM); pull.position.set(.55, Hl - .08, D * .2 - D * .23 - .03); lid.add(pull);
const label = M(new THREE.PlaneGeometry(.5, .14), new THREE.MeshStandardMaterial({roughness:.7, map:tex(512, 144, (g, w, h) => {
  g.fillStyle = '#100d0a'; g.fillRect(0, 0, w, h); g.strokeStyle = '#b07a45'; g.lineWidth = 4; g.strokeRect(10, 10, w - 20, h - 20);
  g.fillStyle = '#e8c690'; g.font = `700 46px ${FONT.serif}`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('NAOR ROYAL TOURS', w / 2, h / 2 + 2);
}, {text:true})}));
label.rotation.x = Math.PI / 2; label.position.set(0, Hl - .075, D * .2 + D * .23 + .05); lid.add(label);
for (let z = -.54; z <= .55; z += .18){ const r = M(ribGeo, bodyMat); r.position.set(-.06, Hl + .002, z); r.scale.y = .6; lid.add(r); }
const plate = M(new THREE.BoxGeometry(.11, .012, .36), [goldM, goldM, new THREE.MeshStandardMaterial({metalness:.75, roughness:.28, map:tex(128, 420, (g, w, h) => {
  const gr = g.createLinearGradient(0, 0, w, h); gr.addColorStop(0, '#f2d9a8'); gr.addColorStop(.5, '#d3a46e'); gr.addColorStop(1, '#b8844f'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
  g.translate(w / 2, h / 2); g.rotate(Math.PI / 2); g.fillStyle = '#3a2614'; g.font = `700 50px ${FONT.serif}`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('NAOR ROYAL', 0, 2);
}, {text:true})}), goldM, goldM, goldM]);
plate.position.set(W / 2 - .3, Hl + .006, 0); lid.add(plate);
wheels(lid, Hl * .5, D / 2 - .24); wheels(lid, Hl * .5, -D / 2 + .24);

/* ---------- folded clothes ---------- */
const knit = (base, line, step) => tex(256, 256, (g, w, h) => { g.fillStyle = base; g.fillRect(0, 0, w, h); g.strokeStyle = line; g.lineWidth = 3;
  for (let x = 0; x < w; x += step){ g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke(); } }, {repeat:[4, 4]});
const linen = tex(256, 256, (g, w, h) => { g.fillStyle = '#f6f2ea'; g.fillRect(0, 0, w, h); for (let i = 0; i < 3000; i++){ g.fillStyle = `rgba(120,100,70,${Math.random() * .08})`; g.fillRect(Math.random() * w, Math.random() * h, 3, 1); } }, {repeat:[3, 3]});
const stripe = (a, b) => tex(256, 256, (g, w, h) => { g.fillStyle = a; g.fillRect(0, 0, w, h); g.fillStyle = b; for (let y = 0; y < h; y += 64){ g.fillRect(0, y, w, 22); } });
function fold(w, d, h, map, x, y, z, ry){
  const m = M(slabGeo(w, d, h, .08, .022, 4), new THREE.MeshStandardMaterial({map, roughness:.96}));
  m.position.set(x, y, z); m.rotation.y = ry; body.add(m);
  const crease = M(new THREE.BoxGeometry(w * .96, .004, .006), new THREE.MeshBasicMaterial({color:0x000000, transparent:true, opacity:.12})); crease.position.set(x, y + h + .023, z + d * .18); crease.rotation.y = ry; body.add(crease);
}
fold(.98, 1.0, .07, knit('#23324d', 'rgba(0,0,0,.18)', 9), -.55, Y0, -.15, .02);
fold(.92, .95, .06, linen, -.55, Y0 + .092, -.15, -.015);
fold(.97, 1.0, .07, knit('#e9dcc6', 'rgba(120,90,60,.16)', 10), .52, Y0, -.15, -.02);
fold(.88, .92, .05, knit('#b07a45', 'rgba(60,35,15,.2)', 9), .52, Y0 + .092, -.15, .025);
[[-.55, stripe('#f2e8d8', '#b07a45')], [.52, stripe('#f7f4ef', '#23324d')]].forEach(([x, map]) => {
  const m = M(new THREE.CylinderGeometry(.085, .085, .94, 32), new THREE.MeshStandardMaterial({map, roughness:.96})); m.rotation.z = Math.PI / 2; m.position.set(x, Y0 + .085, .53); body.add(m);
  const sw = M(new THREE.CylinderGeometry(.086, .086, .02, 32), new THREE.MeshStandardMaterial({color:lin('#d8c6a8'), roughness:.96})); sw.rotation.z = Math.PI / 2; sw.position.set(x + .3, Y0 + .085, .53); body.add(sw);
});
[[-.55, -.15, 1.1, 1.12], [.52, -.15, 1.1, 1.12], [0, .53, 2.1, .3]].forEach(([x, z, w, d]) => { const b = blob(w, d, .35); b.position.set(x, Y0 + .002, z); body.add(b); });
const TOP_L = Y0 + .092 + .06 + .022, TOP_R = Y0 + .092 + .05 + .022;

return {bodyMat, bandMat, metal, rubber, leather, goldM, blob, knit, fitParts,
  W, D, Hb, Hl, T, Hc, Y0, TOP_L, TOP_R,
  display, stand, tilt, body, carry, posts, setTele, lidPivot};
};
})();
