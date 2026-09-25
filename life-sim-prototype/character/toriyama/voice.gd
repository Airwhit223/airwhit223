class_name ToriyamaVoice
extends RefCounted
## Babble voice - a made-up language in the spirit of Animal Crossing / Simlish. The syllables are synthesised from
## scratch (Blender-side pipeline: work/voice/voice_synth.py -> res://audio/voice/syllables/<consonant><vowel>.wav,
## 180 Hz). Each character has their own pitch and pace; the words they "say" follow the real dialogue text:
##   - every word maps to the same syllables every time (so it sounds like a language, not noise)
##   - the syllable vowels follow the word's own vowels, so the drawn / modelled mouth shapes agree with the sound
##   - sentences drift down, questions rise at the end, exclamations lift and get louder
## Offline preview of the same rules: work/voice/voice_demo.py -> outputs/voice/demo.wav.

const BANK_DIR := "res://audio/voice/syllables/"
const CONSONANTS := ["b", "d", "g", "p", "t", "k", "m", "n", "s", "h", "l", "r", "w", "y"]
const VOWEL_OF := {"a": "a", "e": "e", "i": "i", "o": "o", "u": "u", "y": "i"}
## Mouth frame for each vowel (ToriyamaCharacter.ANIME_MOUTH_FRAMES talk shapes).
const MOUTH_OF := {"a": "talk_a", "e": "talk_e", "i": "talk_e", "o": "talk_o", "u": "talk_o"}
const OVERLAP := 0.88              # syllables run into each other a little, like speech
const WORD_GAP := 0.045
const COMMA_GAP := 0.16
const SENTENCE_GAP := 0.30
## Characters on the feminine base (tr_factions.py specs); everyone else gets the lower range.
const FEMININE := ["June", "Marta", "Nia", "Zuri", "Imani", "Ada", "Vex", "Blair", "Kira", "Maya"]

static var _bank: Dictionary = {}

var pitch := 1.0                   # pitch_scale of the whole voice (also speeds it, as in Animal Crossing)
var speed := 1.0                   # extra pace on top

static func sample(syllable: String) -> AudioStream:
	if not _bank.has(syllable):
		var path := BANK_DIR + syllable + ".wav"
		_bank[syllable] = load(path) if ResourceLoader.exists(path) else null
	return _bank[syllable]

## A stable voice for an identity: the same name always gets the same voice.
static func for_identity(identity: String, feminine: bool) -> ToriyamaVoice:
	var v := ToriyamaVoice.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = identity.hash()
	v.pitch = rng.randf_range(1.12, 1.38) if feminine else rng.randf_range(0.82, 1.02)
	v.speed = rng.randf_range(0.95, 1.12)
	return v

static func for_character(character_name: String) -> ToriyamaVoice:
	return for_identity(character_name, character_name in FEMININE)

## Text -> syllables: [{name, mouth, pitch, loud, gap}] where gap is the silence after it (seconds).
func plan(line: String) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("[A-Za-z']+|[.,!?]")
	var vowel_re := RegEx.new()
	vowel_re.compile("[aeiouy]+")
	var tokens: Array = []
	for m in re.search_all(line):
		tokens.append(m.get_string())
	var stripped := line.strip_edges()
	var question := stripped.ends_with("?")
	var exclaim := stripped.ends_with("!")
	var total := 0
	for t in tokens:
		if t[0] not in ".,!?":
			total += 1
	var wi := 0
	for t in tokens:
		if t[0] in ".,!?":
			if not out.is_empty():
				out[-1]["gap"] = COMMA_GAP if t == "," else SENTENCE_GAP
			continue
		var w: String = t.to_lower().replace("'", "")
		var groups: Array = []
		for g in vowel_re.search_all(w):
			groups.append(g.get_string())
		if groups.is_empty():
			groups = ["a"]
		for i in mini(groups.size(), 4):
			var h: int = absi(("%s:%d" % [w, i]).hash())
			var starts_vowel: bool = i == 0 and w.length() > 0 and w[0] in "aeiou"
			var c: String = "" if (starts_vowel and h % 3 == 0) else CONSONANTS[h % CONSONANTS.size()]
			var v: String = VOWEL_OF.get(String(groups[i])[0], "a")
			var prog := float(wi) / maxf(1.0, float(total - 1))
			var p := 1.04 - 0.08 * prog + (0.03 if i == 0 else 0.0)
			if question and wi >= total - 2:
				p += 0.07 + 0.05 * i
			if exclaim:
				p += 0.04
			out.append({"name": c + v, "mouth": MOUTH_OF[v], "pitch": p, "loud": 1.15 if exclaim else 1.0, "gap": 0.0})
		out[-1]["gap"] = WORD_GAP
		wi += 1
	return out

## Wordless chatter for `seconds` (NPCs socialising): made-up words from a small fixed lexicon, so even idle
## chatter repeats "words" like a real language would.
func plan_babble(seconds: float) -> Array:
	var lexicon := ["hey", "yeah", "totally", "maybe", "later", "really", "nice", "okay", "tomorrow", "weird",
		"honestly", "no", "right", "sure", "wait", "listen", "what", "cool", "anyway", "seriously"]
	var words: Array = []
	var est := 0.0
	while est < seconds:
		var w: String = lexicon[randi() % lexicon.size()]
		words.append(w)
		est += 0.14 * maxf(1.0, float(w.length()) / 3.0) + WORD_GAP
	var line := " ".join(words) + ("?" if randf() < 0.3 else ".")
	return plan(line)

## How long one planned syllable takes at this voice (sample length / playback rate, overlapped).
func duration(syl: Dictionary) -> float:
	var s := sample(String(syl["name"]))
	var rate := pitch * float(syl["pitch"]) * speed
	var length := s.get_length() if s else 0.12
	return length / rate * OVERLAP
