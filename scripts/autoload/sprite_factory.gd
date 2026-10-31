extends Node
## Character art. Uses the anime-style art in res://art/characters/<id>.svg
## (made by tools/gen_art.py) and res://art/portraits/<id>.svg for dialogue.
## Characters without art fall back to tiny pixel sprites built at runtime
## from the text templates below (data/characters.json picks body + palette).
##
## Palette letters: h hair, s skin, e eyes, o outfit, a accent, b boots,
## w metal/white. "." is transparent. An outline and a simple right-side
## shade are added automatically.
##
## To use hand-drawn art instead, put a PNG at res://art/characters/<id>.png
## (and optionally res://art/portraits/<id>.png); PNG wins over SVG.

const OUTLINE := Color("#140f1c")
const DEFAULTS := {
	"h": "#3a2a20", "s": "#d39b6b", "e": "#1a1018", "o": "#5b6ee1",
	"a": "#e8c170", "b": "#3b2a20", "w": "#c9d1d9",
}

const BODIES := {
	"tunic": [
		"....hhhh....",
		"...hhhhhh...",
		"..hhhhhhhh..",
		"..hssssssh..",
		"..sesssses..",
		"..ssssssss..",
		"...ssssss...",
		"....aooa....",
		"..oooooooo..",
		".soooaaooos.",
		".soooooooos.",
		"..aaaaaaaa..",
		"..oooooooo..",
		"...oo..oo...",
		"...bb..bb...",
		"..bbb..bbb..",
	],
	"robe": [
		"....hhhh....",
		"...hhhhhh...",
		"..hhhhhhhh..",
		"..hssssssh..",
		"..sesssses..",
		"..hssssssh..",
		"..hhsssshh..",
		"....aooa....",
		"..oooaaooo..",
		".soooaaooos.",
		".soooaaooos.",
		"..oooaaooo..",
		"..oooooooo..",
		"..oooooooo..",
		".oooooooooo.",
		".bbb....bbb.",
	],
	"armor": [
		"....wwww....",
		"...wwwwww...",
		"..wwwaawww..",
		"..wssssssw..",
		"..sesssses..",
		"..wssssssw..",
		"...wwwwww...",
		"..aawwwwaa..",
		".awwwoowwwa.",
		".swwwoowwws.",
		".swwwoowwws.",
		"..aaaaaaaa..",
		"..oooooooo..",
		"...ww..ww...",
		"...ww..ww...",
		"..bbb..bbb..",
	],
	"horse": [
		"...h....h...",
		"...hhhhhh...",
		"..hhsssshh..",
		"..hesssseh..",
		"...ssssss...",
		"...ssssss...",
		"....saas....",
		"....ssss....",
		"..oooooooo..",
		".soooooooos.",
		".soooooooos.",
		".s.aaaaaa.s.",
		"...oooooo...",
		"...oo..oo...",
		"...ss..ss...",
		"..bbb..bbb..",
	],
	"beast": [
		"............",
		"............",
		"..h......h..",
		"..hh....hh..",
		"..hhhhhhhh..",
		".hhehhhhehh.",
		".hhhhhhhhhh.",
		".hhhwhhwhhh.",
		"..hhhhhhhh..",
		".ohhhhhhhho.",
		"ooohhhhhhooo",
		"o.hhhhhhhh.o",
		"..hhhhhhhh..",
		"..hh....hh..",
		"..hh....hh..",
		".bbb....bbb.",
	],
	"small": [
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"....aaaa....",
		"...aaaaaa...",
		"..aaaaaaaa..",
		"...ssssss...",
		"...esssse...",
		"...hhsshh...",
		"...oooooo...",
		"..soooooos..",
		"....o..o....",
		"...bb..bb...",
	],
	"big": [
		"..hhhhhhhh..",
		".hhhhhhhhhh.",
		".hhsssssshh.",
		".hsessssesh.",
		".hssssssssh.",
		".hhsssssshaa",
		"..hhhhhhhh..",
		"soooooooooos",
		"soooooooooos",
		"soooooooooos",
		"s.oooooooo.s",
		"..oooooooo..",
		"..ooo..ooo..",
		"..sss..sss..",
		"..sss..sss..",
		".bbbb..bbbb.",
	],
	"flying": [
		"............",
		"....hhhh....",
		"...hhhhhh...",
		"...hesseh...",
		"...hsssshh..",
		"aa..swws..aa",
		"aaa.oooo.aaa",
		"aaaaooooaaaa",
		".aaaooooaaa.",
		"..a.oooo.a..",
		"....bbbb....",
		".....bb.....",
		"....b..b....",
		"............",
		"............",
		"............",
	],
	"sparkle": [
		"............",
		"............",
		"............",
		"............",
		".....w......",
		".....a......",
		"..a..a..a...",
		"...aawaa....",
		".waawwwaaw..",
		"...aawaa....",
		"..a..a..a...",
		".....a......",
		".....w......",
		"............",
		"............",
		"............",
	],
}

var _cache := {}


func texture(char_id: String) -> Texture2D:
	if _cache.has(char_id):
		return _cache[char_id]
	var art := _art("characters", char_id)
	if art:
		_cache[char_id] = art
		return art
	var info: Dictionary = GameState.db["characters"].get(char_id, {})
	var tex := ImageTexture.create_from_image(build_image(info.get("body", "tunic"), info.get("colors", {})))
	_cache[char_id] = tex
	return tex


## Bust shot for dialogue boxes; falls back to the full-body texture.
func portrait(char_id: String) -> Texture2D:
	var key := "portrait:" + char_id
	if not _cache.has(key):
		var art := _art("portraits", char_id)
		_cache[key] = art if art else texture(char_id)
	return _cache[key]


## True when the character uses smooth (non-pixel) art.
func is_smooth(tex: Texture2D) -> bool:
	return tex != null and tex.get_height() > 64


func _art(folder: String, char_id: String) -> Texture2D:
	for ext in ["png", "svg"]:
		var p := "res://art/%s/%s.%s" % [folder, char_id, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null


func build_image(body_id: String, colors: Dictionary) -> Image:
	var body: Array = BODIES.get(body_id, BODIES["tunic"])
	var pal := {}
	for k in DEFAULTS:
		pal[k] = Color(colors.get(k, DEFAULTS[k]))
	var w := 12
	var h := body.size()
	var img := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = body[y]
		for x in mini(w, row.length()):
			var c := row[x]
			if pal.has(c):
				img.set_pixel(x + 1, y + 1, pal[c])
	# Shade the right edge of every shape for a bit of volume.
	var shaded: Image = img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a > 0 and (x + 1 >= img.get_width() or img.get_pixel(x + 1, y).a == 0):
				shaded.set_pixel(x, y, px.darkened(0.25))
	# Dark outline around everything.
	var out: Image = shaded.duplicate()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0:
				continue
			for d in dirs:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a > 0:
					out.set_pixel(x, y, OUTLINE)
					break
	return out
