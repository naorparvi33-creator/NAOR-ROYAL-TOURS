/* NAOR ROYAL TOURS · בניית המזוודה בתלת־ממד של המסך הראשי (גוף, ידית, גלגלים, תג ותאורה).
   הקובץ רק בונה ומחזיר את החלקים. התנועה והחלפת הצבעים נמצאות ב-hero.js. */
(function(){
const NRT = window.NRT; if (!NRT) return;

const lin = hex => new THREE.Color(hex).convertSRGBToLinear();
function roundedRect(w,h,r){ const s = new THREE.Shape(), x = -w/2, y = -h/2;
  s.moveTo(x+r,y); s.lineTo(x+w-r,y); s.quadraticCurveTo(x+w,y,x+w,y+r); s.lineTo(x+w,y+h-r); s.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
  s.lineTo(x+r,y+h); s.quadraticCurveTo(x,y+h,x,y+h-r); s.lineTo(x,y+r); s.quadraticCurveTo(x,y,x+r,y); return s; }
function slab(w,h,d,r,bevel,mat){ const g = new THREE.ExtrudeGeometry(roundedRect(w,h,r), {depth:d, bevelEnabled:true, bevelThickness:bevel, bevelSize:bevel, bevelSegments:5, curveSegments:18}); g.center(); return new THREE.Mesh(g, mat); }

// look = one entry of NRT.COLORS (body + band colours). Returns the parts, or nothing when WebGL is unavailable.
function buildHeroSuitcase(canvas, look){
  let renderer, scene, camera, rig, spinner, bodyMat, bandMat, tag, shadow;
  try { renderer = new THREE.WebGLRenderer({canvas, antialias:true, alpha:true, powerPreference:'high-performance'}); } catch(e){ return; }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputEncoding = THREE.sRGBEncoding;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = .97;
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(30, 1, .1, 100); camera.position.set(0,0,10);
  const pmrem = new THREE.PMREMGenerator(renderer), env = new THREE.Scene();
  env.add(new THREE.Mesh(new THREE.SphereGeometry(20,32,16), new THREE.MeshBasicMaterial({color:lin('#2a2016'), side:THREE.BackSide})));
  const soft = (c,w,h,x,y,z) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w,h), new THREE.MeshBasicMaterial({color:c, side:THREE.DoubleSide})); m.position.set(x,y,z); m.lookAt(0,0,0); env.add(m); };
  soft(new THREE.Color(3,2.9,2.7),12,4,0,9,5); soft(new THREE.Color(2.1,1.6,1.1),5,10,-11,2,3); soft(new THREE.Color(1.7,1.7,1.75),4,9,11,1,-2); soft(new THREE.Color(.8,.6,.4),12,2,0,-9,6);
  scene.environment = pmrem.fromScene(env, .035).texture;
  const key = new THREE.DirectionalLight(0xffffff,1.5); key.position.set(4,6,7); scene.add(key);
  const rim = new THREE.DirectionalLight(0xffc68a,1.4); rim.position.set(-6,3,-5); scene.add(rim);
  scene.add(new THREE.AmbientLight(0xffffff,.22));

  rig = new THREE.Group(); scene.add(rig);
  spinner = new THREE.Group(); rig.add(spinner);
  const bag = new THREE.Group(); bag.position.y = -.28; spinner.add(bag);
  const W = 1.5, H = 2.1, D = .6;
  bodyMat = new THREE.MeshPhysicalMaterial({color:lin(look.body), roughness:.44, metalness:.02, clearcoat:.45, clearcoatRoughness:.26});
  bandMat = new THREE.MeshStandardMaterial({color:lin(look.band), roughness:.55, metalness:.2});
  const metal = new THREE.MeshStandardMaterial({color:lin('#d9d2c6'), roughness:.22, metalness:1});
  const gold = new THREE.MeshStandardMaterial({color:lin('#e2bd84'), roughness:.25, metalness:1});
  const rubber = new THREE.MeshStandardMaterial({color:lin('#151210'), roughness:.8});
  bag.add(slab(W,H,D,.24,.07,bodyMat));
  const front = D/2 + .07;
  bag.add(slab(W+.035,H+.035,.05,.25,.035,bandMat));
  [-.46,-.16,.16,.46].forEach(x => [1,-1].forEach(side => { const rib = slab(.075,H*.74,.02,.035,.02,bodyMat); rib.position.set(x,0,side*(front+.008)); bag.add(rib); }));
  [[-1,1],[1,1],[-1,-1],[1,-1]].forEach(([sx,sy]) => { const g = new THREE.Mesh(new THREE.SphereGeometry(.13,20,14), bandMat); g.scale.set(1,1,1.9); g.position.set(sx*(W/2-.04), sy*(H/2-.04), 0); bag.add(g); });
  const badge = new THREE.Mesh(new THREE.CylinderGeometry(.11,.11,.025,40), gold); badge.rotation.x = Math.PI/2; badge.position.set(0,H*.36,front+.02); bag.add(badge);
  const top = H/2 + .07;
  const carry = new THREE.Mesh(new THREE.TorusGeometry(.22,.045,14,40,Math.PI), rubber); carry.position.set(0,top,.1); bag.add(carry);
  [-.22,.22].forEach(x => { const f = new THREE.Mesh(new THREE.BoxGeometry(.12,.05,.12), metal); f.position.set(x,top+.01,.1); bag.add(f); });
  [-.42,.42].forEach(x => { const post = new THREE.Mesh(new THREE.CylinderGeometry(.034,.034,.82,18), metal); post.position.set(x,top+.41,-.2); bag.add(post);
    const cap = new THREE.Mesh(new THREE.BoxGeometry(.14,.06,.14), bandMat); cap.position.set(x,top+.02,-.2); bag.add(cap); });
  const grip = new THREE.Mesh(new THREE.CylinderGeometry(.065,.065,1.0,24), rubber); grip.rotation.z = Math.PI/2; grip.position.set(0,top+.84,-.2); bag.add(grip);
  const bottom = -H/2 - .07;
  [[-1,1],[1,1],[-1,-1],[1,-1]].forEach(([sx,sz]) => { const hx = sx*(W/2-.16), hz = sz*(D/2-.06);
    const house = new THREE.Mesh(new THREE.CylinderGeometry(.08,.1,.1,20), bandMat); house.position.set(hx,bottom-.04,hz); bag.add(house);
    [-.045,.045].forEach(o => { const w = new THREE.Mesh(new THREE.CylinderGeometry(.085,.085,.05,24), rubber); w.rotation.z = Math.PI/2; w.position.set(hx+o,bottom-.15,hz); bag.add(w); }); });
  const tc = document.createElement('canvas'); tc.width = 512; tc.height = 300;
  const tex = new THREE.CanvasTexture(tc); tex.encoding = THREE.sRGBEncoding; tex.anisotropy = 4;
  const drawTag = () => { const c = tc.getContext('2d'); c.clearRect(0,0,512,300);
    c.fillStyle = '#f5ebdb'; c.beginPath(); if (c.roundRect) c.roundRect(6,6,500,288,40); else c.rect(6,6,500,288); c.fill();
    c.fillStyle = '#b07a45'; c.fillRect(6,220,500,74);
    c.fillStyle = '#100d0a'; c.font = '700 50px "Bodoni Moda", Georgia, serif'; c.textAlign = 'center'; c.fillText('NAOR ROYAL', 256, 112);
    c.font = '600 30px "IBM Plex Mono", monospace'; c.fillStyle = '#6e6255'; c.fillText('T O U R S', 256, 166);
    c.fillStyle = '#fffcf7'; c.font = '600 34px "IBM Plex Mono", monospace'; c.fillText('TLV  →  WORLD', 256, 270);
    c.fillStyle = '#100d0a'; c.beginPath(); c.arc(56,60,16,0,Math.PI*2); c.fill(); tex.needsUpdate = true; };
  drawTag(); if (document.fonts) document.fonts.ready.then(drawTag);
  tag = new THREE.Group(); tag.position.set(.2,top+.05,.14); bag.add(tag);
  const tagMesh = new THREE.Mesh(new THREE.PlaneGeometry(.5,.29), new THREE.MeshStandardMaterial({map:tex, side:THREE.DoubleSide, roughness:.6, transparent:true}));
  tagMesh.position.set(.18,-.3,.06); tagMesh.rotation.y = -.25; tag.add(tagMesh);
  const string = new THREE.Mesh(new THREE.CylinderGeometry(.008,.008,.24,6), rubber); string.position.set(.05,-.12,.03); string.rotation.z = .55; tag.add(string);
  const sc = document.createElement('canvas'); sc.width = sc.height = 256;
  const sg = sc.getContext('2d'), grd = sg.createRadialGradient(128,128,0,128,128,128);
  grd.addColorStop(0,'rgba(0,0,0,.55)'); grd.addColorStop(1,'rgba(0,0,0,0)'); sg.fillStyle = grd; sg.fillRect(0,0,256,256);
  shadow = new THREE.Mesh(new THREE.PlaneGeometry(2.6,1.1), new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(sc), transparent:true, depthWrite:false}));
  shadow.rotation.x = -Math.PI/2; shadow.position.y = -1.75; rig.add(shadow);
  return {renderer, scene, camera, rig, spinner, bodyMat, bandMat, tag, shadow};
}

NRT.lin = lin;
NRT.buildHeroSuitcase = buildHeroSuitcase;
})();
