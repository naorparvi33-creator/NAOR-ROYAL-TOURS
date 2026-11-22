/* NAOR ROYAL TOURS · "מה לארוז": המודלים של הפריטים שנכנסים למזוודה (דרכון, קרם הגנה, כובע, מעיל ועוד).
   כל פריט הוא פונקציה קטנה אחת. הקובץ מחזיר את רשימת הבנאים (BUILD) ואת המידות (META). */
(function(){
const P = window.NRT_PACK; if (!P) return;
P.makeItems = function(kit){
const {tex, lin, M, slabGeo, knit, goldM, metal, rubber, FONT} = kit;

/* ---------- items ---------- */
function boxTop(w, h, d, topMap, sideColor, rough = .5, metalness = 0){
  const side = new THREE.MeshStandardMaterial({color:lin(sideColor), roughness:rough, metalness});
  const top = new THREE.MeshStandardMaterial({map:topMap, roughness:rough, metalness});
  return M(new THREE.BoxGeometry(w, h, d), [side, side, top, side, side, side]);
}
const std = (color, rough = .6, metal = 0) => new THREE.MeshStandardMaterial({color:lin(color), roughness:rough, metalness:metal});
function makePassport(){
  const t = tex(512, 720, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, w, h); gr.addColorStop(0, '#26395f'); gr.addColorStop(1, '#141e35'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 2600; i++){ g.fillStyle = `rgba(255,255,255,${Math.random() * .05})`; g.fillRect(Math.random() * w, Math.random() * h, 2, 2); }
    g.strokeStyle = '#d9b56d'; g.fillStyle = '#d9b56d'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.font = `700 64px ${FONT.he}`; g.fillText('דרכון', w / 2, 140);
    g.lineWidth = 6; g.beginPath(); g.arc(w / 2, 365, 92, 0, Math.PI * 2); g.stroke();
    g.lineWidth = 4; g.beginPath(); g.ellipse(w / 2, 365, 40, 92, 0, 0, Math.PI * 2); g.stroke();
    [-46, 0, 46].forEach(o => { const hw = Math.sqrt(92 * 92 - o * o); g.beginPath(); g.moveTo(w / 2 - hw, 365 + o); g.lineTo(w / 2 + hw, 365 + o); g.stroke(); });
    g.font = `500 46px ${FONT.serif}`; g.fillText('PASSPORT', w / 2, 560);
    g.lineWidth = 3; g.strokeRect(w / 2 - 34, 616, 68, 46); g.beginPath(); g.arc(w / 2, 639, 12, 0, Math.PI * 2); g.stroke();
  }, {text:true});
  const grp = new THREE.Group();
  grp.add(boxTop(.37, .034, .53, t, '#1a2742', .5));
  const pages = M(new THREE.BoxGeometry(.355, .026, .515), std('#f1ece2', .9)); pages.position.set(.009, -.001, 0); grp.add(pages);
  return grp;
}
function makeGlasses(){
  const grp = new THREE.Group();
  const tort = new THREE.MeshPhysicalMaterial({color:lin('#3b2414'), roughness:.18, clearcoat:1, clearcoatRoughness:.06});
  const lens = new THREE.MeshPhysicalMaterial({color:lin('#2a1a10'), roughness:.03, metalness:.2, clearcoat:1, envMapIntensity:1.8});
  [-1, 1].forEach(s => {
    const l = M(new THREE.CylinderGeometry(.1, .1, .012, 40), lens); l.scale.x = 1.2; l.position.x = s * .135; grp.add(l);
    const f = M(new THREE.TorusGeometry(.1, .016, 12, 48), tort); f.rotation.x = Math.PI / 2; f.scale.x = 1.2; f.position.x = s * .135; grp.add(f);
    const tmp = M(new THREE.BoxGeometry(.42, .016, .02), tort); tmp.position.set(-s * .015, -.006 + s * .009, -.085 - (s > 0 ? .016 : 0)); grp.add(tmp);
  });
  const bridge = M(new THREE.TorusGeometry(.038, .013, 8, 20, Math.PI), tort); bridge.rotation.x = -Math.PI / 2; bridge.position.set(0, .002, .05); grp.add(bridge);
  return grp;
}
function makeSunscreen(){
  const hh = .04, grp = new THREE.Group();
  const label = tex(512, 208, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, w, 0); gr.addColorStop(0, '#ffd36b'); gr.addColorStop(1, '#ff9f43'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    g.fillStyle = '#fffaf0'; g.fillRect(0, h * .66, w, h * .34);
    g.fillStyle = '#7a3b10'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.font = `700 84px ${FONT.mono}`; g.fillText('SPF 50', w / 2 - 20, h * .34);
    g.font = `700 34px ${FONT.serif}`; g.fillStyle = '#b07a45'; g.fillText('SUN CARE', w / 2 - 20, h * .84);
  }, {text:true});
  const tube = boxTop(.3, .07, .13, label, '#ffb45a', .35); tube.position.set(-.03, -hh + .035, 0); grp.add(tube);
  const capG = new THREE.CylinderGeometry(.045, .05, .07, 32); capG.rotateZ(Math.PI / 2);
  const cap = M(capG, std('#fffaf0', .3)); cap.position.set(.155, -hh + .045, 0); grp.add(cap);
  return grp;
}
function makeHat(){
  const hh = .065, grp = new THREE.Group();
  const straw = tex(256, 256, (g, w, h) => { g.fillStyle = '#e6cd98'; g.fillRect(0, 0, w, h); g.strokeStyle = 'rgba(140,100,50,.35)'; g.lineWidth = 2;
    for (let y = 0; y < h; y += 8){ g.beginPath(); g.moveTo(0, y); g.lineTo(w, y + 4); g.stroke(); } }, {repeat:[3, 3]});
  const sm = new THREE.MeshStandardMaterial({map:straw, roughness:.9});
  const brim = M(new THREE.CylinderGeometry(.21, .22, .012, 56), sm); brim.position.y = -hh + .006; grp.add(brim);
  const crown = M(new THREE.SphereGeometry(.12, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2), sm); crown.scale.y = .95; crown.position.y = -hh + .012; grp.add(crown);
  const band = M(new THREE.CylinderGeometry(.122, .122, .03, 40, 1, true), new THREE.MeshStandardMaterial({color:lin('#2a1d13'), roughness:.6, side:THREE.DoubleSide})); band.position.y = -hh + .028; grp.add(band);
  const gl = makeGlasses(); gl.scale.setScalar(.6); gl.position.set(0, -hh + .03, .165); gl.rotation.x = -.12; grp.add(gl);
  return grp;
}
function makeSwim(){
  const hh = .03, grp = new THREE.Group();
  const dots = (base, dot) => tex(128, 128, (g, w, h) => { g.fillStyle = base; g.fillRect(0, 0, w, h); g.fillStyle = dot;
    for (let y = 16; y < h; y += 32) for (let x = (y / 32) % 2 ? 32 : 16; x < w; x += 32){ g.beginPath(); g.arc(x, y, 6, 0, Math.PI * 2); g.fill(); } }, {repeat:[6, 6]});
  const a = M(slabGeo(.38, .28, .022, .08, .01), new THREE.MeshStandardMaterial({map:dots('#1f9fb3', '#fff6e6'), roughness:.7})); a.position.y = -hh + .01; grp.add(a);
  const b = M(slabGeo(.28, .13, .02, .05, .008), new THREE.MeshStandardMaterial({map:dots('#f08a5d', '#fff6e6'), roughness:.7})); b.position.set(.03, -hh + .036, -.03); b.rotation.y = .25; grp.add(b);
  return grp;
}
function makeKit(){
  const hh = .07, grp = new THREE.Group();
  const pouch = M(slabGeo(.42, .24, .1, .07, .02), new THREE.MeshStandardMaterial({map:knit('#2f3e5c', 'rgba(0,0,0,.15)', 6), roughness:.85})); pouch.position.y = -hh + .02; grp.add(pouch);
  const zip = M(new THREE.BoxGeometry(.36, .008, .016), std('#1a140f', .5)); zip.position.y = hh - .002; grp.add(zip);
  const pull = M(new THREE.BoxGeometry(.05, .008, .028), goldM); pull.position.set(.16, hh + .002, .02); grp.add(pull);
  const cross = M(new THREE.PlaneGeometry(.08, .08), new THREE.MeshStandardMaterial({roughness:.6, map:tex(128, 128, (g, w, h) => {
    g.fillStyle = '#fbf6ee'; g.fillRect(0, 0, w, h); g.fillStyle = '#c8362e'; g.fillRect(w * .4, h * .18, w * .2, h * .64); g.fillRect(w * .18, h * .4, w * .64, h * .2);
  })}));
  cross.rotation.x = -Math.PI / 2; cross.position.set(-.1, hh + .001, .04); grp.add(cross);
  const brushG = new THREE.CylinderGeometry(.011, .011, .26, 12); brushG.rotateZ(Math.PI / 2);
  const brush = M(brushG, std('#7fc6d6', .3)); brush.position.set(.02, hh + .012, -.07); brush.rotation.y = .1; grp.add(brush);
  const head = M(new THREE.BoxGeometry(.04, .02, .018), std('#ffffff', .8)); head.position.set(.15, hh + .022, -.057); grp.add(head);
  return grp;
}
function makeCharger(){
  const hh = .045, grp = new THREE.Group(), white = new THREE.MeshPhysicalMaterial({color:lin('#f4f2ee'), roughness:.3, clearcoat:.8});
  const plug = M(new THREE.BoxGeometry(.11, .09, .11), white); plug.position.set(-.11, -hh + .045, 0); grp.add(plug);
  [-.025, .025].forEach(z => { const pg = new THREE.CylinderGeometry(.008, .008, .06, 10); pg.rotateZ(Math.PI / 2); const p = M(pg, metal); p.position.set(-.195, -hh + .045, z); grp.add(p); });
  const cable = new THREE.MeshStandardMaterial({color:lin('#f4f2ee'), roughness:.5});
  const c1 = M(new THREE.TorusGeometry(.09, .011, 8, 48), cable); c1.rotation.x = Math.PI / 2; c1.position.set(.08, -hh + .011, .01); grp.add(c1);
  const c2 = M(new THREE.TorusGeometry(.075, .011, 8, 48), cable); c2.rotation.x = Math.PI / 2; c2.position.set(.09, -hh + .033, 0); grp.add(c2);
  const usb = M(new THREE.BoxGeometry(.05, .02, .025), std('#d9d4cc', .3, .5)); usb.position.set(.18, -hh + .012, .07); grp.add(usb);
  return grp;
}
function makeBottle(){
  const hh = .065, grp = new THREE.Group();
  const g = new THREE.CylinderGeometry(.065, .065, .3, 40); g.rotateZ(Math.PI / 2);
  const b = M(g, new THREE.MeshPhysicalMaterial({color:lin('#3e7c87'), roughness:.28, metalness:.55, clearcoat:.6})); b.position.set(-.03, 0, 0); grp.add(b);
  const cg = new THREE.CylinderGeometry(.05, .05, .06, 32); cg.rotateZ(Math.PI / 2);
  const cap = M(cg, std('#1b1714', .5)); cap.position.set(.15, 0, 0); grp.add(cap);
  const rg = new THREE.CylinderGeometry(.067, .067, .02, 40); rg.rotateZ(Math.PI / 2);
  const ring = M(rg, goldM); ring.position.set(-.08, 0, 0); grp.add(ring);
  return grp;
}
function makeCoat(){
  const hh = .06, grp = new THREE.Group();
  const coat = M(slabGeo(.48, .38, .07, .07, .015), new THREE.MeshStandardMaterial({map:knit('#24324a', 'rgba(0,0,0,.2)', 5), roughness:.9})); coat.position.y = -hh + .015; grp.add(coat);
  const collar = M(slabGeo(.46, .1, .02, .04, .006), new THREE.MeshStandardMaterial({map:knit('#8a6a4a', 'rgba(0,0,0,.2)', 4), roughness:.95})); collar.position.set(0, hh - .022, -.13); grp.add(collar);
  [-.12, 0, .12].forEach(x => { const bt = M(new THREE.CylinderGeometry(.018, .018, .01, 20), goldM); bt.position.set(x, hh - .015, .06); grp.add(bt); });
  return grp;
}
function makeLayers(){
  const hh = .035, grp = new THREE.Group();
  const a = M(slabGeo(.42, .32, .024, .06, .008), new THREE.MeshStandardMaterial({map:knit('#e9e3d8', 'rgba(90,70,50,.18)', 5), roughness:.95})); a.position.y = -hh + .008; grp.add(a);
  const b = M(slabGeo(.4, .3, .024, .06, .008), new THREE.MeshStandardMaterial({map:knit('#7a2e2e', 'rgba(0,0,0,.2)', 5), roughness:.95})); b.position.set(.02, -hh + .04, .01); b.rotation.y = -.08; grp.add(b);
  return grp;
}
function makeBeanie(){
  const hh = .1, grp = new THREE.Group(), wool = new THREE.MeshStandardMaterial({map:knit('#b0413e', 'rgba(0,0,0,.2)', 6), roughness:.95});
  const cuff = M(new THREE.CylinderGeometry(.115, .115, .045, 36), new THREE.MeshStandardMaterial({map:knit('#8d2f2d', 'rgba(0,0,0,.25)', 4), roughness:.95})); cuff.position.set(-.12, -hh + .0225, 0); grp.add(cuff);
  const dome = M(new THREE.SphereGeometry(.11, 36, 18, 0, Math.PI * 2, 0, Math.PI / 2), wool); dome.scale.y = 1.1; dome.position.set(-.12, -hh + .045, 0); grp.add(dome);
  const pom = M(new THREE.SphereGeometry(.038, 20, 14), std('#f3ead9', 1)); pom.position.set(-.12, -hh + .045 + .121 + .02, 0); grp.add(pom);
  const glove = new THREE.MeshStandardMaterial({map:knit('#3a3a44', 'rgba(255,255,255,.08)', 5), roughness:.95});
  [[.1, -.02, .2], [.19, .03, -.15]].forEach(([x, z, r], i) => {
    const gl = M(slabGeo(.1, .17, .024, .045, .008), glove); gl.position.set(x, -hh + .008 + i * .028, z); gl.rotation.y = r; grp.add(gl);
    const th = M(slabGeo(.035, .08, .022, .016, .006), glove); th.position.set(x + .06, -hh + .008 + i * .028, z + .02); th.rotation.y = r + .5; grp.add(th);
  });
  return grp;
}
function makeBoots(){
  const hh = .045, grp = new THREE.Group();
  const s = new THREE.Shape();
  s.moveTo(-.06, -.15); s.lineTo(.05, -.15); s.lineTo(.05, .02); s.quadraticCurveTo(.06, .04, .12, .05);
  s.quadraticCurveTo(.18, .07, .17, .12); s.quadraticCurveTo(.16, .15, .1, .15); s.lineTo(-.06, .15); s.lineTo(-.06, -.15);
  const up = new THREE.ExtrudeGeometry(s, {depth:.065, bevelEnabled:true, bevelThickness:.008, bevelSize:.008, bevelSegments:3, curveSegments:14}); up.rotateX(-Math.PI / 2);
  const so = new THREE.ExtrudeGeometry(s, {depth:.014, bevelEnabled:false, curveSegments:14}); so.rotateX(-Math.PI / 2);
  const leatherB = new THREE.MeshStandardMaterial({color:lin('#5b3a24'), roughness:.5, metalness:.05});
  [[-.08, .05, 1], [.1, -.03, -1]].forEach(([x, z, m]) => {
    const b = new THREE.Group(); b.position.set(x, 0, z); b.scale.x = m; b.rotation.y = m * .12; grp.add(b);
    const sole = M(so, rubber); sole.position.y = -hh; b.add(sole);
    const top = M(up, leatherB); top.position.y = -hh + .022; b.add(top);
  });
  return grp;
}
function makePowerBank(){
  const hh = .045, grp = new THREE.Group();
  const face = tex(256, 450, (g, w, h) => {
    g.fillStyle = '#2b2f36'; g.fillRect(0, 0, w, h);
    g.strokeStyle = '#e8c690'; g.lineWidth = 10; g.lineJoin = 'round'; g.beginPath(); g.moveTo(140, 120); g.lineTo(100, 220); g.lineTo(160, 220); g.lineTo(118, 320); g.stroke();
    [0, 1, 2, 3].forEach(i => { g.fillStyle = i < 3 ? '#5fe08f' : '#3b414a'; g.fillRect(70 + i * 32, 390, 20, 12); });
  });
  const bank = boxTop(.17, .03, .3, face, '#2b2f36', .35, .4); bank.position.set(-.07, -hh + .015, 0); grp.add(bank);
  const plug = M(new THREE.BoxGeometry(.09, .08, .09), new THREE.MeshPhysicalMaterial({color:lin('#f4f2ee'), roughness:.3, clearcoat:.8})); plug.position.set(.12, -hh + .04, -.07); grp.add(plug);
  const c = M(new THREE.TorusGeometry(.065, .01, 8, 40), std('#f4f2ee', .5)); c.rotation.x = Math.PI / 2; c.position.set(.12, -hh + .01, .08); grp.add(c);
  return grp;
}
const BUILD = {passport:makePassport, sunscreen:makeSunscreen, hat:makeHat, swim:makeSwim, kit:makeKit, charger:makeCharger, bottle:makeBottle,
  coat:makeCoat, layers:makeLayers, beanie:makeBeanie, boots:makeBoots, powerbank:makePowerBank};
// [half height, footprint width, footprint depth] of each model, before scaling
const META = {passport:[.017, .37, .53], sunscreen:[.04, .36, .13], hat:[.065, .44, .44], swim:[.03, .38, .28], kit:[.07, .42, .24], charger:[.045, .38, .22],
  bottle:[.065, .38, .13], coat:[.06, .48, .38], layers:[.035, .42, .32], beanie:[.1, .48, .26], boots:[.045, .4, .3], powerbank:[.045, .36, .3]};

return {BUILD, META};
};
})();
