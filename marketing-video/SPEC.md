# NAOR ROYAL TOURS — סרטון השקה לאתר החדש

- Format: 1080×1920 (Reels / TikTok / Stories), 30 fps, 33 s, Hebrew RTL.
- Look: the site's own tokens — ink #100d0a, cream #fffcf7 / #f4ece0, caramel #b07a45, gold #e8c690, WhatsApp #25d366.
  Fonts are the site's files: Frank Ruhl Libre (display), Heebo (body), Bodoni Moda (latin mark), IBM Plex Mono (numbers).
- Safe band: all text between y 168 and y 1330. Below 1330 only texture.
- Banned: feature list as three cards, logo docked in a corner, title over a dimmed screenshot, invented features.
- Every claim maps to real code in the site (leads.js, pack.js, sw.js, config.js).

| # | Time | Scene | Real automation |
|---|------|-------|-----------------|
| 1 | 0–3.5 | Hook: "אתם רק אורזים מזוודה." over Rhodes → "כל השאר — אוטומטי." | — |
| 2 | 3.5–9.5 | Planning form fills, 3 chips toggle, cursor taps "שלחו לי בוואטסאפ" | form + validation |
| 3 | 9.5–15 | WhatsApp bubble builds the exact message buildMsg() writes, lead ID NRT-YYMMDD-XXXX pops | auto message + lead ID |
| 4 | 15–19.5 | Clock "ראשון 10:30" → "זמין עכשיו בוואטסאפ"; flips to "שישי 16:00" → "שבת שלום" | hours + Shabbat status |
| 5 | 19.5–24.5 | Packing list: summer 7 items, toggle → winter 7 items | packing guide per season |
| 6 | 24.5–28.5 | Behind the scenes: offline, field checks, bot trap, accessibility | sw.js, validation, honeypot, a11y |
| 7 | 28.5–33 | Lockup + TRAVEL LIKE ROYALTY + CTA button clicked + 053-623-3816 | — |

Sound: bundled Pixabay SFX on visible actions only (whoosh on cuts, clicks on cursor taps, pops on chips/badges, riser→impact on the mark). No music bed yet.
