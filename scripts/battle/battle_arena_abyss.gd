extends Node3D
class_name BattleArenaAbyss

## Block 15: Abyss Forest battle arena — a compact diorama that feels like
## a fragment of the exploration Abyss Forest.
##
## Visual language inherited from abyss_forest_3d.gd:
##   - twisted/dead trees
##   - dark navy/teal atmosphere
##   - subtle fog
##   - cyan magical accents
##   - warm accent lighting (torches/glows)
##   - rocks and ruined fragments
##
## This is NOT a copy of the exploration world. It is a smaller, controlled
## diorama built for cinematic battle staging (~8m x 8m usable area).

const NATURE_ROOT := "res://Asset 3d/Stylized Nature MegaKit[Standard]/glTF/"
const VILLAGE_ROOT := "res://Asset 3d/Medieval Village MegaKit[Standard]/Medieval Village MegaKit[Standard]/glTF/"
const PROPS_ROOT := "res://Asset 3d/Fantasy Props MegaKit[Standard]/Exports/glTF/"

var _asset_cache: Dictionary = {}


func _ready() -> void:
	_build_ground()
	_build_environment_lighting()
	_build_background_trees()
	_build_ruin_fragments()
	_build_rocks()
	_build_props()
	_build_ambient_particles()


func _build_ground() -> void:
	# Dark mossy ground plane
	var body := StaticBody3D.new()
	body.name = "ArenaGround"
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(18.0, 14.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.048, 0.095, 0.075, 1.0)
	mat.roughness = 0.95
	mat.metallic = 0.0
	mesh.material = mat
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	(col.shape as BoxShape3D).size = Vector3(18.0, 0.2, 14.0)
	col.position.y = -0.1
	body.add_child(col)

	# Block 15.1: the old centre stone sat at (0,0,0) -- dead centre of the
	# battlefield, between the two formations, reading on screen as a slab of
	# teal clutter across the middle of the fight. Moved well behind the
	# enemy line so it still grounds the diorama without blocking the read.
	_spawn_asset(
		NATURE_ROOT + "RockPath_Square_Wide.gltf",
		"ArenaCenterStone", Vector3(0.0, 0.01, -4.6), 0.0, 1.0
	)


func _build_environment_lighting() -> void:
	# Moonlight (directional, blue-teal)
	var moon := DirectionalLight3D.new()
	moon.name = "ArenaeMoon"
	moon.light_color = Color(0.48, 0.68, 0.85, 1.0)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-38.0, 25.0, 0.0)
	add_child(moon)

	# Left torch glow (warm orange accent)
	var torch_left := OmniLight3D.new()
	torch_left.name = "TorchLeft"
	torch_left.position = Vector3(-4.5, 1.6, -2.0)
	torch_left.light_color = Color(1.0, 0.44, 0.14, 1.0)
	torch_left.light_energy = 3.5
	torch_left.omni_range = 5.0
	torch_left.shadow_enabled = false
	add_child(torch_left)

	# Right torch glow (warm orange accent)
	var torch_right := OmniLight3D.new()
	torch_right.name = "TorchRight"
	torch_right.position = Vector3(4.5, 1.6, -2.0)
	torch_right.light_color = Color(1.0, 0.44, 0.14, 1.0)
	torch_right.light_energy = 3.5
	torch_right.omni_range = 5.0
	torch_right.shadow_enabled = false
	add_child(torch_right)

	# Subtle cyan magic ambient point
	var magic_center := OmniLight3D.new()
	magic_center.name = "MagicAmbient"
	magic_center.position = Vector3(0.0, 0.5, 1.0)
	magic_center.light_color = Color(0.18, 0.82, 0.88, 1.0)
	magic_center.light_energy = 0.6
	magic_center.omni_range = 8.0
	magic_center.shadow_enabled = false
	add_child(magic_center)


func _build_background_trees() -> void:
	# Outer tree ring -- all pushed to the boundary so they don't interfere
	# with actor staging in the 8m center diorama.
	# Block 15.1: trees are a BACKDROP, never foreground. Every entry that
	# used to sit at positive Z (between camera and fighters) is pulled behind
	# the formations or out past the wings, so nothing occludes the fight.
	var tree_configs: Array[Dictionary] = [
		{"pos": Vector3(-8.4, 0.0, -3.2), "rot": -0.4, "scale": 0.78, "asset": "TwistedTree_1"},
		{"pos": Vector3(-9.0, 0.0, -0.6), "rot":  1.1, "scale": 0.85, "asset": "DeadTree_2"},
		{"pos": Vector3(-7.6, 0.0, -5.6), "rot": -1.8, "scale": 0.72, "asset": "TwistedTree_3"},
		{"pos": Vector3( 8.6, 0.0, -3.6), "rot":  0.6, "scale": 0.80, "asset": "TwistedTree_2"},
		{"pos": Vector3( 9.2, 0.0, -0.8), "rot": -0.9, "scale": 0.76, "asset": "DeadTree_4"},
		{"pos": Vector3( 7.8, 0.0, -5.8), "rot":  2.1, "scale": 0.82, "asset": "TwistedTree_5"},
		{"pos": Vector3( 0.5, 0.0, -7.4), "rot":  0.2, "scale": 0.70, "asset": "TwistedTree_4"},
		{"pos": Vector3(-3.2, 0.0, -7.6), "rot": -1.3, "scale": 0.65, "asset": "DeadTree_1"},
		{"pos": Vector3( 3.8, 0.0, -7.5), "rot":  0.8, "scale": 0.68, "asset": "DeadTree_3"},
	]
	for i in range(tree_configs.size()):
		var cfg := tree_configs[i]
		_spawn_asset(
			NATURE_ROOT + cfg["asset"] + ".gltf",
			"ArenaTree_%02d" % i,
			cfg["pos"], cfg["rot"], cfg["scale"]
		)


func _build_ruin_fragments() -> void:
	# Small ruin wall fragments at the edges — same asset family as exploration Abyss
	var ruins: Array[Array] = [
		[Vector3(-6.2, 0.0, -5.4), -0.5, "Wall_UnevenBrick_Straight", 0.65],
		[Vector3( 6.4, 0.0, -5.2),  0.4, "Wall_BottomCover", 0.60],
		[Vector3(-1.4, 0.0, -6.6), -1.2, "Wall_UnevenBrick_Straight", 0.55],
	]
	for i in range(ruins.size()):
		var ruin := ruins[i]
		_spawn_asset(
			VILLAGE_ROOT + ruin[2] + ".gltf",
			"ArenaRuin_%02d" % i,
			ruin[0], ruin[1], ruin[3]
		)


func _build_rocks() -> void:
	# Block 15.1: the first two used to sit at z ≈ +3, i.e. directly between
	# the camera and the fighters -- they rendered as the giant boulders
	# swallowing the bottom corners of the frame. Now flanking, and smaller.
	var rocks: Array[Array] = [
		[Vector3(-7.0, 0.0, -1.8), 0.8, 0.55, 1],
		[Vector3( 7.2, 0.0, -2.0),-0.5, 0.58, 2],
		[Vector3(-2.4, 0.0, -5.2), 1.3, 0.48, 3],
		[Vector3( 2.6, 0.0, -5.0),-1.1, 0.52, 1],
	]
	for i in range(rocks.size()):
		var rock := rocks[i]
		_spawn_asset(
			NATURE_ROOT + "Rock_Medium_%d.gltf" % rock[3],
			"ArenaRock_%02d" % i,
			rock[0], rock[1], rock[2]
		)


func _build_props() -> void:
	# Torches flank the stage from the wings, matching the light positions.
	_spawn_asset(PROPS_ROOT + "Torch_Metal.gltf", "ArenaTorchLeft",  Vector3(-6.4, 0.0, -2.2), 0.0, 1.0)
	_spawn_asset(PROPS_ROOT + "Torch_Metal.gltf", "ArenaTorchRight", Vector3( 6.6, 0.0, -2.2), 0.0, 1.0)
	# Block 15.1: relics and undergrowth used to be scattered at z ≈ +1..+3,
	# right in front of the lens -- that is the giant fern and the pair of
	# oversized mushrooms filling the bottom of the frame. All relocated
	# behind or beside the formations, and scaled down to prop size.
	_spawn_asset(PROPS_ROOT + "Lantern_Wall.gltf",     "ArenaLantern",  Vector3( 5.6, 0.0, -4.2),  0.5, 0.70)
	_spawn_asset(PROPS_ROOT + "Chain_Coil.gltf",       "ArenaChain",    Vector3(-5.4, 0.0, -4.4), -0.3, 0.70)
	_spawn_asset(NATURE_ROOT + "Fern_1.gltf",          "ArenaFern0",    Vector3(-6.0, 0.0, -0.4),  0.3, 0.55)
	_spawn_asset(NATURE_ROOT + "Mushroom_Common.gltf", "ArenaShroom0",  Vector3( 6.2, 0.0, -0.6), -0.6, 0.45)
	_spawn_asset(NATURE_ROOT + "Mushroom_Laetiporus.gltf","ArenaShroom1",Vector3(-0.6, 0.0, -5.8), 1.0, 0.45)


func _build_ambient_particles() -> void:
	# Firefly-like cyan particles (same as exploration Abyss world)
	var fireflies := GPUParticles3D.new()
	fireflies.name = "ArenaFireflies"
	fireflies.amount = 32
	fireflies.lifetime = 8.0
	fireflies.randomness = 0.88
	fireflies.visibility_aabb = AABB(Vector3(-7, -0.5, -6), Vector3(14, 5, 12))

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(6.0, 2.0, 5.0)
	process_mat.direction = Vector3(0.2, 0.5, 0.1)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 0.03
	process_mat.initial_velocity_max = 0.10
	process_mat.gravity = Vector3(0.0, 0.018, 0.0)
	process_mat.scale_min = 0.5
	process_mat.scale_max = 1.4
	fireflies.process_material = process_mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	var fly_mat := StandardMaterial3D.new()
	fly_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fly_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fly_mat.albedo_color = Color(0.35, 1.0, 0.82, 0.86)
	fly_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = fly_mat
	fireflies.draw_pass_1 = quad

	fireflies.position = Vector3(0.0, 1.0, 0.0)
	add_child(fireflies)


func _spawn_asset(
	path: String,
	instance_name: String,
	pos: Vector3,
	yaw: float = 0.0,
	uniform_scale: float = 1.0
) -> Node3D:
	var packed: PackedScene = _asset_cache.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		if packed == null:
			push_warning("BattleArenaAbyss: could not load '%s'" % path)
			return null
		_asset_cache[path] = packed

	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	add_child(instance)
	instance.name = instance_name
	instance.position = pos
	instance.rotation.y = yaw
	instance.scale = Vector3.ONE * uniform_scale
	return instance
