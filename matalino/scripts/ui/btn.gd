class_name Btn
extends Control
## Custom-drawn button with a press-scale animation. Lets drags pass through
## to a parent ScrollContainer and cancels the press once the finger moves.

signal pressed

enum Kind { PRIMARY, GHOST, ICON, CARD }

var kind := Kind.PRIMARY
var label := ""
var glyph := ""
var color := UI.TEXT
var enabled := true:
	set(v):
		enabled = v
		queue_redraw()
## Optional custom painter: func(ci: Control, rect: Rect2) for card content.
var painter: Callable

var _press := 0.0
var _held := false
var _start := Vector2.ZERO


static func make(k: Kind, text := "", icon := "", col := UI.TEXT) -> Btn:
	var b := Btn.new()
	b.kind = k
	b.label = text
	b.glyph = icon
	b.color = col
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE


func _gui_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_held = true
			_start = e.position
		elif _held:
			_held = false
			if Rect2(Vector2.ZERO, size).has_point(e.position):
				Sfx.play("tap")
				Sfx.buzz(8)
				pressed.emit()
	elif e is InputEventMouseMotion and _held:
		if e.position.distance_to(_start) > 18.0:
			_held = false


func _process(delta: float) -> void:
	var target := 1.0 if _held else 0.0
	if not is_equal_approx(_press, target):
		_press = move_toward(_press, target, delta * 10.0)
		queue_redraw()


func _draw() -> void:
	var s := 1.0 - _press * 0.04
	var r := Rect2(size * (1.0 - s) * 0.5, size * s)
	var a := 1.0 if enabled else 0.35
	match kind:
		Kind.PRIMARY:
			UI.rrect(self, r, Color(color, a), r.size.y * 0.5)
			_content(r, Color(UI.BG, a))
		Kind.GHOST:
			UI.rrect(self, r, Color(UI.SURFACE_2, a), r.size.y * 0.5)
			_content(r, Color(UI.TEXT, a))
		Kind.ICON:
			UI.circle(self, r.get_center(), r.size.y * 0.5, Color(UI.SURFACE_2, a))
			UI.glyph(self, glyph, r.get_center(), r.size.y * 0.62, Color(color, a))
		Kind.CARD:
			UI.rrect(self, r, UI.SURFACE.lightened(_press * 0.04), UI.RADIUS)
			if painter.is_valid():
				painter.call(self, r)


func _content(r: Rect2, col: Color) -> void:
	var fs := int(r.size.y * 0.34)
	var tw := UI.font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gw := r.size.y * 0.5 if glyph != "" else 0.0
	var gap := 10.0 if glyph != "" and label != "" else 0.0
	var x := r.get_center().x - (gw + gap + tw) * 0.5
	if glyph != "":
		UI.glyph(self, glyph, Vector2(x + gw * 0.5, r.get_center().y), gw, col)
	if label != "":
		UI.text_c(self, Vector2(x + gw + gap + tw * 0.5, r.get_center().y), label, fs, col)
