extends Control
## Title screen.

var _moon: Panel


func _ready() -> void:
	theme = GameState.theme
	var bg := ColorRect.new()
	bg.color = Color("#0d0b16")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# A simple glowing moon with the serpent's shadow over it.
	_moon = Panel.new()
	var moon_style := StyleBoxFlat.new()
	moon_style.bg_color = Color("#f2e6b8")
	moon_style.set_corner_radius_all(140)
	moon_style.shadow_color = Color(0.95, 0.85, 0.55, 0.45)
	moon_style.shadow_size = 50
	_moon.add_theme_stylebox_override("panel", moon_style)
	_moon.anchor_left = 0.5
	_moon.anchor_right = 0.5
	_moon.offset_left = 120
	_moon.offset_right = 400
	_moon.offset_top = 60
	_moon.offset_bottom = 340
	add_child(_moon)
	var bite := Panel.new()
	var bite_style := StyleBoxFlat.new()
	bite_style.bg_color = Color("#0d0b16")
	bite_style.set_corner_radius_all(130)
	bite.add_theme_stylebox_override("panel", bite_style)
	bite.position = Vector2(90, -40)
	bite.size = Vector2(260, 260)
	_moon.add_child(bite)

	var col := VBoxContainer.new()
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_left = 90
	col.offset_right = 700
	col.offset_top = 90
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var title := Label.new()
	title.text = "Alamat ng\nHuling Buwan"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#e8c170"))
	title.add_theme_color_override("font_outline_color", Color("#2a1a10"))
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Kabanata 1: Ang Tolda ng Kapayapaan"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color("#bfc6d9"))
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)

	var new_btn := _button(col, "Bagong Laro")
	new_btn.pressed.connect(_on_new)
	var cont := _button(col, "Ipagpatuloy")
	cont.disabled = not GameState.has_save()
	cont.pressed.connect(_on_continue)
	if not OS.has_feature("web"):
		_button(col, "Lumabas").pressed.connect(func(): get_tree().quit())
	(cont if not cont.disabled else new_btn).grab_focus.call_deferred()

	var seen := Label.new()
	seen.text = "Mga wakas na natuklasan: %d / %d" % [GameState.seen_endings().size(), GameState.db["endings"].size()]
	seen.add_theme_font_size_override("font_size", 18)
	seen.add_theme_color_override("font_color", Color("#8a90a8"))
	col.add_child(seen)

	var ver := Label.new()
	ver.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.1"))
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -120
	ver.offset_top = -40
	ver.add_theme_color_override("font_color", Color("#55596a"))
	add_child(ver)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_moon.modulate = Color(1, 1, 1, 0.9 + sin(t * 1.5) * 0.1)


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(b)
	return b


func _on_new() -> void:
	GameState.new_game()
	GameState.goto("world")


func _on_continue() -> void:
	if GameState.load_game():
		GameState.goto("world")
