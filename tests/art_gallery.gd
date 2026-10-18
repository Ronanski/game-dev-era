extends SceneTree
## Renders every character SVG into one contact sheet PNG (works headless).
##
## Run:  godot --headless --path . -s tests/art_gallery.gd -- --out=gallery.png [--portraits]

func _initialize() -> void:
	var out := "user://gallery.png"
	var folder := "characters"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg == "--portraits":
			folder = "portraits"
	var files: Array = []
	for f in DirAccess.get_files_at("res://art/" + folder):
		if f.ends_with(".svg"):
			files.append(f)
	files.sort()
	var cell := Vector2i(200, 300) if folder == "characters" else Vector2i(240, 240)
	var cols := 8
	var rows := ceili(files.size() / float(cols))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#3a4a3a"))
	for i in files.size():
		var text := FileAccess.get_file_as_string("res://art/%s/%s" % [folder, files[i]])
		var img := Image.new()
		img.load_svg_from_string(text, 0.5)
		img.convert(Image.FORMAT_RGBA8)
		var pos := Vector2i((i % cols) * cell.x, (i / cols) * cell.y)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), pos)
	sheet.save_png(out)
	print("saved ", out)
	quit()
