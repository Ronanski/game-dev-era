extends CanvasLayer
## Exploration HUD: location, day counter, objective, talk prompt,
## the journal (Talaan), and touch controls on phones.

signal save_requested

const TouchControls := preload("res://scripts/world/touch_controls.gd")
const WEAPONS := {
	"espada": "Espada", "sibat": "Sibat", "balaraw": "Balaraw", "pana": "Pana",
	"tungkod": "Tungkod", "palakol": "Palakol",
}

var joystick: Control
var _location: Label
var _status: Label
var _objective: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _journal: PanelContainer
var _tabs: TabContainer
var _clue_text: RichTextLabel
var _party_text: RichTextLabel
var _quest_text: RichTextLabel
var _fade: ColorRect
var _touch := false


func setup(location: String) -> void:
	layer = 10
	_touch = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = GameState.theme
	add_child(root)

	# Top-left: where and when.
	var info := PanelContainer.new()
	info.position = Vector2(16, 16)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)
	var col := VBoxContainer.new()
	info.add_child(col)
	_location = Label.new()
	_location.text = location
	_location.add_theme_color_override("font_color", Color("#e8c170"))
	_location.add_theme_font_size_override("font_size", 24)
	col.add_child(_location)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	col.add_child(_status)
	_objective = Label.new()
	_objective.custom_minimum_size = Vector2(380, 0)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_theme_font_size_override("font_size", 17)
	_objective.add_theme_color_override("font_color", Color("#bfc6d9"))
	col.add_child(_objective)

	# Top-right: journal button.
	var jb := Button.new()
	jb.text = "Talaan (J)" if not _touch else "Talaan"
	jb.anchor_left = 1.0
	jb.anchor_right = 1.0
	jb.offset_left = -180
	jb.offset_right = -16
	jb.offset_top = 16
	jb.offset_bottom = 66
	jb.focus_mode = Control.FOCUS_NONE
	jb.pressed.connect(toggle_journal)
	root.add_child(jb)

	# Bottom-center: talk prompt.
	_prompt = PanelContainer.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -220
	_prompt.offset_right = 220
	_prompt.offset_top = -80
	_prompt.offset_bottom = -30
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	root.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_child(_prompt_label)

	if _touch:
		joystick = TouchControls.new()
		joystick.mode = "stick"
		joystick.anchor_top = 1.0
		joystick.anchor_bottom = 1.0
		joystick.offset_left = 30
		joystick.offset_right = 250
		joystick.offset_top = -250
		joystick.offset_bottom = -30
		root.add_child(joystick)
		var btn := TouchControls.new()
		btn.mode = "button"
		btn.action = "interact"
		btn.label = "Kausapin"
		btn.anchor_left = 1.0
		btn.anchor_right = 1.0
		btn.anchor_top = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_left = -190
		btn.offset_right = -40
		btn.offset_top = -200
		btn.offset_bottom = -50
		root.add_child(btn)

	_build_journal(root)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.5)


func refresh() -> void:
	var d := mini(GameState.day, GameState.MAX_DAYS)
	_status.text = "Araw %d sa %d   |   %d ginto" % [d, GameState.MAX_DAYS, GameState.gold]
	var obj := GameState.objective()
	_objective.text = "> " + obj if obj != "" else ""
	_objective.visible = obj != ""


func set_prompt(target_name: String) -> void:
	_prompt.visible = target_name != "" and not GameState.busy and not is_menu_open()
	if target_name != "":
		_prompt_label.text = ("Kausapin: " if _touch else "[E] ") + target_name


func is_menu_open() -> bool:
	return _journal.visible


func flash() -> void:
	_fade.color = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.9, 0.12)
	t.tween_property(_fade, "color", Color(0, 0, 0, 1), 0.35)
	await t.finished


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.35)
	await t.finished


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") and not GameState.busy:
		toggle_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _journal.visible:
		toggle_journal()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _journal and not GameState.busy:
		toggle_journal()


# --- Journal ------------------------------------------------------------------

func toggle_journal() -> void:
	if GameState.busy and not _journal.visible:
		return
	_journal.visible = not _journal.visible
	if _journal.visible:
		_fill_journal()


func _build_journal(root: Control) -> void:
	_journal = PanelContainer.new()
	_journal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_journal.offset_left = 60
	_journal.offset_right = -60
	_journal.offset_top = 40
	_journal.offset_bottom = -40
	_journal.visible = false
	root.add_child(_journal)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_journal.add_child(col)
	var title := Label.new()
	title.text = "Talaan ni Amihan"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#e8c170"))
	col.add_child(title)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_clue_text = _tab("Mga Clue")
	_quest_text = _tab("Mga Layunin")
	_party_text = _tab("Grupo")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var title_btn := Button.new()
	title_btn.text = "Bumalik sa Title"
	title_btn.pressed.connect(func(): GameState.goto("title"))
	row.add_child(title_btn)
	var save := Button.new()
	save.text = "I-save"
	save.pressed.connect(func(): save_requested.emit())
	row.add_child(save)
	var close := Button.new()
	close.text = "Isara"
	close.pressed.connect(toggle_journal)
	row.add_child(close)


func _tab(tab_name: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.name = tab_name
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", 20)
	r.add_theme_font_size_override("bold_font_size", 22)
	_tabs.add_child(r)
	return r


func _fill_journal() -> void:
	var t := ""
	if GameState.clues.is_empty():
		t = "[i]Wala pang clue. Kausapin ang mga tao at usisain ang mga kumikinang na bagay.[/i]"
	for id in GameState.clues:
		var c: Dictionary = GameState.db["clues"].get(id, {})
		t += "[b][color=#e8c170]%s[/color][/b]\n%s\n\n" % [c.get("name", id), c.get("desc", "")]
	_clue_text.text = t

	t = "[b][color=#e8c170]Pangunahing Layunin[/color][/b]\n%s\n\n" % GameState.objective()
	t += "[b][color=#e8c170]Iba Pang Gawain[/color][/b]\n"
	var any := false
	for q in GameState.db["quests"]:
		if GameState.check(q.get("if", {})):
			t += "- %s\n" % q["text"]
			any = true
	if not any:
		t += "[i]Wala sa ngayon.[/i]\n"
	t += "\n[color=#bfc6d9]Araw %d sa %d. Ang pagpapahinga sa Bahay-Panuluyan ay nagpapalipas ng isang araw.[/color]" % [mini(GameState.day, GameState.MAX_DAYS), GameState.MAX_DAYS]
	t += "\n[color=#bfc6d9]Mga wakas na natuklasan: %d / %d[/color]" % [GameState.seen_endings().size(), GameState.db["endings"].size()]
	_quest_text.text = t

	t = ""
	for m in GameState.party:
		var weapons: Array = []
		for w in m["weapons"]:
			weapons.append(WEAPONS.get(w, w))
		var skills: Array = []
		for s in m["skills"]:
			skills.append(GameState.db["skills"][s]["name"])
		t += "[b][color=#e8c170]%s[/color][/b] - %s\n" % [m["name"], m.get("class", "")]
		t += "HP %d/%d   SP %d/%d   Lakas %d   Mahika %d   Depensa %d   Bilis %d\n" % [
			m["hp"], m["max_hp"], m["sp"], m["max_sp"], m["atk"], m["mag"], m["def"], m["spd"]]
		t += "Sandata: %s\nKasanayan: %s\n\n" % [", ".join(weapons), ", ".join(skills)]
	t += "[b][color=#e8c170]Mga Gamit[/color][/b]   (%d ginto)\n" % GameState.gold
	for id in GameState.items:
		if int(GameState.items[id]) > 0:
			var it: Dictionary = GameState.db["items"].get(id, {})
			t += "%s x%d - %s\n" % [it.get("name", id), int(GameState.items[id]), it.get("desc", "")]
	_party_text.text = t
