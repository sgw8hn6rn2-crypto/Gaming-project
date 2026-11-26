extends TestCase

const CHARS := ["kael", "mira", "ren", "tess", "oda", "vey"]


func test_six_characters_load() -> void:
	for id in CHARS:
		var d: BattlerData = load("res://data/characters/%s.tres" % id)
		assert_true(d != null, id)
		if d == null:
			continue
		assert_eq(d.id, StringName(id))
		assert_true(d.skills.size() >= 1, "%s has a skill" % id)
		assert_true(d.max_hp > 0)


func test_warden_loads() -> void:
	var w: BattlerData = load("res://data/bosses/warden.tres")
	assert_true(w != null)
	if w:
		assert_eq(w.id, &"warden")
		assert_eq(w.max_hp, 600)


func test_warden_attacks_readable() -> void:
	var atks := Content.warden_attacks()
	assert_eq(atks.size(), 3)
	var any_wide := false
	for a in atks:
		assert_true(a.hit_times.size() >= 1)
		assert_true(a.hit_times[0] >= 0.5, "%s winds up for at least 0.5 s" % a.id)
		any_wide = any_wide or a.party_wide
	assert_true(any_wide)


func test_party_builder_slots() -> void:
	var p := Content.build_party()
	assert_eq(p.active[0].data.id, &"kael")
	assert_eq(p.bench[0].data.id, &"oda")
	assert_eq(p.bench[1].data.id, &"vey")
