class_name DuoBoard
extends Board
## Binary balance puzzle (Takuzu): two colors, never three in a line, and
## every row and column holds the same amount of each color.

enum { EMPTY, A, B }

var n := 6
var solution := PackedInt32Array()
var givens := PackedInt32Array()
var cells := PackedInt32Array()

var _press := -1


static func size_for(lvl: int) -> int:
	if lvl <= 4:
		return 4
	if lvl <= 16:
		return 6
	return 8


func generate() -> void:
	n = size_for(level)
	var puzzle := DuoBoard.make(n, level >= 8, rng)
	solution = puzzle.solution
	givens = puzzle.givens
	reset_board()


func reset_board() -> void:
	cells = givens.duplicate()


func snapshot() -> Variant:
	return cells.duplicate()


func restore(s: Variant) -> void:
	cells = s


func status_text() -> String:
	return "%d / %d filled" % [n * n - cells.count(EMPTY), n * n]


# --- Generation ------------------------------------------------------------

static func make(size: int, deep: bool, r: RandomNumberGenerator) -> Dictionary:
	var full := PackedInt32Array()
	full.resize(size * size)
	full.fill(EMPTY)
	_fill(full, 0, size, r)
	var puzzle := full.duplicate()
	var order := range(size * size)
	for i in range(order.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for pass_deep in ([false, true] if deep else [false]):
		for i in order:
			if puzzle[i] == EMPTY:
				continue
			puzzle[i] = EMPTY
			if solve(puzzle.duplicate(), size, pass_deep) != "solved":
				puzzle[i] = full[i]
	return {"solution": full, "givens": puzzle}


static func _fill(g: PackedInt32Array, i: int, size: int, r: RandomNumberGenerator) -> bool:
	if i == size * size:
		return true
	var first := A if r.randf() < 0.5 else B
	for v in [first, 3 - first]:
		g[i] = v
		if _ok_at(g, i, size) and _fill(g, i + 1, size, r):
			return true
	g[i] = EMPTY
	return false


## Checks the row and column through cell i for rule breaks.
static func _ok_at(g: PackedInt32Array, i: int, size: int) -> bool:
	return _line_ok(g, _row(i / size, size), size) and _line_ok(g, _col(i % size, size), size)


static func _row(y: int, size: int) -> Array:
	var out := []
	for x in size:
		out.append(y * size + x)
	return out


static func _col(x: int, size: int) -> Array:
	var out := []
	for y in size:
		out.append(y * size + x)
	return out


static func _line_ok(g: PackedInt32Array, idx: Array, size: int) -> bool:
	var ca := 0
	var cb := 0
	for k in idx.size():
		var v := g[idx[k]]
		if v == A:
			ca += 1
		elif v == B:
			cb += 1
		if k >= 2 and v != EMPTY and v == g[idx[k - 1]] and v == g[idx[k - 2]]:
			return false
	return ca <= size / 2 and cb <= size / 2


static var _line_cache := {}


static func _lines(size: int) -> Array:
	if not _line_cache.has(size):
		var out := []
		for k in size:
			out.append(_row(k, size))
			out.append(_col(k, size))
		_line_cache[size] = out
	return _line_cache[size]


## Fills forced cells. Returns "solved", "stuck" or "contradiction".
static func propagate(g: PackedInt32Array, size: int) -> String:
	var lines := _lines(size)
	var progress := true
	while progress:
		progress = false
		for idx in lines:
			if not _line_ok(g, idx, size):
				return "contradiction"
			for k in size - 2:
				var a := g[idx[k]]
				var b := g[idx[k + 1]]
				var c := g[idx[k + 2]]
				if a != EMPTY and a == b and c == EMPTY:
					g[idx[k + 2]] = 3 - a
					progress = true
				elif b != EMPTY and b == c and a == EMPTY:
					g[idx[k]] = 3 - b
					progress = true
				elif a != EMPTY and a == c and b == EMPTY:
					g[idx[k + 1]] = 3 - a
					progress = true
			var ca := 0
			var cb := 0
			for i in idx:
				ca += int(g[i] == A)
				cb += int(g[i] == B)
			if ca + cb < size and (ca == size / 2 or cb == size / 2):
				var fillv := B if ca == size / 2 else A
				for i in idx:
					if g[i] == EMPTY:
						g[i] = fillv
				progress = true
	for idx in lines:
		if not _line_ok(g, idx, size):
			return "contradiction"
	return "stuck" if g.has(EMPTY) else "solved"


## Logic solver: propagation, plus one level of "what if" when deep.
static func solve(g: PackedInt32Array, size: int, deep: bool) -> String:
	var st := propagate(g, size)
	while st == "stuck" and deep:
		var advanced := false
		for i in size * size:
			if g[i] != EMPTY:
				continue
			for v in [A, B]:
				var t := g.duplicate()
				t[i] = v
				if propagate(t, size) == "contradiction":
					g[i] = 3 - v
					advanced = true
					break
			if advanced:
				break
		if not advanced:
			return "stuck"
		st = propagate(g, size)
	return st


# --- Rules -----------------------------------------------------------------

## Cells that are part of a broken rule.
func errors() -> Dictionary:
	var bad := {}
	for idx in DuoBoard._lines(n):
		var ca := 0
		var cb := 0
		for k in n:
			var v := cells[idx[k]]
			ca += int(v == A)
			cb += int(v == B)
			if k >= 2 and v != EMPTY and v == cells[idx[k - 1]] and v == cells[idx[k - 2]]:
				bad[idx[k]] = true
				bad[idx[k - 1]] = true
				bad[idx[k - 2]] = true
		if ca > n / 2 or cb > n / 2:
			var over := A if ca > n / 2 else B
			for i in idx:
				if cells[i] == over:
					bad[i] = true
	return bad


func pointer_down(p: Vector2) -> void:
	var c := cell_at(n, n, p)
	_press = c.y * n + c.x if c.x >= 0 else -1
	queue_redraw()


func pointer_up(p: Vector2) -> void:
	var c := cell_at(n, n, p)
	var i := c.y * n + c.x if c.x >= 0 else -1
	if i >= 0 and i == _press:
		if givens[i] != EMPTY:
			pop(i)
			Sfx.play("soft", 0.7)
		else:
			push_history()
			cells[i] = (cells[i] + 1) % 3
			pop(i)
			if errors().has(i):
				Sfx.play("error", 1.2)
				Sfx.buzz(25)
			else:
				Sfx.play("tap" if cells[i] == A else ("place" if cells[i] == B else "soft"),
					1.0 if cells[i] != B else 0.8)
				Sfx.buzz(8)
			changed.emit()
			if not cells.has(EMPTY) and errors().is_empty():
				finish()
	_press = -1
	queue_redraw()


func apply_hint() -> bool:
	# First undo a mistake, otherwise fill a cell that logic can force next.
	for i in n * n:
		if cells[i] != EMPTY and cells[i] != solution[i]:
			push_history()
			cells[i] = solution[i]
			pop(i)
			return true
	var t := cells.duplicate()
	DuoBoard.propagate(t, n)
	var pick := -1
	for i in n * n:
		if cells[i] == EMPTY and t[i] != EMPTY:
			pick = i
			break
	if pick < 0:
		pick = cells.find(EMPTY)
	if pick < 0:
		return false
	push_history()
	cells[pick] = solution[pick]
	pop(pick)
	if not cells.has(EMPTY) and errors().is_empty():
		finish()
	return true


# --- Drawing ---------------------------------------------------------------

func draw_board() -> void:
	var gr := grid_rect(n, n)
	var cs := gr.size.x / n
	UI.rrect(self, gr.grow(10), UI.SURFACE, 30)
	var bad := errors()
	for i in n * n:
		var x := i % n
		var y := i / n
		var cr := Rect2(gr.position + Vector2(x * cs, y * cs), Vector2(cs, cs)).grow(-GAP * 0.5)
		var s := 1.0 - pop_amt(i) * 0.12
		var wv := wave(Vector2(x, y).length() / (n * 1.42))
		var r := Rect2(cr.get_center() - cr.size * 0.5 * s, cr.size * s)
		var v := cells[i]
		if v == EMPTY:
			UI.rrect(self, r, UI.SURFACE_2.lightened(0.06 if i == _press else 0.0), cs * 0.18)
			continue
		var col := UI.DUO_A if v == A else UI.DUO_B
		col = col.lerp(Color.WHITE, wv * 0.4)
		UI.rrect(self, r, col, cs * 0.18)
		# Subtle top highlight for a tactile feel.
		UI.rrect(self, Rect2(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.1),
			Vector2(r.size.x * 0.76, r.size.y * 0.16)), Color(1, 1, 1, 0.12), r.size.y * 0.08)
		if givens[i] != EMPTY:
			UI.circle(self, r.get_center(), cs * 0.07, Color(0, 0, 0, 0.3))
		if bad.has(i):
			UI.rrect(self, r.grow(-2), Color.TRANSPARENT, cs * 0.18, 5, UI.TEXT)
			UI.circle(self, r.get_center(), cs * 0.1, UI.TEXT)
