extends Control
## App shell: owns the current screen, transitions, safe-area insets,
## the Android back button and toasts.

const HomeScreen := preload("res://scripts/screens/home.gd")
const GameScreen := preload("res://scripts/screens/game_screen.gd")

var screen: Control
var inset_top := 0.0
var inset_bottom := 0.0

var _toast: Control


func _ready() -> void:
	theme = UI.theme
	get_tree().root.size_changed.connect(_update_insets)
	_update_insets()
	show_home()


func _update_insets() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var scale := size.y / maxf(1.0, win.y) if size.y > 0 else 1.0
	inset_top = 24.0
	inset_bottom = 12.0
	if OS.has_feature("mobile") and win.y > 0:
		inset_top = maxf(24.0, safe.position.y * scale + 8.0)
		inset_bottom = maxf(12.0, (win.y - safe.end.y) * scale)
	if screen and screen.has_method("relayout"):
		screen.relayout()


func show_home() -> void:
	var h := HomeScreen.new()
	h.app = self
	_swap(h, -1)


func play(id: String, daily := false, lvl := 0) -> void:
	var g := GameScreen.new()
	g.app = self
	g.game_id = id
	g.daily = daily
	g.level = lvl if lvl > 0 else Save.level(id)
	_swap(g, 1)


func _swap(next: Control, dir: int) -> void:
	var old := screen
	screen = next
	next.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(next)
	if is_instance_valid(_toast):
		move_child(_toast, -1)
	next.modulate.a = 0.0
	next.position.x = 40.0 * dir
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(next, "modulate:a", 1.0, 0.28)
	tw.tween_property(next, "position:x", 0.0, 0.32)
	if old:
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tw.tween_property(old, "modulate:a", 0.0, 0.18)
		tw.tween_property(old, "position:x", -40.0 * dir, 0.25)
		tw.chain().tween_callback(old.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Save.flush()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		_back()


func _back() -> void:
	if screen and screen.has_method("back") and screen.back():
		return
	get_tree().quit()


func toast(msg: String) -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	var t := Painted.new()
	var fs := 24
	var w := UI.font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 64.0
	t.painter = func(ci: Control, r: Rect2):
		UI.rrect(ci, r, UI.TEXT, r.size.y * 0.5)
		UI.text_c(ci, r.get_center(), msg, fs, UI.BG, false)
	t.size = Vector2(w, 64)
	t.position = Vector2((size.x - w) * 0.5, size.y - inset_bottom - 220)
	add_child(t)
	_toast = t
	t.modulate.a = 0.0
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.8)
	tw.tween_property(t, "modulate:a", 0.0, 0.3)
	tw.tween_callback(t.queue_free)
