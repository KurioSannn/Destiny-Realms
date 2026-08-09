extends Node3D
class_name BattlePresentation3D

## Block 15: 3D presentation adapter for the existing 2D BattleManager.
##
## Architecture contract:
##   BattleManager (2D logic, unchanged)
##   → BattlePresentation3D (adapter, presentation only)
##   → BattleCamera3D + BattleActor3D[] + BattleEnvironment3D (3D presentation)
##
## This node:
##   - Reads EncounterContext to select the correct arena
##   - Instantiates the arena environment scene
##   - Creates BattleActor3D nodes for party and enemy combatants
##   - Drives BattleCamera3D state changes from BattleManager signals/state
##   - Spawns damage/buff numbers in 3D space
##   - Does NOT touch battle logic, damage values, turn order, or energy

signal arena_ready

const NATURE_ROOT := "res://Asset 3d/Stylized Nature MegaKit[Standard]/glTF/"
const VILLAGE_ROOT := "res://Asset 3d/Medieval Village MegaKit[Standard]/Medieval Village MegaKit[Standard]/glTF/"
const PROPS_ROOT := "res://Asset 3d/Fantasy Props MegaKit[Standard]/Exports/glTF/"

## Formation layout (Block 15.1 rework): HSR/Persona-style staging -- party
## reads as a diagonal column in the near-left, enemies as a diagonal column
## in the far-right, so the camera sees two distinct groups facing off with
## real depth between them.
##
## The old values put EnemySlot0 (2.5,0,0) and EnemySlot1 (3.2,0,-0.6) only
## ~0.9m apart, which -- with billboards over a metre wide -- rendered as two
## enemies fused into one blob. Slots are now separated by >1.6m in the
## camera's screen axis so every actor is individually readable and clickable.
const PARTY_SLOTS: Array[Vector3] = [
	Vector3(-2.3, 0.0, 1.1),   # PartySlot0 — active character, nearest camera
	Vector3(-3.5, 0.0, 0.0),   # PartySlot1
	Vector3(-4.5, 0.0, -1.1),  # PartySlot2
]
const ENEMY_SLOTS: Array[Vector3] = [
	Vector3(2.3, 0.0, 0.5),    # EnemySlot0 — primary, nearest camera
	Vector3(4.8, 0.0, -2.0),   # EnemySlot1
	Vector3(6.4, 0.0, -4.4),   # EnemySlot2
]

## Feet-to-head height for the party sprite billboards, in metres.
const PARTY_WORLD_HEIGHT: float = 1.75

const ARENA_CENTER := Vector3(0.0, 0.0, 0.0)

## References (set in _ready or by battle_scene owner)
var battle_manager: BattleManager = null
var battle_camera_3d: BattleCamera3DScript = null

## Arena state
var _arena_environment: Node3D = null
var _arena_profile: BattleEnvironmentProfileScript = null

## Actor collections
var _party_actors: Array[BattleActor3DScript] = []
var _enemy_actors: Array[BattleActor3DScript] = []
var _enemy_combatants_by_actor: Array[Combatant] = []

## Damage label pool
var _damage_labels: Array[Label3D] = []

## Track last-known enemy HP for hit detection
var _last_enemy_hps: Array[int] = []
var _last_player_hp: int = -1

## Advantage entry displayed once
var _advantage_shown: bool = false

## Transition overlay for arena entry
var _transition_overlay: ColorRect = null

var _asset_cache: Dictionary = {}

const BattleActor3DScript := preload("res://scripts/battle/battle_actor_3d.gd")
const BattleCamera3DScript := preload("res://scripts/battle/battle_camera_3d.gd")
const BattleEnvironmentProfileScript := preload("res://scripts/battle/battle_environment_profile.gd")

func _ready() -> void:
	_build_camera()
	_load_arena_from_context()
	await get_tree().process_frame
	_spawn_party_actors()
	_spawn_enemy_actors()
	_finalize_camera_refs()
	_setup_battle_manager_hooks()
	_run_arena_entry_transition()
	arena_ready.emit()


func _process(_delta: float) -> void:
	_sync_actor_hp_display()
	_sync_target_markers()


# --- Setup ------------------------------------------------------------------

func _build_camera() -> void:
	battle_camera_3d = BattleCamera3DScript.new()
	battle_camera_3d.name = "BattleCamera3D"
	add_child(battle_camera_3d)


func _load_arena_from_context() -> void:
	var context: EncounterContext = null
	if EncounterCoordinator.has_active_encounter():
		context = EncounterCoordinator.get_active_context()

	if context != null and not context.source_area_id.is_empty():
		# BattleEnvironmentRegistry is an autoload in the scene tree
		var registry = get_tree().root.get_node_or_null("BattleEnvironmentRegistry")
		if registry != null:
			_arena_profile = registry.resolve_from_context(context)

	if _arena_profile != null and not _arena_profile.environment_scene.is_empty():
		var packed := load(_arena_profile.environment_scene) as PackedScene
		if packed != null:
			_arena_environment = packed.instantiate() as Node3D
			if _arena_environment != null:
				add_child(_arena_environment)
				_arena_environment.position = ARENA_CENTER
	else:
		# Fallback: procedural generic arena
		_build_generic_arena()


func _build_generic_arena() -> void:
	var env_node := Node3D.new()
	env_node.name = "GenericBattleEnvironment"
	add_child(env_node)
	_arena_environment = env_node

	# Flat ground
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(12.0, 12.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.12, 0.10, 1.0)
	mat.roughness = 0.92
	mesh.material = mat
	ground.mesh = mesh
	env_node.add_child(ground)

	# Basic lighting
	var light := DirectionalLight3D.new()
	light.light_color = Color(0.5, 0.65, 0.80, 1.0)
	light.light_energy = 1.2
	light.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	env_node.add_child(light)


func _spawn_party_actors() -> void:
	# For now, spawn only Takashi (slot 0). Future party members extend this.
	var actor := _create_party_actor(0)
	if actor != null:
		_party_actors.append(actor)
		_setup_takashi_actor(actor)


func _create_party_actor(slot_index: int) -> BattleActor3DScript:
	if slot_index >= PARTY_SLOTS.size():
		return null
	var actor = BattleActor3DScript.new()
	actor.name = "PartySlot%d" % slot_index
	actor.is_player_side = true
	actor.position = PARTY_SLOTS[slot_index]
	_build_actor_sprite(actor)
	add_child(actor)
	return actor


func _setup_takashi_actor(actor: BattleActor3DScript) -> void:
	var idle_frames: Array[Texture2D] = []
	var attack_frames: Array[Texture2D] = []
	var skill_frames: Array[Texture2D] = []
	for path in BattleManager.TAKASHI_IDLE_FRAME_PATHS:
		var tex := load(path) as Texture2D
		if tex != null:
			idle_frames.append(tex)
	for path in BattleManager.TAKASHI_BASIC_FRAME_PATHS:
		var tex := load(path) as Texture2D
		if tex != null:
			attack_frames.append(tex)
	for path in BattleManager.TAKASHI_SKILL_FRAME_PATHS:
		var tex := load(path) as Texture2D
		if tex != null:
			skill_frames.append(tex)
	actor.setup_frames(
		idle_frames, attack_frames, skill_frames,
		BattleManager.TAKASHI_IDLE_FRAME_RATE,
		BattleManager.TAKASHI_BASIC_FRAME_RATE,
		BattleManager.TAKASHI_SKILL_FRAME_RATE,
		PARTY_WORLD_HEIGHT
	)


func _spawn_enemy_actors() -> void:
	if battle_manager == null:
		return
	_clear_enemy_actors()
	# Collect all enemy Combatants from the battle scene parent
	var enemies: Array = []
	var parent := battle_manager.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		var combatant := child as Combatant
		if combatant != null and combatant.name != "Player":
			enemies.append(combatant)

	var slot_idx := 0
	for enemy_combatant in enemies:
		if slot_idx >= ENEMY_SLOTS.size():
			break
		var actor := _create_enemy_actor(slot_idx, enemy_combatant)
		if actor != null:
			_enemy_actors.append(actor)
			_enemy_combatants_by_actor.append(enemy_combatant)
			_last_enemy_hps.append(enemy_combatant.current_hp)
		slot_idx += 1


func refresh_enemy_actor_roster() -> void:
	_spawn_enemy_actors()
	_finalize_camera_refs()


func _clear_enemy_actors() -> void:
	for actor in _enemy_actors:
		if actor != null and is_instance_valid(actor):
			actor.queue_free()
	_enemy_actors.clear()
	_enemy_combatants_by_actor.clear()
	_last_enemy_hps.clear()


func _create_enemy_actor(slot_index: int, combatant: Combatant) -> BattleActor3DScript:
	if slot_index >= ENEMY_SLOTS.size():
		return null
	var actor = BattleActor3DScript.new()
	actor.name = "EnemySlot%d" % slot_index
	actor.is_player_side = false
	actor.actor_id = StringName(combatant.name)
	actor.position = ENEMY_SLOTS[slot_index]
	_build_actor_sprite(actor)
	add_child(actor)

	# Block 15.1 fix: the old code took combatant.action_sprite.texture
	# whenever it was non-null -- but that node ships with the Bandit Captain
	# texture baked in and merely HIDDEN for non-bandit encounters, so every
	# Lesser Abyss showed up wearing the bandit's face. Visuals now come from
	# the game-wide ActorVisualRegistry, keyed by the encounter's real
	# battle_enemy_id, so battle shows the same creature exploration does.
	var visual_id := _enemy_visual_id_for(slot_index)
	actor.actor_id = visual_id
	var profile: ActorVisualProfile = ActorVisualRegistry.resolve(visual_id)
	if profile != null and profile.apply_to(actor):
		actor.face_toward(_party_anchor())
		return actor

	# Fallback 1: an explicitly VISIBLE action sprite (the legacy bandit path).
	if combatant.action_sprite is Sprite2D:
		var sprite2d := combatant.action_sprite as Sprite2D
		if sprite2d.texture != null and sprite2d.visible:
			actor.setup_static_texture(sprite2d.texture, 1.85)
			return actor

	# Fallback 2: procedural placeholder, so an unregistered species is still
	# visible and targetable rather than silently invisible.
	push_warning(
		"BattlePresentation3D: no ActorVisualProfile for '%s'; using placeholder. Add res://resources/actor_visuals/%s.tres"
		% [visual_id, visual_id]
	)
	actor.setup_static_texture(_create_enemy_placeholder_texture(slot_index), 1.7)
	return actor


## Resolves which visual an enemy slot should use. Prefers the live
## EncounterContext roster (Block 14), then the legacy bandit flag, so both
## the new encounter path and the original story battle stay correct.
func _enemy_visual_id_for(slot_index: int) -> StringName:
	if EncounterCoordinator.has_active_encounter():
		var context := EncounterCoordinator.get_active_context()
		if context != null and slot_index < context.battle_enemy_ids.size():
			return context.battle_enemy_ids[slot_index]
	if battle_manager != null and battle_manager.is_bandit_encounter:
		return &"clover_bandit"
	return &"lesser_abyss"


func _party_anchor() -> Vector3:
	return PARTY_SLOTS[0] if not PARTY_SLOTS.is_empty() else Vector3.ZERO


func _build_actor_sprite(actor: BattleActor3DScript) -> void:
	# Sprite3D (billboard). pixel_size is NOT set here any more -- BattleActor3D
	# derives it from the texture so the actor ends up its requested world
	# height. The old hardcoded 0.0048 made a 1024px sprite ~4.9m tall.
	var sprite := Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.render_priority = 2
	actor.add_child(sprite)

	# Container for a real 3D model, when the actor's visual profile has one.
	var model_root := Node3D.new()
	model_root.name = "ModelRoot"
	actor.add_child(model_root)

	# Shadow
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.5
	shadow_mesh.bottom_radius = 0.5
	shadow_mesh.height = 0.02
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mesh.material = shadow_mat
	shadow.mesh = shadow_mesh
	actor.add_child(shadow)

	# Target marker ring
	var target := Node3D.new()
	target.name = "TargetMarker"
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.44
	ring_mesh.outer_radius = 0.52
	ring_mesh.rings = 24
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.3, 0.85, 1.0, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.1, 0.6, 1.0, 1.0)
	ring_mat.emission_energy_multiplier = 1.5
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mesh.material = ring_mat
	ring.mesh = ring_mesh
	target.add_child(ring)
	target.visible = false
	actor.add_child(target)

	# HP Label3D
	var hp_label := Label3D.new()
	hp_label.name = "HpLabel3D"
	hp_label.font_size = 28
	hp_label.modulate = Color(0.35, 0.85, 0.45, 1.0)
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_label.no_depth_test = true
	hp_label.pixel_size = 0.0032
	hp_label.text = ""
	hp_label.outline_size = 4
	hp_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	actor.add_child(hp_label)


func _create_enemy_placeholder_texture(slot_index: int) -> Texture2D:
	# Returns a simple image texture as a colored gradient placeholder.
	# In production, enemy-specific sprites would be loaded here.
	var image := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [
		Color(0.28, 0.45, 0.62, 1.0),   # navy blue
		Color(0.45, 0.28, 0.60, 1.0),   # purple
		Color(0.28, 0.58, 0.42, 1.0),   # teal
	]
	var base_color: Color = colors[slot_index % colors.size()]
	for y in range(96):
		for x in range(64):
			var dist_from_center := absf(float(x) - 32.0) / 32.0
			var alpha := 1.0 - dist_from_center * 0.3
			var vy := float(y) / 96.0
			var shade: Color = base_color.lerp(Color(0.1, 0.1, 0.15, 1.0), vy * 0.3)
			shade.a = alpha
			image.set_pixel(x, y, shade)
	return ImageTexture.create_from_image(image)


func _finalize_camera_refs() -> void:
	if battle_camera_3d == null:
		return
	var party_c := PARTY_SLOTS[0] if not PARTY_SLOTS.is_empty() else Vector3.ZERO
	var enemy_c := ENEMY_SLOTS[0] if not ENEMY_SLOTS.is_empty() else Vector3(2.5, 0.0, 0.0)
	battle_camera_3d.set_formation_refs(party_c, enemy_c, ARENA_CENTER)


func _setup_battle_manager_hooks() -> void:
	if battle_manager != null:
		var bg_node := battle_manager.get_node_or_null("../Background") as Node2D
		if bg_node != null:
			bg_node.visible = false
			bg_node.modulate.a = 0.0
		elif battle_manager.forest_background != null:
			battle_manager.forest_background.visible = false

		var ground_effects := battle_manager.get_node_or_null("../StageGroundEffects") as Node2D
		if ground_effects != null:
			ground_effects.visible = false
			ground_effects.modulate.a = 0.0

		if battle_manager.battle_camera != null:
			battle_manager.battle_camera.enabled = false

		if battle_manager.get("player") != null:
			battle_manager.player.visible = false
			battle_manager.player.modulate.a = 0.0

		if battle_manager.get("enemy") != null:
			battle_manager.enemy.visible = false
			battle_manager.enemy.modulate.a = 0.0

		# Also hide any additional combatants dynamically spawned by the encounter coordinator
		var parent := battle_manager.get_parent()
		if parent != null:
			for child in parent.get_children():
				if child is Combatant:
					child.visible = false
					child.modulate.a = 0.0


# --- Sync (polled per frame) -------------------------------------------------

func _sync_actor_hp_display() -> void:
	if battle_manager == null:
		return
	# Party HP
	if not _party_actors.is_empty():
		var actor := _party_actors[0]
		var player_hp := battle_manager.player.current_hp
		if player_hp != _last_player_hp:
			_last_player_hp = player_hp
			actor.update_hp_display(player_hp, battle_manager.player.max_hp)
			if player_hp < _last_player_hp if _last_player_hp > 0 else false:
				actor.play_hit()

	# Enemy HP
	var parent := battle_manager.get_parent() if battle_manager != null else null
	if parent == null:
		return
	var enemy_combatants := _mapped_enemy_combatants()

	for i in range(mini(_enemy_actors.size(), enemy_combatants.size())):
		var actor := _enemy_actors[i]
		var combatant: Combatant = enemy_combatants[i]
		actor.update_hp_display(combatant.current_hp, combatant.max_hp)
		var old_hp := _last_enemy_hps[i] if i < _last_enemy_hps.size() else combatant.current_hp
		if combatant.current_hp < old_hp:
			actor.play_hit()
		if combatant.current_hp <= 0 and not actor.is_defeated():
			actor.play_defeated()
		if i < _last_enemy_hps.size():
			_last_enemy_hps[i] = combatant.current_hp
		else:
			_last_enemy_hps.append(combatant.current_hp)


func _sync_target_markers() -> void:
	if battle_manager == null:
		return
	var selected_target := battle_manager.get_current_target_marker_target()
	var enemy_combatants := _mapped_enemy_combatants()
	for i in range(mini(_enemy_actors.size(), enemy_combatants.size())):
		var actor := _enemy_actors[i]
		var combatant: Combatant = enemy_combatants[i]
		actor.set_target_selected(combatant == selected_target and not actor.is_defeated())


func pick_enemy_combatant_at_screen_position(
	screen_position: Vector2,
	candidates: Array[Node] = [],
	max_screen_distance: float = 104.0
) -> Combatant:
	var camera := _active_camera()
	if camera == null:
		return null
	var enemy_combatants := _mapped_enemy_combatants()
	var best_target: Combatant = null
	var best_distance := INF

	for i in range(mini(_enemy_actors.size(), enemy_combatants.size())):
		var combatant: Combatant = enemy_combatants[i]
		if combatant == null or combatant.is_defeated():
			continue
		if not candidates.is_empty() and not candidates.has(combatant):
			continue
		var actor := _enemy_actors[i]
		if actor == null or actor.is_defeated():
			continue

		var foot_world := actor.global_position + Vector3(0.0, 0.12, 0.0)
		var head_world := actor.global_position + Vector3(0.0, maxf(actor.world_height, 0.8), 0.0)
		if camera.is_position_behind(foot_world) and camera.is_position_behind(head_world):
			continue

		var foot_screen := camera.unproject_position(foot_world)
		var head_screen := camera.unproject_position(head_world)
		var distance := _distance_to_screen_segment(screen_position, foot_screen, head_screen)
		var body_radius := clampf(head_screen.distance_to(foot_screen) * 0.28, 42.0, max_screen_distance)
		if distance <= body_radius and distance < best_distance:
			best_distance = distance
			best_target = combatant

	return best_target


func get_enemy_screen_position(
	combatant: Combatant,
	vertical_ratio: float = 0.52
) -> Vector2:
	var camera := _active_camera()
	if camera == null or combatant == null:
		return Vector2(-INF, -INF)
	var enemy_combatants := _mapped_enemy_combatants()
	var index := enemy_combatants.find(combatant)
	if index < 0 or index >= _enemy_actors.size():
		return Vector2(-INF, -INF)
	var actor := _enemy_actors[index]
	if actor == null:
		return Vector2(-INF, -INF)
	var world_position := actor.global_position + Vector3(
		0.0,
		maxf(actor.world_height * vertical_ratio, 0.3),
		0.0
	)
	if camera.is_position_behind(world_position):
		return Vector2(-INF, -INF)
	return camera.unproject_position(world_position)


func _mapped_enemy_combatants() -> Array[Combatant]:
	var mapped: Array[Combatant] = []
	for combatant in _enemy_combatants_by_actor:
		if combatant == null or not is_instance_valid(combatant):
			return _enemy_combatants()
		mapped.append(combatant)
	if mapped.is_empty():
		return _enemy_combatants()
	return mapped


func _enemy_combatants() -> Array[Combatant]:
	var enemies: Array[Combatant] = []
	if battle_manager == null:
		return enemies
	var parent := battle_manager.get_parent()
	if parent == null:
		return enemies
	for child in parent.get_children():
		var combatant := child as Combatant
		if combatant != null and combatant.name != "Player":
			enemies.append(combatant)
	return enemies


func _active_camera() -> Camera3D:
	if battle_camera_3d == null:
		return null
	return battle_camera_3d.get_camera()


func _distance_to_screen_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


# --- Camera API (called by battle scene owner) ------------------------------

func camera_transition(preset: int) -> void:
	if battle_camera_3d != null:
		battle_camera_3d.transition_to(preset)


func camera_return_to_idle() -> void:
	if battle_camera_3d != null:
		battle_camera_3d.return_to_idle()


func camera_snap(preset: int) -> void:
	if battle_camera_3d != null:
		battle_camera_3d.snap_to(preset)


# --- Actor API (called by battle scene owner) --------------------------------

func play_party_attack(slot: int = 0) -> void:
	if slot < _party_actors.size():
		_party_actors[slot].play_attack()
		camera_transition(BattleCamera3DScript.Preset.PLAYER_BASIC)
		await get_tree().create_timer(0.55).timeout
		camera_return_to_idle()


func play_party_skill(slot: int = 0) -> void:
	if slot < _party_actors.size():
		_party_actors[slot].play_skill()
		camera_transition(BattleCamera3DScript.Preset.PLAYER_SKILL)
		await get_tree().create_timer(0.65).timeout
		camera_return_to_idle()


func play_enemy_attack(enemy_slot: int = 0) -> void:
	camera_transition(BattleCamera3DScript.Preset.ENEMY_ATTACK)
	await get_tree().create_timer(0.5).timeout
	camera_return_to_idle()


func play_victory() -> void:
	camera_transition(BattleCamera3DScript.Preset.VICTORY)


# --- Damage number feedback -------------------------------------------------

func show_damage_number(
	world_slot: Vector3,
	amount: int,
	is_heal: bool = false,
	is_player_side: bool = false
) -> void:
	var label := Label3D.new()
	label.text = ("+" if is_heal else "-") + str(amount)
	label.font_size = 32
	label.modulate = Color(0.35, 0.88, 0.45, 1.0) if is_heal else (
		Color(0.95, 0.88, 0.28, 1.0) if is_player_side else Color(0.9, 0.3, 0.3, 1.0)
	)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.004
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	add_child(label)
	label.position = world_slot + Vector3(0.0, 0.5, 0.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


# --- Opening advantage presentation -----------------------------------------

func show_opening_advantage(advantage: EncounterContext.OpeningAdvantage) -> void:
	if _advantage_shown:
		return
	_advantage_shown = true
	match advantage:
		EncounterContext.OpeningAdvantage.PLAYER_ADVANTAGE:
			_show_timed_label("PLAYER ADVANTAGE", Color(0.35, 0.88, 0.45, 1.0))
		EncounterContext.OpeningAdvantage.ENEMY_ADVANTAGE:
			_show_timed_label("ENEMY ADVANTAGE", Color(0.9, 0.32, 0.32, 1.0))
		_:
			pass  # NEUTRAL — no indicator


func _show_timed_label(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.005
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	add_child(label)
	label.position = ARENA_CENTER + Vector3(0.0, 2.5, 0.0)
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(label.queue_free)


# --- Transition effects ------------------------------------------------------

func _run_arena_entry_transition() -> void:
	# Brief black fade-in when the arena loads
	if _transition_overlay == null:
		return
	var tween := _transition_overlay.create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(_transition_overlay.queue_free)
	_transition_overlay = null


func set_transition_overlay(overlay: ColorRect) -> void:
	_transition_overlay = overlay


func get_enemy_actor(index: int) -> BattleActor3DScript:
	if index < 0 or index >= _enemy_actors.size():
		return null
	return _enemy_actors[index]


func get_party_actor(index: int) -> BattleActor3DScript:
	if index < 0 or index >= _party_actors.size():
		return null
	return _party_actors[index]


func get_enemy_world_position(index: int) -> Vector3:
	if index < 0 or index >= ENEMY_SLOTS.size():
		return ARENA_CENTER
	return ENEMY_SLOTS[index]


func get_party_world_position(index: int) -> Vector3:
	if index < 0 or index >= PARTY_SLOTS.size():
		return ARENA_CENTER
	return PARTY_SLOTS[index]
