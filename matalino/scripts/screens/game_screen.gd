extends Control
## Play screen: top bar, timer/lives, the board, and Undo / Hint / Restart.

const BOARDS := {
	"crown": preload("res://scripts/games/crown.gd"),
	"trail": preload("res://scripts/games/trail.gd"),
	"pulse": preload("res://scripts/games/pulse.gd"),
	"duo": preload("res://scripts/games/duo.gd"),
	"echo": preload("res://scripts/games/echo.gd"),
}

var app: Node
var game_id := "crown"
var daily := false
var level := 1

var board: Board
var elapsed := 0.0
var info: Dictionary

var _back_btn: Btn
var _help_btn: Btn
var _undo: Btn
var _hint: Btn
var _restart: Btn
var _focused := true


func _ready() -> void:
	info = UI.game(game_id)
	board = BOARDS[game_id].new()
	board.solved.connect(_on_solved)
	board.changed.connect(_refresh)
	add_child(board)

	_back_btn = Btn.make(Btn.Kind.ICON, "", "back")
	_back_btn.pressed.connect(func(): app.show_home())
	_help_btn = Btn.make(Btn.Kind.ICON, "", "help", UI.MUTED)
	_help_btn.pressed.connect(_show_rules)
	_undo = Btn.make(Btn.Kind.GHOST, "Undo", "undo")
	_undo.pressed.connect(board.undo)
	_hint = Btn.make(Btn.Kind.GHOST, "Hint", "hint")
	_hint.pressed.connect(board.hint)
	_restart = Btn.make(Btn.Kind.GHOST, "Restart", "restart")
	_restart.pressed.connect(board.restart)
	for b in [_back_btn, _help_btn, _undo, _hint, _restart]:
		add_child(b)
	relayout()
	_start()
	if not Save.g(game_id).get("seen_rules", false):
		Save.g(game_id).seen_rules = true
		Save.flush()
		_show_rules.call_deferred()


func _start() -> void:
	var seed_value := Save.daily_seed(game_id, Save.today()) if daily \
		else Save.level_seed(game_id, level)
	elapsed = 0.0
	board.setup(Save.DAILY_LEVEL if daily else level, seed_value, info.color)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		relayout()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func relayout() -> void:
	if not board or not app:
		return
	var top: float = app.inset_top
	var bottom: float = app.inset_bottom
	_back_btn.position = Vector2(UI.PAD - 4, top + 10)
	_back_btn.size = Vector2(76, 76)
	_help_btn.position = Vector2(size.x - UI.PAD - 72, top + 10)
	_help_btn.size = Vector2(76, 76)
	var bh := 88.0
	var gap := 16.0
	var bw := (size.x - UI.PAD * 2 - gap * 2) / 3.0
	var by := size.y - bottom - bh - 28
	for i in 3:
		var b: Btn = [_undo, _hint, _restart][i]
		b.position = Vector2(UI.PAD + i * (bw + gap), by)
		b.size = Vector2(bw, bh)
	var board_top := top + 200
	board.position = Vector2(UI.PAD + 8, board_top)
	board.size = Vector2(size.x - UI.PAD * 2 - 16, by - board_top - 96)
	queue_redraw()


func back() -> bool:
	for c in get_children():
		if c is Sheet:
			if c.dismissible:
				c.close()
			return true
	app.show_home()
	return true


func _paused() -> bool:
	for c in get_children():
		if c is Sheet:
			return true
	return not _focused


func _process(delta: float) -> void:
	if board.uses_timer() and not board.is_solved and not board.loading and not _paused():
		var before := int(elapsed)
		elapsed += delta
		if int(elapsed) != before:
			queue_redraw()


func _refresh() -> void:
	_undo.enabled = board.can_undo()
	_hint.enabled = not board.is_solved and not board.loading
	_restart.enabled = not board.is_solved and not board.loading
	queue_redraw()


func _draw() -> void:
	var top: float = app.inset_top
	var cx := size.x * 0.5
	UI.text_c(self, Vector2(cx, top + 34), info.name, 34, UI.TEXT, true)
	var sub := ("Daily · " + Save.today()) if daily else ("Level %d" % level)
	UI.text_c(self, Vector2(cx, top + 70), sub, 22, info.color, false)

	# Info row: status on the left, timer or lives on the right.
	var y := top + 140
	var pr := Rect2(Vector2(UI.PAD, y - 30), Vector2(size.x - UI.PAD * 2, 60))
	UI.rrect(self, pr, UI.SURFACE, 30)
	var st := board.status_text() if not board.loading else "…"
	UI.text(self, Vector2(pr.position.x + 26, y + 9), st, 22, UI.MUTED)
	if board.lives() >= 0:
		for i in 3:
			var on := i < board.lives()
			UI.glyph(self, "heart", Vector2(pr.end.x - 40 - i * 40, y), 34,
				UI.DANGER if on else UI.LINE)
	else:
		var t := UI.fmt_time(elapsed)
		UI.text(self, Vector2(pr.position.x, y + 10), t, 26, UI.TEXT, true,
			HORIZONTAL_ALIGNMENT_RIGHT, pr.size.x - 26)


# --- Sheets ----------------------------------------------------------------

func _sheet() -> Sheet:
	var s := Sheet.new()
	s.set_bottom_inset(app.inset_bottom)
	add_child(s)
	return s


func _show_rules() -> void:
	var s := _sheet()
	var col: Color = info.color
	s.add_painted(96, func(ci: Control, r: Rect2):
		var ir := Rect2(r.position, Vector2(96, 96))
		UI.rrect(ci, ir, Color(col, 0.14), 24)
		UI.game_icon(ci, game_id, ir.grow(-14), col)
		UI.text(ci, r.position + Vector2(122, 44), "How to play", 22, UI.MUTED)
		UI.text(ci, r.position + Vector2(122, 84), info.name, 38, UI.TEXT, true))
	s.add_space(4)
	var rules: Array = info.rules
	for i in rules.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var num := Painted.new()
		num.custom_minimum_size = Vector2(44, 44)
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var k := i + 1
		num.painter = func(ci: Control, r: Rect2):
			UI.circle(ci, r.get_center(), 22, Color(col, 0.18))
			UI.text_c(ci, r.get_center(), str(k), 22, col)
		row.add_child(num)
		var l := Label.new()
		l.text = rules[i]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 25)
		l.add_theme_color_override("font_color", UI.TEXT)
		row.add_child(l)
		s.body.add_child(row)
	s.add_space(8)
	var ok := s.add_button(Btn.make(Btn.Kind.PRIMARY, "Let's go", "", col))
	ok.pressed.connect(s.close)


func _on_solved() -> void:
	var stars := board.stars()
	var t := elapsed
	var result := {}
	if daily:
		Save.record_daily(game_id, t)
	else:
		result = Save.record_level(game_id, level, t, stars)
	var s := _sheet()
	s.dismissible = false
	var col: Color = info.color
	var titles := ["Solved", "Nice work", "Brilliant!"]
	var title: String = titles[stars - 1]
	if daily:
		title = "Daily done!"
	var born := Time.get_ticks_msec()
	var header := s.add_painted(230, func(ci: Control, r: Rect2):
		var age := (Time.get_ticks_msec() - born) / 1000.0
		var c := Vector2(r.get_center().x, r.position.y + 70)
		var k := clampf(age * 3.0, 0.0, 1.0)
		var e := 1.0 + sin(k * PI) * 0.15
		UI.circle(ci, c, 66 * k * e + 10, Color(col, 0.15))
		UI.circle(ci, c, 56 * k * e, col)
		if k >= 1.0:
			UI.glyph(ci, "check", c, 80, UI.BG)
		# Confetti burst
		for i in 18:
			var a := TAU * i / 18.0 + 0.3
			var d := 70.0 + age * 260.0
			var fade := clampf(1.0 - age * 1.2, 0.0, 1.0)
			if fade > 0.0:
				var pc: Color = [col, UI.DUO_B, Color("f7b940"), UI.SUCCESS][i % 4]
				UI.circle(ci, c + Vector2(cos(a), sin(a)) * d, 6.0, Color(pc, fade))
		UI.text_c(ci, Vector2(c.x, r.position.y + 180), title, 40, UI.TEXT, true)
		var sub: String = info.name + " · " + (("Daily " + Save.today()) if daily else "Level %d" % level)
		UI.text_c(ci, Vector2(c.x, r.position.y + 218), sub, 22, UI.MUTED, false))
	header.animate = true

	var stats := []
	if board.uses_timer():
		stats.append(["Time", UI.fmt_time(t)])
		if not daily:
			stats.append(["Best", UI.fmt_time(result.best)])
	else:
		stats.append(["Mistakes", str(board.mistakes)])
	stats.append(["Hints", str(board.hints_used)])
	var new_best: bool = result.get("new_best", false)
	s.add_painted(128, func(ci: Control, r: Rect2):
		UI.rrect(ci, r, UI.SURFACE_2, UI.RADIUS)
		var w := r.size.x / (stats.size() + 1)
		for i in stats.size():
			var c := Vector2(r.position.x + w * (i + 0.5), r.get_center().y)
			UI.text_c(ci, c + Vector2(0, -16), stats[i][1], 32, UI.TEXT, true)
			var lab: String = stats[i][0]
			if lab == "Best" and new_best:
				lab = "New best!"
			UI.text_c(ci, c + Vector2(0, 26), lab, 20, col if lab == "New best!" else UI.MUTED, false)
		var sc := Vector2(r.position.x + w * (stats.size() + 0.5), r.get_center().y)
		for i in 3:
			UI.star(ci, sc + Vector2((i - 1) * 34, -14), 15, Color("f7b940") if i < stars else UI.LINE)
		UI.text_c(ci, sc + Vector2(0, 26), "Stars", 20, UI.MUTED, false))
	s.add_space(4)
	if daily:
		var next_id := ""
		for g in UI.GAMES:
			if not Save.daily_done(g.id):
				next_id = g.id
				break
		if next_id != "":
			var nb := s.add_button(Btn.make(Btn.Kind.PRIMARY, "Next daily: " + UI.game(next_id).name, "", col))
			nb.pressed.connect(func(): app.play(next_id, true))
		var hb := s.add_button(Btn.make(Btn.Kind.GHOST, "Home"), 84)
		hb.pressed.connect(func(): app.show_home())
	else:
		var nb := s.add_button(Btn.make(Btn.Kind.PRIMARY, "Next level", "", col))
		nb.pressed.connect(func(): app.play(game_id, false, level + 1))
		var hb := s.add_button(Btn.make(Btn.Kind.GHOST, "Home"), 84)
		hb.pressed.connect(func(): app.show_home())
