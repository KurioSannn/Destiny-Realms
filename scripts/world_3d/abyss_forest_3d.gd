extends Node3D
class_name AbyssForest3D

const LOGIN_SCENE_PATH := "res://scenes/login/login_scene.tscn"
const WERDONIA_OUTSKIRTS_SCENE_PATH := "res://scenes/world/world_scene.tscn"
const NATURE_ROOT := "res://Asset 3d/Stylized Nature MegaKit[Standard]/glTF/"
const VILLAGE_ROOT := "res://Asset 3d/Medieval Village MegaKit[Standard]/Medieval Village MegaKit[Standard]/glTF/"
const PROPS_ROOT := "res://Asset 3d/Fantasy Props MegaKit[Standard]/Exports/glTF/"
const SEAL_POSITION := Vector3(0.0, 0.0, -15.2)

## Trees stay on the default collision layer only (player movement still
## collides with trunks) but are excluded from this bit so the exploration
## camera's obstruction raycast passes through them; trees rely on the
## existing transparency fade instead. Solid geometry (walls, rocks, ruins,
## boundaries) also carries this bit so the camera pushes in around them.
const CAMERA_OBSTRUCTION_LAYER_BIT := 2

@onready var generated_world: Node3D = $GeneratedWorld
@onready var player: CharacterBody3D = $Player
@onready var seal_area: Area3D = $SealArea
@onready var hud_explor: HudExplorPlaceholder = $HudExplorPlaceholder/HUDRoot
@onready var abyss_bgm: AudioStreamPlayer = $AbyssBgm

var generated_asset_count: int = 0
var _asset_cache: Dictionary = {}
var _tree_occluder_meshes: Dictionary = {}
var _near_seal: bool = false
var _last_seal_distance: int = -1


func _ready() -> void:
	_build_abyss_forest()
	_build_collision_boundaries()
	seal_area.body_entered.connect(_on_seal_body_entered)
	seal_area.body_exited.connect(_on_seal_body_exited)
	hud_explor.show_player_marker = false
	hud_explor.set_player_status("Takashi", 10, 1897.0, 2000.0)
	hud_explor.slot_pressed.connect(_on_hud_slot_pressed)
	_setup_abyss_bgm()
	_update_seal_objective(true)


func _process(delta: float) -> void:
	_update_camera_occluders(delta)
	_update_seal_objective()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _near_seal:
		player.call("set_movement_enabled", false)
		SceneTransition.change_to_file(WERDONIA_OUTSKIRTS_SCENE_PATH)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		SceneTransition.change_to_file(LOGIN_SCENE_PATH)
		get_viewport().set_input_as_handled()


func _build_abyss_forest() -> void:
	_build_forest_path()
	_build_abyss_seal()
	_build_ruin_clusters()
	_build_twisted_tree_line()
	_scatter_undergrowth()
	_scatter_rocks_and_relics()
	_build_boundary_silhouettes()


func _build_forest_path() -> void:
	for index in range(20):
		var z_position := 15.4 - float(index) * 1.62
		var x_position := _path_x_at(z_position)
		var path_name := "RockPath_Square_Wide" if index % 4 == 0 else "RockPath_Round_Wide"
		_spawn_asset(
			NATURE_ROOT + path_name + ".gltf",
			"AbyssPath_%02d" % index,
			Vector3(x_position, 0.022, z_position),
			0.12 * sin(float(index) * 1.41),
			1.02
		)

	for index in range(12):
		var z_position := 13.0 - float(index) * 2.45
		var side := -1.0 if index % 2 == 0 else 1.0
		_spawn_asset(
			NATURE_ROOT + "Pebble_Square_%d.gltf" % ((index % 6) + 1),
			"PathFragment_%02d" % index,
			Vector3(_path_x_at(z_position) + side * (1.35 + float(index % 3) * 0.22), 0.018, z_position),
			float(index) * 0.67,
			0.68
		)


func _build_abyss_seal() -> void:
	_spawn_asset(
		VILLAGE_ROOT + "Wall_Arch.gltf",
		"AncientAbyssSeal",
		Vector3(0.0, 0.0, -16.2),
		0.0,
		1.45
	)
	_spawn_asset(
		VILLAGE_ROOT + "Wall_UnevenBrick_Straight.gltf",
		"SealWallLeft",
		Vector3(-3.1, 0.0, -16.25),
		0.0,
		1.25
	)
	_spawn_asset(
		VILLAGE_ROOT + "Wall_UnevenBrick_Straight.gltf",
		"SealWallRight",
		Vector3(3.1, 0.0, -16.25),
		0.0,
		1.25
	)
	_spawn_asset(VILLAGE_ROOT + "Prop_Vine4.gltf", "SealVineLeft", Vector3(-2.4, 0.6, -15.92), 0.0, 1.15)
	_spawn_asset(VILLAGE_ROOT + "Prop_Vine6.gltf", "SealVineRight", Vector3(2.1, 0.4, -15.92), 0.0, 1.2)
	_spawn_asset(PROPS_ROOT + "Torch_Metal.gltf", "SealTorchLeft", Vector3(-2.15, 1.45, -15.55), 0.0, 1.2)
	_spawn_asset(PROPS_ROOT + "Torch_Metal.gltf", "SealTorchRight", Vector3(2.15, 1.45, -15.55), 0.0, 1.2)
	_add_box_collider(generated_world, Vector3(2.0, 4.2, 0.8), Vector3(-2.65, 2.1, -16.2))
	_add_box_collider(generated_world, Vector3(2.0, 4.2, 0.8), Vector3(2.65, 2.1, -16.2))


func _build_ruin_clusters() -> void:
	var ruin_data: Array[Array] = [
		[Vector3(-10.5, 0.0, 7.0), -0.45],
		[Vector3(-11.5, 0.0, 4.8), 1.05],
		[Vector3(10.8, 0.0, 1.0), 0.55],
		[Vector3(11.7, 0.0, -1.2), -1.1],
		[Vector3(-12.0, 0.0, -8.8), 0.18],
		[Vector3(11.5, 0.0, -10.0), -0.28]
	]
	for index in range(ruin_data.size()):
		var position: Vector3 = ruin_data[index][0]
		var yaw: float = ruin_data[index][1]
		var wall_name := "Wall_UnevenBrick_Straight" if index % 2 == 0 else "Wall_BottomCover"
		# Scale range tuned so a ~3m-native ruin wall lands around 4-6m tall,
		# roughly 2-3x Takashi's height -- see docs/world_3d_block_11.md.
		var wall_scale := 1.4 + float(index % 3) * 0.25
		_spawn_asset(
			VILLAGE_ROOT + wall_name + ".gltf",
			"AbyssRuin_%02d" % index,
			position,
			yaw,
			wall_scale
		)
		_add_box_collider(
			generated_world,
			Vector3(2.1, 2.4, 0.38) * wall_scale,
			position + Vector3.UP * 1.2 * wall_scale,
			yaw
		)

	_spawn_asset(PROPS_ROOT + "Cage_Small.gltf", "AbandonedCage", Vector3(-9.4, 0.0, 5.6), 0.3, 1.0)
	_spawn_asset(PROPS_ROOT + "Chain_Coil.gltf", "OldChain", Vector3(-8.6, 0.0, 5.2), -0.4, 1.0)
	_spawn_asset(PROPS_ROOT + "Cauldron.gltf", "ColdCauldron", Vector3(9.5, 0.0, -0.5), 0.0, 1.0)
	_spawn_asset(PROPS_ROOT + "CandleStick_Triple.gltf", "ForgottenCandles", Vector3(10.2, 0.0, -1.2), 0.0, 1.0)


func _build_twisted_tree_line() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1115
	var tree_names: Array[String] = [
		"TwistedTree_1", "TwistedTree_2", "TwistedTree_3", "TwistedTree_4", "TwistedTree_5",
		"DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"
	]
	var placed := 0
	var attempts := 0
	while placed < 34 and attempts < 120:
		attempts += 1
		var position := Vector3(
			rng.randf_range(-21.5, 21.5),
			0.0,
			rng.randf_range(-15.5, 16.5)
		)
		if absf(position.x - _path_x_at(position.z)) < 3.4:
			continue
		if position.distance_to(SEAL_POSITION) < 5.0:
			continue
		var asset_name := tree_names[rng.randi_range(0, tree_names.size() - 1)]
		# Scale range tuned so TwistedTree (~16.7m native) and DeadTree (~9.5m
		# native) land at roughly 8-15x and 5-10x Takashi's ~2.0m sprite
		# height respectively -- see docs/world_3d_block_11.md scale audit.
		var tree_scale := rng.randf_range(1.05, 1.60)
		var tree := _spawn_asset(
			NATURE_ROOT + asset_name + ".gltf",
			"TwistedTree_%02d" % placed,
			position,
			rng.randf_range(-PI, PI),
			tree_scale
		)
		_register_tree_occluder(tree)
		_add_cylinder_collider(
			generated_world,
			0.48 * tree_scale,
			2.7 * tree_scale,
			position + Vector3.UP * 1.35 * tree_scale,
			false
		)
		placed += 1

	var background_pines: Array[Vector3] = [
		Vector3(-22.0, 0.0, -16.5), Vector3(-16.0, 0.0, -17.0),
		Vector3(-9.0, 0.0, -17.3), Vector3(8.5, 0.0, -17.2),
		Vector3(15.0, 0.0, -17.0), Vector3(21.5, 0.0, -16.5),
		Vector3(-21.5, 0.0, 17.0), Vector3(-14.0, 0.0, 17.2),
		Vector3(13.0, 0.0, 17.2), Vector3(21.0, 0.0, 17.0)
	]
	for index in range(background_pines.size()):
		var pine := _spawn_asset(
			NATURE_ROOT + "Pine_%d.gltf" % ((index % 5) + 1),
			"AbyssPine_%02d" % index,
			background_pines[index],
			float(index) * 0.71,
			1.3 + float(index % 3) * 0.15
		)
		_register_tree_occluder(pine)


func _scatter_undergrowth() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 15011
	var undergrowth: Array[String] = [
		"Fern_1", "Grass_Wispy_Short", "Grass_Wispy_Tall", "Mushroom_Common",
		"Mushroom_Laetiporus", "Plant_7", "Plant_7_Big", "Bush_Common"
	]
	for index in range(104):
		var position := Vector3(
			rng.randf_range(-22.5, 22.5),
			0.012,
			rng.randf_range(-16.4, 16.4)
		)
		if absf(position.x - _path_x_at(position.z)) < 2.15:
			continue
		var asset_name := undergrowth[rng.randi_range(0, undergrowth.size() - 1)]
		_spawn_asset(
			NATURE_ROOT + asset_name + ".gltf",
			"AbyssUndergrowth_%03d" % index,
			position,
			rng.randf_range(-PI, PI),
			rng.randf_range(0.65, 1.2)
		)


func _scatter_rocks_and_relics() -> void:
	var rock_positions: Array[Vector3] = [
		Vector3(-5.8, 0.0, 12.0), Vector3(5.2, 0.0, 10.0),
		Vector3(-8.5, 0.0, 1.5), Vector3(8.4, 0.0, 5.0),
		Vector3(-7.0, 0.0, -5.5), Vector3(7.5, 0.0, -7.5),
		Vector3(-14.5, 0.0, 12.0), Vector3(14.0, 0.0, 13.0),
		Vector3(-15.0, 0.0, -3.5), Vector3(15.5, 0.0, -5.0)
	]
	for index in range(rock_positions.size()):
		var position := rock_positions[index]
		# Wider range than before so the cluster reads as a mix of small
		# rocks and genuine boulders rather than uniformly medium-sized ones.
		var scale_value := 0.65 + float(index % 5) * 0.35
		_spawn_asset(
			NATURE_ROOT + "Rock_Medium_%d.gltf" % ((index % 3) + 1),
			"AbyssRock_%02d" % index,
			position,
			float(index) * 0.79,
			scale_value
		)
		_add_cylinder_collider(
			generated_world, 0.65 * scale_value, 0.9 * scale_value, position + Vector3.UP * 0.45 * scale_value
		)

	_spawn_asset(PROPS_ROOT + "Lantern_Wall.gltf", "BrokenLantern", Vector3(3.0, 0.0, 2.5), 1.2, 0.9)
	_spawn_asset(PROPS_ROOT + "Scroll_1.gltf", "WeatheredScroll", Vector3(-4.2, 0.03, -2.0), -0.2, 1.1)
	_spawn_asset(PROPS_ROOT + "Shield_Wooden.gltf", "LostShield", Vector3(5.8, 0.05, -11.0), 0.9, 1.0)


func _build_boundary_silhouettes() -> void:
	# Purely decorative background massing just outside the existing invisible
	# boundary walls (_build_collision_boundaries), so the world edge reads as
	# a looming rock line instead of empty fog. No new collision: the player
	# is already stopped at this Z by the existing boundary colliders.
	var silhouette_positions: Array[Vector3] = [
		Vector3(-18.0, 0.0, -19.5), Vector3(-9.0, 0.0, -20.0), Vector3(2.0, 0.0, -19.8),
		Vector3(12.0, 0.0, -20.0), Vector3(19.5, 0.0, -19.3),
		Vector3(-19.0, 0.0, 19.5), Vector3(-6.0, 0.0, 20.0), Vector3(7.0, 0.0, 19.8),
		Vector3(18.5, 0.0, 19.4),
	]
	for index in range(silhouette_positions.size()):
		_spawn_asset(
			NATURE_ROOT + "Rock_Medium_%d.gltf" % ((index % 3) + 1),
			"AbyssBoundarySilhouette_%02d" % index,
			silhouette_positions[index],
			float(index) * 1.13,
			7.0 + float(index % 4) * 1.8
		)


func _spawn_asset(
	asset_path: String,
	instance_name: String,
	local_position: Vector3,
	yaw: float = 0.0,
	uniform_scale: float = 1.0,
	parent: Node3D = null
) -> Node3D:
	var packed_scene: PackedScene = _asset_cache.get(asset_path) as PackedScene
	if packed_scene == null:
		packed_scene = load(asset_path) as PackedScene
		if packed_scene == null:
			push_warning("Unable to load Abyss Forest asset: %s" % asset_path)
			return null
		_asset_cache[asset_path] = packed_scene

	var instance := packed_scene.instantiate() as Node3D
	if instance == null:
		push_warning("Abyss Forest asset root is not Node3D: %s" % asset_path)
		return null

	var host := parent if parent != null else generated_world
	host.add_child(instance)
	instance.name = instance_name
	instance.position = local_position
	instance.rotation.y = yaw
	instance.scale = Vector3.ONE * uniform_scale
	generated_asset_count += 1
	return instance


func _add_box_collider(
	parent: Node3D,
	size: Vector3,
	local_position: Vector3,
	yaw: float = 0.0,
	obstructs_camera: bool = true
) -> void:
	var body := StaticBody3D.new()
	body.name = "AbyssCollision"
	body.position = local_position
	body.rotation.y = yaw
	body.collision_layer = 1 | (CAMERA_OBSTRUCTION_LAYER_BIT if obstructs_camera else 0)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _add_cylinder_collider(
	parent: Node3D,
	radius: float,
	height: float,
	local_position: Vector3,
	obstructs_camera: bool = true
) -> void:
	var body := StaticBody3D.new()
	body.name = "AbyssNaturalCollision"
	body.position = local_position
	body.collision_layer = 1 | (CAMERA_OBSTRUCTION_LAYER_BIT if obstructs_camera else 0)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)


func _register_tree_occluder(tree: Node3D) -> void:
	if tree == null:
		return
	var meshes: Array[GeometryInstance3D] = []
	for child in tree.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		if geometry != null:
			meshes.append(geometry)
	_tree_occluder_meshes[tree] = meshes


func _update_camera_occluders(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(player):
		return

	var camera_flat := Vector2(camera.global_position.x, camera.global_position.z)
	var player_flat := Vector2(player.global_position.x, player.global_position.z)
	var camera_to_player := player_flat - camera_flat
	var segment_length_squared := camera_to_player.length_squared()
	if segment_length_squared < 0.001:
		return

	for tree_variant in _tree_occluder_meshes.keys():
		var tree := tree_variant as Node3D
		if not is_instance_valid(tree):
			continue
		var tree_flat := Vector2(tree.global_position.x, tree.global_position.z)
		var segment_t := clampf(
			(tree_flat - camera_flat).dot(camera_to_player) / segment_length_squared,
			0.0,
			1.0
		)
		var closest_point := camera_flat + camera_to_player * segment_t
		var blocks_view := (
			segment_t > 0.06
			and segment_t < 0.96
			and tree_flat.distance_to(closest_point) < 3.1
		)
		var target_transparency := 0.82 if blocks_view else 0.0
		var meshes: Array = _tree_occluder_meshes[tree]
		for mesh_variant in meshes:
			var mesh := mesh_variant as GeometryInstance3D
			if mesh != null:
				mesh.transparency = move_toward(
					mesh.transparency,
					target_transparency,
					delta * 3.8
				)


func _build_collision_boundaries() -> void:
	_add_box_collider(generated_world, Vector3(49.0, 3.0, 0.5), Vector3(0.0, 1.5, -17.7))
	_add_box_collider(generated_world, Vector3(49.0, 3.0, 0.5), Vector3(0.0, 1.5, 17.7))
	_add_box_collider(generated_world, Vector3(0.5, 3.0, 35.0), Vector3(-24.2, 1.5, 0.0))
	_add_box_collider(generated_world, Vector3(0.5, 3.0, 35.0), Vector3(24.2, 1.5, 0.0))


func _path_x_at(z_position: float) -> float:
	return sin(z_position * 0.21) * 1.85


func _on_seal_body_entered(body: Node3D) -> void:
	if body != player:
		return
	_near_seal = true
	_update_seal_objective(true)


func _on_seal_body_exited(body: Node3D) -> void:
	if body != player:
		return
	_near_seal = false
	_update_seal_objective(true)


func _update_seal_objective(force: bool = false) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud_explor):
		return
	if _near_seal:
		if force:
			hud_explor.set_quest("Buka jalan keluar Abyss Forest", "Tekan E pada segel kuno")
		return

	var flat_player := Vector2(player.global_position.x, player.global_position.z)
	var flat_seal := Vector2(SEAL_POSITION.x, SEAL_POSITION.z)
	var distance := roundi(flat_player.distance_to(flat_seal))
	if force or distance != _last_seal_distance:
		_last_seal_distance = distance
		hud_explor.set_quest("Temukan jalan keluar Abyss Forest", "%d m menuju segel" % distance)


func _on_hud_slot_pressed(slot_name: StringName) -> void:
	print("Abyss Forest HUD slot requested: %s" % slot_name)


func _setup_abyss_bgm() -> void:
	if not abyss_bgm.finished.is_connected(_restart_abyss_bgm):
		abyss_bgm.finished.connect(_restart_abyss_bgm)
	if not abyss_bgm.playing:
		abyss_bgm.play()


func _restart_abyss_bgm() -> void:
	abyss_bgm.play()
