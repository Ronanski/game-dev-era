class_name TrailBoard
extends Board
## One-stroke path puzzle: draw a single path from 1 through every number in
## order that fills the whole grid.

var n := 5
var numbers := {}  # cell index -> number
var last_number := 0
var solution: Array = []
var path: Array = []

var _before: Array = []
var _active := false
var _bump := 0.0


static func size_for(lvl: int) -> int:
	if lvl <= 2:
		return 4
	if lvl <= 8:
		return 5
	if lvl <= 20:
		return 6
	return 7


func generate() -> void:
	n = size_for(level)
	var puzzle := TrailBoard.make(n, n + 2 + rng.randi_range(0, 2), rng)
	solution = puzzle.solution
	numbers = puzzle.numbers
	last_number = numbers.size()
	reset_board()


func reset_board() -> void:
	path = []
	for i in numbers:
		if numbers[i] == 1:
			path.append(i)


func snapshot() -> Variant:
	return path.duplicate()


func restore(s: Variant) -> void:
	path = s


func status_text() -> String:
	return "%d / %d cells" % [path.size(), n * n]


# --- Generation ------------------------------------------------------------

## Random Hamiltonian path via "backbite" moves, then numbered checkpoints.
static func make(size: int, count: int, r: RandomNumberGenerator) -> Dictionary:
	var p: Array = []
	for y in size:
		for x in size:
			p.append(y * size + (x if y % 2 == 0 else size - 1 - x))
	for step in size * size * 40:
		if r.randi() % 2 == 0:
			p.reverse()
		var end: int = p[0]
		var nb := _neighbors(end, size)
		var q: int = nb[r.randi() % nb.size()]
		var i := p.find(q)
		if i <= 1:
			continue
		var head := p.slice(0, i)
		head.reverse()
		p = head + p.slice(i)
	if r.randi() % 2 == 0:
		p.reverse()
	var idx := {}
	idx[0] = true
	idx[p.size() - 1] = true
	count = clampi(count, 2, p.size())
	while idx.size() < count:
		idx[r.randi_range(1, p.size() - 2)] = true
	var order := idx.keys()
	order.sort()
	var nums := {}
	for k in order.size():
		nums[p[order[k]]] = k + 1
	return {"solution": p, "numbers": nums}


static func _neighbors(i: int, size: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % size
	var y := i / size
	if x > 0: out.append(i - 1)
	if x < size - 1: out.append(i + 1)
	if y > 0: out.append(i - size)
	if y < size - 1: out.append(i + size)
	return out


## True when path is a complete valid answer for these numbers.
static func is_valid(size: int, nums: Dictionary, p: Array) -> bool:
	if p.size() != size * size:
		return false
	var seen := {}
	var expect := 1
	for k in p.size():
		var c: int = p[k]
		if seen.has(c) or c < 0 or c >= size * size:
			return false
		if k > 0 and not c in _neighbors(p[k - 1], size):
			return false
		seen[c] = true
		if nums.has(c):
			if nums[c] != expect:
				return false
			expect += 1
	return expect == nums.size() + 1 and nums.get(p[-1], -1) == nums.size()


# --- Input -----------------------------------------------------------------

func _next_number() -> int:
	var k := 1
	for c in path:
		if numbers.has(c):
			k = numbers[c] + 1
	return k


func _can_enter(c: int) -> bool:
	if path.is_empty() or c in path:
		return false
	if not c in _neighbors(path[-1], n):
		return false
	if numbers.has(path[-1]) and numbers[path[-1]] == last_number:
		return false
	if numbers.has(c):
		if numbers[c] != _next_number():
			return false
		if numbers[c] == last_number and path.size() != n * n - 1:
			return false
	return true


func pointer_down(p: Vector2) -> void:
	_before = path.duplicate()
	var cv := cell_at(n, n, p)
	_active = false
	if cv.x < 0:
		return
	var c := cv.y * n + cv.x
	var k := path.find(c)
	if k >= 0:
		if k < path.size() - 1:
			path.resize(k + 1)
			Sfx.play("soft")
		_active = true
	elif _can_enter(c):
		_extend(c)
		_active = true
	queue_redraw()


func pointer_drag(p: Vector2) -> void:
	if not _active:
		return
	var cv := cell_at(n, n, p)
	if cv.x < 0:
		return
	# Walk toward the finger one cell at a time so fast swipes don't skip cells.
	for guard in n * 2:
		var end: int = path[-1]
		var ex := end % n
		var ey := end / n
		if Vector2i(ex, ey) == cv:
			return
		var dx := cv.x - ex
		var dy := cv.y - ey
		var step := Vector2i(signi(dx), 0) if absi(dx) >= absi(dy) else Vector2i(0, signi(dy))
		var nxt := (ey + step.y) * n + (ex + step.x)
		if path.size() >= 2 and nxt == path[-2]:
			path.pop_back()
			Sfx.play("soft", 0.9)
			queue_redraw()
			continue
		if not _can_enter(nxt):
			# Try the other axis before giving up.
			var alt := Vector2i(0, signi(dy)) if step.x != 0 else Vector2i(signi(dx), 0)
			if alt != Vector2i.ZERO:
				var nxt2 := (ey + alt.y) * n + (ex + alt.x)
				if _can_enter(nxt2):
					_extend(nxt2)
					continue
			if nxt in path or numbers.has(nxt):
				_blocked()
			return
		_extend(nxt)


func _extend(c: int) -> void:
	path.append(c)
	pop(c)
	if numbers.has(c):
		Sfx.play("place", 1.0 + numbers[c] * 0.04)
		Sfx.buzz(12)
	else:
		Sfx.play("tap", 0.8 + float(path.size()) / (n * n) * 0.7)
	queue_redraw()


func _blocked() -> void:
	if _bump <= 0.0:
		_bump = 1.0
		Sfx.play("error", 1.3)


func pointer_up(_p: Vector2) -> void:
	_active = false
	if path != _before:
		history.append(_before)
		changed.emit()
	if TrailBoard.is_valid(n, numbers, path):
		finish()


func apply_hint() -> bool:
	var k := 0
	while k < path.size() and k < solution.size() and path[k] == solution[k]:
		k += 1
	if k >= solution.size():
		return false
	push_history()
	path = solution.slice(0, mini(k + 3, solution.size()))
	for c in path.slice(k):
		pop(c)
	if TrailBoard.is_valid(n, numbers, path):
		finish()
	return true


func _process(delta: float) -> void:
	super(delta)
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 3.0)
		queue_redraw()


# --- Drawing ---------------------------------------------------------------

func _center(c: int) -> Vector2:
	return cell_rect(n, n, c % n, c / n).get_center()


func draw_board() -> void:
	var gr := grid_rect(n, n)
	var cs := gr.size.x / n
	UI.rrect(self, gr.grow(10), UI.SURFACE, 30)
	var on_path := {}
	for k in path.size():
		on_path[path[k]] = k
	for i in n * n:
		var cr := cell_rect(n, n, i % n, i / n).grow(-GAP * 0.5)
		var col := UI.SURFACE_2
		if on_path.has(i):
			col = UI.SURFACE_2.lerp(accent, 0.18)
		UI.rrect(self, cr, col, cs * 0.16)
	# Path stroke with a gradient from start to head.
	var w := cs * 0.36
	var head_col := accent.lightened(0.25)
	for k in range(1, path.size()):
		var t := float(k) / maxf(1.0, n * n - 1)
		var col := accent.lerp(head_col, t)
		if win_t >= 0.0:
			col = col.lerp(Color.WHITE, wave(t) * 0.5)
		UI.line(self, _center(path[k - 1]), _center(path[k]), col, w)
	if not path.is_empty() and not is_solved:
		var hc := _center(path[-1])
		var shake := sin(_bump * 30.0) * _bump * 6.0
		UI.circle(self, hc + Vector2(shake, 0), w * 0.5 + 6.0, Color(head_col, 0.35))
		UI.circle(self, hc + Vector2(shake, 0), w * 0.5, head_col)
	for c in numbers:
		var center := _center(c)
		var visited := on_path.has(c)
		var s := 1.0 + pop_amt(c) * 0.25
		if win_t >= 0.0:
			s += wave(float(numbers[c]) / last_number) * 0.25
		var rad := cs * 0.3 * s
		if visited:
			UI.circle(self, center, rad, UI.TEXT)
			UI.text_c(self, center, str(numbers[c]), int(cs * 0.3 * s), UI.BG)
		else:
			UI.circle(self, center, rad, UI.BG)
			UI.ring(self, center, rad, Color(UI.TEXT, 0.9), 3.0)
			UI.text_c(self, center, str(numbers[c]), int(cs * 0.3 * s), UI.TEXT)
