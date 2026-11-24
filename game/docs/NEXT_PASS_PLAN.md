# Next art pass: a sunny, gritty street look

Status: waiting. The user will write "תתחיל" (start). Do not start before that.

## Inspiration (style only)
The user sent two reference videos: a tactical military shooter indoors, and a sunny open-world crime game street scene.
Use them for inspiration only. Do not copy characters, logos, names, graffiti, HUD art or any asset. All work must be original, procedural or CC0.

## Gaps against the references
1. **Lighting.** The references use strong white midday sun, crisp shadows and a bright sky. Ours is an orange, murky dusk.
2. **Dirt and wear.** The references have puddles, stains, manholes, cracks, litter, graffiti and murals. Ours is too clean.
3. **Density.** The references have utility poles and wires, an elevated overpass, many parked cars and many pedestrians.
4. **Camera.** The references use a close over-the-shoulder camera, with the character about 1/3 of the frame, plus mild motion blur.
5. **Cars.** The references have deep glossy paint, painted pinstripes and chrome rims.
6. **Combat.** The references have muzzle flash, dust and blood impacts, bullet holes, a close red-dot optic and detailed tactical soldiers.
7. **HUD.** The references use a round minimap in the corner and health and armor bars at the bottom.

## Plan when the user says start
Do all 7 items. Same method as the cinematic-look pass:
- Parallel worktree agents on look2/<key> branches.
- Then an integrator.
- Then an art-director pass.

Afterwards:
- Run a headless check.
- Build the APK and the web export (split the gzip, artifact Gny69nvaVv9XTpteJqUQNX).
- Write a Hebrew report.
- Also build a lighter iPhone/Safari web build (smaller textures, less foliage and crowd), which the user asked for before.

Estimated cost: about 2-2.5M tokens, 4-5 hours.

## Open issues to fold in
- Mission beams spoil the look.
- Hairline gaps and the lash cards.
- Wheel arches are dark patches, not cut-outs.
- Repeated facades.
- Palm shadow cost.
