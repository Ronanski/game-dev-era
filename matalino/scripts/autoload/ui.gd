extends Node
## Design tokens (colors, fonts, sizes), the game catalog, and small vector
## drawing helpers shared by every screen. Everything is drawn in code so the
## app stays crisp on any screen density.

const BG := Color("0e0f13")
const SURFACE := Color("171920")
const SURFACE_2 := Color("20232c")
const LINE := Color("2b2f3a")
const TEXT := Color("f3f4f6")
const MUTED := Color("8b909c")
const FAINT := Color("4a4f5c")
const DANGER := Color("ff5c6c")
const SUCCESS := Color("3ee0a0")

const RADIUS := 22.0
const PAD := 28.0

## Region colors for Crown: muted enough for a dark UI, distinct from each other.
const REGION_COLORS := [
	Color("5b4b8a"), Color("2f6f8f"), Color("8a5a3c"), Color("3f7a52"),
	Color("8c4466"), Color("6b7b2f"), Color("3d5a9e"), Color("8f6f2a"),
	Color("4a7f80"),
]

const GAMES := [
	{
		"id": "crown", "name": "Crown", "color": Color("f7b940"),
		"tagline": "Logic · Placement",
		"blurb": "One crown per row, column and color.",
		"rules": [
			"Place exactly one crown in every row, every column and every color region.",
			"Crowns can never touch each other, not even diagonally.",
			"Tap once to mark a cell with ×, tap again for a crown. Drag to mark many cells.",
		],
	},
	{
		"id": "trail", "name": "Trail", "color": Color("4f8bff"),
		"tagline": "Path · Planning",
		"blurb": "One stroke through every cell.",
		"rules": [
			"Draw a single path that starts at 1 and passes the numbers in order.",
			"The path must fill every cell of the grid exactly once.",
			"Drag backwards to erase. Tap any cell on the path to cut it there.",
		],
	},
	{
		"id": "pulse", "name": "Pulse", "color": Color("2ee6a6"),
		"tagline": "Spatial · Rotation",
		"blurb": "Rotate tiles until it all lights up.",
		"rules": [
			"Tap a tile to rotate it a quarter turn.",
			"Connect every tile to the glowing core so the whole network lights up.",
			"No loose ends: every pipe must lead into another pipe.",
		],
	},
	{
		"id": "duo", "name": "Duo", "color": Color("ff6b8b"),
		"tagline": "Logic · Balance",
		"blurb": "Balance two colors. Never three in a row.",
		"rules": [
			"Fill the grid with pink and blue tiles. Tap to cycle a cell.",
			"No more than two of the same color may sit next to each other in a row or column.",
			"Every row and every column holds the same number of each color.",
		],
	},
	{
		"id": "echo", "name": "Echo", "color": Color("b07cff"),
		"tagline": "Memory · Focus",
		"blurb": "See the pattern. Rebuild it from memory.",
		"rules": [
			"Some tiles light up for a moment. Memorize them.",
			"When they go dark, tap every tile that was lit.",
			"Three wrong taps and the round restarts. Later rounds rotate the board.",
		],
	},
]

const DUO_A := Color("ff6b8b")
const DUO_B := Color("4f8bff")

var font: Font = preload("res://assets/fonts/Inter-Medium.ttf")
var font_bold: Font = preload("res://assets/fonts/InterDisplay-Bold.ttf")
var theme: Theme

var _box := StyleBoxFlat.new()


func _ready() -> void:
	_box.anti_aliasing = true
	_box.anti_aliasing_size = 1.0
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 26
	theme.set_color("font_color", "Label", TEXT)


func game(id: String) -> Dictionary:
	for g in GAMES:
		if g.id == id:
			return g
	return {}


# --- Drawing helpers -------------------------------------------------------

## Rounded rectangle (anti-aliased) with optional border.
func rrect(ci: CanvasItem, r: Rect2, color: Color, radius := RADIUS,
		border := 0.0, border_color := Color.TRANSPARENT) -> void:
	_box.bg_color = color
	_box.draw_center = color.a > 0.0
	_box.set_corner_radius_all(int(minf(radius, minf(r.size.x, r.size.y) * 0.5)))
	_box.corner_detail = 12
	_box.set_border_width_all(int(border))
	_box.border_color = border_color
	_box.shadow_size = 0
	ci.draw_style_box(_box, r)


## Soft glow behind a shape (cheap fake bloom).
func glow(ci: CanvasItem, r: Rect2, color: Color, radius := RADIUS, size := 18.0) -> void:
	_box.bg_color = Color.TRANSPARENT
	_box.draw_center = false
	_box.set_border_width_all(0)
	_box.set_corner_radius_all(int(radius))
	_box.shadow_color = color
	_box.shadow_size = int(size)
	_box.shadow_offset = Vector2.ZERO
	ci.draw_style_box(_box, r)
	_box.shadow_size = 0


func circle(ci: CanvasItem, c: Vector2, radius: float, color: Color) -> void:
	rrect(ci, Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), color, radius)


func ring(ci: CanvasItem, c: Vector2, radius: float, color: Color, width: float) -> void:
	ci.draw_arc(c, radius - width * 0.5, 0.0, TAU, 48, color, width, true)


func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	ci.draw_line(a, b, color, width, true)
	circle(ci, a, width * 0.5, color)
	circle(ci, b, width * 0.5, color)


func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color := TEXT,
		bold := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := font_bold if bold else font
	ci.draw_string(f, pos, s, align, width, size, color)


## Draws text centered on a point (vertically by cap height).
func text_c(ci: CanvasItem, center: Vector2, s: String, size: int, color := TEXT, bold := true) -> void:
	var f := font_bold if bold else font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	ci.draw_string(f, Vector2(center.x - w * 0.5, center.y + (asc - desc) * 0.5 - size * 0.04),
		s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [s / 60, s % 60]


# --- Icons -----------------------------------------------------------------

## Draws the emblem of a game inside rect r.
func game_icon(ci: CanvasItem, id: String, r: Rect2, color: Color) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	match id:
		"crown":
			var w := s * 0.62
			var h := s * 0.44
			var x0 := c.x - w * 0.5
			var y0 := c.y - h * 0.5
			var pts := PackedVector2Array([
				Vector2(x0, y0 + h * 0.18), Vector2(x0 + w * 0.27, y0 + h * 0.55),
				Vector2(c.x, y0), Vector2(x0 + w * 0.73, y0 + h * 0.55),
				Vector2(x0 + w, y0 + h * 0.18), Vector2(x0 + w * 0.9, y0 + h),
				Vector2(x0 + w * 0.1, y0 + h),
			])
			ci.draw_colored_polygon(pts, color)
			var outline := pts.duplicate()
			outline.append(pts[0])
			ci.draw_polyline(outline, color, 2.0, true)
			for p in [pts[0], pts[2], pts[4]]:
				circle(ci, p, s * 0.055, color)
		"trail":
			var k := s * 0.2
			var pts := [c + Vector2(-k, k), c + Vector2(-k, -k), c + Vector2(0, -k),
				c + Vector2(0, k), c + Vector2(k, k), c + Vector2(k, -k)]
			for i in pts.size() - 1:
				line(ci, pts[i], pts[i + 1], color, s * 0.09)
			circle(ci, pts[0], s * 0.1, color)
			circle(ci, pts[-1], s * 0.1, color)
			circle(ci, pts[-1], s * 0.045, BG)
		"pulse":
			var k := s * 0.28
			var wd := s * 0.1
			line(ci, c, c + Vector2(0, -k), color, wd)
			line(ci, c, c + Vector2(k, 0), color, wd)
			line(ci, c, c + Vector2(-k, 0), color.darkened(0.45), wd)
			line(ci, c, c + Vector2(0, k), color.darkened(0.45), wd)
			circle(ci, c, s * 0.13, color)
			circle(ci, c, s * 0.06, BG)
		"duo":
			var k := s * 0.15
			var rr := s * 0.12
			circle(ci, c + Vector2(-k, -k), rr, DUO_A)
			circle(ci, c + Vector2(k, k), rr, DUO_A)
			circle(ci, c + Vector2(k, -k), rr, DUO_B)
			circle(ci, c + Vector2(-k, k), rr, DUO_B)
		"echo":
			var k := s * 0.19
			var lit := [0, 4, 5, 6]
			for i in 9:
				var p := c + Vector2((i % 3 - 1) * k, (i / 3 - 1) * k)
				var q := s * 0.075
				rrect(ci, Rect2(p - Vector2(q, q), Vector2(q, q) * 2.0),
					color if i in lit else color.darkened(0.6), q * 0.6)


## Small UI glyphs, drawn at c with size s.
func glyph(ci: CanvasItem, kind: String, c: Vector2, s: float, color: Color) -> void:
	var w := maxf(2.5, s * 0.11)
	match kind:
		"back":
			line(ci, c + Vector2(s * 0.12, -s * 0.28), c + Vector2(-s * 0.16, 0), color, w)
			line(ci, c + Vector2(-s * 0.16, 0), c + Vector2(s * 0.12, s * 0.28), color, w)
		"undo":
			ci.draw_arc(c + Vector2(0, s * 0.06), s * 0.26, -PI * 0.95, PI * 0.55, 24, color, w, true)
			var tip := c + Vector2(-s * 0.26, s * 0.03)
			line(ci, tip, tip + Vector2(-s * 0.1, -s * 0.16), color, w)
			line(ci, tip, tip + Vector2(s * 0.17, -s * 0.07), color, w)
		"restart":
			ci.draw_arc(c, s * 0.27, -PI * 0.35, PI * 1.45, 28, color, w, true)
			var tip := c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * s * 0.27
			line(ci, tip, tip + Vector2(-s * 0.17, -s * 0.03), color, w)
			line(ci, tip, tip + Vector2(0.0, s * 0.17), color, w)
		"hint":
			# Four-point sparkle.
			var k := s * 0.32
			var m := s * 0.07
			var pts := PackedVector2Array([
				c + Vector2(0, -k), c + Vector2(m, -m), c + Vector2(k, 0), c + Vector2(m, m),
				c + Vector2(0, k), c + Vector2(-m, m), c + Vector2(-k, 0), c + Vector2(-m, -m),
			])
			ci.draw_colored_polygon(pts, color)
			circle(ci, c + Vector2(s * 0.27, -s * 0.27), s * 0.06, color)
		"help":
			ring(ci, c, s * 0.32, color, w * 0.8)
			text_c(ci, c, "?", int(s * 0.4), color)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				line(ci, c + Vector2(cos(a), sin(a)) * s * 0.18, c + Vector2(cos(a), sin(a)) * s * 0.3, color, w * 1.2)
			circle(ci, c, s * 0.22, color)
			circle(ci, c, s * 0.1, BG)
		"flame":
			var pts := PackedVector2Array()
			for i in 25:
				var t := TAU * i / 24.0
				var r := s * 0.26 * (1.0 + 0.55 * pow(maxf(0.0, -sin(t)), 3))
				pts.append(c + Vector2(cos(t) * r * 0.85, sin(t) * r * 1.05 + s * 0.06))
			ci.draw_colored_polygon(pts, color)
			circle(ci, c + Vector2(0, s * 0.12), s * 0.1, BG.lerp(color, 0.35))
		"check":
			line(ci, c + Vector2(-s * 0.22, 0), c + Vector2(-s * 0.06, s * 0.17), color, w * 1.2)
			line(ci, c + Vector2(-s * 0.06, s * 0.17), c + Vector2(s * 0.24, -s * 0.18), color, w * 1.2)
		"lock":
			rrect(ci, Rect2(c + Vector2(-s * 0.22, -s * 0.04), Vector2(s * 0.44, s * 0.34)), color, s * 0.06)
			ci.draw_arc(c + Vector2(0, -s * 0.06), s * 0.14, PI, TAU, 16, color, w, true)
		"star":
			star(ci, c, s * 0.4, color)
		"heart":
			var pts := PackedVector2Array()
			for i in 33:
				var t := TAU * i / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(c + Vector2(x, y) * s * 0.019)
			ci.draw_colored_polygon(pts, color)
		"calendar":
			rrect(ci, Rect2(c - Vector2(s * 0.3, s * 0.26), Vector2(s * 0.6, s * 0.56)), color, s * 0.1, w, color)
			rrect(ci, Rect2(c - Vector2(s * 0.3, s * 0.26), Vector2(s * 0.6, s * 0.17)), color, s * 0.08)
			line(ci, c + Vector2(-s * 0.15, -s * 0.36), c + Vector2(-s * 0.15, -s * 0.22), color, w)
			line(ci, c + Vector2(s * 0.15, -s * 0.36), c + Vector2(s * 0.15, -s * 0.22), color, w)


func star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * i / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, color)
