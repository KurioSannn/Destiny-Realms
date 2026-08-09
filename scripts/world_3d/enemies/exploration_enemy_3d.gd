extends CharacterBody3D
class_name ExplorationEnemy3D

## Generic, species-agnostic world enemy controller. Identity and tuning come
## entirely from an assigned ExplorationEnemyProfile -- this script must never
## reference a specific species by name (Lesser Abyss, Bandit, ...). A new
## species is a new .tres, never a new controller script.

enum State { IDLE, PATROL, ALERT, CHASE, ENGAGE, RETURNING, DISABLED }

signal state_changed(old_state: State, new_state: State)
signal enemy_alert_started(enemy: ExplorationEnemy3D)
signal enemy_alert_cancelled(enemy: ExplorationEnemy3D)
signal enemy_field_hit(enemy: ExplorationEnemy3D, attacker: Node3D)

const EXPLORATION_ATTACKABLE_GROUP := &"exploration_attackable"

@export var profile: ExplorationEnemyProfile
## Stable ID for this specific placed instance (not the species). Used to
## build a stable encounter_id and as EncounterContext.initiating_enemy_id.
@export var world_actor_id: StringName = &""
## What battle-side enemies this specific placement represents. If empty,
## falls back to a single-enemy group built from profile.battle_enemy_id.
@export var encounter_group: EncounterGroupProfile
@export var patrol_route_path: NodePath
@export var gravity: float = 28.0
@export var idle_wait_seconds: float = 1.5
@export var debug_draw: bool = false

var _state: State = State.IDLE
var _patrol_route: PatrolRoute3D
var _patrol_index: int = 0
var _patrol_direction: int = 1
var _patrol_wait_remaining: float = 0.0
var _idle_wait_remaining: float = 0.0
var _alert_timer: float = 0.0
var _home_position: Vector3
var _listened_character: Node3D
var _encounter_requested: bool = false
var _encounter_counter: int = 0
var _last_move_direction: Vector3 = Vector3.FORWARD
var _pending_opening_advantage: EncounterContext.OpeningAdvantage = EncounterContext.OpeningAdvantage.NEUTRAL
var _target_indicator: Node3D = null


func _ready() -> void:
	_home_position = global_position
	add_to_group(&"exploration_enemy")
	if profile != null and profile.exploration_attackable:
		add_to_group(EXPLORATION_ATTACKABLE_GROUP)
	_patrol_route = get_node_or_null(patrol_route_path) as PatrolRoute3D
	_rewire_active_character_listener(GameFlowState.get_active_character())
	GameFlowState.active_character_changed.connect(_rewire_active_character_listener)
	EncounterCoordinator.encounter_resolved.connect(_on_encounter_resolved)
	_idle_wait_remaining = idle_wait_seconds
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if _state == State.DISABLED or not GameFlowState.is_exploration_active():
		return

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.ALERT:
			_process_alert(delta)
		State.CHASE:
			_process_chase(delta)
		State.ENGAGE:
			_process_engage(delta)
		State.RETURNING:
			_process_returning(delta)

	_apply_gravity(delta)
	move_and_slide()


func _process(delta: float) -> void:
	if _target_indicator != null and _target_indicator.visible:
		_target_indicator.rotation.y += delta * 1.8


# --- Public API -------------------------------------------------------

func get_state() -> State:
	return _state


func is_disabled() -> bool:
	return _state == State.DISABLED


func set_disabled(disabled: bool) -> void:
	if disabled:
		_set_state(State.DISABLED)
	elif _state == State.DISABLED:
		_set_state(State.IDLE)


func set_target_indicator_visible(visible_state: bool) -> void:
	if visible_state and _target_indicator == null:
		_create_target_indicator()
	if _target_indicator != null:
		_target_indicator.visible = visible_state and _state != State.DISABLED and visible


func get_home_position() -> Vector3:
	return _home_position


## Seam for Block 14: called once an encounter this enemy started has been
## resolved. VICTORY permanently disables (defeated); ESCAPE/DEFEAT resets
## the enemy back into the world without persistence, matching "do not
## implement complete battle-result handling yet."
func apply_encounter_result(result: StringName) -> void:
	_encounter_requested = false
	match result:
		&"victory":
			set_target_indicator_visible(false)
			_set_state(State.DISABLED)
			visible = false
			set_deferred("collision_layer", 0)
			set_deferred("collision_mask", 0)
		&"escape", &"defeat":
			_set_state(State.RETURNING)
		_:
			_set_state(State.RETURNING)


## Exploration Skill seam (Block 12/future skills call this on a hit enemy).
## No status system yet -- effect is a StringName tag plus an optional
## strength Dictionary a future system can interpret.
func apply_field_effect(effect: StringName, _payload: Dictionary = {}) -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual != null and is_instance_valid(visual) and is_inside_tree():
		var tween := create_tween()
		var base_scale := visual.scale
		tween.tween_property(visual, "scale", base_scale * 1.25, 0.1)
		tween.tween_property(visual, "scale", base_scale, 0.15)
	match effect:
		&"stun":
			if _state in [State.CHASE, State.ALERT]:
				_alert_timer = maxf(_alert_timer, 0.0)
		&"reveal":
			if _state == State.IDLE or _state == State.PATROL:
				_enter_alert()
		_:
			pass


func get_debug_info() -> Dictionary:
	return {
		"state": State.keys()[_state],
		"detection_range": profile.detection_range if profile != null else 0.0,
		"lose_target_range": profile.lose_target_range if profile != null else 0.0,
		"home_position": _home_position,
		"leash_distance": profile.leash_distance if profile != null else 0.0,
		"encounter_group_id": encounter_group.encounter_group_id if encounter_group != null else &"",
	}


func receive_exploration_attack(attacker: Node3D) -> void:
	if _state == State.DISABLED:
		return
	var was_unaware := _state in [State.IDLE, State.PATROL, State.ALERT]
	enemy_field_hit.emit(self, attacker)
	var advantage := EncounterContext.OpeningAdvantage.NEUTRAL
	if was_unaware and profile != null and profile.player_attack_opening_advantage_allowed:
		advantage = EncounterContext.OpeningAdvantage.PLAYER_ADVANTAGE
	_begin_engage(advantage)


# --- State processing ---------------------------------------------------

func _process_idle(delta: float) -> void:
	if _detect_active_character(false):
		_enter_alert()
		return
	_idle_wait_remaining -= delta
	if _idle_wait_remaining <= 0.0 and _patrol_route != null and _patrol_route.get_waypoint_count() > 0:
		_set_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	if _detect_active_character(false):
		_enter_alert()
		return
	if _patrol_route == null or _patrol_route.get_waypoint_count() == 0:
		_set_state(State.IDLE)
		return

	if _patrol_wait_remaining > 0.0:
		_patrol_wait_remaining -= delta
		return

	var target := _patrol_route.get_waypoint_position(_patrol_index)
	if _move_toward(target, profile.patrol_speed if profile != null else 2.0, delta):
		_patrol_wait_remaining = _patrol_route.pause_seconds_at_point
		var advance := _patrol_route.advance(_patrol_index, _patrol_direction)
		_patrol_index = advance["index"]
		_patrol_direction = advance["direction"]


func _process_alert(delta: float) -> void:
	if not _detect_active_character(true):
		enemy_alert_cancelled.emit(self)
		_set_state(State.PATROL if _patrol_route != null else State.IDLE)
		return
	_alert_timer -= delta
	if _alert_timer <= 0.0:
		_set_state(State.CHASE)


func _process_chase(delta: float) -> void:
	var character := GameFlowState.get_active_character()
	if not _detect_active_character(true):
		_set_state(State.RETURNING)
		return

	var distance_from_home := Vector2(
		global_position.x - _home_position.x, global_position.z - _home_position.z
	).length()
	if profile != null and distance_from_home > profile.leash_distance:
		_set_state(State.RETURNING)
		return

	var engage_range := profile.engage_range if profile != null else 1.6
	var chase_speed := profile.chase_speed if profile != null else 4.2
	if global_position.distance_to(character.global_position) <= engage_range:
		_begin_engage(EncounterContext.OpeningAdvantage.NEUTRAL)
		return
	_move_toward(character.global_position, chase_speed, delta)


func _process_engage(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_request_encounter()


func _process_returning(delta: float) -> void:
	# No detection while returning: prevents immediate re-alert ping-pong
	# right at the edge of the detection radius.
	var tolerance := profile.return_tolerance if profile != null else 0.75
	if _move_toward(_home_position, profile.patrol_speed if profile != null else 2.0, delta):
		_patrol_index = 0
		_patrol_direction = 1
		_set_state(State.PATROL if _patrol_route != null and _patrol_route.get_waypoint_count() > 0 else State.IDLE)
	elif global_position.distance_to(_home_position) <= tolerance:
		_set_state(State.PATROL if _patrol_route != null and _patrol_route.get_waypoint_count() > 0 else State.IDLE)


# --- Helpers -------------------------------------------------------------

func _enter_alert() -> void:
	_alert_timer = profile.alert_delay if profile != null else 0.4
	_set_state(State.ALERT)
	enemy_alert_started.emit(self)


func _begin_engage(opening_advantage: EncounterContext.OpeningAdvantage) -> void:
	if _state == State.ENGAGE or _state == State.DISABLED:
		return
	_pending_opening_advantage = opening_advantage
	_set_state(State.ENGAGE)


func _request_encounter() -> void:
	if _encounter_requested:
		return
	_encounter_requested = true
	_encounter_counter += 1

	var context := EncounterContext.new()
	context.encounter_id = "%s_encounter_%d" % [String(world_actor_id), _encounter_counter]
	context.source_world_scene = get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	context.opening_advantage = _pending_opening_advantage
	context.initiating_enemy_id = world_actor_id

	if encounter_group != null and not encounter_group.battle_enemy_ids.is_empty():
		context.encounter_group_id = encounter_group.encounter_group_id
		context.battle_enemy_ids = encounter_group.battle_enemy_ids.duplicate()
	elif profile != null:
		context.encounter_group_id = StringName("%s_solo" % String(profile.enemy_id))
		context.battle_enemy_ids = [profile.battle_enemy_id]

	## Block 15: propagate area context so BattleEnvironmentRegistry can
	## resolve the correct 3D arena. Falls back gracefully to empty if
	## the profile has no source_area_id set.
	if profile != null and not profile.source_area_id.is_empty():
		context.source_area_id = profile.source_area_id

	var character := GameFlowState.get_active_character()
	if is_instance_valid(character) and "profile" in character and character.profile != null:
		context.initiating_player_character_id = character.profile.character_id

	EncounterCoordinator.request_encounter(context)


func _move_toward(target_position: Vector3, speed: float, delta: float) -> bool:
	var to_target := target_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return true

	var direction := to_target / distance
	_last_move_direction = direction
	var acceleration := profile.acceleration if profile != null else 12.0
	var target_velocity := direction * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(target_velocity, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if direction.length_squared() > 0.0001:
		look_at(global_position + direction, Vector3.UP)
	return false


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta


func _detect_active_character(is_currently_tracking: bool) -> bool:
	if profile == null:
		return false
	var character := GameFlowState.get_active_character()
	if character == null or not is_instance_valid(character):
		return false

	var to_character := character.global_position - global_position
	var flat_distance := Vector2(to_character.x, to_character.z).length()
	var range_to_use := profile.lose_target_range if is_currently_tracking else profile.detection_range
	if flat_distance > range_to_use:
		return false

	if profile.detection_angle_degrees < 359.0 and flat_distance > 0.01:
		var forward := _last_move_direction
		if forward.is_zero_approx():
			forward = -global_basis.z
		var flat_forward := Vector2(forward.x, forward.z)
		if flat_forward.length_squared() > 0.0001:
			flat_forward = flat_forward.normalized()
			var flat_to_character := Vector2(to_character.x, to_character.z).normalized()
			var angle_degrees := absf(rad_to_deg(flat_forward.angle_to(flat_to_character)))
			if angle_degrees > profile.detection_angle_degrees * 0.5:
				return false

	if profile.use_line_of_sight:
		var space_state := get_world_3d().direct_space_state
		if space_state != null:
			var query := PhysicsRayQueryParameters3D.create(
				global_position + Vector3.UP * 0.5,
				character.global_position + Vector3.UP * 0.5,
				1
			)
			query.exclude = [get_rid()]
			var result := space_state.intersect_ray(query)
			if not result.is_empty() and result.get("collider") != character:
				return false

	return true


## `character` is untyped on purpose: GameFlowState's active-character
## reference can outlive the Node it points to across a scene reload (a
## freed object fails Godot's argument type-check before this function body
## -- and therefore before is_instance_valid() below -- even gets to run if
## the parameter is declared Node3D).
func _rewire_active_character_listener(character) -> void:
	if is_instance_valid(_listened_character) and _listened_character.has_signal("exploration_attack_hit"):
		if _listened_character.exploration_attack_hit.is_connected(_on_active_character_attack_hit):
			_listened_character.exploration_attack_hit.disconnect(_on_active_character_attack_hit)
	_listened_character = character if is_instance_valid(character) else null
	if is_instance_valid(character) and character.has_signal("exploration_attack_hit"):
		character.exploration_attack_hit.connect(_on_active_character_attack_hit)


func _on_active_character_attack_hit(target: Node3D) -> void:
	if target != self:
		return
	receive_exploration_attack(_listened_character)


func _on_encounter_resolved(context: EncounterContext, result: StringName) -> void:
	if context.initiating_enemy_id != world_actor_id:
		return
	apply_encounter_result(result)


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return
	var old_state := _state
	_state = new_state
	if new_state == State.DISABLED and _target_indicator != null:
		_target_indicator.visible = false
	if new_state == State.PATROL:
		_patrol_wait_remaining = 0.0
	if new_state == State.IDLE:
		_idle_wait_remaining = idle_wait_seconds
	if debug_draw:
		print("[ExplorationEnemy3D:%s] %s -> %s" % [String(world_actor_id), State.keys()[old_state], State.keys()[new_state]])
	state_changed.emit(old_state, new_state)


func _create_target_indicator() -> void:
	_target_indicator = Node3D.new()
	_target_indicator.name = "TargetIndicator"
	add_child(_target_indicator)
	_target_indicator.position.y = 0.06

	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.64
	ring_mesh.rings = 28
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.35, 0.95, 1.0, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.1, 0.65, 1.0, 1.0)
	ring_mat.emission_energy_multiplier = 1.4
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mesh.material = ring_mat
	ring.mesh = ring_mesh
	_target_indicator.add_child(ring)
	_target_indicator.visible = false
