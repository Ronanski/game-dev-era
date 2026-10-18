class_name CrownBoard
extends Board
## Queens-style logic puzzle: one crown per row, column and color region,
## and no two crowns may touch (diagonals included).

enum { EMPTY, MARK, CROWN }

var n := 5
var regions := PackedInt32Array()
var solution := PackedInt32Array()  # solution[row] = column
var cells := PackedInt32Array()

var _start := Vector2i(-1, -1)
var _drag_mode := -1  # -1 undecided, EMPTY/MARK = paint value
var _dragged := false
var _before: Variant


static func size_for(lvl: int) -> int:
	if lvl <= 3:
		return 5
	if lvl <= 10:
		return 6
	if lvl <= 25:
		return 7
	return 8


func generate() -> void:
	n = size_for(level)
	var puzzle := CrownBoard.make(n, rng)
	regions = puzzle.regions
	solution = puzzle.solution
	reset_board()


func reset_board() -> void:
	cells = PackedInt32Array()
	cells.resize(n * n)
	cells.fill(EMPTY)


func snapshot() -> Variant:
	return cells.duplicate()


func restore(s: Variant) -> void:
	cells = s


func status_text() -> String:
	return "%d / %d crowns" % [cells.count(CROWN), n]


# --- Generation ------------------------------------------------------------

## Builds a puzzle with exactly one solution.
static func make(size: int, r: RandomNumberGenerator) -> Dictionary:
	for attempt in 2000:
		var sol := _place(size, r)
		var reg := _grow(size, sol, r)
		if count_solutions(size, reg, 2) == 1:
			return {"regions": reg, "solution": sol}
	push_error("Crown: no unique puzzle found")
	return {}


static func _place(size: int, r: RandomNumberGenerator) -> PackedInt32Array:
	var p := PackedInt32Array()
	p.resize(size)
	p.fill(-1)
	_place_row(p, 0, size, r)
	return p


static func _place_row(p: PackedInt32Array, row: int, size: int, r: RandomNumberGenerator) -> bool:
	if row == size:
		return true
	var cols := range(size)
	_shuffle(cols, r)
	for c in cols:
		if c in p.slice(0, row):
			continue
		if row > 0 and absi(p[row - 1] - c) <= 1:
			continue
		p[row] = c
		if _place_row(p, row + 1, size, r):
			return true
	p[row] = -1
	return false


## Grows one region from each crown with random weights so sizes vary a lot;
## lopsided regions make unique solutions far more likely.
static func _grow(size: int, sol: PackedInt32Array, r: RandomNumberGenerator) -> PackedInt32Array:
	var reg := PackedInt32Array()
	reg.resize(size * size)
	reg.fill(-1)
	var weights: Array[float] = []
	for k in size:
		reg[k * size + sol[k]] = k
		weights.append(pow(r.randf(), 2.0) + 0.05)
	var left := size * size - size
	var total := 0.0
	for w in weights:
		total += w
	while left > 0:
		var pick := r.randf() * total
		var k := 0
		while k < size - 1 and pick > weights[k]:
			pick -= weights[k]
			k += 1
		var frontier: Array[int] = []
		for i in size * size:
			if reg[i] != k:
				continue
			var x := i % size
			var y := i / size
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < size and ny < size and reg[ny * size + nx] == -1:
					frontier.append(ny * size + nx)
		if frontier.is_empty():
			total -= weights[k] * 0.5
			weights[k] *= 0.5
			continue
		reg[frontier[r.randi() % frontier.size()]] = k
		left -= 1
	return reg


static func count_solutions(size: int, reg: PackedInt32Array, limit: int) -> int:
	var state := {"count": 0}
	var cols := []
	cols.resize(size)
	cols.fill(false)
	var used := []
	used.resize(size)
	used.fill(false)
	_count_row(size, reg, 0, -5, cols, used, state, limit)
	return state.count


static func _count_row(size: int, reg: PackedInt32Array, row: int, prev: int,
		cols: Array, used: Array, state: Dictionary, limit: int) -> void:
	if row == size:
		state.count += 1
		return
	for c in size:
		var k := reg[row * size + c]
		if cols[c] or used[k] or absi(c - prev) <= 1:
			continue
		cols[c] = true
		used[k] = true
		_count_row(size, reg, row + 1, c, cols, used, state, limit)
		cols[c] = false
		used[k] = false
		if state.count >= limit:
			return


static func _shuffle(a: Array, r: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# --- Rules -----------------------------------------------------------------

## Indices of crowns that break a rule.
func conflicts() -> Dictionary:
	var bad := {}
	var crowns: Array[int] = []
	for i in n * n:
		if cells[i] == CROWN:
			crowns.append(i)
	for a in crowns.size():
		for b in range(a + 1, crowns.size()):
			var i := crowns[a]
			var j := crowns[b]
			var xi := i % n
			var yi := i / n
			var xj := j % n
			var yj := j / n
			if xi == xj or yi == yj or regions[i] == regions[j] \
					or (absi(xi - xj) <= 1 and absi(yi - yj) <= 1):
				bad[i] = true
				bad[j] = true
	return bad


func _check() -> void:
	if cells.count(CROWN) == n and conflicts().is_empty():
		finish()


# --- Input -----------------------------------------------------------------

func pointer_down(p: Vector2) -> void:
	_start = cell_at(n, n, p)
	_drag_mode = -1
	_dragged = false
	_before = snapshot()


func pointer_drag(p: Vector2) -> void:
	if _start.x < 0:
		return
	var c := cell_at(n, n, p)
	if c.x < 0 or (c == _start and not _dragged):
		return
	if _drag_mode == -1:
		var s := cells[_start.y * n + _start.x]
		if s == CROWN:
			_start = Vector2i(-1, -1)
			return
		_drag_mode = MARK if s == EMPTY else EMPTY
		_dragged = true
		_paint(_start)
	_paint(c)


func _paint(c: Vector2i) -> void:
	var i := c.y * n + c.x
	if cells[i] == CROWN or cells[i] == _drag_mode:
		return
	cells[i] = _drag_mode
	pop(i)
	Sfx.play("mark", 0.9 + rng.randf() * 0.2)
	queue_redraw()


func pointer_up(p: Vector2) -> void:
	if _start.x >= 0 and not _dragged:
		var c := cell_at(n, n, p)
		if c == _start:
			var i := c.y * n + c.x
			cells[i] = (cells[i] + 1) % 3
			pop(i)
			if cells[i] == CROWN:
				if conflicts().has(i):
					Sfx.play("error")
					Sfx.buzz(30)
				else:
					Sfx.play("place")
					Sfx.buzz(10)
			else:
				Sfx.play("tap" if cells[i] == MARK else "soft")
	if _before != null and _before != cells:
		history.append(_before)
		changed.emit()
		_check()
	_start = Vector2i(-1, -1)
	_before = null
	queue_redraw()


func apply_hint() -> bool:
	for row in n:
		var want := row * n + solution[row]
		var ok := cells[want] == CROWN
		for c in n:
			if cells[row * n + c] == CROWN and c != solution[row]:
				ok = false
		if ok:
			continue
		push_history()
		for c in n:
			if cells[row * n + c] == CROWN:
				cells[row * n + c] = EMPTY
		cells[want] = CROWN
		pop(want)
		_check()
		return true
	return false


# --- Drawing ---------------------------------------------------------------

func draw_board() -> void:
	var gr := grid_rect(n, n)
	var cs := gr.size.x / n
	var g := GAP * 0.5
	var rad := cs * 0.16
	UI.rrect(self, gr.grow(10), UI.SURFACE, 30)
	var bad := conflicts()
	var bad_regions := {}
	for i in bad:
		bad_regions[regions[i]] = true
	for i in n * n:
		var x := i % n
		var y := i / n
		var cr := Rect2(gr.position + Vector2(x * cs, y * cs), Vector2(cs, cs))
		var d := (Vector2(x, y).length() / (n * 1.42))
		var col: Color = UI.REGION_COLORS[regions[i] % UI.REGION_COLORS.size()]
		col = col.lerp(Color.WHITE, wave(d) * 0.35)
		UI.rrect(self, cr.grow(-g), col, rad)
		# Merge same-region neighbours into one smooth blob.
		if x < n - 1 and regions[i + 1] == regions[i]:
			draw_rect(Rect2(cr.position + Vector2(cs * 0.5, g), Vector2(cs, cs - GAP)), col)
		if y < n - 1 and regions[i + n] == regions[i]:
			draw_rect(Rect2(cr.position + Vector2(g, cs * 0.5), Vector2(cs - GAP, cs)), col)
		if x < n - 1 and y < n - 1 and regions[i + 1] == regions[i] \
				and regions[i + n] == regions[i] and regions[i + n + 1] == regions[i]:
			draw_rect(Rect2(cr.position + Vector2(cs * 0.5, cs * 0.5), Vector2(cs, cs)), col)
	# Faint cell grid so cells inside a region stay countable.
	var gl := Color(0, 0, 0, 0.16)
	for k in range(1, n):
		for j in n:
			var a := gr.position + Vector2(k * cs, j * cs)
			if regions[j * n + k] == regions[j * n + k - 1]:
				draw_line(a + Vector2(0, g + rad), a + Vector2(0, cs - g - rad), gl, 2.0)
			var b := gr.position + Vector2(j * cs, k * cs)
			if regions[k * n + j] == regions[(k - 1) * n + j]:
				draw_line(b + Vector2(g + rad, 0), b + Vector2(cs - g - rad, 0), gl, 2.0)
	# Overlays and pieces on top of the region blobs.
	for i in n * n:
		var x := i % n
		var y := i / n
		var cr := Rect2(gr.position + Vector2(x * cs, y * cs), Vector2(cs, cs))
		if bad_regions.has(regions[i]) and cells[i] != CROWN:
			_hatch(cr.grow(-g), UI.DANGER)
		var s := 1.0 + pop_amt(i) * 0.25
		match cells[i]:
			MARK:
				var k := cs * 0.1 * s
				var c := cr.get_center()
				var mc := Color(1, 1, 1, 0.55)
				UI.line(self, c - Vector2(k, k), c + Vector2(k, k), mc, cs * 0.045)
				UI.line(self, c - Vector2(k, -k), c + Vector2(k, -k), mc, cs * 0.045)
			CROWN:
				var c := cr.get_center()
				var col := UI.DANGER if bad.has(i) else accent
				if win_t >= 0.0:
					s += wave(Vector2(x, y).length() / (n * 1.42)) * 0.3
				var ir := Rect2(c - Vector2(cs, cs) * 0.5 * s, Vector2(cs, cs) * s)
				UI.circle(self, c, cs * 0.34 * s, Color(0, 0, 0, 0.28))
				UI.game_icon(self, "crown", ir, col)


func _hatch(r: Rect2, col: Color) -> void:
	var c := Color(col, 0.22)
	var step := r.size.x / 4.0
	for k in range(-3, 5):
		var a := r.position + Vector2(k * step, r.size.y)
		var b := r.position + Vector2(k * step + r.size.y, 0)
		# Clip the stripe to the cell.
		var t0 := clampf(-(a.x - r.position.x) / (b.x - a.x), 0.0, 1.0)
		var t1 := clampf((r.end.x - a.x) / (b.x - a.x), 0.0, 1.0)
		if t1 > t0:
			draw_line(a.lerp(b, t0), a.lerp(b, t1), c, 3.0, true)
