extends Node
## Generates many levels for every game and checks they are valid and solvable.
## Run: godot --headless --path . res://tests/test_generators.tscn

var failures := 0


func _ready() -> void:
	_crown()
	_trail()
	_pulse()
	_duo()
	_echo()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _rng(id: String, lvl: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("level:%s:%d" % [id, lvl])
	return r


func _crown() -> void:
	var t := Time.get_ticks_msec()
	var worst := 0
	for lvl in range(1, 41):
		var n := CrownBoard.size_for(lvl)
		var t0 := Time.get_ticks_msec()
		var p := CrownBoard.make(n, _rng("crown", lvl))
		worst = maxi(worst, Time.get_ticks_msec() - t0)
		_check(not p.is_empty(), "crown %d generated" % lvl)
		_check(CrownBoard.count_solutions(n, p.regions, 3) == 1, "crown %d unique" % lvl)
		var regs := {}
		for row in n:
			regs[p.regions[row * n + p.solution[row]]] = true
		_check(regs.size() == n, "crown %d solution covers all regions" % lvl)
	print("crown ok: %d ms total, worst %d ms" % [Time.get_ticks_msec() - t, worst])


func _trail() -> void:
	var t := Time.get_ticks_msec()
	for lvl in range(1, 41):
		var n := TrailBoard.size_for(lvl)
		var p := TrailBoard.make(n, n + 3, _rng("trail", lvl))
		_check(TrailBoard.is_valid(n, p.numbers, p.solution), "trail %d solution valid" % lvl)
	print("trail ok: %d ms" % (Time.get_ticks_msec() - t))


func _pulse() -> void:
	var t := Time.get_ticks_msec()
	for lvl in range(1, 41):
		var n := PulseBoard.size_for(lvl)
		var core := (n / 2) * n + n / 2
		var sol := PulseBoard.make(n, core, _rng("pulse", lvl))
		_check(PulseBoard.is_complete(n, core, sol), "pulse %d solution complete" % lvl)
	print("pulse ok: %d ms" % (Time.get_ticks_msec() - t))


func _duo() -> void:
	var t := Time.get_ticks_msec()
	var worst := 0
	for lvl in range(1, 41):
		var n := DuoBoard.size_for(lvl)
		var t0 := Time.get_ticks_msec()
		var p := DuoBoard.make(n, lvl >= 8, _rng("duo", lvl))
		worst = maxi(worst, Time.get_ticks_msec() - t0)
		var g: PackedInt32Array = p.givens.duplicate()
		_check(DuoBoard.solve(g, n, lvl >= 8) == "solved", "duo %d solvable" % lvl)
		_check(g == p.solution, "duo %d solves to solution" % lvl)
		var empties := 0
		for v in p.givens:
			empties += int(v == 0)
		if lvl % 8 == 0:
			print("  duo lvl %d: %dx%d, %d blanks" % [lvl, n, n, empties])
	print("duo ok: %d ms total, worst %d ms" % [Time.get_ticks_msec() - t, worst])


func _echo() -> void:
	for lvl in range(1, 41):
		var n := EchoBoard.size_for(lvl)
		var k := EchoBoard.count_for(lvl)
		_check(EchoBoard.make(n, k, _rng("echo", lvl)).size() == k, "echo %d" % lvl)
	print("echo ok")
