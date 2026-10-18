extends Node
## Player progress and settings, persisted as JSON in user://.

const PATH := "user://matalino.json"
const DAILY_LEVEL := 14

var data := {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	data = {}
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			data = parsed
	if not data.has("settings"):
		data.settings = {"sound": true, "haptics": true}
	if not data.has("games"):
		data.games = {}
	if not data.has("daily"):
		data.daily = {}
	if not data.has("streak"):
		data.streak = {"count": 0, "best": 0, "last": ""}
	for g in UI.GAMES:
		if not data.games.has(g.id):
			data.games[g.id] = {"level": 1, "solved": 0, "best": {}, "stars": {}, "seen_rules": false}


func flush() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func reset() -> void:
	var settings: Dictionary = data.settings
	data = {"settings": settings}
	load_data()
	flush()


func setting(key: String) -> bool:
	return bool(data.settings.get(key, true))


func set_setting(key: String, value: bool) -> void:
	data.settings[key] = value
	flush()


func g(id: String) -> Dictionary:
	return data.games[id]


func level(id: String) -> int:
	return int(g(id).level)


func stars_for(id: String, lvl: int) -> int:
	return int(g(id).stars.get(str(lvl), 0))


func best_for(id: String, lvl: int) -> float:
	return float(g(id).best.get(str(lvl), 0.0))


func total_solved() -> int:
	var n := 0
	for id in data.games:
		n += int(data.games[id].solved)
	return n


func total_stars() -> int:
	var n := 0
	for id in data.games:
		for k in data.games[id].stars:
			n += int(data.games[id].stars[k])
	return n


## Records a solved level. Returns {"best": float, "new_best": bool}.
func record_level(id: String, lvl: int, time: float, stars: int) -> Dictionary:
	var gd := g(id)
	var key := str(lvl)
	var prev := float(gd.best.get(key, 0.0))
	var new_best := prev <= 0.0 or time < prev
	if new_best:
		gd.best[key] = snappedf(time, 0.1)
	gd.stars[key] = max(int(gd.stars.get(key, 0)), stars)
	gd.solved = int(gd.solved) + 1
	if lvl >= int(gd.level):
		gd.level = lvl + 1
	_touch_streak()
	flush()
	return {"best": float(gd.best[key]), "new_best": new_best and prev > 0.0}


# --- Daily challenge -------------------------------------------------------

static func today() -> String:
	return _local_date(0)


static func daily_seed(id: String, date: String) -> int:
	return hash("daily:%s:%s" % [id, date])


static func level_seed(id: String, lvl: int) -> int:
	return hash("level:%s:%d" % [id, lvl])


func daily_done(id: String, date := "") -> bool:
	if date == "":
		date = today()
	return data.daily.get(date, {}).has(id)


func daily_count(date := "") -> int:
	if date == "":
		date = today()
	return data.daily.get(date, {}).size()


func record_daily(id: String, time: float) -> void:
	var d := today()
	if not data.daily.has(d):
		data.daily[d] = {}
	if not data.daily[d].has(id) or time < float(data.daily[d][id]):
		data.daily[d][id] = snappedf(time, 0.1)
	_touch_streak()
	flush()


func streak() -> int:
	var s: Dictionary = data.streak
	var last := str(s.get("last", ""))
	if last == today() or last == _yesterday():
		return int(s.count)
	return 0


func _touch_streak() -> void:
	var s: Dictionary = data.streak
	var t := today()
	if s.get("last", "") == t:
		return
	s.count = int(s.count) + 1 if s.get("last", "") == _yesterday() else 1
	s.best = max(int(s.get("best", 0)), int(s.count))
	s.last = t


static func _yesterday() -> String:
	return _local_date(-1)


static func _local_date(day_offset: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var unix := int(Time.get_unix_time_from_system()) + bias * 60 + day_offset * 86400
	var d := Time.get_date_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]
