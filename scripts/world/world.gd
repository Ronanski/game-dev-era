extends Node3D
## Overworld. Builds an HD-2D style scene (simple 3D props, pixel-art
## billboard sprites, tilt-shift depth of field, bloom and fog) from
## res://data/maps/<map_id>.json and handles exploration, talking,
## random encounters and map exits.

const SPEED := 4.6
const TALK_RANGE := 2.0
const PIXEL := 0.09
const CAM_OFFSET := Vector3(0, 8.0, 10.5)

var map: Dictionary
var player: CharacterBody3D
var player_sprite: Sprite3D
var camera: Camera3D
var actors: Array = []
var hud: CanvasLayer

var _rng := RandomNumberGenerator.new()
var _mats := {}
var _time := 0.0
var _walked := 0.0
var _next_encounter := 0.0
var _leaving := false
var _focus = null


func _ready() -> void:
	if GameState.party.is_empty():
		GameState.new_game()
	map = GameState.load_json("res://data/maps/%s.json" % GameState.map_id)
	_rng.seed = hash(GameState.map_id)
	_build_environment()
	_build_ground()
	for p in map.get("props", []):
		_build_prop(p)
	_build_exits()
	_build_actors()
	_build_player()
	_build_camera()
	hud = preload("res://scripts/world/hud.gd").new()
	add_child(hud)
	hud.setup(map.get("name", ""))
	hud.save_requested.connect(_save)
	_roll_encounter()
	_refresh()
	_save(false)
	await get_tree().process_frame
	await _run_pending(true)


func _physics_process(delta: float) -> void:
	_time += delta
	_animate_actors()
	if _leaving:
		return
	var input := Vector2.ZERO
	var free: bool = not GameState.busy and not hud.is_menu_open()
	if free:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if hud.joystick and hud.joystick.vector.length() > 0.15:
			input = hud.joystick.vector
	player.velocity = Vector3(input.x, 0, input.y) * SPEED
	player.move_and_slide()
	player.position.y = 0.0
	var moving := input.length() > 0.1
	if absf(input.x) > 0.1:
		player_sprite.flip_h = input.x < 0
	player_sprite.position.y = absf(sin(_time * 12.0)) * 0.08 if moving else 0.0
	camera.position = camera.position.lerp(player.position + CAM_OFFSET, 1.0 - exp(-6.0 * delta))
	if not free:
		return
	if moving and map.has("encounters"):
		_walked += player.get_real_velocity().length() * delta
		if _walked >= _next_encounter:
			var groups: Array = map["encounters"]["groups"]
			_start_battle(groups[randi() % groups.size()])
			return
	if _check_exits():
		return
	_update_focus()
	if _focus != null and Input.is_action_just_pressed("interact"):
		_talk(_focus)


# --- Story flow ---------------------------------------------------------------

func _talk(actor: Dictionary) -> void:
	for entry in actor["data"].get("talk", []):
		if GameState.check(entry.get("if", {})):
			await Dialogue.run(entry["file"], entry["start"])
			break
	await _run_pending(false)


## Handles anything a dialogue or battle asked for: follow-up dialogue,
## map events, endings, battles, and the trial deadline.
func _run_pending(entering: bool) -> void:
	if entering and GameState.pending_dialogue != "":
		var pd := GameState.pending_dialogue.split(":")
		GameState.pending_dialogue = ""
		await Dialogue.run(pd[0], pd[1])
	if entering:
		for ev in map.get("events", []):
			if GameState.check(ev.get("if", {})):
				await Dialogue.run(ev["file"], ev["start"])
				break
	_refresh()
	if GameState.pending_ending != "":
		_leaving = true
		await hud.fade_out()
		GameState.goto("ending")
		return
	if GameState.pending_battle != "":
		_start_battle(GameState.pending_battle)
		return
	if GameState.day > GameState.MAX_DAYS and not GameState.flags.get("trial_started", false):
		await Dialogue.run("trial", "forced")
		await _run_pending(false)


func _start_battle(group: String) -> void:
	_leaving = true
	GameState.pending_battle = ""
	GameState.battle_group = group
	GameState.return_pos = [player.position.x, player.position.z]
	await hud.flash()
	GameState.goto("battle")


func _check_exits() -> bool:
	for e in map.get("exits", []):
		var c := _v(e["pos"])
		var s: Array = e.get("size", [3, 3])
		if absf(player.position.x - c.x) < s[0] / 2.0 and absf(player.position.z - c.z) < s[1] / 2.0:
			_leaving = true
			GameState.map_id = e["to"]
			GameState.spawn_id = e["spawn"]
			GameState.return_pos = null
			_go_to_map()
			return true
	return false


func _go_to_map() -> void:
	await hud.fade_out()
	GameState.goto("world")


func _save(announce := true) -> void:
	GameState.save_game([player.position.x, player.position.z])
	if announce:
		GameState.toast.emit("Nai-save ang laro.")


func _roll_encounter() -> void:
	_walked = 0.0
	if map.has("encounters"):
		var e: Dictionary = map["encounters"]
		_next_encounter = randf_range(e.get("min", 15), e.get("max", 30))


func _refresh() -> void:
	for a in actors:
		var show := GameState.check(a["data"].get("if", {}))
		a["root"].visible = show
		if a["shape"]:
			a["shape"].disabled = not show
	if player_sprite and not GameState.party.is_empty():
		player_sprite.texture = Sprites.texture(GameState.party[0]["id"])
	hud.refresh()


func _update_focus() -> void:
	var best = null
	var best_d := TALK_RANGE
	for a in actors:
		if not a["root"].visible or a["data"].get("talk", []).is_empty():
			continue
		var d: float = a["root"].position.distance_to(player.position)
		if d < best_d:
			best_d = d
			best = a
	_focus = best
	if best == null:
		hud.set_prompt("")
	else:
		var data: Dictionary = best["data"]
		hud.set_prompt(data.get("name", GameState.character_name(data.get("look", data["id"]))))


func _animate_actors() -> void:
	for a in actors:
		if a["data"].get("look", "") == "sparkle":
			a["sprite"].position.y = 0.25 + sin(_time * 3.0 + a["phase"]) * 0.12
			a["sprite"].modulate.a = 0.7 + sin(_time * 5.0 + a["phase"]) * 0.3
		elif a["data"].get("idle", true):
			a["sprite"].scale.y = 1.0 + sin(_time * 2.2 + a["phase"]) * 0.015


# --- Scene construction -------------------------------------------------------

func _v(p: Array) -> Vector3:
	if p.size() >= 3:
		return Vector3(p[0], p[1], p[2])
	return Vector3(p[0], 0, p[1])


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(map.get("sky", "#1b2030"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(map.get("ambient", "#8890b0"))
	env.ambient_light_energy = map.get("ambient_energy", 0.7)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(map.get("fog", "#a0a8c0"))
	env.fog_density = map.get("fog_density", 0.015)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	# Tilt-shift look: blur near and far, keep the play area sharp.
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 15.0
	attrs.dof_blur_far_transition = 8.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 7.0
	attrs.dof_blur_near_transition = 3.0
	attrs.dof_blur_amount = 0.1
	we.camera_attributes = attrs
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(map.get("sun", "#ffe2b0"))
	sun.light_energy = map.get("sun_energy", 1.0)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)


func _build_ground() -> void:
	var size: Array = map.get("size", [40, 30])
	var w := float(size[0])
	var d := float(size[1])
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 40, d + 40)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _noise_texture(Color(map.get("ground", "#5d7c45")))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3((w + 40) / 4.0, (d + 40) / 4.0, 1)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)
	# Invisible walls at the map edges.
	_collider(Vector3(0, 1, -d / 2 - 0.5), Vector3(w + 2, 2, 1))
	_collider(Vector3(0, 1, d / 2 + 0.5), Vector3(w + 2, 2, 1))
	_collider(Vector3(-w / 2 - 0.5, 1, 0), Vector3(1, 2, d + 2))
	_collider(Vector3(w / 2 + 0.5, 1, 0), Vector3(1, 2, d + 2))


func _noise_texture(base: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c := base
			var r := _rng.randf()
			if r < 0.08:
				c = base.darkened(0.18)
			elif r < 0.16:
				c = base.lightened(0.08)
			else:
				c = base.darkened(_rng.randf_range(-0.04, 0.05))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _mat(color: String, glow := false, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color, glow, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.albedo_color.a = alpha
	m.roughness = 0.9
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		m.metallic = 0.3
	if glow:
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = 1.3
	_mats[key] = m
	return m


func _mesh(mesh: Mesh, pos: Vector3, color: String, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color, glow)
	add_child(mi)
	return mi


func _box(pos: Vector3, size: Vector3, color: String, collide := true, glow := false) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	if collide:
		_collider(pos, size)
	return _mesh(bm, pos, color, glow)


func _collider(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _cyl(pos: Vector3, top: float, bottom: float, height: float, color: String, sides := 8, glow := false) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	return _mesh(cm, pos, color, glow)


func _ball(pos: Vector3, radius: float, color: String, squash := 1.0, glow := false) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0 * squash
	sm.radial_segments = 8
	sm.rings = 4
	return _mesh(sm, pos, color, glow)


func _light(pos: Vector3, color: String, energy := 1.4, radius := 6.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(color)
	l.light_energy = energy
	l.omni_range = radius
	add_child(l)


func _build_prop(p: Dictionary) -> void:
	var t: String = p.get("type", "")
	var pos := _v(p.get("pos", [0, 0]))
	var size: Array = p.get("size", [1, 1, 1])
	match t:
		"house":
			_house(pos, p)
		"tent":
			_tent(pos, p)
		"tree":
			_tree(pos, p.get("kind", "round"), p.get("scale", 1.0))
		"balete":
			_balete(pos)
		"scatter":
			_scatter(p)
		"rock":
			_rock(pos, p.get("scale", 1.0))
		"bush":
			_ball(pos + Vector3(0, 0.3, 0), 0.5 * p.get("scale", 1.0), p.get("color", "#3f7a3a"), 0.7)
		"lamp":
			_lamp(pos, p.get("color", "#ffb35c"))
		"wisp":
			_ball(pos + Vector3(0, 1.4, 0), 0.12, p.get("color", "#9fe8ff"), 1.0, true)
			_light(pos + Vector3(0, 1.4, 0), p.get("color", "#9fe8ff"), 0.9, 4.0)
		"path":
			var road := _box(pos + Vector3(0, 0.01, 0), Vector3(size[0], 0.02, size[1]), "#000000", false)
			var rm := StandardMaterial3D.new()
			rm.albedo_texture = _noise_texture(Color(p.get("color", "#8a7356")))
			rm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			rm.uv1_scale = Vector3(float(size[0]) / 4.0, float(size[1]) / 4.0, 1)
			rm.roughness = 1.0
			road.material_override = rm
		"water":
			_box(pos + Vector3(0, 0.03, 0), Vector3(size[0], 0.04, size[1]), p.get("color", "#3a7bbf"), false)
			_box(pos + Vector3(0, -0.2, 0), Vector3(size[0] + 0.02, 0.3, size[1] + 0.02), "#1c3d5e", false)
			_collider(pos + Vector3(0, 1, 0), Vector3(size[0], 2, size[1]))
		"box":
			var h := float(size[1])
			_box(pos + Vector3(0, h / 2, 0), Vector3(size[0], h, size[2]), p.get("color", "#8a7a6a"), p.get("collide", true), p.get("glow", false))
		"pillar":
			var h := float(p.get("height", 3.0))
			var pillar := _cyl(pos + Vector3(0, h / 2, 0), 0.35, 0.42, h, p.get("color", "#a39a8a"), 8)
			pillar.rotation_degrees = Vector3(p.get("tilt", 0.0), 0, p.get("tilt", 0.0) * 0.5)
			_collider(pos + Vector3(0, 1, 0), Vector3(0.8, 2, 0.8))
		"statue":
			_statue(pos, p)
		"moon":
			_ball(pos, p.get("radius", 4.0), p.get("color", "#f2e6b8"), 1.0, true)
		"chest":
			_box(pos + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.7), "#6b4226")
			_box(pos + Vector3(0, 0.62, 0), Vector3(1.04, 0.08, 0.74), "#e8c170", false)
		"sign":
			var label := Label3D.new()
			label.text = p.get("text", "")
			label.position = pos + Vector3(0, p.get("height", 2.6), 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 48
			label.pixel_size = 0.01
			label.outline_size = 12
			label.modulate = Color("#f5ecd0")
			add_child(label)
		"fence":
			_box(pos + Vector3(0, 0.4, 0), Vector3(size[0], 0.8, size[1]), p.get("color", "#6b4a30"))
		_:
			push_warning("Unknown prop type: " + t)


func _house(pos: Vector3, p: Dictionary) -> void:
	var size: Array = p.get("size", [4, 3, 3])
	var w := float(size[0])
	var h := float(size[1])
	var d := float(size[2])
	var base := h
	if p.get("stilts", false):
		# Bahay kubo: raised on posts.
		base = 0.8
		for sx in [-w / 2 + 0.2, w / 2 - 0.2]:
			for sz in [-d / 2 + 0.2, d / 2 - 0.2]:
				_box(pos + Vector3(sx, base / 2, sz), Vector3(0.18, base, 0.18), "#5a3d2b", false)
		_collider(pos + Vector3(0, 1, 0), Vector3(w, 2, d))
		_box(pos + Vector3(0, base + (h - base) / 2, 0), Vector3(w, h - base, d), p.get("color", "#c8b08a"), false)
	else:
		_box(pos + Vector3(0, h / 2, 0), Vector3(w, h, d), p.get("color", "#c8b08a"))
	var pm := PrismMesh.new()
	pm.size = Vector3(d + 0.7, h * 0.7, w + 0.7)
	var roof := _mesh(pm, pos + Vector3(0, h + h * 0.35, 0), p.get("roof", "#7a3b2e"))
	roof.rotation_degrees.y = 90
	var door_y := 0.75 if not p.get("stilts", false) else 0.8 + 0.6
	_box(pos + Vector3(0, door_y, d / 2 + 0.03), Vector3(0.9, 1.4, 0.06), "#3a2418", false)
	for wx in [-w / 3.0, w / 3.0]:
		_box(pos + Vector3(wx, h * 0.62, d / 2 + 0.03), Vector3(0.6, 0.5, 0.06), "#ffcf6b", false, true)


func _tent(pos: Vector3, p: Dictionary) -> void:
	var size: Array = p.get("size", [3, 2, 3])
	var pm := PrismMesh.new()
	pm.size = Vector3(size[0], size[1], size[2])
	_mesh(pm, pos + Vector3(0, float(size[1]) / 2, 0), p.get("color", "#d9c9a3"))
	_box(pos + Vector3(0, 0.6, float(size[2]) / 2 + 0.02), Vector3(0.8, 1.2, 0.04), "#2a1a12", false)
	_collider(pos + Vector3(0, 1, 0), Vector3(size[0], 2, size[2]))
	if p.has("banner"):
		_box(pos + Vector3(float(size[0]) / 2 + 0.3, 1.5, 0), Vector3(0.08, 3.0, 0.08), "#3a2a20", false)
		_box(pos + Vector3(float(size[0]) / 2 + 0.62, 2.5, 0), Vector3(0.6, 0.9, 0.04), p["banner"], false)


func _tree(pos: Vector3, kind: String, sc: float) -> void:
	sc *= _rng.randf_range(0.85, 1.2)
	var greens := ["#2f5d3a", "#3a6b3f", "#2c5232", "#41763d"]
	var leaf: String = greens[_rng.randi() % greens.size()]
	match kind:
		"pine":
			_cyl(pos + Vector3(0, 0.6 * sc, 0), 0.12 * sc, 0.18 * sc, 1.2 * sc, "#4a3424", 6)
			_cyl(pos + Vector3(0, 1.9 * sc, 0), 0.0, 1.2 * sc, 2.2 * sc, leaf, 7)
			_cyl(pos + Vector3(0, 2.9 * sc, 0), 0.0, 0.85 * sc, 1.6 * sc, leaf, 7)
		"palm":
			var trunk := _cyl(pos + Vector3(0, 1.6 * sc, 0), 0.1 * sc, 0.16 * sc, 3.2 * sc, "#7a5a3a", 6)
			trunk.rotation_degrees.z = _rng.randf_range(-8, 8)
			for i in 5:
				var frond := _box(pos + Vector3(0, 3.2 * sc, 0), Vector3(2.2 * sc, 0.08, 0.5 * sc), "#4f8a3a", false)
				frond.rotation_degrees = Vector3(0, i * 36.0, -15)
		_:
			_cyl(pos + Vector3(0, 0.8 * sc, 0), 0.14 * sc, 0.2 * sc, 1.6 * sc, "#5a3d2b", 6)
			_ball(pos + Vector3(0, 2.2 * sc, 0), 1.1 * sc, leaf, 0.9)
			_ball(pos + Vector3(0.5 * sc, 2.8 * sc, 0.2 * sc), 0.7 * sc, leaf, 0.9)
	_collider(pos + Vector3(0, 1, 0), Vector3(0.6, 2, 0.6))


func _balete(pos: Vector3) -> void:
	_cyl(pos + Vector3(0, 2.5, 0), 0.6, 1.1, 5.0, "#4a3a2e", 8)
	for i in 8:
		var a := TAU * i / 8.0
		var root := _cyl(pos + Vector3(cos(a) * 1.1, 1.6, sin(a) * 1.1), 0.08, 0.16, 3.2, "#3e3026", 5)
		root.rotation_degrees = Vector3(sin(a) * 18, 0, -cos(a) * 18)
	_ball(pos + Vector3(0, 6.0, 0), 3.6, "#24402c", 0.7)
	_ball(pos + Vector3(1.8, 6.8, 0.8), 2.2, "#2c4a32", 0.8)
	_ball(pos + Vector3(-1.6, 6.5, -0.6), 2.4, "#203a28", 0.8)
	_collider(pos + Vector3(0, 1, 0), Vector3(2.4, 2, 2.4))


func _rock(pos: Vector3, sc: float) -> void:
	sc *= _rng.randf_range(0.7, 1.3)
	var r := _ball(pos + Vector3(0, 0.25 * sc, 0), 0.55 * sc, "#7b7b80", 0.7)
	r.rotation_degrees.y = _rng.randf_range(0, 360)
	_collider(pos + Vector3(0, 0.5, 0), Vector3(0.9 * sc, 1, 0.9 * sc))


func _lamp(pos: Vector3, color: String) -> void:
	_box(pos + Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), "#2a2220")
	_box(pos + Vector3(0, 1.9, 0), Vector3(0.3, 0.3, 0.3), color, false, true)
	_light(pos + Vector3(0, 1.9, 0), color, 0.8, 5.0)


func _statue(pos: Vector3, p: Dictionary) -> void:
	var stone: String = p.get("color", "#9a948a")
	_box(pos + Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 2.2), stone)
	_box(pos + Vector3(0, 1.6, 0), Vector3(0.9, 1.6, 0.6), stone, false)
	_box(pos + Vector3(0, 2.7, 0), Vector3(0.6, 0.6, 0.5), stone, false)
	if p.get("orb", true):
		_ball(pos + Vector3(0, 3.6, 0), 0.45, p.get("orb_color", "#f2e6b8"), 1.0, true)
		_light(pos + Vector3(0, 3.6, 0), p.get("orb_color", "#f2e6b8"), 1.6, 7.0)


func _scatter(p: Dictionary) -> void:
	var area: Array = p["area"]
	var avoid: Array = p.get("avoid", [])
	var kind: String = p.get("kind", "tree")
	var placed := 0
	var tries := 0
	while placed < int(p.get("count", 10)) and tries < 2000:
		tries += 1
		var x := _rng.randf_range(area[0], area[2])
		var z := _rng.randf_range(area[1], area[3])
		var blocked := false
		for r in avoid:
			if x > r[0] and x < r[2] and z > r[1] and z < r[3]:
				blocked = true
				break
		if blocked:
			continue
		placed += 1
		var pos := Vector3(x, 0, z)
		match kind:
			"rock":
				_rock(pos, p.get("scale", 1.0))
			"bush":
				_ball(pos + Vector3(0, 0.3, 0), 0.5 * _rng.randf_range(0.7, 1.3), p.get("color", "#3f7a3a"), 0.7)
			"pillar":
				var h := _rng.randf_range(1.0, 3.5)
				var pl := _cyl(pos + Vector3(0, h / 2, 0), 0.35, 0.42, h, p.get("color", "#a39a8a"), 8)
				pl.rotation_degrees = Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12))
				_collider(pos + Vector3(0, 1, 0), Vector3(0.8, 2, 0.8))
			_:
				var kinds: Array = p.get("trees", ["round"])
				_tree(pos, kinds[_rng.randi() % kinds.size()], p.get("scale", 1.0))


func _build_exits() -> void:
	for e in map.get("exits", []):
		var pos := _v(e["pos"])
		var s: Array = e.get("size", [3, 3])
		_box(pos + Vector3(0, 0.02, 0), Vector3(s[0], 0.03, s[1]), "#ffd98a", false, true)
		var label := Label3D.new()
		label.text = e.get("label", "")
		label.position = pos + Vector3(0, 1.6, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 44
		label.pixel_size = 0.01
		label.outline_size = 12
		label.modulate = Color("#ffe7a8")
		add_child(label)


func _make_sprite(char_id: String) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Sprites.texture(char_id)
	s.pixel_size = PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	s.centered = true
	s.offset = Vector2(0, s.texture.get_height() / 2.0)
	return s


func _blob_shadow(parent: Node3D, radius: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.01
	cm.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position.y = 0.02
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build_actors() -> void:
	for a in map.get("actors", []):
		var root := Node3D.new()
		root.position = _v(a["pos"])
		add_child(root)
		var look: String = a.get("look", a["id"])
		var spr := _make_sprite(look)
		if a.has("scale"):
			spr.pixel_size = PIXEL * float(a["scale"])
			spr.offset.y = spr.texture.get_height() / 2.0
		root.add_child(spr)
		var shape: CollisionShape3D = null
		if look == "sparkle":
			spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_light(root.position + Vector3(0, 0.6, 0), "#fff2a8", 0.8, 2.5)
		else:
			_blob_shadow(root, 0.45 * float(a.get("scale", 1.0)))
			var body := StaticBody3D.new()
			shape = CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.35 * float(a.get("scale", 1.0))
			cyl.height = 1.5
			shape.shape = cyl
			shape.position.y = 0.75
			body.add_child(shape)
			root.add_child(body)
		actors.append({"data": a, "root": root, "sprite": spr, "shape": shape, "phase": _rng.randf() * TAU})


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.2
	shape.shape = cap
	shape.position.y = 0.6
	player.add_child(shape)
	player_sprite = _make_sprite(GameState.party[0]["id"])
	player.add_child(player_sprite)
	_blob_shadow(player, 0.4)
	add_child(player)
	if GameState.return_pos is Array:
		player.position = Vector3(GameState.return_pos[0], 0, GameState.return_pos[1])
		GameState.return_pos = null
	else:
		var spawns: Dictionary = map.get("spawns", {})
		player.position = _v(spawns.get(GameState.spawn_id, spawns.get("start", [0, 0])))


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.position = player.position + CAM_OFFSET
	camera.look_at(player.position + Vector3(0, 0.8, 0))
	camera.make_current()
