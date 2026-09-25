# Rival hairstyle & headwear correction pass (queued)

> **History document.** This records problems found after implementation. The target is defined in
> `VISUAL_DIRECTION_BIBLE.md` and `RACE_BIBLE.md` — consult those first.

From the user's reference review. Supersedes the earlier punk/bob/theatrical-volume direction. **Theo: no changes.**

1. **Headwear accessory system first.** No headwear slot exists yet.
   - Add a headwear attach point on the base head rig, sitting over the hair clump kit with partial coverage — hair
     still shows at sides/back/fringe per style, never fully hidden.
   - Build as a modular accessory type in the same spirit as the clump kit: reusable base shapes (beanie, headband)
     that recolour/retexture per character, not one-off meshes.
   - Needed for Jace (beanie with a small patch/pin) and Mr. Jones (beanie).
2. **Jace** — beanie plus spiky hair poking out beneath it, not a fully exposed style. Hair is two-tone: dark brown
   base with blonde streak clumps mixed in. The beanie now carries most of the punk/skater identity.
3. **Blair** — scrap the bob direction. Long, voluminous, wavy blonde hair in a high ponytail; a bow accessory at the
   ponytail base (its own small attach point); sweeping side bangs and a precise part. The "sharp, deliberate" quality
   comes from the bow, the part and the controlled wave — not from a blunt cut. Build from existing curl/wave clumps
   extended in length and volume.
4. **Kira** — two buns near the top/back from contained coil/curl-mass clumps pinned close to the scalp, plus separate
   longer spiral/drill-curl strands hanging loose from them (distinct elements). Pink streak stays as is. Should come
   from existing clump types; flag if the drill/spiral strand is not achievable with current primitives.
5. **Mr. Jones** — beanie plus moderate curls at the sides/front, mostly tucked under. Slightly tighter/neater curls,
   not bigger. Beard stays.
6. Re-render the full rival lineup comparison in the same format once the four are updated.
