extends Control
## Home: brand header, streak/stats, the daily challenge and the game list.

var app: Node

var _margin: MarginContainer
var _col: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_margin)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 18)
	_margin.add_child(_col)
	relayout()
	_build()
	for i in _col.get_child_count():
		var c: Control = _col.get_child(i)
		c.modulate.a = 0.0
		var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.03 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.35)


func relayout() -> void:
	if not _margin:
		return
	_margin.add_theme_constant_override("margin_left", int(UI.PAD))
	_margin.add_theme_constant_override("margin_right", int(UI.PAD))
	_margin.add_theme_constant_override("margin_top", int(app.inset_top + 8))
	_margin.add_theme_constant_override("margin_bottom", int(app.inset_bottom + 32))


func back() -> bool:
	for c in get_children():
		if c is Sheet:
			c.close()
			return true
	return false


func _painted(h: float, f: Callable) -> Painted:
	var p := Painted.new()
	p.custom_minimum_size.y = h
	p.painter = f
	return p


func _build() -> void:
	# Header
	var header := _painted(150, _draw_header)
	var gear := Btn.make(Btn.Kind.ICON, "", "gear", UI.MUTED)
	gear.size = Vector2(72, 72)
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.offset_left = -72
	gear.offset_top = 14
	gear.offset_bottom = 86
	gear.pressed.connect(_open_settings)
	header.add_child(gear)
	_col.add_child(header)

	# Stats
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 14)
	var items := [
		["flame", Color("ff8a3d"), str(Save.streak()), "day streak"],
		["check", UI.SUCCESS, str(Save.total_solved()), "solved"],
		["star", Color("f7b940"), str(Save.total_stars()), "stars"],
	]
	for it in items:
		var p := _painted(108, func(ci: Control, r: Rect2):
			UI.rrect(ci, r, UI.SURFACE, UI.RADIUS)
			UI.glyph(ci, it[0], r.position + Vector2(40, 40), 40, it[1])
			UI.text(ci, r.position + Vector2(68, 54), it[2], 34, UI.TEXT, true)
			UI.text(ci, r.position + Vector2(24, 92), it[3], 20, UI.MUTED))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(p)
	_col.add_child(stats)

	# Daily challenge
	var daily := Btn.make(Btn.Kind.CARD)
	daily.custom_minimum_size.y = 196
	daily.painter = _draw_daily
	daily.pressed.connect(_open_daily)
	_col.add_child(daily)

	_col.add_child(_painted(56, func(ci: Control, r: Rect2):
		UI.text(ci, r.position + Vector2(4, 44), "Puzzles", 30, UI.TEXT, true)
		UI.text(ci, r.position + Vector2(0, 44), "Infinite levels", 22, UI.MUTED, false,
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4)))

	for g in UI.GAMES:
		var card := Btn.make(Btn.Kind.CARD)
		card.custom_minimum_size.y = 128
		card.painter = _draw_game_card.bind(g)
		card.pressed.connect(app.play.bind(g.id))
		_col.add_child(card)

	_col.add_child(_painted(70, func(ci: Control, r: Rect2):
		UI.text_c(ci, r.get_center(), "Matalino · Gawa sa Pilipinas", 20, UI.FAINT, false)))


# --- Painters --------------------------------------------------------------

func _draw_header(ci: Control, r: Rect2) -> void:
	var y := r.position.y + 78
	UI.text(ci, Vector2(r.position.x, y), "matalino", 64, UI.TEXT, true)
	var w := UI.font_bold.get_string_size("matalino", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	UI.circle(ci, Vector2(r.position.x + w + 12, y - 8), 9, Color("f7b940"))
	UI.text(ci, Vector2(r.position.x + 2, y + 46), "Mind puzzles para sa matatalino.", 24, UI.MUTED)


func _draw_daily(ci: Control, r: Rect2) -> void:
	var done := Save.daily_count()
	var p := r.position
	UI.glyph(ci, "calendar", p + Vector2(46, 50), 40, UI.TEXT)
	UI.text(ci, p + Vector2(82, 52), "Daily challenge", 30, UI.TEXT, true)
	var date := Time.get_date_string_from_system()
	UI.text(ci, p + Vector2(82, 84), "Fresh puzzles every day · " + date, 21, UI.MUTED)
	var pill := "%d / 5" % done
	var pr := Rect2(Vector2(r.end.x - 112, p.y + 26), Vector2(88, 44))
	UI.rrect(ci, pr, UI.SUCCESS if done == 5 else UI.SURFACE_2, 22)
	UI.text_c(ci, pr.get_center(), pill, 22, UI.BG if done == 5 else UI.TEXT)
	var n := UI.GAMES.size()
	var gap := 14.0
	var cw := (r.size.x - 48 - gap * (n - 1)) / n
	for i in n:
		var g: Dictionary = UI.GAMES[i]
		var cr := Rect2(p + Vector2(24 + i * (cw + gap), 112), Vector2(cw, 60))
		var is_done := Save.daily_done(g.id)
		UI.rrect(ci, cr, Color(g.color, 0.9) if is_done else UI.SURFACE_2, 18)
		if is_done:
			UI.glyph(ci, "check", cr.get_center(), 40, UI.BG)
		else:
			UI.game_icon(ci, g.id, Rect2(cr.get_center() - Vector2(26, 26), Vector2(52, 52)), g.color)


func _draw_game_card(ci: Control, r: Rect2, g: Dictionary) -> void:
	var p := r.position
	var ir := Rect2(p + Vector2(18, 18), Vector2(r.size.y - 36, r.size.y - 36))
	UI.rrect(ci, ir, Color(g.color, 0.14), 20)
	UI.game_icon(ci, g.id, ir.grow(-12), g.color)
	var x := ir.end.x + 22
	UI.text(ci, Vector2(x, p.y + 54), g.name, 32, UI.TEXT, true)
	UI.text(ci, Vector2(x, p.y + 90), g.blurb, 21, UI.MUTED, false, HORIZONTAL_ALIGNMENT_LEFT,
		r.end.x - x - 120)
	var lvl := Save.level(g.id)
	var pill := "Lv %d" % lvl
	var pw := UI.font_bold.get_string_size(pill, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 32
	var pr := Rect2(Vector2(r.end.x - pw - 24, p.y + 26), Vector2(pw, 40))
	UI.rrect(ci, pr, Color(g.color, 0.16), 20)
	UI.text_c(ci, pr.get_center(), pill, 22, g.color)
	_chevron(ci, Vector2(r.end.x - 40, p.y + 90))


func _chevron(ci: Control, c: Vector2) -> void:
	UI.line(ci, c + Vector2(-6, -10), c + Vector2(4, 0), UI.FAINT, 4)
	UI.line(ci, c + Vector2(4, 0), c + Vector2(-6, 10), UI.FAINT, 4)


# --- Actions ---------------------------------------------------------------

func _open_daily() -> void:
	for g in UI.GAMES:
		if not Save.daily_done(g.id):
			app.play(g.id, true)
			return
	app.toast("All 5 done today. See you tomorrow!")


func _open_settings() -> void:
	var s := Sheet.new()
	s.set_bottom_inset(app.inset_bottom)
	add_child(s)
	s.add_label("Settings", 36, UI.TEXT, true)
	for key in ["sound", "haptics"]:
		var row := Btn.make(Btn.Kind.CARD)
		row.custom_minimum_size.y = 96
		var title: String = "Sound effects" if key == "sound" else "Vibration"
		row.painter = func(ci: Control, r: Rect2):
			UI.rrect(ci, r, UI.SURFACE_2, UI.RADIUS)
			UI.text(ci, r.position + Vector2(28, 58), title, 27, UI.TEXT)
			var on := Save.setting(key)
			var sw := Rect2(Vector2(r.end.x - 108, r.position.y + 28), Vector2(80, 44))
			UI.rrect(ci, sw, UI.SUCCESS if on else UI.LINE, 22)
			UI.circle(ci, sw.position + Vector2(58 if on else 22, 22), 17, UI.TEXT)
		row.pressed.connect(func():
			Save.set_setting(key, not Save.setting(key))
			row.queue_redraw())
		s.body.add_child(row)
	var reset := Btn.make(Btn.Kind.GHOST, "Reset progress", "", UI.DANGER)
	var armed := [false]
	reset.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			reset.label = "Tap again to erase everything"
			reset.queue_redraw()
			return
		Save.reset()
		s.close()
		app.show_home()
		app.toast("Progress reset"))
	s.add_button(reset, 88)
	s.add_label("Matalino 1.0 · 5 mind puzzles, infinite levels.\nFont: Inter (SIL Open Font License).",
		20, UI.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
