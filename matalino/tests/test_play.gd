extends Node
## Plays every game through simulated touches (tap/drag on the real board),
## checks the win is detected and progress is saved.
## Run: godot --headless --path . res://tests/test_play.tscn

var main: Control
var failures := 0


func _ready() -> void:
	Save.data = {}
	Save.load_data()
	for g in UI.GAMES:
		Save.g(g.id).seen_rules = true
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	for id in ["crown", "trail", "pulse", "duo", "echo"]:
		for lvl in [1, 9, 27]:
			await _play(id, lvl)
	await _play_daily("crown")
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _play(id: String, lvl: int) -> void:
	main.play(id, false, lvl)
	var b := await _board()
	var won := [false]
	b.solved.connect(func(): won[0] = true)
	await _solve(id, b)
	for i in 120:
		if won[0]:
			break
		await get_tree().process_frame
	await get_tree().create_timer(1.3).timeout
	_check(won[0], "%s level %d solved via input" % [id, lvl])
	_check(Save.level(id) >= lvl + 1, "%s level %d progress saved" % [id, lvl])
	print("%s level %d: %s" % [id, lvl, "ok" if won[0] else "NOT SOLVED"])


func _play_daily(id: String) -> void:
	main.play(id, true)
	var b := await _board()
	await _solve(id, b)
	await get_tree().create_timer(1.5).timeout
	_check(Save.daily_done(id), "daily %s recorded" % id)
	_check(Save.streak() >= 1, "streak counted")


func _board() -> Board:
	for i in 3:
		await get_tree().process_frame
	var b: Board = main.screen.board
	while b.loading:
		await get_tree().process_frame
	await get_tree().process_frame
	return b


func _center(b: Board, n: int, i: int) -> Vector2:
	return b.cell_rect(n, n, i % n, i / n).get_center()


func _press(b: Board, p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	b._gui_input(e)


func _drag(b: Board, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	b._gui_input(e)


func _tap(b: Board, p: Vector2, times := 1) -> void:
	for t in times:
		_press(b, p, true)
		_press(b, p, false)


func _solve(id: String, b: Board) -> void:
	match id:
		"crown":
			var c: CrownBoard = b
			for row in c.n:
				_tap(c, _center(c, c.n, row * c.n + c.solution[row]), 2)
		"trail":
			var t: TrailBoard = b
			_press(t, _center(t, t.n, t.solution[0]), true)
			for k in range(1, t.solution.size()):
				_drag(t, _center(t, t.n, t.solution[k]))
			_press(t, _center(t, t.n, t.solution[-1]), false)
		"pulse":
			var p: PulseBoard = b
			for i in p.n * p.n:
				var turns := 0
				while PulseBoard.rot(p.tiles[i], turns) != p.solution[i]:
					turns += 1
				_tap(p, _center(p, p.n, i), turns)
		"duo":
			var d: DuoBoard = b
			for i in d.n * d.n:
				if d.cells[i] == DuoBoard.EMPTY:
					_tap(d, _center(d, d.n, i), d.solution[i])
		"echo":
			var e: EchoBoard = b
			while e.phase != EchoBoard.Phase.INPUT:
				await get_tree().process_frame
			for i in e.pattern.keys():
				_tap(e, _center(e, e.n, i))
