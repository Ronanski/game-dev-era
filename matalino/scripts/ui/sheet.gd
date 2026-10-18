class_name Sheet
extends Control
## Modal bottom sheet with a dimmed backdrop and slide-up animation.

signal closed

var dismissible := true
var panel: PanelContainer
var body: VBoxContainer

var _t := 0.0
var _closing := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.SURFACE
	sb.corner_radius_top_left = 40
	sb.corner_radius_top_right = 40
	sb.corner_detail = 12
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 52
	sb.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	panel.add_child(body)
	panel.draw.connect(_draw_handle)


func set_bottom_inset(px: float) -> void:
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	sb.content_margin_bottom = 40 + px


func _ready() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_t, 0.0, 1.0, 0.32)


func _set_t(v: float) -> void:
	_t = v
	panel.position.y = size.y - panel.size.y + panel.size.y * (1.0 - v)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6 * _t))


func _draw_handle() -> void:
	var w := 64.0
	UI.rrect(panel, Rect2(Vector2((panel.size.x - w) * 0.5, 16), Vector2(w, 7)), UI.LINE, 4)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and dismissible:
		if not panel.get_global_rect().has_point(e.global_position):
			close()
	accept_event()


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_t, _t, 0.0, 0.22)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and panel and not _closing:
		_set_t.call_deferred(_t)


# --- Content helpers -------------------------------------------------------

func add_label(s: String, font_size := 26, color := UI.TEXT, bold := false,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UI.font_bold)
	body.add_child(l)
	return l


func add_space(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(c)


func add_button(b: Btn, h := 92.0) -> Btn:
	b.custom_minimum_size.y = h
	body.add_child(b)
	return b


## A control that paints itself with f(ci, rect).
func add_painted(h: float, f: Callable) -> Control:
	var c := Painted.new()
	c.custom_minimum_size.y = h
	c.painter = f
	body.add_child(c)
	return c
