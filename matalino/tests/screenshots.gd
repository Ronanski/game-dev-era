extends Node
## Renders the main screens to PNG (needs a display, e.g. xvfb-run).
## Run: godot --path . res://tests/screenshots.tscn -- --out=/some/folder

var out := "user://screenshots"
var main: Control


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Save.data = {}
	Save.load_data()
	for g in UI.GAMES:
		Save.g(g.id).seen_rules = true
	Save.g("crown").level = 12
	Save.g("trail").level = 7
	Save.g("pulse").level = 18
	Save.g("duo").level = 9
	Save.g("echo").level = 5
	Save.data.daily[Save.today()] = {"trail": 40.0, "pulse": 22.0}
	Save.data.streak = {"count": 6, "best": 9, "last": Save.today()}
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("home", 40)

	main.play("crown", false, 12)
	var b: CrownBoard = await _wait_board()
	for row in [0, 2, 3]:
		b.cells[row * b.n + b.solution[row]] = CrownBoard.CROWN
	b.cells[1 * b.n + 0] = CrownBoard.MARK
	b.cells[1 * b.n + 1] = CrownBoard.MARK
	b.cells[5 * b.n + b.solution[3]] = CrownBoard.CROWN
	b.queue_redraw()
	main.screen.queue_redraw()
	await _shot("crown", 10)

	main.play("trail", false, 7)
	var t: TrailBoard = await _wait_board()
	t.path = t.solution.slice(0, 15)
	t.queue_redraw()
	main.screen.queue_redraw()
	await _shot("trail", 10)

	main.play("pulse", false, 18)
	var p: PulseBoard = await _wait_board()
	for i in p.n * p.n / 2:
		p.tiles[i] = p.solution[i]
	p._refresh()
	await _shot("pulse", 10)

	main.play("duo", false, 9)
	var d: DuoBoard = await _wait_board()
	for i in 10:
		var k := d.cells.find(DuoBoard.EMPTY)
		d.cells[k] = d.solution[k]
	d.queue_redraw()
	main.screen.queue_redraw()
	await _shot("duo", 10)

	main.play("echo", false, 9)
	await _wait_board()
	await _shot("echo", 50)

	main.screen._show_rules()
	await _shot("rules", 30)

	main.play("pulse", false, 3)
	var p2: PulseBoard = await _wait_board()
	p2.tiles = p2.solution.duplicate()
	p2._refresh()
	p2.finish()
	await _shot("win", 110)
	get_tree().quit()


func _wait_board() -> Board:
	await get_tree().process_frame
	await get_tree().process_frame
	var b: Board = main.screen.board
	while b.loading:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	return b


func _shot(shot_name: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, shot_name])
	print("saved ", shot_name)
