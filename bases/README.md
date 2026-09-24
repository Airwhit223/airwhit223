# Meshy base bodies

`male_base_meshy.glb` and `female_base_meshy.glb` are Meshy generations of
the base-body turnaround *sheets*, so each file holds the whole sheet: front,
side and back figures side by side (5–6 separate figures, each ~450
triangles). `characters/base_character.py` picks the front-facing figure,
scales it to a real height, centers it and smooths it.

`preview_extracted.png` shows the extracted male and female figures.

For better bases next time, give Meshy a **single front-view figure** (crop
one pose out of the sheet, or use its multi-view input with separate front
and side images). You'll get one higher-detail body instead of a sheet.
Swap the new file in and re-run the character scripts; the joint finding is
automatic.
