extends Control
## Battle view. Draws placeholder art, measures button timing against its own
## clock and feeds press deltas to BattleController.

signal finished(victory: bool)

const BOSS_ID := &"warden"
const ATTACK_IMPACT := 0.5           # seconds from prompt start to impact
const ATTACK_LATE_LIMIT := 0.4       # no press by impact + this = no press
const DEFENSE_RESOLVE_AFTER := DefenseInput.RESOLVE_AFTER  # judge each hit this long after it lands
const SQUARE_LEAD := 0.6             # the defense square starts closing this long before each hit
const END_DELAY := 1.6
const DEBUG_LOSS_PRESETS := [0, 4, 11, 21]
const SAVE_POINT_SCENE := "res://scenes/save_point/save_point.tscn"
const DEFEAT_SCENE := "res://scenes/defeat/defeat.tscn"

enum Mode { NONE, ATTACK_TIMING, DEFENSE, ENDED }

const BOSS_RECT := Rect2(40, 30, 56, 66)
const SLOT_ORIGIN := Vector2(164, 54)
const SLOT_SIZE := Vector2(20, 28)
const SLOT_STEP := 37.0

var ctrl: BattleController
var party: Party
var boss: Battler

var _mode: Mode = Mode.NONE
var _t0 := 0.0
var _attack_press := -1.0
var _defense: DefenseInput
var _hit_sampled: Array[bool] = []
var _hit_resolved: Array[bool] = []
var _flash: Dictionary = {}  # Battler -> seconds left
var _boss_offset := Vector2.ZERO
var _debug_preset := 0
var _victory_wait := false

var _timeline
var _panel
var _menu
var _prompt
var _message: Label
var _hint: Label


func _ready() -> void:
	var t := Theme.new()
	t.default_font_size = 8
	theme = t

	_timeline = _add_ui("res://scenes/battle/ui/timeline_bar.gd", Rect2(0, 0, 320, 14))
	_panel = _add_ui("res://scenes/battle/ui/party_panel.gd", Rect2(126, 118, 192, 60))
	_menu = _add_ui("res://scenes/battle/ui/action_menu.gd", Rect2(2, 118, 120, 60))
	_prompt = _add_ui("res://scenes/battle/ui/timing_prompt.gd", Rect2(0, 0, 320, 180))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message = _add_label(Rect2(130, 100, 188, 12), HORIZONTAL_ALIGNMENT_CENTER)
	_hint = _add_label(Rect2(0, 16, 316, 10), HORIZONTAL_ALIGNMENT_RIGHT)
	_hint.modulate = Color(1, 1, 1, 0.6)
	_menu.hide()
	_menu.attack_chosen.connect(func() -> void: ctrl.choose_attack())
	_menu.skill_chosen.connect(_on_skill_chosen)
	_menu.item_chosen.connect(_on_item_chosen)
	_menu.swap_chosen.connect(_on_swap_chosen)

	party = Content.build_party()
	boss = Battler.new(Content.warden())
	var start_hp: int = GameState.pending_boss_start_hp
	GameState.pending_boss_start_hp = -1
	GameState.last_boss_id = BOSS_ID
	ctrl = BattleController.new(party, boss, Content.warden_attacks(), randi(), start_hp)
	ctrl.phase_changed.connect(_on_phase_changed)
	ctrl.actor_changed.connect(func(_a: Battler) -> void: _refresh())
	ctrl.damage_dealt.connect(_on_damage)
	ctrl.healed.connect(_on_healed)
	ctrl.enemy_attack_started.connect(_on_enemy_attack)
	ctrl.swapped.connect(func(_o: Battler, _i: Battler) -> void: _refresh())
	ctrl.battle_ended.connect(_on_battle_ended)
	_debug_preset = DEBUG_LOSS_PRESETS.find(GameState.loss_assist.losses(BOSS_ID))
	ctrl.start()
	_refresh()


func _add_ui(script_path: String, r: Rect2) -> Control:
	var c := Control.new()
	c.set_script(load(script_path))
	c.position = r.position
	c.size = r.size
	add_child(c)
	return c


func _add_label(r: Rect2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	add_child(l)
	return l


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


# --- Controller events -----------------------------------------------------

func _on_phase_changed(p: BattleController.Phase) -> void:
	match p:
		BattleController.Phase.PLAYER_CHOOSE:
			_mode = Mode.NONE
			_message.text = "%s's turn" % ctrl.actor.data.display_name
			_hint.text = ""
			_menu.open(ctrl)
		BattleController.Phase.PLAYER_TIMING:
			_mode = Mode.ATTACK_TIMING
			_t0 = _now()
			_attack_press = -1.0
			_message.text = "Press when the ring closes!"
		BattleController.Phase.ENEMY_DEFENSE:
			_menu.close()
	_refresh()


func _on_enemy_attack(attack: BossAttack, targets: Array) -> void:
	_mode = Mode.DEFENSE
	_t0 = _now()
	var n := attack.hit_times.size()
	_defense = DefenseInput.new(attack.hit_times)
	_hit_sampled = []
	_hit_resolved = []
	for i in n:
		_hit_sampled.append(false)
		_hit_resolved.append(false)
	_message.text = attack.telegraph_text if attack.telegraph_text != "" else attack.display_name
	var styles := {}
	for t in targets:
		styles[(t as Battler).data.defense_style] = true
	_hint.text = _defense_hint(styles.keys())
	_refresh()


func _defense_hint(styles: Array) -> String:
	var parts: Array[String] = []
	for s in styles:
		match s:
			BattlerData.DefenseStyle.PARRY:
				parts.append("PARRY: tap on hit")
			BattlerData.DefenseStyle.DODGE:
				parts.append("DODGE: tap on hit")
			BattlerData.DefenseStyle.BLOCK:
				parts.append("BLOCK: hold through hit")
	return "  ".join(parts)


func _on_damage(target: Battler, amount: int, label: String) -> void:
	var text := str(amount) if amount > 0 else "0"
	if label != "":
		text = "%s %s" % [label, text] if amount > 0 else label
	_float_text(_anchor_for(target), text, Color.WHITE if target == boss else Color("#ff8a80"))
	_flash[target] = 0.15
	_refresh()


func _on_healed(target: Battler, amount: int) -> void:
	_float_text(_anchor_for(target), "+%d" % amount, Color("#69f0ae"))
	_refresh()


func _on_battle_ended(victory: bool) -> void:
	_mode = Mode.ENDED
	_menu.close()
	_prompt.ring_progress = -1.0
	_prompt.square_progress = -1.0
	_hint.text = ""
	if victory:
		GameState.loss_assist.record_victory(BOSS_ID)
		_message.text = "The Warden is defeated!"
	else:
		GameState.loss_assist.record_loss(BOSS_ID, boss.hp, boss.data.max_hp)
		_message.text = "Your party has fallen..."
	_refresh()
	await get_tree().create_timer(END_DELAY).timeout
	finished.emit(victory)
	if victory:
		_message.text = "The Warden is defeated!  Press action to continue."
		_victory_wait = true
	else:
		_change_scene(DEFEAT_SCENE)


func _change_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		get_tree().reload_current_scene()


# --- Menu events -----------------------------------------------------------

func _on_skill_chosen(skill: SkillData, target: Battler) -> void:
	if not ctrl.choose_skill(skill, target):
		_menu.open(ctrl)


func _on_item_chosen(item_id: String, target: Battler) -> void:
	if not ctrl.choose_item(item_id, target):
		_menu.open(ctrl)


func _on_swap_chosen(active_idx: int, bench_idx: int) -> void:
	ctrl.swap(active_idx, bench_idx)
	_message.text = "%s's turn" % ctrl.actor.data.display_name
	_menu.open(ctrl)
	_refresh()


# --- Input and timing ------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_losses"):
		_debug_preset = (_debug_preset + 1) % DEBUG_LOSS_PRESETS.size()
		var n: int = DEBUG_LOSS_PRESETS[_debug_preset]
		GameState.loss_assist.debug_set_losses(BOSS_ID, n)
		_float_text(Vector2(160, 24), "DEBUG: Warden losses = %d" % n, Color.ORANGE)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("action"):
		if _mode == Mode.DEFENSE and _defense:
			_defense.release()
		return
	if not event.is_action_pressed("action") or event.is_echo():
		return
	var now := _now()
	match _mode:
		Mode.ATTACK_TIMING:
			if _attack_press < 0.0:
				_attack_press = now
		Mode.DEFENSE:
			_defense.press(now - _t0)
		Mode.ENDED:
			if _victory_wait:
				_victory_wait = false
				_change_scene(SAVE_POINT_SCENE)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	for b in _flash.keys():
		_flash[b] -= delta
		if _flash[b] <= 0.0:
			_flash.erase(b)
	var now := _now()
	match _mode:
		Mode.ATTACK_TIMING:
			_process_attack(now)
		Mode.DEFENSE:
			_process_defense(now)
		_:
			_prompt.ring_progress = -1.0
			_prompt.square_progress = -1.0
			_boss_offset = Vector2.ZERO
	queue_redraw()


func _process_attack(now: float) -> void:
	var impact := _t0 + ATTACK_IMPACT
	_prompt.ring_center = BOSS_RECT.get_center()
	_prompt.ring_progress = (now - _t0) / ATTACK_IMPACT
	if _attack_press >= 0.0 and now >= impact:
		_mode = Mode.NONE
		_prompt.ring_progress = -1.0
		ctrl.resolve_player_timing(_attack_press - impact)
	elif now >= impact + ATTACK_LATE_LIMIT:
		_mode = Mode.NONE
		_prompt.ring_progress = -1.0
		ctrl.resolve_player_timing(INF)


func _process_defense(now: float) -> void:
	var attack := ctrl.pending_attack
	if attack == null:
		return
	var next_hit := INF
	for i in attack.hit_times.size():
		var hit_t := _t0 + attack.hit_times[i]
		if not _hit_sampled[i] and now >= hit_t:
			_hit_sampled[i] = true
			_defense.sample(i)
		if not _hit_resolved[i]:
			if hit_t > now:
				next_hit = minf(next_hit, hit_t)
			if now >= hit_t + DEFENSE_RESOLVE_AFTER:
				_hit_resolved[i] = true
				var r := _defense.result(i)
				ctrl.resolve_enemy_hit(i, r["delta"], r["held"], r["carried"])
				return  # the controller may have started a new turn
	# Square closes on each target and lands exactly on the next hit.
	_prompt.square_progress = -1.0
	if not is_inf(next_hit) and next_hit - now <= SQUARE_LEAD:
		_prompt.square_progress = 1.0 - (next_hit - now) / SQUARE_LEAD
	_prompt.square_centers.clear()
	for t in ctrl.pending_targets:
		var i := party.active.find(t)
		if i >= 0 and not (t as Battler).is_ko():
			_prompt.square_centers.append(_slot_rect(i).get_center())
	# Wind-up: lean back as the next hit approaches, then lunge.
	if is_inf(next_hit):
		_boss_offset = Vector2(10, 0)
	else:
		var k := clampf(1.0 - (next_hit - now) / 0.6, 0.0, 1.0)
		_boss_offset = Vector2(-6.0 * k, -2.0 * k)


# --- Drawing ---------------------------------------------------------------

func _slot_rect(i: int) -> Rect2:
	return Rect2(SLOT_ORIGIN + Vector2(i * SLOT_STEP, 0), SLOT_SIZE)


func _anchor_for(b: Battler) -> Vector2:
	if b == boss:
		return BOSS_RECT.get_center() + Vector2(0, -30)
	var i := party.active.find(b)
	if i >= 0:
		var r := _slot_rect(i)
		return Vector2(r.get_center().x, r.position.y - 4)
	return Vector2(250, 112)


func _refresh() -> void:
	if ctrl == null:
		return
	var current: Battler = ctrl.actor
	_timeline.show_order(ctrl.timeline.preview(6), current)
	_panel.refresh(party, current if current != boss else null)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("#1b1b26"))
	draw_rect(Rect2(0, 96, 320, 22), Color("#24243a"))
	if ctrl == null:
		return
	var font := get_theme_default_font()
	# Boss
	var br := Rect2(BOSS_RECT.position + _boss_offset, BOSS_RECT.size)
	var bcol := boss.data.color
	if _flash.has(boss):
		bcol = Color.WHITE
	if not boss.is_ko():
		draw_rect(br, bcol)
		draw_rect(Rect2(br.position + Vector2(10, 14), Vector2(8, 6)), Color("#ff5252"))
		draw_rect(Rect2(br.position + Vector2(36, 14), Vector2(8, 6)), Color("#ff5252"))
	draw_string(font, Vector2(BOSS_RECT.position.x, 26), boss.data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	var pct := float(boss.hp) / boss.data.max_hp
	draw_rect(Rect2(BOSS_RECT.position.x, 98, BOSS_RECT.size.x, 4), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(BOSS_RECT.position.x, 98, BOSS_RECT.size.x * pct, 4), Color("#ef5350"))
	draw_string(font, Vector2(BOSS_RECT.end.x + 4, 103), "%d/%d" % [boss.hp, boss.data.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.8, 0.8))
	# Party
	for i in party.active.size():
		var b := party.active[i]
		var r := _slot_rect(i)
		var col := b.data.color
		if b.is_ko():
			col = Color(0.3, 0.3, 0.3)
			r = Rect2(r.position + Vector2(-4, r.size.y - 8), Vector2(r.size.y, 8))
		if _flash.has(b):
			col = Color.WHITE
		draw_rect(r, col)
		if b == ctrl.actor and ctrl.phase != BattleController.Phase.ENEMY_DEFENSE:
			draw_rect(r.grow(2), Color.YELLOW, false, 1.0)
		if _mode == Mode.DEFENSE and ctrl.pending_targets.has(b):
			var blink := int(Time.get_ticks_msec() / 120) % 2 == 0
			if blink:
				draw_rect(r.grow(3), Color("#ff5252"), false, 1.0)
		draw_string(font, Vector2(r.position.x - 6, 92), b.data.display_name, HORIZONTAL_ALIGNMENT_CENTER, 32, 8, Color.WHITE)


func _float_text(pos: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.size = Vector2(120, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos - Vector2(60, 6)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(l.queue_free)
