class_name PowerCatalog
extends RefCounted
## Static repository of data definitions for the Rolling Tides Power System.
## Provides data-driven access to Universal abilities, Mutation affinities,
## Magic disciplines, Races, Adaptations, Transformations, Fusions, and Gear.

# ----------------- 1. Universal Physical Abilities -----------------
static func get_universal_abilities() -> Dictionary:
	return {
		"strength": {
			"id": "strength", "name": "Superhuman Strength", "source": "Universal",
			"description": "Raw muscular and kinetic force output.",
			"stat": "strength", "synergy_elements": ["flame", "earth"]
		},
		"speed": {
			"id": "speed", "name": "Superhuman Speed", "source": "Universal",
			"description": "Locomotive velocity and sprint acceleration.",
			"stat": "speed", "synergy_elements": ["lightning", "wind"]
		},
		"resistance": {
			"id": "resistance", "name": "Superhuman Resistance", "source": "Universal",
			"description": "Physical durability, bone density, and impact absorption.",
			"stat": "resistance", "synergy_elements": ["earth", "flame"]
		},
		"mobility": {
			"id": "mobility", "name": "Supernatural Mobility / Flight", "source": "Universal",
			"description": "Aerial movement, double jumps, and glide control.",
			"stat": "mobility", "synergy_elements": ["wind", "light"]
		},
		"reflex": {
			"id": "reflex", "name": "Superhuman Reflexes", "source": "Universal",
			"description": "Sensory reaction time and dodge window duration.",
			"stat": "reflex", "synergy_elements": ["lightning", "light"]
		},
		"agility": {
			"id": "agility", "name": "Superhuman Agility", "source": "Universal",
			"description": "Balance, airborne turning radius, and recovery speed.",
			"stat": "agility", "synergy_elements": ["wind", "water"]
		},
		"senses": {
			"id": "senses", "name": "Enhanced Senses", "source": "Universal",
			"description": "Perception range, enemy detection, and spatial awareness.",
			"stat": "senses", "synergy_elements": ["light", "dark"]
		},
		"stamina": {
			"id": "stamina", "name": "Endless Stamina", "source": "Universal",
			"description": "Energy reserve pool and anaerobic endurance.",
			"stat": "stamina", "synergy_elements": ["water", "earth"]
		},
		"recovery": {
			"id": "recovery", "name": "Rapid Recovery", "source": "Universal",
			"description": "Natural cellular regeneration and exhaustion recovery.",
			"stat": "recovery", "synergy_elements": ["water", "light"]
		}
	}

# ----------------- 2. Races -----------------
static func get_races() -> Dictionary:
	return {
		"human": {
			"id": "human",
			"display_name": "Human",
			"description": "Adaptable, versatile survivor capable of learning any discipline through dedicated training.",
			"stat_modifiers": {"stamina": 1.15, "recovery": 1.1},
			"natural_affinities": ["none"],
			"race_transformation_id": "human_transcendent",
			"required_race_mastery_for_transform": 70.0
		},
		"wolf_beastfolk": {
			"id": "wolf_beastfolk",
			"display_name": "Wolf Beastfolk",
			"description": "Predatory hunter with heightened instincts, swift reflex, and keen nocturnal senses.",
			"stat_modifiers": {"speed": 1.25, "reflex": 1.3, "senses": 1.35},
			"natural_affinities": ["lightning", "wind"],
			"race_transformation_id": "wolf_ancestral",
			"required_race_mastery_for_transform": 50.0
		},
		"dragon_kin": {
			"id": "dragon_kin",
			"display_name": "Dragon-Kin",
			"description": "Ancient draconic lineage endowed with thermal resistance and devastating kinetic power.",
			"stat_modifiers": {"strength": 1.3, "resistance": 1.35},
			"natural_affinities": ["flame", "earth"],
			"race_transformation_id": "dragon_ancestral",
			"required_race_mastery_for_transform": 55.0
		},
		"elf": {
			"id": "elf",
			"display_name": "Elf",
			"description": "Mystical, long-lived scholars whose souls naturally synchronize with mana flow.",
			"stat_modifiers": {"agility": 1.2, "senses": 1.25},
			"natural_affinities": ["light", "wind"],
			"race_transformation_id": "elf_ancestral",
			"required_race_mastery_for_transform": 60.0
		},
		"dwarf": {
			"id": "dwarf",
			"display_name": "Dwarf",
			"description": "Dense, resilient subterranean builders with unyielding kinetic endurance.",
			"stat_modifiers": {"resistance": 1.4, "strength": 1.2},
			"natural_affinities": ["earth"],
			"race_transformation_id": "dwarf_ancestral",
			"required_race_mastery_for_transform": 55.0
		},
		"ancient_cousin": {
			"id": "ancient_cousin",
			"display_name": "Ancient Cousin",
			"description": "Distant evolutionary kin of humanity from another world. Possesses dormant ancestral biology awakened through Primal Form.",
			"stat_modifiers": {"strength": 1.3, "speed": 1.25, "reflex": 1.3, "recovery": 1.25},
			"natural_affinities": ["lightning", "flame"],
			"race_transformation_id": "ancient_primal",
			"required_race_mastery_for_transform": 50.0
		}
	}

# ----------------- 3. Mutation Affinities (Body) -----------------
static func get_mutation_affinities() -> Dictionary:
	return {
		"flame": {
			"id": "flame",
			"display_name": "Flame Mutation",
			"description": "Biological thermogenesis. The body generates and channels superheated kinetic energy.",
			"source": "Body",
			"element": "flame",
			"ability_ids_early": ["mut_flame_heat_res", "mut_flame_heated_strikes"],
			"ability_ids_developed": ["mut_flame_fire_burst", "mut_flame_propulsion"],
			"ability_ids_advanced": ["mut_flame_partial_convert"],
			"ability_ids_mastered": ["mut_flame_body_mastery"],
			"transformation_id": "flame_body"
		},
		"lightning": {
			"id": "lightning",
			"display_name": "Lightning Mutation",
			"description": "Neural hyper-conductivity. Electrical currents accelerate reflexes and motor reflexes.",
			"source": "Body",
			"element": "lightning",
			"ability_ids_early": ["mut_light_neuro_reflex", "mut_light_spark_touch"],
			"ability_ids_developed": ["mut_light_spark_dash", "mut_light_charged_strike"],
			"ability_ids_advanced": ["mut_light_burst_acceleration"],
			"ability_ids_mastered": ["mut_light_body_mastery"],
			"transformation_id": "lightning_body"
		}
	}

# ----------------- 4. Magic Disciplines (Soul) -----------------
static func get_magic_disciplines() -> Dictionary:
	return {
		"flame": {
			"id": "flame",
			"display_name": "Flame Evocation",
			"description": "Channeling soul energy into combustive atmospheric flame arcs.",
			"source": "Soul",
			"element": "flame",
			"ability_ids_early": ["mag_flame_ember_bolt"],
			"ability_ids_developed": ["mag_flame_fire_ward", "mag_flame_column"],
			"ability_ids_advanced": ["mag_flame_pyro_lance"],
			"ability_ids_mastered": ["mag_flame_supernova"],
			"transformation_id": "astral_attunement"
		},
		"lightning": {
			"id": "lightning",
			"display_name": "Lightning Thaumaturgy",
			"description": "Manipulating ionic atmospheric potentials to call down lightning strikes.",
			"source": "Soul",
			"element": "lightning",
			"ability_ids_early": ["mag_light_arc_bolt"],
			"ability_ids_developed": ["mag_light_chain_surge", "mag_light_barrier"],
			"ability_ids_advanced": ["mag_light_storm_call"],
			"ability_ids_mastered": ["mag_light_tempest"],
			"transformation_id": "astral_attunement"
		},
		"dark_spatial": {
			"id": "dark_spatial",
			"display_name": "Dark & Spatial Magic",
			"description": "Tapping into the Dream Realm void for displacement, shadow stepping, and spatial folds.",
			"source": "Soul",
			"element": "dark",
			"ability_ids_early": ["mag_dark_shadow_step"],
			"ability_ids_developed": ["mag_dark_void_pocket", "mag_dark_abyssal_snare"],
			"ability_ids_advanced": ["mag_dark_dimensional_rift"],
			"ability_ids_mastered": ["mag_dark_void_mastery"],
			"transformation_id": "astral_attunement"
		},
		"summoning": {
			"id": "summoning",
			"display_name": "Dream Summoning",
			"description": "Forging soul pacts with ethereal spirits, beasts, and Dream Realm companions.",
			"source": "Soul",
			"element": "spirit",
			"ability_ids_early": ["mag_sum_dream_sprite"],
			"ability_ids_developed": ["mag_sum_astral_hound", "mag_sum_spirit_shield"],
			"ability_ids_advanced": ["mag_sum_flying_gryphon"],
			"ability_ids_mastered": ["mag_sum_ancient_colossus"],
			"transformation_id": "astral_attunement"
		}
	}

# ----------------- 5. Adaptations (Tier II) -----------------
static func get_adaptations() -> Dictionary:
	return {
		"physical": {
			"id": "physical",
			"display_name": "Physical Adaptation",
			"description": "Heavy cellular hardening against blunt force, bullets, falls, and sharp blade impacts.",
			"damage_reductions": {"blunt": 0.45, "slash": 0.4, "impact": 0.5, "fall": 0.3},
			"status_resistances": ["bleed", "fracture", "stagger"]
		},
		"soul": {
			"id": "soul",
			"display_name": "Soul Adaptation",
			"description": "Spiritual warding insulating against supernatural status effects, curses, and Dream Realm distortion.",
			"damage_reductions": {"magic": 0.5, "dark": 0.55, "elemental": 0.45},
			"status_resistances": ["curse", "soul_drain", "confusion", "nightmare"]
		}
	}

# ----------------- 6. Transformations (3 Axes + Fusions) -----------------
static func get_transformations() -> Dictionary:
	return {
		# Axis 1: Race Forms (What I Am)
		"wolf_ancestral": {
			"id": "wolf_ancestral",
			"display_name": "Ancestral Wolf Form",
			"axis": "race",
			"description": "Unlocks the primal beast within. Senses, sprint speed, and claw agility surge dramatically.",
			"stat_multipliers": {"speed": 1.5, "reflex": 1.4, "agility": 1.4, "jump": 1.3},
			"energy_drain_per_sec": 6.0,
			"base_duration": 30.0,
			"aura_color": Color(0.2, 0.65, 0.95, 0.45),
			"aura_emission_energy": 1.6,
			"particle_effect_style": "feral",
			"cosmetic_socket_attachment": "wolf_features",
			"full_model_path": "res://character/transformations/wolf_beast_full.glb",
			"special_ability": "feral_slash"
		},
		"dragon_ancestral": {
			"id": "dragon_ancestral",
			"display_name": "Ancestral Dragon Form",
			"axis": "race",
			"description": "Ignites the slumbering dragon bloodline. Grants armored scales, draconic horns, wings, and devastating breath.",
			"stat_multipliers": {"strength": 1.7, "resistance": 1.8, "speed": 1.2, "jump": 1.4},
			"energy_drain_per_sec": 6.5,
			"base_duration": 28.0,
			"aura_color": Color(1.0, 0.3, 0.05, 0.45),
			"aura_emission_energy": 1.8,
			"particle_effect_style": "dragon_fire",
			"cosmetic_socket_attachment": "dragon_features",
			"full_model_path": "res://character/transformations/dragon_drake_full.glb",
			"special_ability": "inferno_breath"
		},
		"elf_ancestral": {
			"id": "elf_ancestral",
			"display_name": "Ancestral High Elf Form",
			"axis": "race",
			"description": "Resonates with ancient Dream mana. Heightens supernatural agility, celestial halos, and restorative nature surges.",
			"stat_multipliers": {"recovery": 2.2, "agility": 1.6, "mobility": 1.5, "reflex": 1.4},
			"energy_drain_per_sec": 5.5,
			"base_duration": 32.0,
			"aura_color": Color(0.15, 0.95, 0.55, 0.45),
			"aura_emission_energy": 1.8,
			"particle_effect_style": "nature_astral",
			"cosmetic_socket_attachment": "elf_features",
			"full_model_path": "res://character/transformations/elf_astral_full.glb",
			"special_ability": "nature_surge"
		},
		"dwarf_ancestral": {
			"id": "dwarf_ancestral",
			"display_name": "Ancestral Stone Dwarf Form",
			"axis": "race",
			"description": "Hardens skin and bone into living subterranean bedrock with heavy runic shoulder armor and seismic shockwaves.",
			"stat_multipliers": {"resistance": 2.2, "strength": 1.6, "recovery": 1.3},
			"energy_drain_per_sec": 6.0,
			"base_duration": 30.0,
			"aura_color": Color(0.75, 0.45, 0.18, 0.45),
			"aura_emission_energy": 1.6,
			"particle_effect_style": "runic_earth",
			"cosmetic_socket_attachment": "dwarf_features",
			"full_model_path": "res://character/transformations/dwarf_champion_full.glb",
			"special_ability": "earth_tremor"
		},
		"human_transcendent": {
			"id": "human_transcendent",
			"display_name": "Apex Human Transcendence",
			"axis": "race",
			"description": "Unlocks the apex human potential through sheer willpower and training. Grants all-round stat boosts and adrenaline rushes.",
			"stat_multipliers": {"strength": 1.35, "speed": 1.35, "resistance": 1.35, "reflex": 1.35, "recovery": 1.5},
			"energy_drain_per_sec": 5.0,
			"base_duration": 35.0,
			"aura_color": Color(1.0, 0.85, 0.25, 0.40),
			"aura_emission_energy": 1.6,
			"particle_effect_style": "transcendent_gold",
			"cosmetic_socket_attachment": "human_features",
			"full_model_path": "res://character/transformations/human_transcendent_full.glb",
			"special_ability": "adrenaline_surge"
		},
		"ancient_primal": {
			"id": "ancient_primal",
			"display_name": "Ancient Primal Form",
			"axis": "race",
			"description": "Awakens dormant ancestral biology. Preserves the character's base body and clothing while igniting dramatic gold lightning hair highlights, a 3-part electric-blue and fiery-orange aura, and glowing organic ancestral markings.",
			"stat_multipliers": {"strength": 1.8, "speed": 1.6, "resistance": 1.6, "reflex": 1.7, "recovery": 1.5},
			"energy_drain_per_sec": 5.0,
			"base_duration": 35.0,
			"keep_base_body": true,
			"aura_color": Color(0.12, 0.72, 1.0, 0.45),
			"aura_inner_color": Color(1.0, 0.42, 0.05, 0.65),
			"lightning_color": Color(1.0, 0.88, 0.25),
			"aura_emission_energy": 2.6,
			"particle_effect_style": "ancient_primal",
			"cosmetic_socket_attachment": "ancient_primal_features",
			"special_ability": "ancestral_shockwave"
		},
		"ancient_primal_dark": {
			"id": "ancient_primal_dark",
			"display_name": "Dark Primal Form",
			"axis": "race",
			"description": "Uncontrolled ancestral survival surge. Erupts into wild white hair, glowing red eyes, crimson ancestral markings, and unstable dark energy.",
			"stat_multipliers": {"strength": 2.2, "speed": 1.8, "resistance": 1.4, "reflex": 1.9, "recovery": 1.1},
			"energy_drain_per_sec": 7.5,
			"base_duration": 25.0,
			"keep_base_body": true,
			"aura_color": Color(0.85, 0.05, 0.12, 0.6),
			"aura_inner_color": Color(0.12, 0.02, 0.04, 0.85),
			"lightning_color": Color(1.0, 0.2, 0.1),
			"aura_emission_energy": 3.0,
			"particle_effect_style": "dark_primal",
			"cosmetic_socket_attachment": "ancient_dark_features",
			"special_ability": "ancestral_shockwave"
		},
		# Axis 2: Mutation Forms
		"flame_body": {
			"id": "flame_body",
			"display_name": "Flame Body Transformation",
			"axis": "mutation",
			"description": "The physical body ignites into living plasma. Attacks deal explosive kinetic fire damage.",
			"stat_multipliers": {"strength": 1.8, "speed": 1.3, "resistance": 1.4},
			"energy_drain_per_sec": 8.0,
			"base_duration": 25.0,
			"aura_color": Color(1.0, 0.35, 0.05, 0.75),
			"aura_emission_energy": 3.0,
			"particle_effect_style": "flame",
			"cosmetic_socket_attachment": ""
		},
		"lightning_body": {
			"id": "lightning_body",
			"display_name": "Lightning Body Transformation",
			"axis": "mutation",
			"description": "Cells oscillate at electrical frequencies. Enables near-instantaneous burst traversal.",
			"stat_multipliers": {"speed": 2.2, "reflex": 2.0, "jump": 1.5},
			"energy_drain_per_sec": 8.5,
			"base_duration": 22.0,
			"aura_color": Color(0.15, 0.85, 1.0, 0.8),
			"aura_emission_energy": 3.2,
			"particle_effect_style": "lightning",
			"cosmetic_socket_attachment": ""
		},
		# Axis 3: Magic Form
		"astral_attunement": {
			"id": "astral_attunement",
			"display_name": "Astral Soul Attunement",
			"axis": "magic",
			"description": "The soul expands outward, synchronizing casting speed and empowering supernatural disciplines.",
			"stat_multipliers": {"recovery": 2.0, "resistance": 1.3, "mobility": 1.4},
			"energy_drain_per_sec": 7.0,
			"base_duration": 28.0,
			"aura_color": Color(0.7, 0.3, 1.0, 0.65),
			"aura_emission_energy": 2.5,
			"particle_effect_style": "astral",
			"cosmetic_socket_attachment": ""
		},
		# Tier VI Fusions
		"lightning_beast": {
			"id": "lightning_beast",
			"display_name": "Lightning Beast (Race + Mutation)",
			"axis": "fusion",
			"description": "Synchronization between Ancestral Wolf and Lightning Mutation. Thunderous predatory velocity.",
			"fusion_requirements": {"race": "wolf_beastfolk", "mutation": "lightning"},
			"stat_multipliers": {"speed": 2.6, "reflex": 2.4, "strength": 1.6, "jump": 1.8},
			"energy_drain_per_sec": 12.0,
			"base_duration": 20.0,
			"aura_color": Color(0.4, 0.95, 1.0, 0.9),
			"aura_emission_energy": 4.5,
			"particle_effect_style": "lightning_feral",
			"cosmetic_socket_attachment": "wolf_features",
			"special_ability": "thunder_claw_barrage"
		},
		"inferno_dragon": {
			"id": "inferno_dragon",
			"display_name": "Inferno Dragon (Race + Mutation)",
			"axis": "fusion",
			"description": "Synchronization between Dragon-Kin and Flame Mutation. Colossal fiery resilience and cataclysmic breath.",
			"fusion_requirements": {"race": "dragon_kin", "mutation": "flame"},
			"stat_multipliers": {"strength": 2.5, "resistance": 2.2, "speed": 1.4},
			"energy_drain_per_sec": 12.0,
			"base_duration": 20.0,
			"aura_color": Color(1.0, 0.2, 0.0, 0.9),
			"aura_emission_energy": 4.5,
			"particle_effect_style": "flame",
			"cosmetic_socket_attachment": "dragon_features",
			"special_ability": "calamity_inferno"
		}
	}

# ----------------- 7. Gear & Artificial Powers -----------------
static func get_gear_powers() -> Dictionary:
	return {
		"rocket_boots": {
			"id": "rocket_boots", "name": "Pneumatic Rocket Boots",
			"type": "mobility", "description": "Equipped boots providing a 14 m/s vertical burst impulse.",
			"stat_modifiers": {"jump": 1.6}
		},
		"kinetic_barrier": {
			"id": "kinetic_barrier", "name": "Deployable Kinetic Shield",
			"type": "defensive", "description": "Micro-generator projecting a solid force field absorbing up to 150 damage.",
			"stat_modifiers": {"resistance": 1.5}
		}
	}

static func get_artificial_powers() -> Dictionary:
	return {
		"strength_serum": {
			"id": "strength_serum", "name": "Titan Muscle Serum (Artificial)",
			"description": "Chemically stimulates fast-twitch muscle fibres, temporarily granting +80% strength.",
			"total_duration": 30.0,
			"stat_modifiers": {"strength": 1.8},
			"strain_penalty": {"stamina_recovery": 0.5, "fatigue": 20.0}
		},
		"lightning_stimulant": {
			"id": "lightning_stimulant", "name": "Neural Overclock Inhaler (Artificial)",
			"description": "Artificially spikes synaptic conduction, granting high-speed reflex for 25 seconds.",
			"total_duration": 25.0,
			"stat_modifiers": {"speed": 1.5, "reflex": 1.6},
			"strain_penalty": {"energy_loss": 15.0}
		}
	}
