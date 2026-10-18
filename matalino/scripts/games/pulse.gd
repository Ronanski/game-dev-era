class_name PulseBoard
extends Board
## Rotate pipe tiles until every tile is connected to the core with no
## loose ends (a scrambled random spanning tree).

const N_ := 1
const E_ := 2
const S_ := 4
const W_ := 8
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var n := 4
var core := 0
var tiles := PackedInt32Array()
var solution := PackedInt32Array()
var moves := 0
var lit := {}

var _spin := {}  # cell -> remaining spin angle (radians)
var _press := -1


static func size_for(lvl: int) -> int:
	if lvl <= 3:
		return 4
	if lvl <= 10:
		return 5
	if lvl <= 25:
		return 6
	return 7


static func rot(mask: int, times := 1) -> int:
	for t in times % 4:
		mask = ((mask << 1) | (mask >> 3)) & 15
	return mask


func generate() -> void:
	n = size_for(level)
	core = (n / 2) * n + n / 2
	solution = PulseBoard.make(n, core, rng)
	reset_board()


func reset_board() -> void:
	# Scramble deterministically for this level so restart gives the same start.
	var r := RandomNumberGenerator.new()
	r.seed = hash(solution)
	tiles = solution.duplicate()
	while true:
		for i in n * n:
			tiles[i] = rot(tiles[i], r.randi_range(0, 3))
		if not PulseBoard.is_complete(n, core, tiles):
			break
	moves = 0
	_spin.clear()
	_refresh()


func snapshot() -> Variant:
	return [tiles.duplicate(), moves]


func restore(s: Variant) -> void:
	tiles = s[0]
	moves = s[1]
	_refresh()


func status_text() -> String:
	return "%d / %d lit · %d moves" % [lit.size(), n * n, moves]


# --- Generation ------------------------------------------------------------

## Random spanning tree grown outward from the core (Prim-style frontier).
static func make(size: int, start: int, r: RandomNumberGenerator) -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(size * size)
	t.fill(0)
	var inside := {start: true}
	var frontier: Array = []
	_add_frontier(start, size, inside, frontier)
	while not frontier.is_empty():
		var k := r.randi() % frontier.size()
		var e: Array = frontier[k]
		frontier.remove_at(k)
		var to: int = e[1]
		if inside.has(to):
			continue
		var from: int = e[0]
		var d: int = e[2]
		# Avoid four-way crosses most of the time; they make boards too easy.
		if _bits(t[from]) >= 3 and r.randf() < 0.85 and frontier.size() > 0:
			frontier.append(e)
			continue
		t[from] |= 1 << d
		t[to] |= 1 << ((d + 2) % 4)
		inside[to] = true
		_add_frontier(to, size, inside, frontier)
	return t


static func _add_frontier(i: int, size: int, inside: Dictionary, frontier: Array) -> void:
	var x := i % size
	var y := i / size
	for d in 4:
		var nx: int = x + DIRS[d].x
		var ny: int = y + DIRS[d].y
		if nx >= 0 and ny >= 0 and nx < size and ny < size and not inside.has(ny * size + nx):
			frontier.append([i, ny * size + nx, d])


static func _bits(m: int) -> int:
	return (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1) + ((m >> 3) & 1)


## Cells reachable from the core through matching pipe ends.
static func connected(size: int, start: int, t: PackedInt32Array) -> Dictionary:
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % size
		var y := i / size
		for d in 4:
			if not (t[i] & (1 << d)):
				continue
			var nx: int = x + DIRS[d].x
			var ny: int = y + DIRS[d].y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			var j := ny * size + nx
			if t[j] & (1 << ((d + 2) % 4)) and not seen.has(j):
				seen[j] = true
				stack.append(j)
	return seen


static func is_complete(size: int, start: int, t: PackedInt32Array) -> bool:
	if connected(size, start, t).size() != size * size:
		return false
	for i in size * size:
		var x := i % size
		var y := i / size
		for d in 4:
			if not (t[i] & (1 << d)):
				continue
			var nx: int = x + DIRS[d].x
			var ny: int = y + DIRS[d].y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				return false
			if not (t[ny * size + nx] & (1 << ((d + 2) % 4))):
				return false
	return true


func _refresh() -> void:
	var before := lit.size()
	lit = PulseBoard.connected(n, core, tiles)
	if lit.size() > before and before > 0:
		Sfx.play("connect", 0.9 + float(lit.size()) / (n * n) * 0.5)


# --- Input -----------------------------------------------------------------

func pointer_down(p: Vector2) -> void:
	var c := cell_at(n, n, p)
	_press = c.y * n + c.x if c.x >= 0 else -1
	queue_redraw()


func pointer_up(p: Vector2) -> void:
	var c := cell_at(n, n, p)
	var i := c.y * n + c.x if c.x >= 0 else -1
	if i >= 0 and i == _press:
		_rotate(i)
	_press = -1
	queue_redraw()


func _rotate(i: int) -> void:
	push_history()
	tiles[i] = rot(tiles[i])
	moves += 1
	_spin[i] = _spin.get(i, 0.0) - PI / 2.0
	Sfx.play("rotate", 0.95 + rng.randf() * 0.1)
	Sfx.buzz(8)
	_refresh()
	changed.emit()
	if PulseBoard.is_complete(n, core, tiles):
		finish()


func apply_hint() -> bool:
	# Fix a wrong tile, preferring one touching the lit network.
	var best := -1
	for i in n * n:
		if tiles[i] == solution[i]:
			continue
		if best < 0:
			best = i
		if _touches_lit(i):
			best = i
			break
	if best < 0:
		return false
	push_history()
	var turns := 0
	while tiles[best] != solution[best] and turns < 4:
		tiles[best] = rot(tiles[best])
		turns += 1
	_spin[best] = _spin.get(best, 0.0) - PI / 2.0 * turns
	pop(best)
	_refresh()
	if PulseBoard.is_complete(n, core, tiles):
		finish()
	return true


func _touches_lit(i: int) -> bool:
	var x := i % n
	var y := i / n
	for d in DIRS:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx >= 0 and ny >= 0 and nx < n and ny < n and lit.has(ny * n + nx):
			return true
	return false


func _process(delta: float) -> void:
	super(delta)
	if not _spin.is_empty():
		for k in _spin.keys():
			_spin[k] = move_toward(_spin[k], 0.0, delta * 14.0 * maxf(1.0, absf(_spin[k])))
			if is_zero_approx(_spin[k]):
				_spin.erase(k)
		queue_redraw()


func _always_animate() -> bool:
	return true  # the core breathes


# --- Drawing ---------------------------------------------------------------

func draw_board() -> void:
	var gr := grid_rect(n, n)
	var cs := gr.size.x / n
	var t := Time.get_ticks_msec() / 1000.0
	UI.rrect(self, gr.grow(10), UI.SURFACE, 30)
	for i in n * n:
		var x := i % n
		var y := i / n
		var cr := Rect2(gr.position + Vector2(x * cs, y * cs), Vector2(cs, cs))
		var on := lit.has(i)
		var bg := UI.SURFACE_2
		if i == _press:
			bg = bg.lightened(0.08)
		var d := Vector2(x - n / 2, y - n / 2).length() / n
		var wv := wave(d)
		UI.rrect(self, cr.grow(-GAP * 0.5), bg.lerp(accent, wv * 0.3), cs * 0.16)
		var c := cr.get_center()
		var col := accent if on else UI.FAINT
		col = col.lerp(Color.WHITE, wv * 0.5)
		var ang: float = _spin.get(i, 0.0)
		draw_set_transform(c, ang)
		var w := cs * 0.15
		var reach := cs * 0.5 - GAP * 0.5 + 1.0
		for dd in 4:
			if tiles[i] & (1 << dd):
				var dir := Vector2(DIRS[dd])
				if on:
					draw_line(Vector2.ZERO, dir * reach, Color(accent, 0.25), w * 2.2, true)
				UI.line(self, Vector2.ZERO, dir * reach, col, w)
		var deg := PulseBoard._bits(tiles[i])
		if i == core:
			var br := 0.5 + 0.5 * sin(t * 3.0)
			UI.circle(self, Vector2.ZERO, cs * (0.27 + 0.03 * br), Color(accent, 0.25))
			UI.circle(self, Vector2.ZERO, cs * 0.22, accent)
			UI.circle(self, Vector2.ZERO, cs * 0.09, UI.BG)
		elif deg == 1:
			var s := 1.0 + pop_amt(i) * 0.3
			if on:
				UI.circle(self, Vector2.ZERO, cs * 0.2 * s, Color(accent, 0.25))
				UI.circle(self, Vector2.ZERO, cs * 0.15 * s, accent.lerp(Color.WHITE, wv))
				UI.circle(self, Vector2.ZERO, cs * 0.06 * s, UI.BG)
			else:
				UI.circle(self, Vector2.ZERO, cs * 0.15 * s, UI.SURFACE_2)
				UI.ring(self, Vector2.ZERO, cs * 0.15 * s, UI.FAINT, w * 0.6)
		else:
			UI.circle(self, Vector2.ZERO, w * 0.62, col)
		draw_set_transform(Vector2.ZERO, 0.0)
