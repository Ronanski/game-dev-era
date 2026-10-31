extends SceneTree
## Checks that all story data is consistent: every dialogue jump, clue,
## character, battle, map exit and ending referenced actually exists.
##
## Run:  godot --headless --path . -s tests/validate_data.gd

var errors: Array = []
var db := {}
var dialogues := {}


func _init() -> void:
	for key in ["characters", "party", "skills", "enemies", "encounters", "items", "clues", "endings", "quests"]:
		db[key] = _json("res://data/%s.json" % key)
	for f in DirAccess.get_files_at("res://data/dialogue"):
		if f.ends_with(".json"):
			dialogues[f.get_basename()] = _json("res://data/dialogue/" + f)
	var maps := {}
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.ends_with(".json"):
			maps[f.get_basename()] = _json("res://data/maps/" + f)

	for id in db["party"]:
		var m: Dictionary = db["party"][id]
		_need(db["characters"].has(id), "party member %s has no character entry" % id)
		for s in m["skills"]:
			_need(db["skills"].has(s), "party %s: unknown skill %s" % [id, s])
	for id in db["enemies"]:
		_need(db["characters"].has(db["enemies"][id].get("look", id)), "enemy %s has no character/look" % id)
	for g in db["encounters"]:
		var enc: Dictionary = db["encounters"][g]
		for e in enc["enemies"]:
			_need(db["enemies"].has(e), "encounter %s: unknown enemy %s" % [g, e])
		_check_fx(enc.get("win", {}), "encounter " + g)
		if enc.has("after"):
			var parts: PackedStringArray = enc["after"].split(":")
			_need_node(parts[0], parts[1], "encounter %s after" % g)
	for q in db["quests"]:
		_check_cond(q.get("if", {}), "quest")

	for file in dialogues:
		for id in dialogues[file]:
			var node: Dictionary = dialogues[file][id]
			var where := "%s:%s" % [file, id]
			_check_cond(node.get("if", {}), where)
			_check_fx(node.get("do", {}), where)
			if node.has("else"):
				_need_jump(file, node["else"], where + " else")
			if node.has("next"):
				_need_jump(file, node["next"], where + " next")
			for line in node.get("lines", []):
				_need(line is Array and line.size() == 2, where + ": bad line " + str(line))
				if line is Array and line.size() == 2 and line[0] != "":
					_need(db["characters"].has(line[0]), where + ": unknown speaker " + str(line[0]))
			for c in node.get("choices", []):
				_need(c.has("text"), where + ": choice without text")
				_check_cond(c.get("if", {}), where + " choice")
				_check_fx(c.get("do", {}), where + " choice")
				_need_jump(file, c.get("next", ""), where + " choice")

	for map_id in maps:
		var map: Dictionary = maps[map_id]
		for ev in map.get("events", []):
			_check_cond(ev.get("if", {}), map_id + " event")
			_need_node(ev["file"], ev["start"], map_id + " event")
		for ex in map.get("exits", []):
			_need(maps.has(ex["to"]), "%s exit: unknown map %s" % [map_id, ex["to"]])
			if maps.has(ex["to"]):
				_need(maps[ex["to"]].get("spawns", {}).has(ex["spawn"]), "%s exit: map %s has no spawn %s" % [map_id, ex["to"], ex["spawn"]])
		for g in map.get("encounters", {}).get("groups", []):
			_need(db["encounters"].has(g), "%s: unknown encounter %s" % [map_id, g])
		for a in map.get("actors", []):
			var where := "%s actor %s" % [map_id, a["id"]]
			_need(db["characters"].has(a.get("look", a["id"])), where + ": unknown look")
			_check_cond(a.get("if", {}), where)
			for t in a.get("talk", []):
				_check_cond(t.get("if", {}), where)
				_need_node(t["file"], t["start"], where)

	if errors.is_empty():
		print("OK: story data is consistent (%d dialogue files, %d maps)." % [dialogues.size(), maps.size()])
		quit(0)
	else:
		for e in errors:
			printerr("ERROR: " + e)
		printerr("%d problem(s) found." % errors.size())
		quit(1)


func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("cannot open " + path)
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		errors.append("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data


func _need(ok: bool, msg: String) -> void:
	if not ok:
		errors.append(msg)


func _need_jump(file: String, target: String, where: String) -> void:
	if target == "":
		return
	if target.contains(":"):
		var parts := target.split(":")
		_need_node(parts[0], parts[1], where)
	else:
		_need_node(file, target, where)


func _need_node(file: String, id: String, where: String) -> void:
	_need(dialogues.has(file) and dialogues[file].has(id), "%s: missing dialogue node %s:%s" % [where, file, id])


func _arr(v) -> Array:
	return v if v is Array else [v]


func _check_cond(cond: Dictionary, where: String) -> void:
	for key in cond:
		match key:
			"clue", "not_clue", "any_clue":
				for c in _arr(cond[key]):
					_need(db["clues"].has(c), "%s: unknown clue %s" % [where, c])
			"member", "not_member":
				for m in _arr(cond[key]):
					_need(db["party"].has(m), "%s: unknown party member %s" % [where, m])
			"flag", "not_flag", "gold", "min_day", "max_day":
				pass
			_:
				errors.append("%s: unknown condition %s" % [where, key])


func _check_fx(fx: Dictionary, where: String) -> void:
	for key in fx:
		match key:
			"clue":
				for c in _arr(fx[key]):
					_need(db["clues"].has(c), "%s: unknown clue %s" % [where, c])
			"item":
				for i in fx[key]:
					_need(db["items"].has(i), "%s: unknown item %s" % [where, i])
			"join", "leave":
				_need(db["party"].has(fx[key]), "%s: unknown party member %s" % [where, fx[key]])
			"battle":
				_need(db["encounters"].has(fx[key]), "%s: unknown encounter %s" % [where, fx[key]])
			"ending":
				_need(db["endings"].has(fx[key]), "%s: unknown ending %s" % [where, fx[key]])
			"set", "gold", "heal", "rest":
				pass
			_:
				errors.append("%s: unknown effect %s" % [where, key])
