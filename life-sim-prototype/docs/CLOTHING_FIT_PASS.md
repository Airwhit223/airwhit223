# Clothing fit pass (queued)

> **History document.** This records problems found after implementation. The target is defined in
> `VISUAL_DIRECTION_BIBLE.md` and `RACE_BIBLE.md` — consult those first.

The user sees clothes not fitting properly while idling and walking. What the in-game capture and the Blender checks
actually show:

**Not the cause.** Garment weights are clean: no vertex on the jeans or jacket is weighted to both legs, no faces
bridge the legs, and the jacket sleeve reaches the wrist in the bind pose (sleeve ends z 1.045, arm ends z 1.040).

**The real causes**
1. **Bind pose vs game pose.** Everything is modelled and skinned in a T-pose, but CharacterRig hangs the arms
   straight down — roughly a 90° shoulder rotation. Plain linear blend skinning collapses volume at that angle, so
   the shoulder/armpit pinches and the sleeve twists away from the arm. Same effect, smaller, at the knees and hips
   through the stride.
   *Fix:* bake pose-space correctives in Blender — pose the rig to the game's rest (arms down, slight knee bend),
   snapshot the difference as blend shapes (`Pose_Arms_Down`, `Pose_Knees`), export them, and hold them at a fixed
   value in game. The M8 rig and bind pose stay untouched.
2. **The baggy jeans are wide enough to merge.** At `leg_ease` 1.55 the two legs' fabric overlaps in silhouette, so a
   walk cycle reads as one column and a shoe disappears inside the hem.
   *Fix:* taper the hem (keep the volume at the thigh), and let the secondary-motion cloth profile swing the hems
   apart with the stride.
3. **Sleeve/forearm gap while walking.** Partly (1); also the sleeve end and the arm mesh are close in radius, so any
   skinning drift shows skin through the cuff. *Fix:* thicken the cuff slightly and inset the arm under it.

**Order:** correctives first (they fix every garment at once), then the jeans taper, then the cuff.
