extends Control
## Turn-based battle inspired by Octopath Traveler.
## - Every enemy has a Kalasag (shield) and hidden weaknesses.
## - Hitting a weakness lowers the shield; at 0 the enemy is BROKEN:
##   it loses its next turn and takes double damage.
## - Each party member gains 1 BP per round (max 5) and can spend up to 3
##   to Boost: more hits for attacks, more power for skills.

signal _picked(index: int)

const MAX_BP := 5
const MAX_BOOST := 3
const TYPE_NAMES := {
	"espada": "Espada", "sibat": "Sibat", "balaraw": "Balaraw", "pana": "Pana",
	"tungkod": "Tungkod", "palakol": "Palakol", "apoy": "Apoy", "hangin": "Hangin",
	"kulog": "Kulog", "liwanag": "Liwanag", "dilim": "Dilim", "tubig": "Tubig",
}

var group: Dictionary
var enemies: Array = []
var party: Array = []
var _state := {}   # party id -> {bp, boosted, defending}
var _cards := {}   # party id -> card nodes
var _boost := 0
var _active = null
var _result := ""
var _rng := RandomNumberGenerator.new()

var _enemy_row: HBoxContainer
var _party_col: VBoxContainer
var _log: RichTextLabel
var _menu: GridContainer
var _turn_label: Label
var _boost_row: HBoxContainer
var _boost_label: Label


func _ready() -> void:
	_rng.randomize()
	if GameState.party.is_empty():
		GameState.new_game()
		GameState.join("bagwis", false)
	if GameState.battle_group == "":
		GameState.battle_group = "gubat_1"
	theme = GameState.theme
	group = GameState.db["encounters"][GameState.battle_group]
	party = GameState.party
	for m in party:
		_state[m["id"]] = {"bp": 1, "boosted": false, "defending": false}
	var counts := {}
	for id in group["enemies"]:
		counts[id] = counts.get(id, 0) + 1
	var seen := {}
	for id in group["enemies"]:
		var base: Dictionary = GameState.db["enemies"][id]
		var e: Dictionary = base.duplicate(true)
		seen[id] = seen.get(id, 0) + 1
		e["id"] = id
		if counts[id] > 1:
			e["name"] = "%s %s" % [base["name"], "ABCDE"[seen[id] - 1]]
		e["max_hp"] = base["hp"]
		e["max_shield"] = base["shield"]
		e["broken"] = 0
		e["known"] = []
		e["is_enemy"] = true
		enemies.append(e)
	_build_ui()
	_refresh()
	_log_line(group.get("intro", "Lumitaw ang mga kalaban!"))
	await get_tree().create_timer(0.6).timeout
	_battle_loop()


func _unhandled_input(event: InputEvent) -> void:
	if _active == null:
		return
	if event.is_action_pressed("boost_up"):
		_change_boost(1)
	elif event.is_action_pressed("boost_down"):
		_change_boost(-1)


# --- Battle flow --------------------------------------------------------------

func _battle_loop() -> void:
	var round_n := 0
	while _result == "":
		round_n += 1
		for m in _alive(party):
			var st: Dictionary = _state[m["id"]]
			if st["boosted"]:
				st["boosted"] = false
			elif round_n > 1:
				st["bp"] = mini(MAX_BP, st["bp"] + 1)
		_refresh()
		var order: Array = []
		for c in _alive(party) + _alive(enemies):
			order.append([float(c["spd"]) + _rng.randf() * 3.0, c])
		order.sort_custom(func(a, b): return a[0] > b[0])
		for entry in order:
			var c: Dictionary = entry[1]
			if _result != "":
				break
			if c["hp"] <= 0:
				continue
			if c.get("is_enemy", false):
				if c["broken"] > 0:
					_log_line("[color=#ffd166]%s ay hindi makagalaw![/color]" % c["name"])
					await _wait(0.5)
					continue
				var actions := 1
				if c.get("enrage", false) and c["hp"] < c["max_hp"] / 2.0:
					actions = 2
				for i in actions:
					if _result == "":
						await _enemy_turn(c)
						_check_end()
			else:
				await _player_turn(c)
				_check_end()
		for e in enemies:
			if e["broken"] > 0:
				e["broken"] -= 1
				if e["broken"] == 0 and e["hp"] > 0:
					e["shield"] = e["max_shield"]
					_log_line("Nakabangon si %s." % e["name"])
		for m in party:
			_state[m["id"]]["defending"] = false
		_refresh()
	match _result:
		"win":
			await _victory()
		"lose":
			await _defeat()
		"escape":
			GameState.goto("world")


func _check_end() -> void:
	if _alive(enemies).is_empty():
		_result = "win"
	elif _alive(party).is_empty():
		_result = "lose"


func _alive(list: Array) -> Array:
	return list.filter(func(c): return c["hp"] > 0)


func _player_turn(m: Dictionary) -> void:
	_active = m
	_boost = 0
	_refresh()
	var st: Dictionary = _state[m["id"]]
	while true:
		var opts := ["Atake", "Kasanayan", "Item", "Depensa"]
		if group.get("escape", true):
			opts.append("Tumakas")
		var pick := await _choose(opts)
		if pick == 0:
			var weapon: String = m["weapons"][0]
			if m["weapons"].size() > 1:
				var names: Array = []
				for w in m["weapons"]:
					names.append(TYPE_NAMES.get(w, w))
				names.append("< Bumalik")
				var wi := await _choose(names)
				if wi == m["weapons"].size():
					continue
				weapon = m["weapons"][wi]
			var target = await _pick(_alive(enemies))
			if target == null:
				continue
			var boost := _spend_boost(st)
			await _hit(m, target, {"name": "Atake", "type": weapon, "stat": "atk", "power": 1.0, "hits": 1 + boost}, 0)
			break
		elif pick == 1:
			var names: Array = []
			var disabled: Array = []
			for sid in m["skills"]:
				var sk: Dictionary = GameState.db["skills"][sid]
				names.append("%s  (%d SP)" % [sk["name"], sk["sp"]])
				disabled.append(m["sp"] < sk["sp"])
			names.append("< Bumalik")
			disabled.append(false)
			var si := await _choose(names, disabled)
			if si == m["skills"].size():
				continue
			var skill: Dictionary = GameState.db["skills"][m["skills"][si]]
			_log_line("[color=#bfc6d9]%s[/color]" % skill.get("desc", ""))
			var target = null
			match skill["target"]:
				"enemy":
					target = await _pick(_alive(enemies))
				"ally":
					target = await _pick(_alive(party))
			if target == null and skill["target"] in ["enemy", "ally"]:
				continue
			m["sp"] -= skill["sp"]
			var boost := _spend_boost(st)
			await _use_skill(m, skill, target, boost)
			break
		elif pick == 2:
			var ids: Array = []
			var names: Array = []
			for id in GameState.items:
				if int(GameState.items[id]) > 0:
					ids.append(id)
					names.append("%s x%d" % [GameState.db["items"][id]["name"], int(GameState.items[id])])
			names.append("< Bumalik")
			var ii := await _choose(names)
			if ii == ids.size():
				continue
			var item: Dictionary = GameState.db["items"][ids[ii]]
			var pool := party if item.has("revive") else _alive(party)
			var target = await _pick(pool)
			if target == null:
				continue
			GameState.items[ids[ii]] = int(GameState.items[ids[ii]]) - 1
			_use_item(m, item, target)
			await _wait(0.6)
			break
		elif pick == 3:
			st["defending"] = true
			_log_line("%s ay nagdepensa." % m["name"])
			await _wait(0.4)
			break
		elif pick == 4:
			if _rng.randf() < 0.6:
				_log_line("Nakatakas kayo!")
				await _wait(0.6)
				_result = "escape"
			else:
				_log_line("Hindi makatakas!")
				await _wait(0.6)
			break
	_active = null
	_refresh()


func _spend_boost(st: Dictionary) -> int:
	var b := _boost
	if b > 0:
		st["bp"] -= b
		st["boosted"] = true
	_boost = 0
	return b


func _use_skill(user: Dictionary, skill: Dictionary, target, boost: int) -> void:
	match skill["kind"]:
		"damage":
			var targets: Array = [target] if skill["target"] == "enemy" else _alive(enemies)
			for t in targets:
				await _hit(user, t, skill, boost)
		"steal":
			await _hit(user, target, skill, boost)
			if _rng.randf() < 0.6 + boost * 0.1:
				var g := _rng.randi_range(15, 40)
				GameState.gold += g
				_log_line("[color=#e8c170]Nakanakaw si %s ng %d ginto![/color]" % [user["name"], g])
			else:
				_log_line("Walang nakuha.")
			await _wait(0.4)
		"heal", "heal_all":
			_log_line("%s: %s!" % [user["name"], skill["name"]])
			var amount := int(float(user["mag"]) * float(skill["power"]) * 2.0 * (1.0 + boost * 0.5))
			var targets: Array = [target] if skill["kind"] == "heal" else _alive(party)
			for t in targets:
				t["hp"] = mini(int(t["max_hp"]), int(t["hp"]) + amount)
				_popup(t, "+%d" % amount, Color("#8fe388"))
			_refresh()
			await _wait(0.6)


func _use_item(user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	_log_line("%s ay gumamit ng %s." % [user["name"], item["name"]])
	if item.has("revive"):
		if target["hp"] <= 0:
			target["hp"] = int(target["max_hp"] * float(item["revive"]))
			_popup(target, "Buhay!", Color("#8fe388"))
		else:
			_log_line("Walang epekto.")
	if item.has("heal"):
		target["hp"] = mini(int(target["max_hp"]), int(target["hp"]) + int(item["heal"]))
		_popup(target, "+%d" % int(item["heal"]), Color("#8fe388"))
	if item.has("sp"):
		target["sp"] = mini(int(target["max_sp"]), int(target["sp"]) + int(item["sp"]))
		_popup(target, "+%d SP" % int(item["sp"]), Color("#7fb2ff"))
	_refresh()


func _hit(user: Dictionary, target: Dictionary, action: Dictionary, boost: int) -> void:
	if target["hp"] <= 0:
		return
	var hits := int(action.get("hits", 1))
	var power := float(action.get("power", 1.0)) * (1.0 + boost * 0.8)
	var type: String = action.get("type", "")
	var weak: bool = type in target.get("weak", [])
	_log_line("%s: %s%s!" % [user["name"], action["name"], " (%s)" % TYPE_NAMES.get(type, type) if type != "" else ""])
	if weak and not type in target["known"]:
		target["known"].append(type)
	for i in hits:
		if target["hp"] <= 0:
			break
		var stat := float(user[action.get("stat", "atk")])
		var dmg := maxf(1.0, stat * power * 2.2 - float(target["def"])) * _rng.randf_range(0.9, 1.1)
		if weak:
			dmg *= 1.3
		if target["broken"] > 0:
			dmg *= 2.0
		var d := int(round(dmg))
		target["hp"] = maxi(0, int(target["hp"]) - d)
		_popup(target, str(d), Color("#ffd166") if weak else Color.WHITE)
		if weak and target["broken"] == 0 and target["shield"] > 0:
			target["shield"] -= 1
			if target["shield"] == 0:
				target["broken"] = 2
				_log_line("[color=#ffd166]BREAK! Nasira ang depensa ni %s![/color]" % target["name"])
		_refresh()
		await _wait(0.2)
	if target["hp"] <= 0:
		_log_line("Natalo si %s." % target["name"])
	await _wait(0.3)


func _enemy_turn(e: Dictionary) -> void:
	var targets := _alive(party)
	if targets.is_empty():
		return
	var skills: Array = e.get("skills", [{"name": "Atake", "power": 1.0}])
	var sk: Dictionary = skills[_rng.randi() % skills.size()]
	_log_line("[color=#ff9a8a]%s: %s![/color]" % [e["name"], sk["name"]])
	var hit_list: Array = targets if sk.get("all", false) else [targets[_rng.randi() % targets.size()]]
	for m in hit_list:
		var dmg := maxf(1.0, float(e["atk"]) * float(sk.get("power", 1.0)) * 2.0 - float(m["def"]))
		dmg *= _rng.randf_range(0.9, 1.1)
		if _state[m["id"]]["defending"]:
			dmg *= 0.5
		var d := int(round(dmg))
		m["hp"] = maxi(0, int(m["hp"]) - d)
		_popup(m, str(d), Color("#ff8a7a"))
		if sk.get("drain", false):
			e["hp"] = mini(int(e["max_hp"]), int(e["hp"]) + d / 2)
		if m["hp"] <= 0:
			_log_line("[color=#ff8a7a]Bumagsak si %s![/color]" % m["name"])
	_refresh()
	await _wait(0.8)


func _victory() -> void:
	var gold := 0
	for e in enemies:
		gold += int(e.get("gold", 10))
	GameState.gold += gold
	for m in party:
		if m["hp"] <= 0:
			m["hp"] = 1
	_log_line("[color=#8fe388]TAGUMPAY![/color]  +%d ginto" % gold)
	GameState.apply(group.get("win", {}))
	if group.has("after"):
		GameState.pending_dialogue = group["after"]
	await _choose(["Magpatuloy"])
	GameState.goto("world")


func _defeat() -> void:
	_log_line("[color=#ff8a7a]Natalo ang inyong grupo...[/color]")
	var opts := ["Bumalik sa Title"]
	if GameState.has_save():
		opts.push_front("I-load ang huling save")
	var pick := await _choose(opts)
	if opts[pick] == "Bumalik sa Title":
		GameState.goto("title")
	elif GameState.load_game():
		GameState.goto("world")
	else:
		GameState.goto("title")


# --- Menus --------------------------------------------------------------------

func _choose(options: Array, disabled: Array = []) -> int:
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = i < disabled.size() and disabled[i]
		b.pressed.connect(func(): _picked.emit(i))
		_menu.add_child(b)
	for child in _menu.get_children():
		if not child.disabled:
			child.grab_focus.call_deferred()
			break
	var idx: int = await _picked
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	return idx


func _pick(pool: Array):
	var names: Array = []
	for c in pool:
		names.append("%s  (HP %d)" % [c["name"], c["hp"]])
	names.append("< Bumalik")
	var i := await _choose(names)
	return null if i == pool.size() else pool[i]


func _change_boost(delta: int) -> void:
	if _active == null:
		return
	var bp: int = _state[_active["id"]]["bp"]
	_boost = clampi(_boost + delta, 0, mini(MAX_BOOST, bp))
	_refresh()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _log_line(text: String) -> void:
	_log.append_text(text + "\n")


func _popup(target: Dictionary, text: String, color: Color) -> void:
	var card: Control = target["card"] if target.has("card") else _cards[target["id"]]["root"]
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.position = card.global_position + Vector2(card.size.x * 0.4 + _rng.randf_range(-20, 20), card.size.y * 0.3)
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 60, 0.7)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	t.tween_callback(l.queue_free)


# --- UI -----------------------------------------------------------------------

func _refresh() -> void:
	for e in enemies:
		var c: Dictionary = e["ui"]
		c["hp"].max_value = e["max_hp"]
		c["hp"].value = e["hp"]
		c["shield"].text = "BREAK!" if e["broken"] > 0 else "Kalasag: %d" % e["shield"]
		c["shield"].add_theme_color_override("font_color", Color("#ffd166") if e["broken"] > 0 else Color("#9fc7ff"))
		var weak: Array = []
		for w in e["weak"]:
			weak.append(TYPE_NAMES.get(w, w) if w in e["known"] else "?")
		c["weak"].text = "Kahinaan: " + " ".join(weak)
		e["card"].modulate = Color(1, 1, 1, 0.25) if e["hp"] <= 0 else Color.WHITE
		c["sprite"].modulate = Color(1, 0.85, 0.5) if e["broken"] > 0 else Color.WHITE
	for m in party:
		var c: Dictionary = _cards[m["id"]]
		var st: Dictionary = _state[m["id"]]
		c["hp"].max_value = m["max_hp"]
		c["hp"].value = m["hp"]
		c["hp_label"].text = "HP %d/%d   SP %d/%d" % [m["hp"], m["max_hp"], m["sp"], m["max_sp"]]
		for i in MAX_BP:
			var pip: ColorRect = c["pips"][i]
			if _active == m and i >= st["bp"] - _boost and i < st["bp"]:
				pip.color = Color("#ff9a3a")
			elif i < st["bp"]:
				pip.color = Color("#e8c170")
			else:
				pip.color = Color(1, 1, 1, 0.15)
		var tint := Color.WHITE
		if m["hp"] <= 0:
			tint = Color(0.6, 0.3, 0.3, 0.6)
		elif _active == m:
			tint = Color(1.15, 1.1, 0.85)
		c["root"].modulate = tint
	_boost_row.visible = _active != null
	if _active != null:
		_turn_label.text = "Turno ni %s" % _active["name"]
		_boost_label.text = "Boost: %d   (BP %d)" % [_boost, _state[_active["id"]]["bp"]]
	else:
		_turn_label.text = ""


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	var grad := Gradient.new()
	var colors: Array = group.get("bg", ["#1b2030", "#3a4a3a"])
	grad.set_color(0, Color(colors[0]))
	grad.set_color(1, Color(colors[1]))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0, 0, 0, 0.25)
	floor_rect.anchor_right = 1.0
	floor_rect.anchor_top = 0.42
	floor_rect.anchor_bottom = 0.62
	add_child(floor_rect)

	_enemy_row = HBoxContainer.new()
	_enemy_row.anchor_left = 0.02
	_enemy_row.anchor_right = 0.62
	_enemy_row.anchor_top = 0.04
	_enemy_row.anchor_bottom = 0.6
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.add_theme_constant_override("separation", 20)
	add_child(_enemy_row)
	for e in enemies:
		var big: bool = e.get("boss", false)
		var card := VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_END
		var spr := TextureRect.new()
		spr.texture = Sprites.texture(e.get("look", e["id"]))
		spr.custom_minimum_size = Vector2(220, 260) if big else Vector2(150, 180)
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.flip_h = true
		card.add_child(spr)
		var name_l := Label.new()
		name_l.text = e["name"]
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_l)
		var hp := ProgressBar.new()
		hp.show_percentage = false
		hp.custom_minimum_size = Vector2(150, 10)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#d0574a")
		hp.add_theme_stylebox_override("fill", fill)
		card.add_child(hp)
		var shield := Label.new()
		shield.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shield.add_theme_font_size_override("font_size", 19)
		card.add_child(shield)
		var weak := Label.new()
		weak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weak.add_theme_font_size_override("font_size", 15)
		weak.custom_minimum_size = Vector2(150, 0)
		weak.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(weak)
		_enemy_row.add_child(card)
		e["card"] = card
		e["ui"] = {"hp": hp, "shield": shield, "weak": weak, "sprite": spr}

	_party_col = VBoxContainer.new()
	_party_col.anchor_left = 0.64
	_party_col.anchor_right = 0.98
	_party_col.anchor_top = 0.04
	_party_col.anchor_bottom = 0.6
	_party_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_party_col.add_theme_constant_override("separation", 8)
	add_child(_party_col)
	for m in party:
		var card := PanelContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var spr := TextureRect.new()
		spr.texture = Sprites.texture(m["id"])
		spr.custom_minimum_size = Vector2(64, 76)
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(spr)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var top := HBoxContainer.new()
		col.add_child(top)
		var name_l := Label.new()
		name_l.text = m["name"]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_color_override("font_color", Color("#e8c170"))
		top.add_child(name_l)
		var pips: Array = []
		for i in MAX_BP:
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(12, 12)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			top.add_child(pip)
			pips.append(pip)
		var hp := ProgressBar.new()
		hp.show_percentage = false
		hp.custom_minimum_size = Vector2(0, 10)
		col.add_child(hp)
		var hp_l := Label.new()
		hp_l.add_theme_font_size_override("font_size", 17)
		col.add_child(hp_l)
		_party_col.add_child(card)
		_cards[m["id"]] = {"root": card, "hp": hp, "hp_label": hp_l, "pips": pips}

	var log_panel := PanelContainer.new()
	log_panel.anchor_left = 0.02
	log_panel.anchor_right = 0.55
	log_panel.anchor_top = 0.64
	log_panel.anchor_bottom = 0.97
	add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 18)
	log_panel.add_child(_log)

	var cmd := PanelContainer.new()
	cmd.anchor_left = 0.57
	cmd.anchor_right = 0.98
	cmd.anchor_top = 0.64
	cmd.anchor_bottom = 0.97
	add_child(cmd)
	var cmd_col := VBoxContainer.new()
	cmd.add_child(cmd_col)
	_turn_label = Label.new()
	_turn_label.add_theme_color_override("font_color", Color("#e8c170"))
	cmd_col.add_child(_turn_label)
	_boost_row = HBoxContainer.new()
	cmd_col.add_child(_boost_row)
	var minus := Button.new()
	minus.text = " - "
	minus.focus_mode = Control.FOCUS_NONE
	minus.pressed.connect(func(): _change_boost(-1))
	_boost_row.add_child(minus)
	_boost_label = Label.new()
	_boost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boost_row.add_child(_boost_label)
	var plus := Button.new()
	plus.text = " + "
	plus.focus_mode = Control.FOCUS_NONE
	plus.pressed.connect(func(): _change_boost(1))
	_boost_row.add_child(plus)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cmd_col.add_child(scroll)
	_menu = GridContainer.new()
	_menu.columns = 2
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_menu)
