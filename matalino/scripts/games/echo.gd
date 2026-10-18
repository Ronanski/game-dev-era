class_name EchoBoard
extends Board
## Visual memory: a pattern flashes, then the player rebuilds it. Later
## levels spin the board before you answer.

enum Phase { READY, SHOW, SPIN, INPUT, FAIL, DONE }

const MAX_LIVES := 3

var n := 3
var count := 3
var pattern := {}
var found := {}
var wrong := {}
var phase := Phase.READY
var lives_left := MAX_LIVES
var spin := 0.0  # visual rotation offset (radians) while spinning

var _timer := 0.0
var _spin_dir := 1


static func size_for(lvl: int) -> int:
	if lvl <= 2:
		return 3
	if lvl <= 6:
		return 4
	if lvl <= 12:
		return 5
	if lvl <= 20:
		return 6
	return 7


static func count_for(lvl: int) -> int:
	var sz := size_for(lvl)
	return mini(3 + (lvl + 1) / 2, sz * sz / 2)


static func rotates(lvl: int) -> bool:
	return lvl >= 6


func uses_timer() -> bool:
	return false


func supports_undo() -> bool:
	return false


func lives() -> int:
	return lives_left


func status_text() -> String:
	match phase:
		Phase.READY, Phase.SHOW:
			return "Memorize %d tiles" % count
		Phase.SPIN:
			return "Spinning…"
		Phase.FAIL:
			return "Out of lives, new pattern"
	return "%d / %d found" % [found.size(), count]


func generate() -> void:
	n = size_for(level)
	count = count_for(level)
	lives_left = MAX_LIVES
	_new_round()


func reset_board() -> void:
	lives_left = MAX_LIVES
	_new_round()


func _new_round() -> void:
	pattern = EchoBoard.make(n, count, rng)
	found.clear()
	wrong.clear()
	phase = Phase.READY
	_timer = 0.5
	spin = 0.0


static func make(size: int, k: int, r: RandomNumberGenerator) -> Dictionary:
	var out := {}
	while out.size() < k:
		out[r.randi() % (size * size)] = true
	return out


func _show_time() -> float:
	return 1.1 + count * 0.12


func _process(delta: float) -> void:
	super(delta)
	if loading:
		return
	match phase:
		Phase.READY:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.SHOW
				_timer = _show_time()
				Sfx.play("flash")
				for i in pattern:
					pop(i)
		Phase.SHOW:
			_timer -= delta
			if _timer <= 0.0:
				if rotates(level):
					_start_spin()
				else:
					phase = Phase.INPUT
					Sfx.play("soft")
		Phase.SPIN:
			spin = move_toward(spin, 0.0, delta * 3.2)
			if is_zero_approx(spin):
				spin = 0.0
				phase = Phase.INPUT
				Sfx.play("soft")
		Phase.FAIL:
			_timer -= delta
			if _timer <= 0.0:
				lives_left = MAX_LIVES
				_new_round()
	queue_redraw()


func _start_spin() -> void:
	# Rotate the answer a quarter turn; draw it un-rotated first and spin into place.
	_spin_dir = 1 if rng.randf() < 0.5 else -1
	var rotated := {}
	for i in pattern:
		var x: int = i % n
		var y: int = i / n
		var nx := n - 1 - y if _spin_dir == 1 else y
		var ny := x if _spin_dir == 1 else n - 1 - x
		rotated[ny * n + nx] = true
	pattern = rotated
	spin = -PI / 2.0 * _spin_dir
	phase = Phase.SPIN
	Sfx.play("rotate", 0.7)


func pointer_up(p: Vector2) -> void:
	if phase != Phase.INPUT:
		return
	var c := cell_at(n, n, p)
	if c.x < 0:
		return
	var i := c.y * n + c.x
	if found.has(i) or wrong.has(i):
		return
	pop(i)
	if pattern.has(i):
		found[i] = true
		Sfx.play("place", 0.9 + float(found.size()) / count * 0.6)
		Sfx.buzz(10)
		if found.size() == count:
			phase = Phase.DONE
			finish()
	else:
		wrong[i] = true
		mistakes += 1
		lives_left -= 1
		Sfx.play("error")
		Sfx.buzz(45)
		if lives_left <= 0:
			phase = Phase.FAIL
			_timer = 1.6
	changed.emit()


func apply_hint() -> bool:
	if phase != Phase.INPUT:
		return false
	for i in pattern:
		if not found.has(i):
			found[i] = true
			pop(i)
			if found.size() == count:
				phase = Phase.DONE
				finish()
			return true
	return false


func stars() -> int:
	return clampi(3 - hints_used - mistakes, 1, 3)


func draw_board() -> void:
	var gr := grid_rect(n, n)
	var cs := gr.size.x / n
	var center := gr.get_center()
	draw_set_transform(center, spin)
	var off := -center
	UI.rrect(self, Rect2(gr.position + off, gr.size).grow(10), UI.SURFACE, 30)
	var showing := phase == Phase.SHOW or phase == Phase.FAIL
	for i in n * n:
		var x := i % n
		var y := i / n
		var cr := Rect2(gr.position + off + Vector2(x * cs, y * cs), Vector2(cs, cs)).grow(-GAP)
		var s := 1.0 + pop_amt(i) * 0.12
		var r := Rect2(cr.get_center() - cr.size * 0.5 * s, cr.size * s)
		var col := UI.SURFACE_2
		if found.has(i):
			col = accent.lerp(Color.WHITE, wave(Vector2(x, y).length() / (n * 1.42)) * 0.5)
		elif wrong.has(i):
			col = UI.DANGER.darkened(0.25)
		elif showing and pattern.has(i):
			col = accent if phase == Phase.SHOW else Color(accent, 0.35)
		if (phase == Phase.SHOW and pattern.has(i)) or found.has(i):
			UI.glow(self, r, Color(accent, 0.35), cs * 0.18, 14.0)
		UI.rrect(self, r, col, cs * 0.18)
		if wrong.has(i):
			var k := cs * 0.12
			var c := r.get_center()
			UI.line(self, c - Vector2(k, k), c + Vector2(k, k), UI.TEXT, 4.0)
			UI.line(self, c - Vector2(k, -k), c + Vector2(k, -k), UI.TEXT, 4.0)
	draw_set_transform(Vector2.ZERO, 0.0)
