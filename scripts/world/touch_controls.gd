extends Control
## On-screen controls for phones: a virtual joystick (mode "stick") or a
## round button that presses an input action (mode "button").
## Uses real touch events so the stick and button work at the same time.

var mode := "stick"
var action := "interact"
var label := ""
var vector := Vector2.ZERO

var _touch := -1
var _pressed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _radius() -> float:
	return minf(size.x, size.y) * 0.5 - 6.0


func _draw() -> void:
	var c := size / 2.0
	var r := _radius()
	if mode == "stick":
		draw_circle(c, r, Color(1, 1, 1, 0.10))
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(c + vector * r * 0.6, r * 0.38, Color(0.91, 0.76, 0.44, 0.55))
	else:
		draw_circle(c, r, Color(0.91, 0.76, 0.44, 0.55 if _pressed else 0.28))
		draw_arc(c, r, 0, TAU, 48, Color(0.91, 0.76, 0.44, 0.9), 3.0)
		var font := get_theme_default_font()
		var fs := 20
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)


func _gui_input(event: InputEvent) -> void:
	var touch := DisplayServer.is_touchscreen_available()
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_down(event.position)
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_up()
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch:
		_move(event.position)
		accept_event()
	elif not touch and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down(event.position)
		else:
			_up()
	elif not touch and event is InputEventMouseMotion and _pressed:
		_move(event.position)


func _down(pos: Vector2) -> void:
	_pressed = true
	if mode == "button":
		Input.action_press(action)
	else:
		_move(pos)
	queue_redraw()


func _move(pos: Vector2) -> void:
	if mode != "stick":
		return
	var v := (pos - size / 2.0) / (_radius() * 0.6)
	vector = v.limit_length(1.0)
	queue_redraw()


func _up() -> void:
	_pressed = false
	vector = Vector2.ZERO
	if mode == "button":
		Input.action_release(action)
	queue_redraw()
