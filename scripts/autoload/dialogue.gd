extends CanvasLayer
## Runs data-driven conversations from res://data/dialogue/<file>.json and
## shows toast notifications.
##
## A dialogue file maps node ids to nodes. A node may contain:
##   "if":      condition (see GameState.check). If false, jump to "else".
##   "do":      effects applied when the node is reached (see GameState.apply).
##   "lines":   [[speaker_id, text], ...]  speaker "" is narration.
##   "choices": [{"text", "next", "if", "do"}, ...]
##   "next":    next node id, or "file:node" to jump to another file.
## A missing or empty "next" ends the conversation.

signal _advance
signal _typed
signal _chosen(index: int)

const NARRATION_COLOR := "#bfc6d9"

var _files := {}
var _root: Control
var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: RichTextLabel
var _hint: Label
var _choices: VBoxContainer
var _toast_box: PanelContainer
var _toast_label: Label
var _tween: Tween
var _typing := false
var _waiting := false
var _toasts: Array = []
var _toasting := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	GameState.toast.connect(show_toast)


func is_open() -> bool:
	return _root.visible


func run(file: String, start: String) -> void:
	GameState.busy = true
	_root.visible = true
	_name.text = ""
	_text.text = ""
	_portrait.visible = false
	var cur_file := file
	var id := start
	var steps := 0
	while id != "" and steps < 1000:
		steps += 1
		if id.contains(":"):
			var parts := id.split(":")
			cur_file = parts[0]
			id = parts[1]
		var convo := _load(cur_file)
		if not convo.has(id):
			push_error("Dialogue node not found: %s:%s" % [cur_file, id])
			break
		var node: Dictionary = convo[id]
		if node.has("if") and not GameState.check(node["if"]):
			id = node.get("else", "")
			continue
		GameState.apply(node.get("do", {}))
		var choices: Array = []
		for c in node.get("choices", []):
			if GameState.check(c.get("if", {})):
				choices.append(c)
		var lines: Array = node.get("lines", [])
		for i in lines.size():
			var last := i == lines.size() - 1
			await _show_line(lines[i][0], lines[i][1], not (last and not choices.is_empty()))
		if choices.is_empty():
			id = node.get("next", "")
		else:
			var idx: int = await _ask(choices)
			var picked: Dictionary = choices[idx]
			GameState.apply(picked.get("do", {}))
			id = picked.get("next", "")
			if not picked.has("next") and node.has("next"):
				id = node["next"]
	_root.visible = false
	await get_tree().create_timer(0.15).timeout
	GameState.busy = false


func _load(file: String) -> Dictionary:
	if not _files.has(file):
		var d = GameState.load_json("res://data/dialogue/%s.json" % file)
		_files[file] = d if d is Dictionary else {}
	return _files[file]


func _show_line(speaker: String, text: String, wait: bool) -> void:
	var info: Dictionary = GameState.db["characters"].get(speaker, {})
	_name.text = info.get("name", "")
	_name.visible = speaker != ""
	_portrait.visible = speaker != ""
	if speaker != "":
		_portrait.texture = Sprites.portrait(speaker)
		_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if Sprites.is_smooth(_portrait.texture) else CanvasItem.TEXTURE_FILTER_NEAREST
		_text.text = text
	else:
		_text.text = "[color=%s][i]%s[/i][/color]" % [NARRATION_COLOR, text]
	_text.visible_ratio = 0.0
	_hint.visible = false
	_typing = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, clampf(text.length() * 0.016, 0.15, 2.5))
	_tween.finished.connect(_finish_typing)
	if _typing:
		await _typed
	if wait:
		_hint.visible = true
		_waiting = true
		await _advance
		_waiting = false
		_hint.visible = false


func _finish_typing() -> void:
	if not _typing:
		return
	if _tween:
		_tween.kill()
	_text.visible_ratio = 1.0
	_typing = false
	_typed.emit()


func _press() -> void:
	if _typing:
		_finish_typing()
	elif _waiting:
		_advance.emit()


func _ask(choices: Array) -> int:
	for i in choices.size():
		var b := Button.new()
		b.text = choices[i]["text"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func(): _chosen.emit(i))
		_choices.add_child(b)
	_choices.visible = true
	(_choices.get_child(0) as Button).grab_focus.call_deferred()
	var idx: int = await _chosen
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	_choices.visible = false
	return idx


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or _choices.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_press()


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press()


# --- Toasts -------------------------------------------------------------------

func show_toast(msg: String) -> void:
	_toasts.append(msg)
	if not _toasting:
		_run_toasts()


func _run_toasts() -> void:
	_toasting = true
	while not _toasts.is_empty():
		_toast_label.text = _toasts.pop_front()
		var t := create_tween()
		t.tween_property(_toast_box, "modulate:a", 1.0, 0.2)
		t.tween_interval(1.6)
		t.tween_property(_toast_box, "modulate:a", 0.0, 0.35)
		await t.finished
	_toasting = false


# --- UI construction ----------------------------------------------------------

func _build() -> void:
	var base := Control.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.theme = GameState.theme
	add_child(base)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(_root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 24
	_panel.offset_right = -24
	_panel.offset_top = -224
	_panel.offset_bottom = -16
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	_root.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(180, 180)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	_name = Label.new()
	_name.add_theme_color_override("font_color", Color("#e8c170"))
	_name.add_theme_font_size_override("font_size", 25)
	col.add_child(_name)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 23)
	_text.add_theme_font_size_override("italics_font_size", 23)
	col.add_child(_text)

	_hint = Label.new()
	_hint.text = ">>"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", Color("#e8c170"))
	col.add_child(_hint)

	_choices = VBoxContainer.new()
	_choices.anchor_left = 1.0
	_choices.anchor_right = 1.0
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = -720
	_choices.offset_right = -40
	_choices.offset_top = -240
	_choices.offset_bottom = -240
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.add_theme_constant_override("separation", 6)
	_choices.visible = false
	_root.add_child(_choices)

	_toast_box = PanelContainer.new()
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_left = -330
	_toast_box.offset_right = 330
	_toast_box.offset_top = 86
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.modulate.a = 0.0
	base.add_child(_toast_box)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_color_override("font_color", Color("#e8c170"))
	_toast_box.add_child(_toast_label)
