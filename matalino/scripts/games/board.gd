class_name Board
extends Control
## Base class for every puzzle board: seeded generation, undo history,
## pointer handling, small pop animations and the win wave.

signal solved
signal changed

const GAP := 6.0

var level := 1
var accent := Color.WHITE
var rng := RandomNumberGenerator.new()
var hints_used := 0
var mistakes := 0
var is_solved := false
var history: Array = []
## Seconds since the board was solved (-1 while playing); drives the win wave.
var win_t := -1.0

## True while the puzzle is being generated on a worker thread.
var loading := false

var _pops := {}
var _down := false
var _task := -1


func setup(lvl: int, seed_value: int, color: Color) -> void:
	level = lvl
	accent = color
	rng.seed = seed_value
	hints_used = 0
	mistakes = 0
	is_solved = false
	win_t = -1.0
	history.clear()
	_pops.clear()
	loading = true
	queue_redraw()
	_task = WorkerThreadPool.add_task(generate, true, "puzzle generation")


func _finish_loading() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	loading = false
	queue_redraw()
	changed.emit()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# --- Overridables ----------------------------------------------------------

func generate() -> void:
	pass


func snapshot() -> Variant:
	return null


func restore(_s: Variant) -> void:
	pass


func reset_board() -> void:
	pass


## Applies one hint. Returns false when no hint is possible.
func apply_hint() -> bool:
	return false


func uses_timer() -> bool:
	return true


func supports_undo() -> bool:
	return true


func lives() -> int:
	return -1


## Short progress text shown above the board, e.g. "3 / 7 crowns".
func status_text() -> String:
	return ""


func pointer_down(_p: Vector2) -> void:
	pass


func pointer_drag(_p: Vector2) -> void:
	pass


func pointer_up(_p: Vector2) -> void:
	pass


# --- Common behavior -------------------------------------------------------

func can_undo() -> bool:
	return supports_undo() and not history.is_empty() and not is_solved and not loading


func undo() -> void:
	if not can_undo():
		return
	restore(history.pop_back())
	Sfx.play("undo")
	queue_redraw()
	changed.emit()


func restart() -> void:
	if is_solved or loading:
		return
	if supports_undo():
		history.append(snapshot())
	reset_board()
	Sfx.play("undo", 0.8)
	queue_redraw()
	changed.emit()


func hint() -> void:
	if is_solved or loading:
		return
	if apply_hint():
		hints_used += 1
		Sfx.play("hint")
		Sfx.buzz(20)
		queue_redraw()
		changed.emit()


func stars() -> int:
	return clampi(3 - hints_used - (1 if mistakes > 0 else 0), 1, 3)


func push_history() -> void:
	if supports_undo():
		history.append(snapshot())
		if history.size() > 200:
			history.pop_front()


func finish() -> void:
	if is_solved:
		return
	is_solved = true
	win_t = 0.0
	Sfx.play("win")
	Sfx.buzz(40)
	changed.emit()
	await get_tree().create_timer(1.15).timeout
	solved.emit()


func pop(key: Variant) -> void:
	_pops[key] = 1.0


func pop_amt(key: Variant) -> float:
	return _pops.get(key, 0.0)


func _process(delta: float) -> void:
	if loading:
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
			_finish_loading()
		else:
			queue_redraw()
			return
	var animating := false
	for k in _pops.keys():
		_pops[k] -= delta * 4.0
		if _pops[k] <= 0.0:
			_pops.erase(k)
		animating = true
	if win_t >= 0.0 and win_t < 3.0:
		win_t += delta
		animating = true
	if animating or _always_animate():
		queue_redraw()


func _always_animate() -> bool:
	return false


## Brightness boost of the win wave for a cell at normalized distance d (0..1).
func wave(d: float) -> float:
	if win_t < 0.0:
		return 0.0
	var t := win_t * 1.6 - d
	return clampf(sin(clampf(t, 0.0, 1.0) * PI), 0.0, 1.0)


func _draw() -> void:
	if loading:
		var c := size * 0.5
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(c, 34.0, t * 5.0, t * 5.0 + PI * 1.4, 32, accent, 6.0, true)
		UI.text_c(self, c + Vector2(0, 80), "Building puzzle", 24, UI.MUTED, false)
		return
	draw_board()


func draw_board() -> void:
	pass


func _gui_input(e: InputEvent) -> void:
	if is_solved or loading:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			pointer_down(e.position)
		elif _down:
			_down = false
			pointer_up(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _down:
		pointer_drag(e.position)
		accept_event()


# --- Grid geometry ---------------------------------------------------------

## Largest centered square-cell grid that fits this control.
func grid_rect(cols: int, rows: int) -> Rect2:
	var cs := minf(size.x / cols, size.y / rows)
	var sz := Vector2(cs * cols, cs * rows)
	return Rect2((size - sz) * 0.5, sz)


func cell_size(cols: int, rows: int) -> float:
	return grid_rect(cols, rows).size.x / cols


func cell_rect(cols: int, rows: int, c: int, r: int) -> Rect2:
	var gr := grid_rect(cols, rows)
	var cs := gr.size.x / cols
	return Rect2(gr.position + Vector2(c * cs, r * cs), Vector2(cs, cs))


## Returns Vector2i(col, row) under p, or (-1, -1).
func cell_at(cols: int, rows: int, p: Vector2) -> Vector2i:
	var gr := grid_rect(cols, rows)
	if not gr.has_point(p):
		return Vector2i(-1, -1)
	var cs := gr.size.x / cols
	var c := clampi(int((p.x - gr.position.x) / cs), 0, cols - 1)
	var r := clampi(int((p.y - gr.position.y) / cs), 0, rows - 1)
	return Vector2i(c, r)
