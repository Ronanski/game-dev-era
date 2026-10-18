extends SceneTree
## Automated playthrough: talks to characters, answers choices, fights the
## bosses and reaches an ending, using the real scenes and dialogue.
##
## Run:  godot --headless --path . -s tests/playthrough.gd
## Pass  -- --route=<name>  to pick a route (best, war, hiraya, partial).

var plan: Array = []
var gs: Node
var dlg: Node
var failed := false
var route := "best"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--route="):
			route = arg.substr(8)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if dlg == null:
		return false
	# Auto-advance dialogue.
	if dlg._typing:
		dlg._finish_typing()
	elif dlg._waiting:
		dlg._advance.emit()
	elif dlg._choices.visible and dlg._choices.get_child_count() > 0:
		_answer()
	# Auto-fight: always pick the first menu option (Atake, first weapon, first target).
	var scene := current_scene
	if scene and scene.name == "Battle" and scene._menu.get_child_count() > 0:
		var first: Button = scene._menu.get_child(0)
		if not first.is_queued_for_deletion():
			scene._picked.emit(0)
	return false


func _answer() -> void:
	var texts: Array = []
	for b in dlg._choices.get_children():
		texts.append(b.text)
	var idx := texts.size() - 1
	if not plan.is_empty():
		for i in texts.size():
			if plan[0] in texts[i]:
				idx = i
				plan.pop_front()
				break
	print("    choose: ", texts[idx])
	dlg._chosen.emit(idx)


func _run() -> void:
	gs = root.get_node("GameState")
	dlg = root.get_node("Dialogue")
	gs.new_game()
	# Make the party strong so the test is about story flow, not balance.
	gs.join("bagwis", false)
	for m in gs.party:
		m["atk"] = 60
		m["mag"] = 60
		m["hp"] = 999
		m["max_hp"] = 999

	plan = ["Para sa kapayapaan"]
	await _enter("halina")
	_expect(gs.flags.get("intro_done", false), "intro played")

	await _talk("dumalaw", ["Babalik"])
	if route == "late":
		# Rest past the deadline: the trial must start by itself.
		await _talk("rosing", ["Magpahinga"])
		await _talk("rosing", ["Magpahinga"])
		await _talk("rosing", ["Magpahinga", "Matutulog", "Hindi ko alam"])
		_expect(gs.flags.get("trial_started", false), "trial forced after day 3")
		_expect(gs.pending_ending == "digmaan", "no answer leads to war")
		await _wait_scene("Ending", 10)
		print("RESULT: ", "FAIL" if failed else "PASS", " (route: late)")
		quit(1 if failed else 0)
		return
	await _talk("tasa", [])
	_expect("tasa" in gs.clues, "found poisoned cup")
	await _talk("lito", ["Salamat"])
	await _talk("gaspar", ["espada", "Paalam"])
	_expect("walang_sugat" in gs.clues, "checked Gaspar's sword")
	await _talk("tala", ["Ibalik", "Sige, sumama"])
	_expect(gs.is_member("tala"), "Tala joined")
	await _talk("pacing", ["Hahanapin"])

	await _enter("gubat")
	await _talk("tikbalang", ["Bakunawa", "Huling Buwan", "ugat", "Sino pa", "Iyon lang"])
	_expect("puting_balabal" in gs.clues and "alibi_hiraya" in gs.clues, "Tikbalang answered")
	await _talk("hukay", [])
	await _talk("kapre", ["Pakawalan"])
	await _battle_and_return()
	_expect(gs.flags.get("pepe_saved", false), "Pepe saved after Kapre fight")

	if route != "partial":
		await _enter("guho")
		await _talk("sigbin", [])
		await _battle_and_return()
		await _talk("dibdib", [])
		_expect("sulat" in gs.clues, "found the Kapatiran letter")

	await _enter("halina")
	await _talk("pacing", [])
	_expect("putik" in gs.clues, "Aling Pacing's testimony")

	var accuse: String = {"best": "Apo Banal", "partial": "Apo Banal", "war": "Sir Gaspar ng", "hiraya": "Dayang Hiraya"}[route]
	var expected: String = {"best": "bukang_liwayway", "partial": "anino", "war": "digmaan", "hiraya": "luha"}[route]
	await _talk("dumalaw", ["Handa na", "Oo", accuse])
	_expect(gs.pending_ending == expected, "reached ending %s (got '%s')" % [expected, gs.pending_ending])
	await _wait_scene("Ending", 10)
	_expect(expected in gs.seen_endings(), "ending recorded")

	print("RESULT: ", "FAIL" if failed else "PASS", " (route: %s)" % route)
	quit(1 if failed else 0)


func _enter(map_id: String) -> void:
	print("-- enter ", map_id)
	gs.map_id = map_id
	gs.spawn_id = "start"
	gs.return_pos = null
	gs.goto("world")
	await _wait_scene("World", 10)
	await _idle()


func _talk(actor_id: String, choices: Array) -> void:
	print("  talk ", actor_id)
	plan = choices.duplicate()
	var world := current_scene
	var target = null
	for a in world.actors:
		if a["data"]["id"] == actor_id and a["root"].visible:
			target = a
	_expect(target != null, "actor %s is present" % actor_id)
	if target == null:
		return
	world._talk(target)
	await _idle()
	if not plan.is_empty():
		_expect(false, "unused choices for %s: %s" % [actor_id, plan])


func _battle_and_return() -> void:
	await _wait_scene("Battle", 10)
	print("  battle ", gs.battle_group)
	await _wait_scene("World", 120)
	await _idle()


func _idle() -> void:
	for i in 5:
		await process_frame
	var deadline := Time.get_ticks_msec() + 60000
	while (gs.busy or dlg.is_open()) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i in 5:
		await process_frame


func _wait_scene(scene_name: String, max_seconds: int) -> void:
	var deadline := Time.get_ticks_msec() + max_seconds * 1000
	while (current_scene == null or current_scene.name != scene_name) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(current_scene != null and current_scene.name == scene_name, "scene %s loaded" % scene_name)


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failed = true
