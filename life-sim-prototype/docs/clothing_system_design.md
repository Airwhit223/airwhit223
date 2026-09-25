# Regional Clothing System — Buy, Wear, Mix & Match

Every region has its own fashion culture. The player can buy and wear any of it — and mix pieces across cultures however they want. Fashion is a core life-sim activity, not just stat gear.

---

## Design Philosophy

> **No outfit locks.** If you can buy it, you can wear it anywhere. An Egyptian headdress with a hoodie and medieval boots? That's your call. NPCs will *react* to what you're wearing (compliments, confusion, cultural commentary) but never block you.

> **Sets are rewarded, not required.** Wearing a full regional set gives a cosmetic bonus (special idle animations, NPC dialogue unlocks, shop discounts in that region) but individual pieces work fine.

> **Every piece is visible on the character model.** This game's clothing isn't stat-screen-only. The CharacterRig socket system already handles this — every item maps to a body socket and renders on the 3D model.

---

## Equipment Slots

| Slot | Socket Point | What Goes Here |
|---|---|---|
| **Head** | `head_top` | Hats, hoods, crowns, headwraps, headdresses, helmets |
| **Hair** | `hair_root` | Hairstyles (bought at salons/barbers per region) |
| **Face** | `face_front` | Glasses, masks, kohl makeup, face paint, scarves |
| **Neckwear** | `neck` | Necklaces, scarves, collars, broad collars, chokers |
| **Top** | `torso_upper` | Shirts, hoodies, vests, tunics, robes, armor |
| **Outer Layer** | `torso_outer` | Jackets, cloaks, coats, capes (layered over top) |
| **Hands** | `hand_L` / `hand_R` | Gloves, rings, bracers, arm bands, wraps |
| **Bottom** | `torso_lower` | Pants, shorts, skirts, robes (lower), kilts |
| **Feet** | `foot_L` / `foot_R` | Shoes, boots, sandals, wraps, barefoot style |
| **Back** | `spine_upper` | Backpacks, weapons (sheathed), wings (dragonfolk), cloaks (attach point) |
| **Accessory 1–3** | various | Belts, pouches, jewelry, charms, badges |

---

## Region 1: THE NEIGHBORHOOD — Modern Streetwear

### Shop: **"Threads" — Corner Clothing Store**
Located next to the minimart. Run by a retired fashion-obsessed NPC. Small storefront, rotating stock.

### Style DNA
Contemporary casual — hoodies, graphic tees, jeans, sneakers, joggers. Skater and basketball culture influence. The baseline that every other region's fashion contrasts against.

### Key Items

| Item | Slot | Price | Description |
|---|---|---|---|
| Zip-Up Hoodie | Top | \$40 | Classic. Multiple colors. The protagonist's starting look. |
| Graphic Tee (rotating designs) | Top | \$25 | New designs each week. Band logos, skate brands, abstract art. |
| Henley (fitted) | Top | \$30 | Shows build better than a tee. Rolled sleeves. |
| Bomber Jacket | Outer | \$65 | Cropped or full-length. Layering staple. |
| Denim Jacket | Outer | \$55 | Distressed or clean. Works over anything. |
| Baggy Jeans | Bottom | \$35 | Loose fit, cuffed at the ankle. |
| Cargo Pants | Bottom | \$40 | Pockets for days. Functional. |
| Basketball Shorts | Bottom | \$20 | Athletic. Good for hot weather or the court. |
| Skate Sneakers | Feet | \$50 | Chunky soles, visible branding. Multiple colorways. |
| High-Top Sneakers | Feet | \$55 | Classic. |
| Platform Sneakers | Feet | \$60 | Added height. Popular with feminine builds. |
| Snapback Cap | Head | \$20 | Forward or backward. |
| Beanie | Head | \$15 | Slouchy or fitted. |
| Chain Necklace | Neckwear | \$25 | Simple silver or gold. |
| Backpack | Back | \$30 | Canvas or leather. Visible on model. |
| Wristbands | Hands | \$10 | Rubber or leather. Stackable. |

### Tradition
No formal tradition — this is modern life. But there's an unspoken rule: **you are what you wear.** NPCs notice and comment. Wearing all-new gear gets compliments. Wearing the same outfit for a week gets side-eye.

---

## Region 2: THE OLD SHORE — Coastal & Beachwear

### Shop: **"Salt & Sun" — Boardwalk Surf Shop**
Open-air shop on the docks. Run by a retired aquatic-folk surfer. Boards hanging from the ceiling. Smells like wax and salt water.

### Style DNA
Beach town meets fishing village. Relaxed, sun-faded, practical for water. Linen, canvas, rope accessories. The Rolling Tides heritage area.

### Key Items

| Item | Slot | Price | Description |
|---|---|---|---|
| Linen Button-Up (open) | Top | \$35 | Light, airy. Worn unbuttoned over a tank or alone. Faded pastels. |
| Tank Top | Top | \$15 | Simple. Shows arms and build. |
| Wetsuit Top | Top | \$45 | Fitted, functional. For actual water activities. |
| Board Shorts | Bottom | \$25 | Colorful tropical prints or solid. Quick-dry. |
| Linen Pants (rolled) | Bottom | \$30 | Loose, rolled at the calf. Sand-colored or white. |
| Flip-Flops | Feet | \$10 | The cheapest footwear in the game. |
| Canvas Boat Shoes | Feet | \$35 | Worn, comfortable. Salt-stained. |
| Sandals (strappy) | Feet | \$20 | Leather straps. Works for all genders. |
| Straw Sun Hat | Head | \$15 | Wide brim. Practical. |
| Bandana | Head/Face | \$10 | Tied on head or around neck. Multiple patterns. |
| Shell Necklace | Neckwear | \$20 | Handmade. Each one slightly different. |
| Rope Bracelet | Hands | \$8 | Sailor's knot. Stackable. |
| Fishing Vest | Outer | \$40 | Lots of pockets. Practical but looks cool layered. |
| Surfboard | Back | \$80 | Cosmetic carry item. Multiple designs. |

### Tradition
The shore folk have a **naming ceremony** when you catch your first big fish — they give you a custom rope bracelet with a carved shell charm. Wearing it marks you as "shore-accepted" and unlocks discounted prices.

---

## Region 3: MEDIEVAL GOTHIC TOWN — Olde World Fashion

### Shop: **"The Ironthread Tailor" — Stone Shopfront**
A tailor's workshop in the town square. Stone walls, a heavy wooden door, fabric bolts visible through the window. Run by a serious dwarven-built human who takes measurements with terrifying precision.

### Style DNA
Practical medieval — leather, linen, wool, iron fixtures. Not royal court fashion. These are clothes for people who work, fight, and travel. The gothic undertone shows in dark colors, pointed silhouettes, and iron/silver hardware. Think Witcher-lite meets Dragon Quest town.

### Key Items

| Item | Slot | Price | Description |
|---|---|---|---|
| Linen Tunic | Top | 30 coin | Simple, long. Base layer for layering. Cream, grey, dark green. |
| Leather Vest (fitted) | Top | 50 coin | Shows build. Buckle or lace-up front. |
| Chainmail Vest | Top | 120 coin | Light armor. Visible links. Worn over tunic. |
| Wool Cloak | Outer | 60 coin | Full length, hooded. Dark colors — black, deep green, burgundy. |
| Half-Cape | Outer | 40 coin | Over one shoulder. Looks dramatic. Less practical. |
| Leather Armor Jacket | Outer | 90 coin | Structured, with buckles and straps. The "cool" option. |
| Fitted Trousers | Bottom | 35 coin | Tucked into boots. Dark wool or leather. |
| Split Riding Skirt | Bottom | 40 coin | Full mobility. Popular with feminine builds and beastfolk. |
| Leather Boots (knee) | Feet | 55 coin | Sturdy. Buckled. The standard. |
| Heeled Boots (pointed) | Feet | 65 coin | Gothic silhouette. Adds height. |
| Iron-Shod Boots | Feet | 75 coin | Heavy. Armored toe. The fighter's choice. |
| Hood (separate) | Head | 20 coin | Attachable to any cloak or worn alone. |
| Leather Circlet | Head | 30 coin | Simple band with a small gem or metal accent. |
| Iron Crown (simple) | Head | 100 coin | Earned, not bought. Given by the town elder for completing quests. |
| Fingerless Leather Gloves | Hands | 25 coin | Grip + dexterity. |
| Gauntlets (light) | Hands | 45 coin | Forearm protection. Leather with iron studs. |
| Bracers (engraved) | Hands | 55 coin | Decorative + protective. The prestige hand item. |
| Sword Belt + Scabbard | Accessory | 35 coin | Required to sheathe a sword on your hip visually. |
| Pouch Belt | Accessory | 20 coin | Multiple small pouches. Replaces modern pockets. |
| Amulet (various) | Neckwear | 40–80 coin | Silver or iron on a leather cord. Each has a different symbol. |

### Tradition
The town has a **Blacksmith's Mark** tradition — when you commission your first custom weapon, the smith brands a small symbol onto your glove or bracer. NPCs with the mark treat you as a peer. Without it, you're a tourist.

---

## Region 4: RESURFACED EGYPTIAN CITY — Ancient Royal Fashion

### Shop: **"The Weaver's Hall" — Temple-Adjacent Market**
A long open-air hall with stone columns, fabric hanging from ceiling beams, and artisans working looms in the back. Run by the **Queen's appointed textile minister** — a precise, no-nonsense human woman who judges your taste silently.

### Style DNA
Ancient Egyptian elevated — pristine white linen, gold accessories, turquoise and lapis accents, kohl eye makeup. Everything is intentional. Colors indicate rank. Jewelry indicates achievement. These clothes are *statements*.

### Key Items

| Item | Slot | Price | Description |
|---|---|---|---|
| Pleated Linen Tunic | Top | 40 scarab | Clean white. The base. Surprisingly flattering on every body type. |
| Wrapped Chest Binding | Top | 25 scarab | Minimal. For hot weather or athletic builds. Shows torso. |
| Beaded Collar Top | Top | 60 scarab | Linen with a built-in broad collar. Colorful beadwork. |
| Sheer Linen Robe | Outer | 55 scarab | Light, flowing, slightly transparent. Layered over a tunic or binding. |
| Pharaonic Kilt | Bottom | 35 scarab | Pleated white linen, knee-length. Gold belt. Classic. |
| Wrapped Linen Pants | Bottom | 30 scarab | Loose, gathered at ankle. Comfortable. |
| Long Pleated Skirt | Bottom | 40 scarab | Floor-length, slit to the thigh for mobility. |
| Leather Sandals (gold-tipped) | Feet | 35 scarab | Strappy, with small gold caps on the toe straps. |
| Barefoot Anklets | Feet | 20 scarab | No shoes — just gold ankle chains. A fashion choice. |
| Reed Sandals | Feet | 15 scarab | Simple, traditional. The cheapest option. |
| Royal Headband | Head | 40 scarab | Gold band with a single uraeus (cobra) symbol. |
| Nemes Headdress (striped) | Head | 80 scarab | The iconic striped cloth headdress. Makes you look pharaonic. |
| Vulture Crown (small) | Head | 120 scarab | The queen's style, miniaturized. A prestige item. Requires queen's favor. |
| Broad Collar Necklace | Neckwear | 65 scarab | Wide beaded collar in turquoise, gold, red, and blue. The signature piece. |
| Gold Arm Bands | Hands | 50 scarab | Upper arm. Snake or geometric pattern. Sold in pairs. |
| Wrist Cuffs (gold) | Hands | 45 scarab | Wide gold bands. |
| Kohl Eye Kit | Face | 25 scarab | Applies dramatic eye makeup. Changes your character's face rendering. |
| Ankh Pendant | Neckwear | 55 scarab | Gold ankh on a gold chain. |
| Scarab Belt | Accessory | 40 scarab | Gold scarab buckle on a linen sash. |
| Ceremonial Staff | Back | 150 scarab | The queen has to personally approve this purchase. End-game prestige. |

### Tradition
The Egyptian city uses **scarab coins** — you exchange modern money or medieval coin at a money-changer near the market entrance. The exchange rate fluctuates based on your standing with the queen.

**Rank Colors:** White = commoner, Blue = recognized, Gold accents = queen's favor, Full gold = royal court access. NPCs notice and react to your color rank.

---

## Region 5: SAND VILLAGES — Desert Nomad Fashion

### Shop: **"The Dune Bazaar" — Tent Market**
A cluster of merchant tents in the largest sand village. Haggling is expected — the listed price is the *starting* price. Your charisma stat affects final cost.

### Style DNA
Desert practical — loose wraps, head coverings, layered fabric for sun and sand protection. Earthy tones (terracotta, sand, ochre, deep indigo) with handwoven patterns. Less refined than the city's royal fashion — this is working desert culture.

### Key Items

| Item | Slot | Price | Description |
|---|---|---|---|
| Desert Wrap Tunic | Top | 20 scarab | Loose, crossed front. Breathable. Earth tones. |
| Layered Vest (woven) | Top | 30 scarab | Handwoven with geometric patterns. Each vendor's pattern is unique. |
| Nomad Chest Wrap | Top | 15 scarab | Minimal. Strips of fabric. Maximum ventilation. |
| Baggy Desert Pants | Bottom | 20 scarab | Gathered at ankle and waist. Moves with you. |
| Wrapped Skirt (layered) | Bottom | 25 scarab | Multiple fabric layers. Creates movement. |
| Desert Boots (leather) | Feet | 30 scarab | Soft leather, high ankle. Sand-colored. |
| Wrapped Foot Bindings | Feet | 10 scarab | Cloth strips. Cheapest protection. |
| Keffiyeh (head wrap) | Head | 15 scarab | Large fabric square, wrapped for sun protection. Multiple styles. |
| Turban | Head | 25 scarab | Wound fabric. More structured than keffiyeh. |
| Desert Goggles | Face | 20 scarab | Leather and tinted glass. Sandstorm protection. Look cool. |
| Face Veil (mesh) | Face | 15 scarab | Light fabric. Sand protection + mystery. |
| Beaded Sash | Accessory | 18 scarab | Waist sash with sewn-in clay and stone beads. |
| Bone Necklace | Neckwear | 12 scarab | Desert creature bones, carved and strung. |
| Leather Arm Wraps | Hands | 15 scarab | Wound strips up the forearm. Practical. |
| Waterskin | Accessory | 10 scarab | Visible on hip. Functional — affects hydration in desert heat. |

### Tradition
The sand villages practice **pattern trading** — each village weaves a unique geometric pattern into their vests and sashes. Owning patterns from multiple villages means you've traveled widely and earned trust. NPCs from a village will warm up faster if you're wearing their pattern.

---

## Region 6: UNDERGROUND CITY — Ceremonial & Ancient

### Shop: **"The Keeper's Vault" — Sealed Chamber**
Not a traditional shop. A sealed room in the underground city that opens only after you've proven yourself to the spirit guardians. The "shopkeeper" is an **ancient automaton** (a stone golem with hieroglyphic instructions carved into it) that trades items for **Dream Fragments** dropped by spirit enemies.

### Style DNA
Sacred, ceremonial, touched by the Dream Realm. Dark base fabrics with glowing accents — gold thread that pulses, gemstones that emit faint light, symbols that shift when you're not looking directly at them. This clothing is *alive* in a subtle way.

### Key Items

| Item | Slot | Price | Description |
|---|---|---|---|
| Ritual Robe (dark) | Top + Bottom | 80 fragments | Full-length dark linen with gold thread patterns that faintly glow. |
|Wraithweave Tunic | Top | 50 fragments | Fabric has a slight transparency — like it's between worlds. |
| Guardian's Chestplate | Top | 100 fragments | Stone and gold armor piece. Heavy. Ceremonial but protective. |
| Spirit-Thread Pants | Bottom | 40 fragments | Dark with thin luminous thread woven through. |
| Sealed Boots | Feet | 45 fragments | Heavy stone-and-leather. Glowing hieroglyphs on the soles. |
| Death Mask (decorative) | Face | 60 fragments | Gold face covering. Anubis-inspired. Terrifying. |
| Crown of Judgment | Head | 120 fragments | Gold circlet with an eye-of-Horus centerpiece. Glows in dark areas. |
| Dream-Touched Cloak | Outer | 90 fragments | Fabric shifts color slowly — dark purple to deep blue to black. |
| Glowing Arm Bands | Hands | 35 fragments | Gold with embedded crystals that pulse with Dream energy. |
| Ankh of Passage | Neckwear | 70 fragments | Required to access the deepest chambers. Functional + cosmetic. |
| Spirit Lantern | Accessory | 25 fragments | Handheld. Glows. Reveals hidden inscriptions on walls. |

### Tradition
Nothing is *bought* here — it's **earned through trials**. Each item requires defeating a specific spirit guardian or solving a tomb puzzle. The automaton simply holds the rewards. Wearing underground gear on the surface makes NPCs uneasy — "Where did you GET that?"

---

## Region 7: COSMIC PLANET — Alien Artifacts

### Shop: **No shop. Found items only.**
Alien artifacts are discovered in the environment — growing from crystal formations, left by previous visitors, or gifted by entities. You can't buy cosmic fashion. You *find* it.

### Style DNA
Not clothing in the traditional sense — **energy constructs and crystalline accessories** that attach to your existing outfit. Light-based, geometric, otherworldly. They look wrong on Earth because they *are* wrong on Earth.

### Key Items

| Item | Slot | Price | Description |
|---|---|---|---|
| Crystal Shoulder Guard | Outer | found | Floating crystalline structure above one shoulder. Hums. |
| Light-Construct Cloak | Outer | found | A cloak made of solidified light. Slightly transparent. Moves like fabric but isn't. |
| Void Visor | Face | found | Dark translucent visor that forms over the eyes. Shows star maps. |
| Starfield Hair Clip | Head | found | Small crystal that makes your hair shimmer with stars. Subtle. |
| Energy Gauntlet | Hands | found | Light construct over one forearm. Functions as a tool/weapon. |
| Gravity Boots | Feet | found | Your existing shoes + floating ankle rings. Allows double-jump. |
| Nebula Scarf | Neckwear | found | Flowing fabric that shows a tiny nebula pattern moving inside it. |
| Cosmic Ring | Accessory | found | Small ring. When activated, projects a tiny holographic solar system above your hand. |
| Bioluminescent Tattoo | Face/Body | found | Applied by an alien plant. Glowing patterns under the skin. Permanent. |

### Tradition
There is no tradition because no one *lives* here permanently. Cosmic items are trophies — proof you went to another world and came back. On Earth, they draw stares, questions, and occasionally fear.

---

## Mix & Match Rules

### What Happens When You Cross-Dress Regions

| Combo | NPC Reaction |
|---|---|
| Full Neighborhood set in Medieval Town | "What... are you wearing?" (curiosity, slight mockery) |
| Egyptian headdress + hoodie + jeans | "That's a bold choice." (amused, some respect for confidence) |
| Full Egyptian set in Neighborhood | "Halloween's not for six months." / "Actually... that looks kinda fire." |
| Medieval cloak + modern sneakers | "Practical AND dramatic. I respect it." |
| Underground glowing gear anywhere | Unease. "Where did you find that?" Conversation unlocks. |
| Cosmic items on Earth | Fear, awe, or fascination depending on the NPC. Quest triggers. |
| Full regional set in its own region | Discount at shops, unique dialogue, NPC warmth, set bonus animation |

### Set Bonuses (Cosmetic)

| Full Set | Bonus |
|---|---|
| **Neighborhood** | Unique idle: checks phone, adjusts cap |
| **Old Shore** | Unique idle: stretches, watches waves, skips a stone |
| **Medieval** | Unique idle: rests hand on sword pommel, adjusts cloak |
| **Egyptian** | Unique idle: regal posture, touches collar, commands attention |
| **Sand Village** | Unique idle: shields eyes from sun, adjusts headwrap |
| **Underground** | Unique idle: items glow brighter, character looks wary |
| **Cosmic** | Unique idle: small energy crackle, looks at the sky like they're remembering |

---

## Integration with CharacterRig Socket System

Every item maps directly to the existing equipment socket architecture:

```
CharacterRig
├── Skeleton
│   ├── head_top        → Head slot items
│   ├── hair_root       → Hairstyles
│   ├── face_front      → Face items (masks, goggles, kohl)
│   ├── neck            → Neckwear
│   ├── torso_upper     → Top slot
│   ├── torso_outer     → Outer layer (cloaks, jackets)
│   ├── hand_L/hand_R   → Gloves, bracers, rings
│   ├── torso_lower     → Bottom slot
│   ├── foot_L/foot_R   → Footwear
│   ├── spine_upper     → Back slot (weapons, packs, cloaks attach)
│   └── accessory_1-3   → Belts, pouches, charms
```

Each clothing item is a `PackedScene` that:
1. Attaches to its socket bone
2. Hides/replaces the default body mesh for that region
3. Applies its own material (using the toon shader with region-appropriate colors)
4. Stores metadata: `region_id`, `set_id`, `cultural_rank`, `price`, `currency_type`
