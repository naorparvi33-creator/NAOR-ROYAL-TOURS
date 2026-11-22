---
name: kids-viral-reels
description: Creates short viral Reels/Shorts/TikToks (15-60s) for kids aged 3-10, built on original characters with a real plot. Covers the character bible, hook, beat sheet, shot list, AI image/video prompts, voice, sound, captions and series plan. Use when asked for a kids' reel, a cartoon short, a character story for children, a kids' animation channel, "סרטון לילדים", "רילס לילדים", "דמויות לילדים" or "סדרה מצוירת קצרה".
---

# Kids Viral Reels: viral short reels for kids with characters and a plot

The goal is a 15-60 second clip that a child **watches to the end, asks to watch again, and wants the next episode of**.
The skill produces a complete production package: characters, script, shots, generation prompts, sound and a series plan.

> Research basis: published research and analyses of the leading kids' shorts formats (see `references/research-notes.md`).
> The skill was built **without watching real videos** (vidIQ credits ran out and YouTube/TikTok were blocked by the network).
> To calibrate against real videos, run **calibration mode** at the bottom of this file.

---

## 0. Ask (or pick sensible defaults)

| Question | Default if not specified |
|---|---|
| Age | 4-8 |
| Language | Hebrew, with minimal dialogue (works without sound too) |
| Platform | Vertical 9:16, Reels + Shorts + TikTok |
| Length | 30-45 seconds |
| Style | Bright, soft 3D animation (rounded "toy" look) |
| Production tool | AI (image → video) or animation; the skill writes prompts for both |
| Series goal | Recurring characters, one episode a day |

---

## 1. The 7 laws of a viral kids' reel

1. **A face in frame within the first second.** Big eyes, a clear emotion (surprise, fear, joy). Kids lock onto faces before anything else.
2. **A problem within 3 seconds.** No intros, no logo, no "hi kids". Open mid-event: something breaks, falls, disappears or grows.
3. **One clear goal and one simple obstacle.** A 5-year-old should be able to explain what's happening without sound.
4. **Something changes every 1.5-2.5 seconds.** A cut, zoom, sound or new reaction. No flat moments.
5. **Exaggerated physical emotion.** Crying = a fountain of tears, surprise = eyes popping out, joy = a jump with sparkles. Squash & stretch.
6. **A twist or payoff 2-4 seconds before the end.** The surprise is the reason to share.
7. **An ending that loops or opens the next episode.** The last frame connects smoothly back to the first, or leaves a small question ("Who knocked on the door?").

---

## 2. Character bible (fill in before every new series)

Build **2-4 original characters**. Never use existing characters, brands or famous designs (copyright plus channel removal).

For each character:
```
Name: short, easy to repeat (2 syllables, a sound kids like: "Pupi", "Bambo", "Zizi")
Species/object: animal / fruit / vegetable / toy / everyday object / small monster
One-line silhouette: a shape recognizable even as a shadow (round, tall, triangular)
Signature color: one strong color that belongs to this character only
Signature detail: hat / horn / glasses / a missing tooth
Core trait: (curious / greedy / scaredy / show-off / clumsy / over-helpful)
Weakness that drives plots: what always gets them in trouble
Signature sound: a sound or word they always make ("Oops-la!", "hmm-hmm-hmm")
Catchphrase: 2-4 words, repeated in every episode
Relationship to the others: who teases whom, who rescues whom
```

**Proven casting archetypes (dynamic, not specific characters):**
- **The little one and the big one**: a small, brave character next to a large, scared one (contrast = humor).
- **The greedy one and the generous one**: food, candy and toys are the most common motor of conflict.
- **The clever one and the clumsy one**: the clumsy one causes the trouble, the clever one tries to fix it (and fails funnily).
- **A small trickster**: a mischievous character who causes chaos and gets "punished" lightly at the end (kids love seeing small justice).
- **Mom/dad/grandma figure**: a source of rules plus a surprise ending.

**Visual lock (critical for AI):** write one "Master Prompt" for each character and paste it **word for word** into every shot. Don't change colors, species or proportions between shots. A character that changes appearance breaks the series.

---

## 3. Plot templates (pick one per episode)

Each template has been tested in the kids' shorts space as a repeatable format. Change the content, keep the rhythm.

| # | Template | Structure | Example |
|---|---|---|---|
| 1 | **Mystery box / the magic button** | Strange object → pressed/opened → crazy consequence → bigger consequence → twist | Pupi presses a button and the house becomes giant |
| 2 | **Hunger and food** | Character wants food → obstacle → creative solution → funny surprise | Bambo tries to reach the cookie jar on the top shelf |
| 3 | **Transformation** | Normal → "magic" (bath, paint, machine) → big change → reveal | A gray egg goes into a rainbow bubble bath |
| 4 | **Wrong choice / right choice** | 3 doors/cups/colors → each one = consequence → right choice | Which door leads to the candy? |
| 5 | **Small vs. big** | Small character faces a giant problem → small trick → wins | A mouse vs. a broken refrigerator door |
| 6 | **The trickster gets caught** | Character pranks → it seems to work → the prank comes back at them | Zizi hides her brother's sock... and falls into the laundry |
| 7 | **Rescue in a race against time** | Friend in trouble → countdown → failed attempts → rescue in the last second | A balloon carries a little friend into the sky |
| 8 | **Copy me / the mirror** | Character does a move → the shadow/double/little copies do it differently → chaos | Little copies of Pupi copy him wrong |
| 9 | **Before and after (emotion)** | Sad character → a friend's act of kindness → huge joy | A snowman who has no hat |
| 10 | **"Don't touch!"** | A clear rule → temptation → touch → consequence → lesson with a smile | The red button in grandma's lab |
| 11 | **Hidden learning** | A plot that requires counting/colors/shapes to solve | Count to 5 to open the gate |
| 12 | **Sing-along** | A short rhythmic song that repeats and grows | "Wash, wash, wash your hands" with bubble monsters |

**Recommended rotation:** 60% templates 1-8 (entertainment), 25% template 9 (emotion), 15% templates 11-12 (learning). Parents share emotion and learning, kids rewatch entertainment.

---

## 4. Beat sheet: 35-second skeleton (default)

```
0.0-1.0s   HOOK VISUAL   — Close-up of a face + an absurd sight (something huge/broken/glowing)
1.0-3.0s   PROBLEM       — The goal or problem is clear without words
3.0-8.0s   ATTEMPT 1     — Fails funnily (exaggerated physical reaction)
8.0-14.0s  ATTEMPT 2     — Escalation: a bigger, crazier idea
14.0-20.0s COMPLICATION  — Things get worse / a second character joins
20.0-28.0s CLIMAX        — The decisive moment, a short pause (0.5s silence), then an explosion
28.0-32.0s TWIST/PAYOFF  — The surprise: an unexpected solution, or the problem flips
32.0-35.0s LOOP/TEASER   — Catchphrase + a frame that connects to the start / a tease for the next episode
```

For 15-20 seconds: drop attempt 2 and the complication. For 50-60 seconds: add a third attempt and a second twist.

---

## 5. Visual, sound and text rules

**Visual**
- Vertical 9:16, character in the center of the frame (top and bottom are hidden by the interface).
- Saturated, bright colors, a clear background that's less busy than the character.
- A camera move in every shot (slow push-in, zoom on reactions, whip pan on transitions).
- Big, clear facial expressions. No small details that don't show on a phone.

**Sound**
- Sound effects on **every** action (boing, pop, swoosh, splat). They matter more than the music.
- Short music with a happy rhythm, and a sudden drop at the climax.
- Voice: high, expressive, few words. Character "gibberish" plus 1-3 clear Hebrew words works across languages.
- Use only original music or music licensed for commercial use. No trending songs without a license.

**On-screen text**
- At most 3-5 words, large, at the top of the frame, only at the start ("Don't press the button!") or the end.
- Big, clear captions for any dialogue (many people watch without sound).

---

## 6. Safety and policy guardrails (mandatory)

- **No scary or violent content** for small kids: no blood, real injuries, threatening monsters, a "scary doctor", needles, kidnapping or dangerous behavior that can be copied (falling, fire, electricity, swallowing).
- No sexual content, insults, bullying presented as funny without consequence, or adult jokes.
- No existing characters, trademarks or famous voices. Everything is original.
- **AI disclosure:** label realistic synthetic content as required by the platform.
- **Made for Kids:** mark the content correctly (COPPA). Expect lower ad revenue and no personalized comments.
- **Avoid "AI slop":** YouTube removes channels with repetitive, template-made content with little variation from monetization. Every episode needs a new plot, a real joke and a real emotion, not just a background swap.
- No manipulative hooks ("Mom will be angry if you don't watch") and no fake educational claims.
- Every episode ends in a positive place: no one is left sad, hurt or alone.

---

## 7. Required output for each episode

Return everything in this order:

1. **Title** (3 options, up to 50 characters, curiosity without clickbait) plus a short caption and 3-5 hashtags.
2. **One-line logline**: who, wants what, what gets in the way, what the surprise is.
3. **Character bible** (if this is a new series) plus a Master Prompt for each character.
4. **Timed script**: a table of `time | what's seen | what's heard (voice/SFX/music) | on-screen text`.
5. **Shot list for production**: 8-14 shots, each with:
   - Image prompt (Master Prompt + scene + angle + lighting + "vertical 9:16, 3D Pixar-like toy style" or the chosen style)
   - Video/motion prompt (what moves, camera movement, length in seconds)
6. **Voice and sound**: voiceover lines, voice type, list of SFX, music direction.
7. **Thumbnail/cover**: one frame with the face + the problem.
8. **Checklist** (section 9) filled in.
9. **Hook for the next episode** plus 3 follow-up episode ideas.

When the user asks for "a series" or "a channel": add a **12-episode plan** (title + template + logline per episode), with recurring characters and a slowly building arc (a new friend, a new place, a "season finale").

---

## 8. Production recommendations

- **AI images → video:** create a character sheet first (front, side, 3/4, 4 emotions) and use it as a reference in every shot. Generate 2-4 second shots and edit in an editor (CapCut and similar).
- **HyperFrames/animation:** if the `hyperframes` skill is available, simple scenes (text, bubbles, transitions, counting) can be built directly with it.
- **Voice:** a TTS voice with expression or the user's own voice. Pitch up slightly for "cute" characters.
- **Publishing rhythm:** consistency beats perfection. Same characters, same time of day, 4-7 episodes a week.
- **Measurement:** look at retention percentage and the % of viewers who swiped past in the first 3 seconds. Fix the hook before you fix anything else.

---

## 9. Checklist before publishing

- [ ] A face plus something strange in the first second?
- [ ] Is the problem clear without sound by second 3?
- [ ] Something changes at least every 2.5 seconds?
- [ ] At least one big physical reaction that's fun to imitate?
- [ ] A real twist, not just "and that's the end"?
- [ ] Does the ending connect to the start or open the next episode?
- [ ] Characters look identical in every shot?
- [ ] Catchphrase appears at least once?
- [ ] No scary, violent, dangerous-to-copy or copyrighted content?
- [ ] Something new in this episode compared to the previous ones (not a template copy)?
- [ ] Made for Kids and AI disclosure marked as required?

---

## 10. Calibration mode: learning from real videos

When the user asks to "watch videos and learn", or when a video analysis tool is available:

1. Find 50 outliers: kids' character/animation shorts that outperform their channel's median (e.g. `vidiq_outliers` with `contentType: short`, `vidiq_instagram_tiktok_outlier_search`).
2. Watch each one (`vidiq_watch_shortform_content`, in parallel) and record into `references/video-analysis.md`:
   `URL | views | length | first-second hook | template (from section 3) | number of cuts | characters | twist | loop yes/no | sound`
3. Summarize: which templates repeat, average length, time to problem, cut density, recurring sounds.
4. Update sections 1, 3 and 4 in this file according to the findings, and note the update date.

Never present conclusions as based on "watching videos" if no videos were actually watched.
