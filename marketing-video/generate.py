#!/usr/bin/env python3
"""Generates the NAOR ROYAL TOURS launch film (HyperFrames project)."""
import json, os, html
import os
OUT = os.path.dirname(os.path.abspath(__file__))
W, H = 1080, 1920

FONTS = """
@font-face{font-family:'Frank Ruhl Libre';font-weight:500 900;font-display:block;src:url('assets/fonts/frankruhllibre-500-hebrew.woff2') format('woff2')}
@font-face{font-family:'Heebo';font-weight:300 900;font-display:block;src:url('assets/fonts/heebo-300-hebrew.woff2') format('woff2');unicode-range:U+0590-05FF,U+200C-2010,U+20AA,U+25CC,U+FB1D-FB4F}
@font-face{font-family:'Heebo';font-weight:300 900;font-display:block;src:url('assets/fonts/heebo-300-latin.woff2') format('woff2');unicode-range:U+0000-00FF,U+2000-206F,U+2190-21FF}
@font-face{font-family:'Bodoni Moda';font-weight:500 700;font-display:block;src:url('assets/fonts/bodonimoda-500-latin.woff2') format('woff2')}
@font-face{font-family:'IBM Plex Mono';font-weight:600;font-display:block;src:url('assets/fonts/ibmplexmono-600-latin.woff2') format('woff2')}
"""

BASE = """
#root{position:absolute;inset:0;overflow:hidden;direction:rtl;font-family:'Heebo',sans-serif;color:var(--white);
  --ink:#100d0a;--ink2:#1d1813;--cream:#f4ece0;--cream2:#e9dcc8;--white:#fffcf7;--caramel:#b07a45;--caramel-lt:#d8aa76;--gold:#e8c690;--muted:#6b5f52;--wa:#25d366;
  background:radial-gradient(120% 70% at 50% 38%,#6a3f22 0%,#2b1a10 48%,#0b0806 100%)}
.kick{position:absolute;top:220px;right:90px;left:90px;display:flex;gap:22px;align-items:center;color:var(--gold);font-size:32px;font-weight:500;letter-spacing:.02em}
.kick .n{font-family:'IBM Plex Mono',monospace;font-weight:600;font-size:28px;letter-spacing:.14em;direction:ltr;color:var(--caramel-lt)}
.kick .bar{width:64px;height:2px;background:var(--gold);opacity:.7}
.ttl{position:absolute;top:278px;right:90px;left:60px;font-family:'Frank Ruhl Libre',serif;font-weight:900;font-size:90px;line-height:1.0;color:var(--white);letter-spacing:-.01em}
.ttl em{font-style:normal;background:linear-gradient(100deg,#f6e2bd,#d8aa76 60%,#b07a45);-webkit-background-clip:text;background-clip:text;color:transparent}
.cursor{position:absolute;left:0;top:0;width:92px;height:92px;z-index:50;filter:drop-shadow(0 10px 18px rgba(0,0,0,.45))}
.cursor svg{width:100%;height:100%}
.grain{position:absolute;inset:0;pointer-events:none;opacity:.05;background-image:repeating-radial-gradient(circle at 30% 30%,#fff 0 1px,transparent 1px 3px)}
"""

CURSOR = '<svg viewBox="0 0 32 32"><path d="M6 3l19 12.5-8.3 1.6 4.9 9.3-3.7 1.9-4.9-9.4L6 25z" fill="#fffcf7" stroke="#100d0a" stroke-width="1.6" stroke-linejoin="round"/></svg>'
WA = '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm0 18.2c-1.5 0-3-.4-4.3-1.2l-.3-.2-3 .8.8-2.9-.2-.3A8.2 8.2 0 1 1 12 20.2zm4.5-6.1c-.2-.1-1.5-.7-1.7-.8-.2-.1-.4-.1-.6.1l-.8 1c-.1.2-.3.2-.5.1a6.7 6.7 0 0 1-3.3-2.9c-.3-.4.2-.4.7-1.3.1-.2 0-.3 0-.4l-.8-1.8c-.2-.5-.4-.4-.6-.4h-.5a1 1 0 0 0-.7.3 3 3 0 0 0-.9 2.2c0 1.3.9 2.5 1 2.7.1.2 1.8 2.8 4.4 3.9 1.6.7 2.3.8 3.1.6.5-.1 1.5-.6 1.7-1.2.2-.6.2-1.1.2-1.2-.1-.1-.3-.2-.5-.3z"/></svg>'

ICONS = {
  'passport':'<rect x="5.5" y="2.5" width="13" height="19" rx="2"/><circle cx="12" cy="10" r="3.2"/><path d="M8.8 10h6.4M12 6.8c1.3 1.6 1.3 4.8 0 6.4M12 6.8c-1.3 1.6-1.3 4.8 0 6.4M9 17h6"/>',
  'sunscreen':'<path d="M9 8h6v12a1.5 1.5 0 0 1-1.5 1.5h-3A1.5 1.5 0 0 1 9 20z"/><path d="M10 8V5h4v3M10.5 3h3M11 13h2M11 16h2"/>',
  'hat':'<path d="M2.5 15.5c2.5 2 16.5 2 19 0"/><path d="M6.5 15.5c0-4.5 2.5-8 5.5-8s5.5 3.5 5.5 8"/><path d="M7 13.2h10"/>',
  'swim':'<path d="M7 3v3.5c0 2 2 3.5 5 3.5s5-1.5 5-3.5V3"/><path d="M5 12.5h14l-2.5 7.5h-3L12 16l-1.5 4h-3z"/>',
  'kit':'<rect x="3" y="8" width="18" height="12" rx="3"/><path d="M8.5 8V6.5a3.5 3.5 0 0 1 7 0V8M12 11.5v5M9.5 14h5"/>',
  'charger':'<path d="M9 2.5v4.5M15 2.5v4.5"/><path d="M6.5 7h11v4a5.5 5.5 0 0 1-11 0z"/><path d="M12 16.5v5"/>',
  'bottle':'<path d="M10 2.5h4v2.5h-4z"/><path d="M9 5h6l1 3v12a1.8 1.8 0 0 1-1.8 1.8H9.8A1.8 1.8 0 0 1 8 20V8z"/><path d="M8.3 12h7.4"/>',
  'coat':'<path d="M8 3l4 3 4-3 4 3v15H4V6z"/><path d="M12 6v15M10 11h.01M10 15h.01"/>',
  'layers':'<path d="M12 3 2.5 8 12 13l9.5-5z"/><path d="M2.5 12.3 12 17.3l9.5-5"/><path d="M2.5 16.5 12 21.5l9.5-5"/>',
  'beanie':'<path d="M5 15a7 7 0 0 1 14 0"/><rect x="4" y="15" width="16" height="4.5" rx="1.5"/><circle cx="12" cy="5.2" r="1.8"/>',
  'boots':'<path d="M6.5 3h6v9.5l6.2 2.8a2 2 0 0 1 1.3 1.9V20H4v-3.5l2.5-2z"/><path d="M4 18h16"/>',
  'powerbank':'<rect x="6" y="2.5" width="12" height="19" rx="2.5"/><path d="M12.6 7.5 10 12.3h4l-2.6 4.7"/>',
}
def icon(k, cls='ic'):
    return f'<svg class="{cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">{ICONS[k]}</svg>'

def chars(text, cls):
    """Per-character spans so typing is a function of timeline time."""
    return ''.join(f'<span class="{cls}">{html.escape(c) if c != " " else "&nbsp;"}</span>' for c in text)

def scene(cid, dur, css, body, js):
    return f"""<template>
  <style>{FONTS}{BASE}{css}</style>
  <div id="root" data-composition-id="{cid}" data-width="{W}" data-height="{H}" data-start="0" data-duration="{dur}">
{body}
    <div class="grain" data-layout-ignore></div>
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
{js}
    window.__timelines["{cid}"] = tl;
  </script>
</template>
"""

def kick(n, label):
    return f'<div class="kick" id="{{p}}-kick"><span class="n">{n}</span><span class="bar"></span><span>{label}</span></div>'

def head_js(p):
    return f"""    tl.fromTo("#{p}-kick", {{opacity:0, x:40}}, {{opacity:1, x:0, duration:.45, ease:"power3.out"}}, 0.05);
    tl.fromTo("#{p}-ttl .w", {{opacity:0, y:70, rotateX:-50}}, {{opacity:1, y:0, rotateX:0, duration:.6, ease:"power4.out", stagger:.07}}, 0.12);
"""
def ttl(p, words):
    # words: list of (text, gold?) ; '\n' forces a line break
    out = []
    for t, g in words:
        if t == '\n': out.append('<br>'); continue
        inner = f'<em>{t}</em>' if g else t
        out.append(f'<span class="w" style="display:inline-block">{inner}</span> ')
    return f'<h1 class="ttl" id="{p}-ttl" style="perspective:800px">{"".join(out)}</h1>'

def exit_js(p, at):
    return f"""    tl.to("#{p}-wrap", {{opacity:0, y:-120, scale:.96, duration:.32, ease:"power3.in"}}, {at});
"""

scenes = {}

# ---------------- S1 HOOK ----------------
scenes['hook'] = (3.5, """
#h-img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;transform-origin:50% 60%}
#h-shade{position:absolute;inset:0;background:linear-gradient(180deg,rgba(11,8,6,.82) 0%,rgba(11,8,6,.35) 38%,rgba(11,8,6,.25) 55%,rgba(11,8,6,.92) 100%)}
#h-top{position:absolute;top:250px;right:90px;left:90px;color:var(--gold);font-size:34px;font-weight:500;display:flex;align-items:center;gap:20px}
#h-top .mark{font-family:'Bodoni Moda',serif;font-weight:700;letter-spacing:.18em;font-size:30px;direction:ltr}
#h-top .bar{width:70px;height:2px;background:var(--gold)}
#h-h{position:absolute;top:340px;right:84px;left:60px;font-family:'Frank Ruhl Libre',serif;font-weight:900;font-size:168px;line-height:1.0;color:var(--white);text-shadow:0 8px 40px rgba(0,0,0,.45)}
#h-h .l{display:block}
#h-h em{font-style:normal;background:linear-gradient(100deg,#f8e6c4,#e8c690 45%,#b07a45);-webkit-background-clip:text;background-clip:text;color:transparent}
#h-sub{position:absolute;top:1010px;right:90px;left:90px;font-family:'Frank Ruhl Libre',serif;font-weight:700;font-size:96px;line-height:1.05;color:var(--white)}
#h-sub .dash{color:var(--gold)}
#h-sub2{position:absolute;top:1140px;right:92px;left:90px;font-size:40px;font-weight:400;color:rgba(255,248,238,.85)}
""", """
    <div id="h-wrap" style="position:absolute;inset:0">
      <img id="h-img" src="assets/img/rho-tall.webp" alt="">
      <div id="h-shade"></div>
      <div id="h-top"><span class="bar"></span><span>האתר החדש של</span><span class="mark">NAOR ROYAL TOURS</span></div>
      <h1 id="h-h"><span class="l" id="h-l1">אתם רק</span><span class="l" id="h-l2">אורזים <em>מזוודה.</em></span></h1>
      <div id="h-sub" data-layout-allow-overflow><span id="h-s1" style="display:inline-block">כל השאר</span> <span class="dash" id="h-s2" style="display:inline-block">— אוטומטי.</span></div>
      <div id="h-sub2">5 אוטומציות · 24/7</div>
    </div>
""", """
    tl.fromTo("#h-img", {scale:1.12}, {scale:1.22, duration:3.5, ease:"none"}, 0);
    tl.fromTo("#h-l1", {y:18}, {y:0, duration:.9, ease:"power3.out"}, 0);
    tl.fromTo("#h-l2", {y:30}, {y:0, duration:1.0, ease:"power3.out"}, 0);
    tl.fromTo("#h-top", {opacity:.0, x:30}, {opacity:1, x:0, duration:.5, ease:"power3.out"}, .25);
    tl.fromTo("#h-s1", {opacity:0, y:60, filter:"blur(10px)"}, {opacity:1, y:0, filter:"blur(0px)", duration:.45, ease:"power4.out"}, 1.25);
    tl.fromTo("#h-s2", {opacity:0, y:60, filter:"blur(10px)"}, {opacity:1, y:0, filter:"blur(0px)", duration:.45, ease:"power4.out"}, 1.55);
    tl.fromTo("#h-sub2", {opacity:0, y:20}, {opacity:1, y:0, duration:.4, ease:"power3.out"}, 1.7);
""" + exit_js('h', 3.15))

# ---------------- S2 FORM ----------------
CH = ['זוגית','משפחה','שופינג','בטן־גב','טיולים','כשרה','שבת','יוקרה','חיי לילה']
PICK = [1, 3, 5]
chips_html = ''.join(f'<div class="chip" id="f-chip{i}"><span class="fill"></span><span class="t">{c}</span></div>' for i, c in enumerate(CH))
def field(fid, label, val, extra=''):
    return f'<div class="fld {extra}"><div class="lbl">{label}</div><div class="inp" id="f-{fid}"><span class="txt">{chars(val, "c")}</span><span class="caret"></span></div></div>'
scenes['form'] = (6.0, """
#f-card{position:absolute;top:500px;left:70px;right:70px;background:var(--white);border-radius:44px;padding:44px 44px 40px;color:var(--ink);box-shadow:0 40px 90px rgba(0,0,0,.5)}
.row{display:flex;gap:22px;margin-bottom:22px}
.fld{flex:1}
.lbl{font-size:28px;font-weight:700;color:var(--ink);margin-bottom:10px}
.inp{height:86px;border-radius:22px;background:#f1e9dd;border:2px solid transparent;display:flex;align-items:center;padding:0 26px;font-size:38px;font-weight:500;color:var(--ink);position:relative}
.inp.ltr .txt{direction:ltr}
.caret{width:3px;height:42px;background:var(--caramel);margin-right:4px;opacity:0}
.c{opacity:0}
.chips-l{font-size:28px;font-weight:700;margin:6px 0 14px}
.chips{display:flex;flex-wrap:wrap;gap:14px}
.chip{position:relative;overflow:hidden;border:2px solid #d9cdbb;border-radius:999px;padding:12px 26px;font-size:30px;font-weight:500;color:var(--ink)}
.chip .fill{position:absolute;inset:0;background:var(--ink);border-radius:999px;transform:scale(0);opacity:1}
.chip .t{position:relative}
#f-send{margin-top:30px;height:110px;border-radius:999px;background:var(--ink);display:flex;align-items:center;justify-content:space-between;padding:0 18px 0 40px;color:var(--white);font-size:38px;font-weight:700;position:relative;overflow:hidden}
#f-send .wa{width:80px;height:80px;border-radius:50%;background:var(--wa);display:grid;place-items:center;color:#fff}
#f-send .wa svg{width:46px;height:46px}
#f-send .t{margin-right:14px}
#f-ripple{position:absolute;left:58px;top:55px;width:60px;height:60px;margin:-30px;border-radius:50%;background:var(--wa)}
""", f"""
    <div id="f-wrap" style="position:absolute;inset:0">
      {kick('STEP 1 / 3','ממלאים את הטופס החכם').replace('{p}','f')}
      {ttl('f', [('ממלאים',False),('פעם',False),('\n',False),('אחת.',True)])}
      <div id="f-card">
        <div class="row">{field('name','איך קוראים לכם?','דנה')}{field('dest','לאן?','רודוס')}</div>
        <div class="row">{field('people','כמה נוסעים?','2 מבוגרים + 2 ילדים')}</div>
        <div class="row">{field('from','יציאה','14/07/2027','ltr')}{field('to','חזרה','21/07/2027','ltr')}</div>
        <div class="chips-l">מה חשוב לכם?</div>
        <div class="chips">{chips_html}</div>
        <div id="f-send"><span class="t">שלחו לי בוואטסאפ</span><span class="wa">{WA}</span><span id="f-ripple"></span></div>
      </div>
      <div class="cursor" id="f-cur">{CURSOR}</div>
    </div>
""", head_js('f') + """
    tl.fromTo("#f-card .row, #f-card .chips-l, #f-card .chips, #f-send", {opacity:0, y:30}, {opacity:1, y:0, duration:.35, ease:"power3.out", stagger:.06}, .05);
    tl.set("#f-ripple", {scale:0, opacity:0}, 0);
    // cursor path (absolute frame coords)
    tl.fromTo("#f-cur", {x:1100, y:1500}, {x:700, y:650, duration:.55, ease:"power3.inOut"}, .75);
    const at = (sel) => { let e = document.querySelector(sel), x = 0, y = 0; const w0 = e.offsetWidth, h0 = e.offsetHeight; const wrap = document.querySelector('#f-wrap'); while (e && e !== wrap) { x += e.offsetLeft; y += e.offsetTop; e = e.offsetParent; } return {cx: x + w0 / 2, cy: y + h0 / 2}; };
    const typeIn = (id, t0, dur) => {
      const box = "#f-" + id, n = document.querySelectorAll(box + " .c").length;
      tl.to(box, {borderColor:"#b07a45", duration:.12}, t0 - .05);
      tl.fromTo(box + " .caret", {opacity:0}, {opacity:1, duration:.05}, t0 - .05);
      tl.fromTo(box + " .c", {opacity:0}, {opacity:1, duration:.01, stagger: dur / n}, t0);
      tl.to(box, {borderColor:"rgba(0,0,0,0)", duration:.12}, t0 + dur + .1);
      tl.to(box + " .caret", {opacity:0, duration:.05}, t0 + dur + .1);
    };
    tl.to("#f-cur", {scale:.85, duration:.08, yoyo:true, repeat:1}, 1.3);
    typeIn('name', 1.4, .3);
    tl.to("#f-cur", {x:260, y:650, duration:.35, ease:"power3.inOut"}, 1.55);
    typeIn('dest', 1.95, .35);
    tl.to("#f-cur", {x:620, y:860, duration:.3, ease:"power3.inOut"}, 2.25);
    typeIn('people', 2.5, .55);
    typeIn('from', 3.05, .3);
    typeIn('to', 3.25, .3);
""" + ''.join(f"""
    tl.to("#f-cur", {{x:() => at('#f-chip{i}').cx - 14, y:() => at('#f-chip{i}').cy - 8, duration:.28, ease:"power3.inOut"}}, {3.55 + k*.42:.2f});
    tl.to("#f-cur", {{scale:.85, duration:.07, yoyo:true, repeat:1}}, {3.83 + k*.42:.2f});
    tl.fromTo("#f-chip{i} .fill", {{scale:0}}, {{scale:1.2, duration:.25, ease:"power3.out"}}, {3.86 + k*.42:.2f});
    tl.to("#f-chip{i} .t", {{color:"#fffcf7", duration:.1}}, {3.88 + k*.42:.2f});
    tl.to("#f-chip{i}", {{borderColor:"#100d0a", duration:.1}}, {3.86 + k*.42:.2f});
""" for k, i in enumerate(PICK)) + """
    tl.to("#f-cur", {x:() => at('#f-send .wa').cx - 14, y:() => at('#f-send').cy - 8, duration:.35, ease:"power3.inOut"}, 4.95);
    tl.to("#f-cur", {scale:.85, duration:.07, yoyo:true, repeat:1}, 5.32);
    tl.to("#f-send", {scale:.96, duration:.08, yoyo:true, repeat:1}, 5.34);
    tl.to("#f-ripple", {scale:24, opacity:.9, duration:.4, ease:"power2.out"}, 5.36);
""" + exit_js('f', 5.66))

# ---------------- S3 WHATSAPP ----------------
LEAD = 'NRT-261110-3441'   # same lead ID the real site produced in the recording
MSG = ['היי נאור, אשמח לתכנן חופשה:', 'שם: דנה', 'יעד: רודוס', 'נוסעים: 2 מבוגרים + 2 ילדים',
       'תאריכים: 14/07/2027 עד 21/07/2027', 'חשוב לנו: משפחה, בטן־גב, כשרה', '', f'מספר פנייה: <b id="w-id">{LEAD}</b>']
lines = ''.join(f'<div class="ml" id="w-l{i}">{t or "&nbsp;"}</div>' for i, t in enumerate(MSG))
scenes['whatsapp'] = (5.5, """
#w-chat{position:absolute;top:500px;left:70px;right:70px;height:790px;border-radius:44px;overflow:hidden;background:#efeae2;box-shadow:0 40px 90px rgba(0,0,0,.5)}
#w-head{height:120px;background:#0b6b5d;display:flex;align-items:center;gap:22px;padding:0 34px;color:#fff}
#w-av{width:78px;height:78px;border-radius:50%;background:linear-gradient(135deg,#e8c690,#b07a45);display:grid;place-items:center;font-family:'Bodoni Moda',serif;font-weight:700;font-size:36px;color:#100d0a}
#w-name{font-size:36px;font-weight:700;line-height:1.1}
#w-name small{display:block;font-size:28px;font-weight:400;opacity:.85}
#w-body{position:relative;padding:40px 34px;height:700px;background-image:radial-gradient(rgba(0,0,0,.04) 1.5px,transparent 1.5px);background-size:26px 26px}
#w-bub{position:absolute;left:34px;top:40px;width:800px;background:#d9fdd3;border-radius:28px 28px 28px 6px;padding:28px 32px 54px;color:#111b21;font-size:33px;line-height:1.5;box-shadow:0 2px 2px rgba(0,0,0,.08);transform-origin:0% 100%}
#w-bub b{font-family:'IBM Plex Mono',monospace;font-weight:600;font-size:31px;direction:ltr;unicode-bidi:isolate;background:rgba(232,198,144,0);border-radius:8px;padding:0 6px}
#w-meta{position:absolute;left:26px;bottom:12px;font-size:28px;color:#667781;direction:ltr}
#w-meta .tk{color:#53bdeb;margin-left:6px}
#w-ticket{position:absolute;top:1095px;left:120px;right:120px;height:190px;border-radius:30px;background:linear-gradient(120deg,#f6e2bd,#e8c690 55%,#d8aa76);color:#100d0a;display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 30px 70px rgba(0,0,0,.55)}
#w-ticket .k{font-size:30px;font-weight:700;letter-spacing:.02em}
#w-ticket .v{font-family:'IBM Plex Mono',monospace;font-weight:600;font-size:64px;letter-spacing:.06em;direction:ltr;line-height:1.15}
#w-ticket:before,#w-ticket:after{content:"";position:absolute;top:50%;width:40px;height:40px;margin-top:-20px;border-radius:50%;background:#2b1a10}
#w-ticket:before{left:-20px}#w-ticket:after{right:-20px}
""", f"""
    <div id="w-wrap" style="position:absolute;inset:0">
      {kick('STEP 2 / 3','וואטסאפ נפתח עם הודעה מוכנה').replace('{p}','w')}
      {ttl('w', [('ההודעה',False),('\n',False),('נכתבת',False),('לבד.',True)])}
      <div id="w-chat">
        <div id="w-head"><div id="w-av">N</div><div id="w-name">נאור · NAOR ROYAL TOURS<small>זמין עכשיו</small></div></div>
        <div id="w-body">
          <div id="w-bub">{lines}<div id="w-meta">10:31 <span class="tk">✓✓</span></div></div>
        </div>
      </div>
      <div id="w-ticket" data-layout-allow-overlap><div class="k">כל פנייה מקבלת מספר מעקב</div><div class="v">{LEAD}</div></div>
    </div>
""", head_js('w') + """
    tl.fromTo("#w-chat", {opacity:0, y:160}, {opacity:1, y:0, duration:.55, ease:"power4.out"}, .2);
    tl.fromTo("#w-bub", {scale:.6, opacity:0}, {scale:1, opacity:1, duration:.4, ease:"back.out(1.6)"}, .6);
    tl.fromTo("#w-bub .ml", {opacity:0, x:-24}, {opacity:1, x:0, duration:.22, ease:"power2.out", stagger:.2}, .7);
    tl.fromTo("#w-meta", {opacity:0}, {opacity:1, duration:.2}, 2.3);
    tl.to("#w-id", {backgroundColor:"rgba(232,198,144,1)", duration:.25}, 2.55);
    tl.fromTo("#w-ticket", {opacity:0, y:-260, scale:.5}, {opacity:1, y:0, scale:1, duration:.55, ease:"back.out(1.5)"}, 2.75);
""" + exit_js('w', 5.16))

# ---------------- S4 STATUS ----------------
scenes['status'] = (5.0, """
#s-panel{position:absolute;top:500px;left:70px;right:70px;height:760px;border-radius:44px;background:rgba(255,246,232,.07);border:2px solid rgba(255,236,210,.18);overflow:hidden}
.st{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:52px}
.clock{font-family:'IBM Plex Mono',monospace;font-weight:600;font-size:150px;color:var(--white);direction:ltr;letter-spacing:.02em;line-height:1}
.day{font-size:46px;font-weight:500;color:var(--gold);margin-bottom:-30px}
.pill{display:flex;align-items:center;gap:26px;padding:30px 44px;border-radius:999px;background:var(--white);color:var(--ink);box-shadow:0 20px 50px rgba(0,0,0,.35)}
.pill .dot{width:30px;height:30px;border-radius:50%;flex:none}
.pill .t{font-size:44px;font-weight:800;line-height:1.15}
.pill .s{font-size:30px;font-weight:400;color:var(--muted)}
#s-on .dot{background:var(--wa);box-shadow:0 0 0 10px rgba(37,211,102,.22)}
#s-sh .pill{background:linear-gradient(120deg,#f6e2bd,#e8c690)}
#s-sh .dot{background:#b07a45;box-shadow:0 0 0 10px rgba(176,122,69,.25)}
.cand{display:flex;gap:40px;margin-bottom:-14px}
.cand i{display:block;width:22px;height:110px;border-radius:6px;background:linear-gradient(#fffcf7,#e9dcc8);position:relative}
.cand i:before{content:"";position:absolute;left:50%;top:-46px;width:26px;height:40px;margin-left:-13px;border-radius:50% 50% 50% 50%/60% 60% 40% 40%;background:radial-gradient(circle at 50% 70%,#fff3c4,#e8a23c 60%,rgba(232,162,60,0) 72%)}
#s-foot{position:absolute;top:1290px;left:90px;right:90px;text-align:center;font-size:32px;color:rgba(255,248,238,.8)}
""", f"""
    <div id="s-wrap" style="position:absolute;inset:0">
      {kick('STEP 3 / 3','אני חוזר אליכם עם אפשרויות').replace('{p}','s')}
      {ttl('s', [('יודע',False),('מתי',False),('\n',False),('אני',False),('זמין.',True)])}
      <div id="s-panel">
        <div class="st" id="s-on"><div class="day">יום ראשון</div><div class="clock">10:30</div>
          <div class="pill"><span class="dot"></span><div><div class="t">זמין עכשיו בוואטסאפ</div><div class="s">מענה אישי בדרך כלל תוך זמן קצר</div></div></div></div>
        <div class="st" id="s-sh"><div class="cand"><i></i><i></i></div><div class="day">יום שישי</div><div class="clock">16:00</div>
          <div class="pill"><span class="dot"></span><div><div class="t">שבת שלום</div><div class="s">נחזור אליכם במוצאי שבת</div></div></div></div>
      </div>
      <div id="s-foot">מתעדכן לבד לפי שעון ישראל</div>
    </div>
""", head_js('s') + """
    tl.fromTo("#s-panel", {opacity:0, y:140}, {opacity:1, y:0, duration:.55, ease:"power4.out"}, .2);
    tl.set("#s-sh", {opacity:0}, 0);
    tl.fromTo("#s-on .pill", {scale:.7, opacity:0}, {scale:1, opacity:1, duration:.4, ease:"back.out(1.7)"}, .65);
    tl.to("#s-on", {opacity:0, y:-80, duration:.3, ease:"power3.in"}, 2.55);
    tl.fromTo("#s-sh", {opacity:0, y:90}, {opacity:1, y:0, duration:.4, ease:"power3.out"}, 2.8);
    tl.fromTo("#s-sh .pill", {scale:.7}, {scale:1, duration:.4, ease:"back.out(1.7)"}, 2.9);
    tl.fromTo("#s-sh .cand i", {opacity:0, y:20}, {opacity:1, y:0, duration:.3, stagger:.12}, 3.05);
    tl.fromTo("#s-foot", {opacity:0}, {opacity:1, duration:.3}, 1.2);
""" + exit_js('s', 4.66))

# ---------------- S5 PACKING ----------------
SUMMER = [('passport','דרכון וביטוח נסיעות'),('sunscreen','קרם הגנה SPF 30+'),('hat','כובע ומשקפי שמש'),('swim','בגד ים'),('kit','טואלטיקה ותרופות'),('charger','מטען ומתאם חשמל'),('bottle','בקבוק מים רב־פעמי')]
WINTER = [('passport','דרכון וביטוח נסיעות'),('coat','מעיל חם ועמיד למים'),('layers','ביגוד תרמי'),('beanie','כובע צמר, כפפות וצעיף'),('boots','נעליים אטומות למים'),('kit','טואלטיקה ותרופות'),('powerbank','מטען וסוללה ניידת')]
def plist(pid, items):
    return f'<div class="list" id="{pid}">' + ''.join(f'<div class="it"><span class="ib">{icon(k)}</span><span class="tx">{html.escape(t)}</span><span class="ck">✓</span></div>' for k, t in items) + '</div>'
scenes['packing'] = (5.0, """
#p-tog{position:absolute;top:510px;left:150px;right:150px;height:104px;border-radius:999px;background:rgba(0,0,0,.35);border:2px solid rgba(255,236,210,.18);display:flex;align-items:center}
#p-knob{position:absolute;top:8px;right:8px;width:calc(50% - 8px);height:84px;border-radius:999px;background:var(--gold)}
#p-tog .o{position:relative;flex:1;text-align:center;font-size:36px;font-weight:700}
#p-o1{color:var(--ink)}#p-o2{color:rgba(255,248,238,.75)}
#p-box{position:absolute;top:660px;left:70px;right:70px;height:640px}
.list{position:absolute;inset:0;display:flex;flex-direction:column;gap:10px}
.it{height:82px;display:flex;align-items:center;gap:26px;padding:0 26px;border-radius:24px;background:rgba(255,246,232,.07);border:1.5px solid rgba(255,236,210,.14)}
.ib{width:60px;height:60px;border-radius:50%;border:2px solid rgba(232,198,144,.5);display:grid;place-items:center;color:var(--gold);flex:none}
.ic{width:34px;height:34px}
.tx{flex:1;font-size:36px;font-weight:500;color:var(--white)}
.ck{width:46px;height:46px;border-radius:50%;background:var(--gold);color:var(--ink);display:grid;place-items:center;font-size:28px;font-weight:900}
""", f"""
    <div id="p-wrap" style="position:absolute;inset:0">
      {kick('04','מדריך אריזה חכם').replace('{p}','p')}
      {ttl('p', [('מה',False),('לארוז?',False),('\n',False),('לפי',False),('העונה.',True)])}
      <div id="p-tog"><span id="p-knob"></span><span class="o" id="p-o1">☀ קיץ</span><span class="o" id="p-o2">❄ חורף</span></div>
      <div id="p-box">{plist('p-sum', SUMMER)}{plist('p-win', WINTER)}</div>
      <div class="cursor" id="p-cur">{CURSOR}</div>
    </div>
""", head_js('p') + """
    tl.fromTo("#p-tog", {opacity:0, y:60}, {opacity:1, y:0, duration:.45, ease:"power3.out"}, .2);
    tl.set("#p-win .it", {opacity:0, x:-120}, 0);
    tl.fromTo("#p-sum .it", {opacity:0, x:120}, {opacity:1, x:0, duration:.35, ease:"power3.out", stagger:.13}, .45);
    tl.fromTo("#p-sum .ck", {scale:0}, {scale:1, duration:.25, ease:"back.out(2.5)", stagger:.13}, .7);
    tl.fromTo("#p-cur", {x:1100, y:1500}, {x:260, y:540, duration:.5, ease:"power3.inOut"}, 1.9);
    tl.to("#p-cur", {scale:.85, duration:.07, yoyo:true, repeat:1}, 2.45);
    tl.to("#p-knob", {x:-382, duration:.4, ease:"power3.inOut"}, 2.5);
    tl.to("#p-o1", {color:"rgba(255,248,238,.75)", duration:.2}, 2.6);
    tl.to("#p-o2", {color:"#100d0a", duration:.2}, 2.6);
    tl.to("#p-cur", {x:1150, y:1700, duration:.5, ease:"power3.in"}, 2.75);
    tl.to("#p-sum .it", {opacity:0, x:-120, duration:.25, ease:"power3.in", stagger:.05}, 2.55);
    tl.to("#p-win .it", {opacity:1, x:0, duration:.35, ease:"power3.out", stagger:.11}, 2.95);
    tl.fromTo("#p-win .ck", {scale:0}, {scale:1, duration:.25, ease:"back.out(2.5)", stagger:.11}, 3.15);
""" + exit_js('p', 4.66))

# ---------------- S6 EXTRAS ----------------
EXTRA = [
  ('<path d="M12 3v12M7 10l5 5 5-5"/><path d="M4 17v3h16v-3"/>', 'נפתח מהר גם בלי קליטה', 'נשמר בטלפון כמו אפליקציה'),
  ('<path d="M4 12l5 5L20 6"/>', 'בודק את הפרטים לפני שליחה', 'שם, טלפון ותאריכים — בלי טעויות'),
  ('<path d="M12 3l8 3v6c0 4.5-3.4 8.2-8 9-4.6-.8-8-4.5-8-9V6z"/><path d="M9 12l2 2 4-4"/>', 'חוסם בוטים וספאם', 'רק פניות אמיתיות מגיעות אליי'),
  ('<circle cx="12" cy="4.5" r="1.8"/><path d="M5 8.5l7 1.5 7-1.5M12 10v5M12 15l-3 6M12 15l3 6"/>', 'תפריט נגישות מובנה', 'כל אחד יכול לתכנן חופשה'),
]
rows = ''.join(f'<div class="xr" id="x-r{i}"><span class="xi"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">{p}</svg></span><span class="xt"><b>{t}</b><small>{s}</small></span></div>' for i, (p, t, s) in enumerate(EXTRA))
scenes['extras'] = (4.0, """
#x-list{position:absolute;top:530px;left:70px;right:70px;display:flex;flex-direction:column;gap:26px}
.xr{display:flex;align-items:center;gap:30px;padding:30px 34px;border-radius:34px;background:var(--white);color:var(--ink);box-shadow:0 24px 60px rgba(0,0,0,.4)}
.xi{width:110px;height:110px;border-radius:30px;background:var(--ink);color:var(--gold);display:grid;place-items:center;flex:none}
.xi svg{width:56px;height:56px}
.xt b{display:block;font-size:42px;font-weight:800;line-height:1.2}
.xt small{display:block;font-size:31px;font-weight:400;color:var(--muted);margin-top:4px}
""", f"""
    <div id="x-wrap" style="position:absolute;inset:0">
      {kick('05','מאחורי הקלעים').replace('{p}','x')}
      {ttl('x', [('ועוד',False),('קצת',False),('\n',False),('קסם.',True)])}
      <div id="x-list">{rows}</div>
    </div>
""", head_js('x') + """
    tl.fromTo("#x-list .xr", {opacity:0, x:200, rotate:-2}, {opacity:1, x:0, rotate:0, duration:.45, ease:"power4.out", stagger:.5}, .35);
    tl.fromTo("#x-list .xi", {scale:.4}, {scale:1, duration:.4, ease:"back.out(2)", stagger:.5}, .45);
""" + exit_js('x', 3.66))

# ---------------- S7 END ----------------
scenes['endcard'] = (3 * (60 / 128) * 4, """
#e-img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
#e-shade{position:absolute;inset:0;background:linear-gradient(180deg,rgba(11,8,6,.9),rgba(11,8,6,.6) 45%,rgba(11,8,6,.95))}
#e-mark{position:absolute;top:400px;left:0;right:0;text-align:center;direction:ltr}
#e-word{font-family:'Bodoni Moda',serif;font-weight:700;font-size:66px;letter-spacing:.12em;white-space:nowrap;color:var(--white);line-height:1.1}
#e-tag{margin-top:22px;font-family:'Bodoni Moda',serif;font-weight:500;font-size:36px;letter-spacing:.42em;color:var(--gold)}
#e-line{width:280px;height:2px;margin:36px auto 0;background:var(--gold);transform-origin:50% 50%}
#e-h{position:absolute;top:660px;left:60px;right:60px;text-align:center;font-family:'Frank Ruhl Libre',serif;font-weight:900;font-size:92px;line-height:1.08;color:var(--white)}
#e-h em{font-style:normal;background:linear-gradient(100deg,#f8e6c4,#e8c690 45%,#b07a45);-webkit-background-clip:text;background-clip:text;color:transparent}
#e-cta{position:absolute;top:930px;left:150px;right:150px;height:124px;border-radius:999px;background:var(--white);color:var(--ink);display:flex;align-items:center;justify-content:space-between;padding:0 20px 0 0;overflow:hidden}
#e-cta .t{position:relative;font-size:40px;font-weight:800;margin-right:46px;z-index:2}
#e-cta .p{position:relative;width:88px;height:88px;border-radius:50%;background:var(--caramel);color:#fff;display:grid;place-items:center;font-size:58px;font-weight:300;margin-left:18px;z-index:2}
#e-fill{position:absolute;inset:0;background:linear-gradient(120deg,#f6e2bd,#e8c690);transform-origin:50% 100%;z-index:1}
#e-ph{position:absolute;top:1100px;left:0;right:0;display:flex;justify-content:center;align-items:center;gap:18px;font-size:44px;font-weight:700;color:var(--white)}
#e-ph .wa{width:62px;height:62px;border-radius:50%;background:var(--wa);display:grid;place-items:center;color:#fff}
#e-ph .wa svg{width:38px;height:38px}
#e-ph .n{font-family:'IBM Plex Mono',monospace;font-weight:600;direction:ltr;letter-spacing:.04em}
""", f"""
    <div id="e-wrap" style="position:absolute;inset:0">
      <img id="e-img" src="assets/img/fco-tall.webp" alt="">
      <div id="e-shade"></div>
      <div id="e-mark"><div id="e-word">NAOR ROYAL TOURS</div><div id="e-tag">TRAVEL LIKE ROYALTY</div><div id="e-line"></div></div>
      <h2 id="e-h">אתם רק אורזים<br><em>מזוודה.</em></h2>
      <div id="e-cta"><span id="e-fill"></span><span class="t">בואו נתכנן את החופשה שלי</span><span class="p">+</span></div>
      <div id="e-ph"><span class="wa">{WA}</span><span>וואטסאפ</span><span class="n">053-623-3816</span></div>
      <div class="cursor" id="e-cur">{CURSOR}</div>
    </div>
""", """
    tl.fromTo("#e-img", {scale:1.25}, {scale:1.1, duration:4.5, ease:"power2.out"}, 0);
    tl.fromTo("#e-word", {opacity:0, scale:1.25, filter:"blur(12px)"}, {opacity:1, scale:1, filter:"blur(0px)", duration:.5, ease:"power4.out"}, .0);
    tl.fromTo("#e-tag", {opacity:0, y:20}, {opacity:1, y:0, duration:.35, ease:"power3.out"}, .47);
    tl.fromTo("#e-line", {scaleX:0}, {scaleX:1, duration:.4, ease:"power3.inOut"}, .47);
    tl.fromTo("#e-h", {opacity:0, y:50}, {opacity:1, y:0, duration:.4, ease:"power3.out"}, .94);
    tl.fromTo("#e-cta", {opacity:0, y:50, scale:.9}, {opacity:1, y:0, scale:1, duration:.5, ease:"back.out(1.6)"}, 1.41);
    tl.fromTo("#e-ph", {opacity:0, y:30}, {opacity:1, y:0, duration:.4, ease:"power3.out"}, 1.64);
    tl.set("#e-fill", {scaleY:0}, 0);
    tl.fromTo("#e-cur", {x:1100, y:1500}, {x:330, y:980, duration:.5, ease:"power3.inOut"}, 1.85);
    tl.to("#e-cur", {scale:.85, duration:.07, yoyo:true, repeat:1}, 2.79);
    tl.to("#e-cta", {scale:.96, duration:.08, yoyo:true, repeat:1}, 2.81);
    tl.to("#e-fill", {scaleY:1, duration:.45, ease:"power3.out"}, 2.81);
    tl.to("#e-cur", {x:1150, y:1700, opacity:0, duration:.5, ease:"power3.in"}, 3.3);
""")


# ---------------- PHONE TOUR (real site recording inside a floating phone) ----------------
SW, SH = 560, 1212            # screen size (recording is 390x844 css px -> x1.4359)
PX, PY = (W - SW) // 2, 360   # screen top-left in frame
K = SW / 390
BEAT = 60 / 128; BAR = 4 * BEAT   # music grid: 128 BPM
SEGS = [  # start, dur, media-start, rate  (deterministic 1x recording, actions placed on the beat)
  (0.0, 22.5, 0.0, 1.0),
]
CAPS = [  # start, kicker, line
  (0.0, 'NAOR ROYAL TOURS', 'האתר <em>החדש.</em>'),
  (BAR, '', 'בוחרים <em>חופשה.</em>'),
  (4 * BAR, '', 'המזוודה <em>נארזת.</em>'),
  (6 * BAR, '', 'קיץ? <em>חורף.</em>'),
  (13.6, '', '10 <em>יעדים.</em>'),
  (8.5 * BAR, '', 'טופס <em>אחד.</em>'),
  (11 * BAR, '', 'ישר <em>לוואטסאפ.</em>'),
]
TAPS = [  # film time, viewport x, y, callout (text, swatch) or None
  (1.88, 109, 535, ('משפחתית', 'בז׳ שמנת', '#e2d0b0')),
  (3.75, 282, 678, ('כשרה', 'שחור', '#15110e')),
  (5.63, 282, 535, ('זוגית', 'קרמל', '#b07a45')),
  (8.20, 264, 140, None),
  (11.25, 130, 140, None),
]
vids = '\n'.join(f'''        <video id="ph-v{i}" class="clip scr" style="position:absolute;left:0;top:0;width:{SW}px;height:{SH}px;object-fit:cover" src="assets/video/site-tour-30.mp4" muted playsinline data-start="{a}" data-duration="{d}" data-media-start="{m}" data-playback-rate="{r}" data-track-index="{2 + i % 2}"></video>''' for i, (a, d, m, r) in enumerate(SEGS))
caps = ''.join(f'<div class="cap" id="ph-c{i}"><div class="ck">{k}</div><div class="cl">{l}</div></div>' for i, (_, k, l) in enumerate(CAPS))
calls = ''.join(f'<div class="call" id="ph-o{i}"><span class="sw" style="background:{c[2]}"></span><span><b>{c[0]}</b><small>{c[1]}</small></span></div>' for i, (_, _, _, c) in enumerate(TAPS) if c)
taps = ''.join(f'<div class="tap" id="ph-t{i}" style="left:{round(x*K)}px;top:{round(y*K)}px"></div>' for i, (_, x, y, _) in enumerate(TAPS))
cap_js = ''
for i, (t, _, _) in enumerate(CAPS):
    cap_js += f'    tl.fromTo("#ph-c{i}", {{opacity:0, y:40}}, {{opacity:1, y:0, duration:.4, ease:"power3.out"}}, {max(t, .0) + (.0 if i == 0 else .05):.2f});\n'
    if i + 1 < len(CAPS):
        cap_js += f'    tl.to("#ph-c{i}", {{opacity:0, y:-30, duration:.22, ease:"power2.in"}}, {CAPS[i+1][0] - .2:.2f});\n'
    else:
        cap_js += f'    tl.to("#ph-c{i}", {{opacity:0, y:-30, duration:.25, ease:"power2.in"}}, 21.6);\n'
tap_js = ''
for i, (t, _, _, c) in enumerate(TAPS):
    tap_js += f'    tl.fromTo("#ph-t{i}", {{scale:.3, opacity:.95}}, {{scale:1.5, opacity:0, duration:.55, ease:"power2.out", immediateRender:false}}, {t - .06:.2f});\n'
oi = 0
for t, _, _, c in TAPS:
    if not c: continue
    end = TAPS[oi + 1][0] - .1 if oi + 1 < 3 else 7.4
    tap_js += f'    tl.fromTo("#ph-o{oi}", {{opacity:0, x:-60, scale:.8}}, {{opacity:1, x:0, scale:1, duration:.35, ease:"back.out(1.8)"}}, {t + .45:.2f});\n'
    tap_js += f'    tl.to("#ph-o{oi}", {{opacity:0, x:-30, duration:.2}}, {end - .2:.2f});\n'
    oi += 1
scenes['phone'] = (22.5, f"""
#ph-glow{{position:absolute;left:50%;top:960px;width:1300px;height:1300px;margin:-650px 0 0 -650px;border-radius:50%;background:radial-gradient(circle,rgba(232,198,144,.28),rgba(176,122,69,.10) 40%,rgba(0,0,0,0) 68%)}}
#ph-shadow{{position:absolute;left:50%;top:1640px;width:560px;height:70px;margin-left:-280px;border-radius:50%;background:radial-gradient(closest-side,rgba(0,0,0,.6),rgba(0,0,0,0))}}
#ph-rig{{position:absolute;inset:0;perspective:2200px;z-index:1}}
#ph-body{{position:absolute;left:{PX - 20}px;top:{PY - 20}px;width:{SW + 40}px;height:{SH + 40}px;border-radius:92px;background:linear-gradient(145deg,#3a332c,#0d0b09 30%,#1b1713 70%,#4a4037);padding:20px;box-shadow:0 60px 120px rgba(0,0,0,.6),inset 0 0 0 2px rgba(255,236,210,.18);transform-style:preserve-3d}}
#ph-body:before{{content:"";position:absolute;inset:7px;border-radius:86px;background:#050403}}
#ph-btn1,#ph-btn2,#ph-btn3{{position:absolute;width:6px;border-radius:3px;background:#2a241f}}
#ph-btn1{{left:-5px;top:240px;height:90px}}#ph-btn2{{left:-5px;top:350px;height:90px}}#ph-btn3{{right:-5px;top:300px;height:150px}}
#ph-screen{{position:absolute;left:20px;top:20px;width:{SW}px;height:{SH}px;border-radius:72px;overflow:hidden;background:#100d0a}}
.scr{{position:absolute;left:0;top:0;width:{SW}px;height:{SH}px;object-fit:cover}}
#ph-island{{position:absolute;left:50%;top:22px;width:150px;height:44px;margin-left:-75px;border-radius:22px;background:#000;z-index:5}}
#ph-gloss{{position:absolute;inset:0;border-radius:72px;background:linear-gradient(115deg,rgba(255,255,255,.10) 0%,rgba(255,255,255,0) 28%);z-index:4;pointer-events:none}}
.tap{{position:absolute;width:96px;height:96px;margin:-48px 0 0 -48px;border-radius:50%;border:5px solid rgba(255,252,247,.95);background:rgba(255,252,247,.25);z-index:6;opacity:0}}
.cap{{position:absolute;top:178px;left:70px;right:70px;opacity:0}}
.ck{{color:var(--gold);font-size:30px;font-weight:500;letter-spacing:.02em}}
.cl{{font-family:'Frank Ruhl Libre',serif;font-weight:900;font-size:96px;line-height:1.05;color:var(--white);margin-top:4px}}
.cl em{{font-style:normal;background:linear-gradient(100deg,#f6e2bd,#d8aa76 60%,#b07a45);-webkit-background-clip:text;background-clip:text;color:transparent}}
.call{{position:absolute;left:40px;top:1060px;display:flex;align-items:center;gap:20px;padding:20px 30px 20px 22px;border-radius:30px;background:var(--white);color:var(--ink);box-shadow:0 24px 60px rgba(0,0,0,.5);opacity:0;z-index:20;direction:rtl}}
.call .sw{{width:62px;height:62px;border-radius:18px;box-shadow:inset 0 0 0 2px rgba(0,0,0,.15)}}
.call b{{display:block;font-size:36px;font-weight:800;line-height:1.15}}
.call small{{display:block;font-size:28px;color:var(--muted)}}
#ph-card{{position:absolute;left:70px;top:500px;width:940px;height:790px;border-radius:44px;background:var(--white);box-shadow:0 40px 90px rgba(0,0,0,.5);transform-origin:0 0;opacity:0;z-index:30}}
""", f"""
    <div id="ph-wrap" style="position:absolute;inset:0">
      <div id="ph-glow"></div>
      <div id="ph-shadow"></div>
      <div id="ph-rig" data-layout-allow-overflow>
        <div id="ph-body">
          <span id="ph-btn1"></span><span id="ph-btn2"></span><span id="ph-btn3"></span>
          <div id="ph-screen">
{vids}
            <div id="ph-island"></div>
            <div id="ph-gloss"></div>
            {taps}
          </div>
        </div>
      </div>
      {caps}
      {calls}
      <div id="ph-card"></div>
    </div>
""", f"""
    // float: enters tilted, then breathes
    tl.fromTo("#ph-body", {{rotateY:-24, rotateX:10, y:60, scale:.94}}, {{rotateY:6, rotateX:3, y:0, scale:1, duration:1.6, ease:"power3.out"}}, 0);
    tl.to("#ph-body", {{rotateY:-5, rotateX:-2, y:-18, duration:3.0, ease:"sine.inOut", yoyo:true, repeat:10}}, 1.6);
    tl.fromTo("#ph-shadow", {{scaleX:.8, opacity:.6}}, {{scaleX:1.08, opacity:1, duration:3.0, ease:"sine.inOut", yoyo:true, repeat:10}}, 1.6);
{cap_js}{tap_js}
    // the planning form comes out of the phone
    tl.to("#ph-body", {{scale:.82, y:120, opacity:.25, duration:.7, ease:"power3.inOut", overwrite:"auto"}}, 21.75);
    tl.to("#ph-shadow", {{opacity:0, duration:.4, overwrite:"auto"}}, 21.75);
    tl.fromTo("#ph-card", {{opacity:1, x:{PX - 70}, y:{PY - 500}, scaleX:{SW / 940:.4f}, scaleY:{SH / 790:.4f}}}, {{opacity:1, x:0, y:0, scaleX:1, scaleY:1, duration:.6, ease:"power4.inOut", immediateRender:false}}, 21.85);
""")
wd, wcss, wbody, wjs = scenes['whatsapp']
wbody = wbody.replace(wbody[wbody.index('<div class="kick"'):wbody.index('<div id="w-chat">')], '')
wbody = wbody.replace('<div class="k">כל פנייה מקבלת מספר מעקב</div>', '<div class="k">מספר פנייה</div>')
scenes['wa2'] = (BAR, wcss.replace('#w-chat{position:absolute;top:500px', '#w-chat{position:absolute;top:500px').replace('#w-ticket{position:absolute;top:1095px', '#w-ticket{position:absolute;top:1110px'), wbody.replace('id="w-', 'id="w-'), """
    tl.fromTo("#w-wrap", {scale:1}, {scale:1.06, duration:1.875, ease:"none"}, 0.0);
    tl.fromTo("#w-bub", {scale:.6, opacity:0}, {scale:1, opacity:1, duration:.25, ease:"back.out(1.6)"}, 0.0);
    tl.fromTo("#w-bub .ml", {opacity:0, x:-24}, {opacity:1, x:0, duration:.12, ease:"power2.out", stagger:.06}, .05);
    tl.fromTo("#w-ticket", {rotate:0}, {rotate:-3, duration:.9, ease:"sine.inOut"}, 1.2);
    tl.fromTo("#w-meta", {opacity:0}, {opacity:1, duration:.1}, .55);
    tl.to("#w-id", {backgroundColor:"rgba(232,198,144,1)", duration:.15}, .7);
    tl.fromTo("#w-ticket", {opacity:0, y:-200, scale:.5}, {opacity:1, y:0, scale:1, duration:.35, ease:"back.out(1.6)"}, BEAT * 2 - .05);
""".replace('BEAT * 2', str(round(2 * BEAT, 3))))
ORDER = ['phone', 'wa2', 'endcard']
os.makedirs(f'{OUT}/compositions', exist_ok=True)
starts, t = {}, 0.0
for cid in ORDER:
    dur, css, body, js = scenes[cid]
    starts[cid] = t
    with open(f'{OUT}/compositions/{cid}.html', 'w') as f:
        f.write(scene(cid, dur, css, body, js))
    t += dur
TOTAL = round(t, 2)

S = starts
SFX = [  # id, file, abs time, volume
  ('sfx-in', 'whoosh-cinematic', S['phone'] + 0.0, .35),
  ('sfx-t0', 'click-soft', S['phone'] + 1.87, .7),
  ('sfx-t1', 'click-soft', S['phone'] + 3.74, .65),
  ('sfx-t2', 'click-soft', S['phone'] + 5.62, .7),
  ('sfx-pk', 'whoosh-short', S['phone'] + 7.45, .4),
  ('sfx-t3', 'click-soft', S['phone'] + 8.19, .7),
  ('sfx-t4', 'click-soft', S['phone'] + 11.24, .7),
  ('sfx-dst', 'whoosh', S['phone'] + 13.55, .35),
  ('sfx-frm', 'whoosh-short', S['phone'] + 15.9, .4),
  ('sfx-c1', 'pop', S['phone'] + 19.22, .45),
  ('sfx-c2', 'pop', S['phone'] + 19.69, .4),
  ('sfx-c3', 'pop', S['phone'] + 20.16, .45),
  ('sfx-send', 'click', S['phone'] + 21.08, .7),
  ('sfx-out', 'whoosh', S['phone'] + 21.8, .55),
  ('sfx-msg', 'notification', S['wa2'] + .02, .5),
  ('sfx-id', 'pop', S['wa2'] + .9, .5),
  ('sfx-riser', 'riser', S['endcard'] - 1.62, .4),
  ('sfx-mark', 'impact-bass-1', S['endcard'] + .0, .6),
  ('sfx-cta', 'click', S['endcard'] + 2.80, .7),
]
SFXFILE = {'click': 'click-soft'}
import subprocess
DUR = {n[:-4]: round(float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',f'{OUT}/assets/sfx/{n}']).decode()) - .02, 2) for n in os.listdir(f'{OUT}/assets/sfx')}
DUR['riser'] = 2.4  # only bundled names we copied
hosts = '\n'.join(f'''      <div id="{cid}" data-composition-id="{cid}" data-composition-src="compositions/{cid}.html" data-start="{S[cid]:.2f}" data-duration="{scenes[cid][0]}" data-track-index="1" data-track-kind="graphics" data-width="{W}" data-height="{H}"></div>''' for cid in ORDER)
audio = '\n'.join(f'''      <audio id="{i}" class="clip" src="assets/sfx/{SFXFILE.get(f, f)}.mp3" data-start="{a:.2f}" data-duration="{DUR[SFXFILE.get(f, f)]}" data-track-index="{3 + n % 3}" data-volume="{v}"></audio>''' for n, (i, f, a, v) in enumerate(SFX))
MUSIC = 'assets/music/summer-in-ibiza-instrumental.mp3'
MUSIC_START = 67.5   # the track's hook; first downbeat of the cut sits on film 0
if os.path.exists(f'{OUT}/{MUSIC}') and os.path.getsize(f'{OUT}/{MUSIC}') > 100000:
    audio += f'''
      <audio id="music" class="clip" src="{MUSIC}" data-start="0" data-duration="{TOTAL}" data-media-start="{MUSIC_START}" data-track-index="2" data-volume="0.85" data-fade-out="1.2"></audio>'''
index = f"""<!doctype html>
<html lang="he">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width={W}, height={H}" />
    <title>NAOR ROYAL TOURS — האתר החדש</title>
    <script src="assets/vendor/gsap.min.js"></script>
    <style>
      * {{ margin: 0; padding: 0; box-sizing: border-box; }}
      html, body {{ margin: 0; width: {W}px; height: {H}px; overflow: hidden; background: #0b0806; }}
      #ground {{ position: absolute; inset: 0; background: #0b0806; }}
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{TOTAL}" data-width="{W}" data-height="{H}">
      <div id="ground"></div>
{hosts}
{audio}
    </div>
    <script>
      window.__timelines = window.__timelines || {{}};
      window.__timelines["main"] = gsap.timeline({{ paused: true }});
    </script>
  </body>
</html>
"""
index = index.replace('id="sfx-riser"', 'id="sfx-riser" data-media-start="1.85" data-fade-out="0.3"')
with open(f'{OUT}/index.html', 'w') as f:
    f.write(index)
print('total', TOTAL, starts)
