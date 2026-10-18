extends Control
## Shows the ending the player reached, one paragraph at a time.

func _ready() -> void:
	theme = GameState.theme
	var id := GameState.pending_ending
	if id == "":
		id = "digmaan"
	GameState.pending_ending = ""
	GameState.record_ending(id)
	var ending: Dictionary = GameState.db["endings"].get(id, {})

	var bg := ColorRect.new()
	bg.color = Color("#0a0910")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 140
	col.offset_right = -140
	col.offset_top = 50
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var kind := Label.new()
	kind.text = ending.get("kind", "")
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.add_theme_color_override("font_color", Color("#8a90a8"))
	col.add_child(kind)
	var title := Label.new()
	title.text = ending.get("title", id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(ending.get("color", "#e8c170")))
	col.add_child(title)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 22)
	col.add_child(text)

	var btn := Button.new()
	btn.text = "Bumalik sa Title"
	btn.custom_minimum_size = Vector2(300, 56)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.modulate.a = 0.0
	btn.pressed.connect(func(): GameState.goto("title"))
	col.add_child(btn)

	title.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(title, "modulate:a", 1.0, 1.2)
	for p in ending.get("text", []):
		t.tween_callback(func(): text.append_text(p + "\n\n"))
		t.tween_interval(clampf(p.length() * 0.03, 1.2, 3.5))
	t.tween_property(btn, "modulate:a", 1.0, 0.6)
	t.tween_callback(btn.grab_focus)
