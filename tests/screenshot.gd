extends SceneTree
## Saves screenshots of each map and a battle (needs a display; not headless).
##
## Run:  godot --path . -s tests/screenshot.gd -- --out=/some/folder

var out := "user://screenshots"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var gs := root.get_node("GameState")
	gs.goto("title")
	await _shot("title", 30)
	gs.new_game()
	gs.join("bagwis", false)
	gs.join("tala", false)
	gs.flags = {"intro_done": true, "gubat_visited": true, "guho_visited": true,
		"objective": "Siyasatin ang tolda ng konseho."}
	var spots := {"halina": [-4, -1], "gubat": [6, -4], "guho": [0, -3]}
	for map_id in spots:
		gs.map_id = map_id
		gs.return_pos = spots[map_id]
		gs.goto("world")
		await _shot(map_id, 90)
		if map_id == "halina":
			root.get_node("Dialogue").run("halina", "pacing_waiting")
			await _shot("dialogue", 200)
			root.get_node("Dialogue")._press()
			await _shot("dialogue_end", 30)
	gs.battle_group = "kapre_boss"
	gs.goto("battle")
	await _shot("battle", 150)
	quit()


func _shot(shot_name: String, frames: int) -> void:
	for i in frames:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, shot_name])
	print("saved ", shot_name)
