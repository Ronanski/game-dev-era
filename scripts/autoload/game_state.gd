extends Node
## Global game state: story flags, clues, party, inventory and saving.
##
## Story content never touches this file directly. Dialogue and map JSON
## describe conditions ("if") and effects ("do"), which are evaluated by
## check() and apply() below.

signal toast(text: String)

const SAVE_PATH := "user://save.json"
const ENDINGS_PATH := "user://endings.json"
const MAX_DAYS := 3
const DATA_FILES := ["characters", "party", "skills", "enemies", "encounters", "items", "clues", "endings", "quests"]

var db := {}
var theme: Theme

var flags := {}
var clues: Array = []
var day := 1
var gold := 0
var items := {}
var party: Array = []
var map_id := "halina"
var spawn_id := "start"
var return_pos = null  # [x, z] to resume at, or null to use spawn_id

var busy := false
var battle_group := ""
var pending_battle := ""
var pending_ending := ""
var pending_dialogue := ""  # "file:node", run when the world scene loads


func _ready() -> void:
	_setup_input()
	for key in DATA_FILES:
		db[key] = load_json("res://data/%s.json" % key)
	theme = _build_theme()


func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Invalid JSON: " + path)
		return {}
	return parsed


# --- New game / party ---------------------------------------------------------

func new_game() -> void:
	flags = {}
	clues = []
	day = 1
	gold = 60
	items = {"tonik": 3, "lagundi": 1}
	party = []
	map_id = "halina"
	spawn_id = "start"
	return_pos = null
	battle_group = ""
	pending_battle = ""
	pending_ending = ""
	pending_dialogue = ""
	join("amihan", false)


func join(id: String, announce := true) -> void:
	if is_member(id):
		return
	var base: Dictionary = db["party"][id]
	var m: Dictionary = base.duplicate(true)
	m["id"] = id
	m["name"] = character_name(id)
	m["max_hp"] = base["hp"]
	m["max_sp"] = base["sp"]
	party.append(m)
	if announce:
		toast.emit("Sumali si %s sa grupo!" % m["name"])


func leave(id: String) -> void:
	for m in party:
		if m["id"] == id:
			party.erase(m)
			toast.emit("Umalis si %s sa grupo." % m["name"])
			return


func is_member(id: String) -> bool:
	for m in party:
		if m["id"] == id:
			return true
	return false


func heal_party() -> void:
	for m in party:
		m["hp"] = m["max_hp"]
		m["sp"] = m["max_sp"]


func character_name(id: String) -> String:
	return db["characters"].get(id, {}).get("name", id)


func add_clue(id: String) -> void:
	if id in clues:
		return
	clues.append(id)
	toast.emit("Bagong clue: " + db["clues"].get(id, {}).get("name", id))


func add_item(id: String, count: int) -> void:
	items[id] = int(items.get(id, 0)) + count
	if count > 0:
		toast.emit("Nakuha: %s x%d" % [db["items"].get(id, {}).get("name", id), count])


func objective() -> String:
	return flags.get("objective", "")


# --- Conditions & effects -----------------------------------------------------

func check(cond) -> bool:
	if not cond is Dictionary:
		return true
	for key in cond:
		var v = cond[key]
		match key:
			"flag":
				for f in _arr(v):
					if not flags.get(f, false):
						return false
			"not_flag":
				for f in _arr(v):
					if flags.get(f, false):
						return false
			"clue":
				for c in _arr(v):
					if not c in clues:
						return false
			"not_clue":
				for c in _arr(v):
					if c in clues:
						return false
			"any_clue":
				var found := false
				for c in _arr(v):
					if c in clues:
						found = true
				if not found:
					return false
			"member":
				for id in _arr(v):
					if not is_member(id):
						return false
			"not_member":
				for id in _arr(v):
					if is_member(id):
						return false
			"gold":
				if gold < int(v):
					return false
			"min_day":
				if day < int(v):
					return false
			"max_day":
				if day > int(v):
					return false
			_:
				push_warning("Unknown condition: " + str(key))
	return true


func apply(fx) -> void:
	if not fx is Dictionary:
		return
	if fx.has("set"):
		for k in fx["set"]:
			flags[k] = fx["set"][k]
			if k == "objective":
				toast.emit("Layunin: " + str(fx["set"][k]))
	if fx.has("clue"):
		for c in _arr(fx["clue"]):
			add_clue(c)
	if fx.has("gold"):
		var delta := int(fx["gold"])
		gold = max(0, gold + delta)
		toast.emit("%+d ginto" % delta)
	if fx.has("item"):
		for k in fx["item"]:
			add_item(k, int(fx["item"][k]))
	if fx.has("join"):
		join(fx["join"])
	if fx.has("leave"):
		leave(fx["leave"])
	if fx.has("heal"):
		heal_party()
	if fx.has("rest"):
		heal_party()
		day += 1
		if day > MAX_DAYS:
			toast.emit("Sumapit na ang araw ng paglilitis.")
		else:
			toast.emit("Araw %d sa %d" % [day, MAX_DAYS])
	if fx.has("battle"):
		pending_battle = fx["battle"]
	if fx.has("ending"):
		pending_ending = fx["ending"]


func _arr(v) -> Array:
	return v if v is Array else [v]


# --- Save / load --------------------------------------------------------------

func save_game(pos = null) -> void:
	var data := {
		"flags": flags, "clues": clues, "day": day, "gold": gold, "items": items,
		"party": party, "map_id": map_id, "spawn_id": spawn_id, "pos": pos,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var d = load_json(SAVE_PATH)
	if not d is Dictionary or d.is_empty():
		return false
	flags = d.get("flags", {})
	clues = d.get("clues", [])
	day = int(d.get("day", 1))
	gold = int(d.get("gold", 0))
	items = d.get("items", {})
	party = d.get("party", [])
	map_id = d.get("map_id", "halina")
	spawn_id = d.get("spawn_id", "start")
	return_pos = d.get("pos")
	pending_battle = ""
	pending_ending = ""
	pending_dialogue = ""
	return true


func record_ending(id: String) -> void:
	var seen := seen_endings()
	if id in seen:
		return
	seen.append(id)
	var f := FileAccess.open(ENDINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(seen))


func seen_endings() -> Array:
	if not FileAccess.file_exists(ENDINGS_PATH):
		return []
	var d = load_json(ENDINGS_PATH)
	return d if d is Array else []


func goto(scene: String) -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/%s.tscn" % scene)


# --- Input & theme ------------------------------------------------------------

func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
		"journal": [KEY_J, KEY_TAB],
		"boost_up": [KEY_R, KEY_PAGEUP],
		"boost_down": [KEY_Q, KEY_PAGEDOWN],
	}
	var pads := {
		"move_left": JOY_BUTTON_DPAD_LEFT,
		"move_right": JOY_BUTTON_DPAD_RIGHT,
		"move_up": JOY_BUTTON_DPAD_UP,
		"move_down": JOY_BUTTON_DPAD_DOWN,
		"interact": JOY_BUTTON_A,
		"journal": JOY_BUTTON_START,
		"boost_up": JOY_BUTTON_RIGHT_SHOULDER,
		"boost_down": JOY_BUTTON_LEFT_SHOULDER,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action]
		InputMap.action_add_event(action, jb)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)


func _build_theme() -> Theme:
	var gold_c := Color("#e8c170")
	var t := Theme.new()
	t.default_font_size = 22

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.07, 0.13, 0.93)
	panel.border_color = Color(0.78, 0.65, 0.38)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.10, 0.11, 0.20, 0.95)
	btn.border_color = Color(0.45, 0.40, 0.32)
	btn.set_border_width_all(2)
	btn.set_corner_radius_all(5)
	btn.content_margin_left = 16
	btn.content_margin_right = 16
	btn.content_margin_top = 8
	btn.content_margin_bottom = 8
	var hover: StyleBoxFlat = btn.duplicate()
	hover.bg_color = Color(0.18, 0.17, 0.30, 0.98)
	hover.border_color = gold_c
	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color = Color(0.28, 0.22, 0.12, 1.0)
	var disabled: StyleBoxFlat = btn.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.10, 0.7)
	disabled.border_color = Color(0.25, 0.25, 0.28)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = gold_c
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.95, 0.92, 0.85))
	t.set_color("font_hover_color", "Button", gold_c)
	t.set_color("font_focus_color", "Button", gold_c)
	t.set_color("font_pressed_color", "Button", gold_c)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	t.set_color("font_color", "Label", Color(0.95, 0.92, 0.85))
	t.set_color("default_color", "RichTextLabel", Color(0.95, 0.92, 0.85))

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.05, 0.08)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#6cc070")
	bar_fill.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	var tab_sel: StyleBoxFlat = hover.duplicate()
	var tab_unsel: StyleBoxFlat = btn.duplicate()
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_unsel)
	t.set_stylebox("tab_hovered", "TabContainer", hover)
	t.set_stylebox("panel", "TabContainer", panel)
	return t
