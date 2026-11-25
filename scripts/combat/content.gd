class_name Content
extends RefCounted
## Paths and loaders for the slice's placeholder content.

const CHARACTER_IDS := ["kael", "mira", "ren", "tess", "oda", "vey"]
const WARDEN := "res://data/bosses/warden.tres"
const WARDEN_ATTACKS := [
	"res://data/bosses/warden_attacks/crushing_swing.tres",
	"res://data/bosses/warden_attacks/flurry.tres",
	"res://data/bosses/warden_attacks/shockwave.tres",
]


static func character(id: String) -> BattlerData:
	return load("res://data/characters/%s.tres" % id)


## Fresh party at full HP. kael, mira, ren, tess active; oda, vey on the bench.
static func build_party() -> Party:
	var members: Array[Battler] = []
	for id in CHARACTER_IDS:
		members.append(Battler.new(character(id)))
	return Party.new(members)


static func warden() -> BattlerData:
	return load(WARDEN)


static func warden_attacks() -> Array[BossAttack]:
	var out: Array[BossAttack] = []
	for p in WARDEN_ATTACKS:
		out.append(load(p))
	return out
