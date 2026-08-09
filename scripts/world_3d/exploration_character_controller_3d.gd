extends CharacterBody3D
class_name ExplorationCharacterController3D

## Generic, protagonist-agnostic exploration controller. Character-specific
## tuning comes from an assigned ExplorationProfile resource, not from
## hardcoded values here -- a new playable character is a new .tres, never a
## new controller script or a code fork. Expects a child AnimatedSprite3D
## named "CharacterVisual" and a child MeshInstance3D named "Shadow", the
## same structural convention any exploration character scene follows.

signal movement_state_changed(is_moving: bool)
signal sprint_state_changed(is_sprinting: bool)
signal jumped
signal landed
## Emitted when the last-faced direction changes. Purely a data foundation for
## a future directional sprite system -- the current billboard sprite still
## always faces the camera regardless of this value.
signal facing_direction_changed(direction: StringName)
signal exploration_attack_used
## target is whatever Node3D was in front of the character within range;
## Block 13 world enemies can listen for this or check group membership.
signal exploration_attack_hit(target: Node3D)
signal exploration_skill_used
signal exploration_skill_hit(target: Node3D)
signal exploration_target_changed(target: Node3D)
signal interactable_target_changed(interactable: Node)
signal interacted(interactable: Node)

const EXPLORATION_ATTACKABLE_GROUP := &"exploration_attackable"

## Per-character tuning. If unassigned, the exported fallback values below are
## used instead so the controller still works with no profile wired up.
@export var profile: ExplorationProfile

@export_category("Movement Fallbacks")
@export var move_speed: float = 5.2
@export var sprint_speed: float = 8.5
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var jump_velocity: float = 5.8

@export_category("World Tuning")
@export var gravity: float = 28.0
@export var playable_bounds: Rect2 = Rect2(-24.0, -17.0, 48.0, 34.0)

@export_category("Exploration Action Fallbacks")
@export var exploration_attack_cooldown: float = 0.5
@export var exploration_attack_range: float = 2.2
@export var exploration_skill_cooldown: float = 3.0
@export var exploration_skill_range: float = 4.5

@export_category("Presentation")
@export var moving_bob_height: float = 0.055
@export var moving_bob_speed: float = 11.0

@onready var character_visual: AnimatedSprite3D = $CharacterVisual
@onready var shadow: MeshInstance3D = $Shadow

var _move_speed: float
var _sprint_speed: float
var _acceleration: float
var _deceleration: float
var _jump_velocity: float
var _exploration_attack_cooldown_duration: float
var _exploration_attack_range: float
var _exploration_skill_cooldown_duration: float

var _exploration_enabled: bool = true
var _was_moving: bool = false
var _was_sprinting: bool = false
var _bob_time: float = 0.0
var _visual_rest_position: Vector3
var _shadow_rest_scale: Vector3
var _last_move_direction: Vector3 = Vector3.ZERO
var _facing_direction: StringName = &"front"
var _exploration_attack_cooldown_remaining: float = 0.0
var _exploration_skill_cooldown_remaining: float = 0.0
var _current_exploration_target: Node3D = null
var _nearby_interactables: Array = []
var _current_interactable: Node = null


func _ready() -> void:
	add_to_group(&"exploration_character")
	_apply_profile()
	_visual_rest_position = character_visual.position
	_shadow_rest_scale = shadow.scale
	if character_visual.sprite_frames != null and character_visual.sprite_frames.has_animation(&"idle"):
		character_visual.play(&"idle")
	# Built-in CharacterBody3D floor handling only (no custom physics): a
	# slightly longer snap length keeps the character glued to the ground
	# across small rocks/path edges/low steps instead of catching or
	# micro-bouncing.
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)


func set_profile(new_profile: ExplorationProfile) -> void:
	profile = new_profile
	_apply_profile()


func _apply_profile() -> void:
	if profile != null:
		_move_speed = profile.move_speed
		_sprint_speed = profile.sprint_speed
		_acceleration = profile.acceleration
		_deceleration = profile.deceleration
		_jump_velocity = profile.jump_velocity
		_exploration_attack_cooldown_duration = profile.exploration_attack_cooldown
		_exploration_attack_range = profile.exploration_attack_range
		_exploration_skill_cooldown_duration = profile.exploration_skill_cooldown
	else:
		_move_speed = move_speed
		_sprint_speed = sprint_speed
		_acceleration = acceleration
		_deceleration = deceleration
		_jump_velocity = jump_velocity
		_exploration_attack_cooldown_duration = exploration_attack_cooldown
		_exploration_attack_range = exploration_attack_range
		_exploration_skill_cooldown_duration = exploration_skill_cooldown


func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if _is_input_active():
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var ui_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if ui_direction.length_squared() > input_direction.length_squared():
			input_direction = ui_direction

	var world_direction := _camera_relative_direction(input_direction)
	if not world_direction.is_zero_approx():
		_last_move_direction = world_direction

	var is_sprinting := (
		_is_input_active()
		and not world_direction.is_zero_approx()
		and Input.is_action_pressed("sprint")
	)
	if is_sprinting != _was_sprinting:
		_was_sprinting = is_sprinting
		sprint_state_changed.emit(is_sprinting)

	var current_move_speed := _sprint_speed if is_sprinting else _move_speed
	var target_horizontal := world_direction * current_move_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var response := _acceleration if not world_direction.is_zero_approx() else _deceleration
	horizontal = horizontal.move_toward(target_horizontal, response * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var was_grounded := is_on_floor()
	if was_grounded:
		if _is_input_active() and Input.is_action_just_pressed("jump"):
			velocity.y = _jump_velocity
			jumped.emit()
		else:
			velocity.y = -0.5
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	if is_on_floor() and not was_grounded:
		landed.emit()

	_clamp_to_playable_bounds()
	_update_character_visual(delta, input_direction, world_direction)
	_update_facing_direction()
	_refresh_current_exploration_target()
	_process_exploration_actions(delta)
	_process_interaction_input()


func set_movement_enabled(enabled: bool) -> void:
	set_exploration_enabled(enabled)


## Preferred name going forward: gates movement, sprint, jump, exploration
## attack/skill, and interaction all at once from a single flag, so callers
## (dialogue, cutscenes, transitions, pause) never have to juggle several
## unrelated booleans. set_movement_enabled is kept as an alias for existing
## call sites.
func set_exploration_enabled(enabled: bool) -> void:
	_exploration_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_current_exploration_target(null)


func is_exploration_enabled() -> bool:
	return _exploration_enabled


## Block 14: the local flag alone isn't enough -- GameFlowState.set_context()
## (TRANSITION/BATTLE/etc.) must also gate input, or a caller that forgets to
## also call set_exploration_enabled(false) leaks a frame of movement/
## attack/skill/interact during a transition. is_exploration_enabled() above
## keeps returning only the local flag so existing callers/tests that
## introspect it are unaffected.
func _is_input_active() -> bool:
	return _exploration_enabled and GameFlowState.is_exploration_active()


func get_facing_direction() -> StringName:
	return _facing_direction


func register_nearby_interactable(interactable: Node) -> void:
	if not _nearby_interactables.has(interactable):
		_nearby_interactables.append(interactable)
	_refresh_current_interactable()


func unregister_nearby_interactable(interactable: Node) -> void:
	_nearby_interactables.erase(interactable)
	_refresh_current_interactable()


func get_current_interactable() -> Node:
	return _current_interactable


func try_exploration_attack() -> bool:
	if not _is_input_active() or _exploration_attack_cooldown_remaining > 0.0:
		return false
	_exploration_attack_cooldown_remaining = _exploration_attack_cooldown_duration
	exploration_attack_used.emit()
	_spawn_attack_vfx()
	var target := _current_exploration_target
	if not _is_valid_exploration_target(target, _exploration_attack_range, -0.1):
		target = _find_exploration_attack_target()
	if target != null:
		exploration_attack_hit.emit(target)
	return true


func try_exploration_skill() -> bool:
	if not _is_input_active() or _exploration_skill_cooldown_remaining > 0.0:
		return false
	_exploration_skill_cooldown_remaining = _exploration_skill_cooldown_duration
	exploration_skill_used.emit()
	_spawn_skill_vfx()
	var targets := _find_exploration_skill_targets()
	for target in targets:
		exploration_skill_hit.emit(target)
		if target.has_method("apply_field_effect"):
			target.call("apply_field_effect", &"stun", {"duration": 2.0})
	return true


## Block 14.5 Part I: lets HUD icons reflect real controller state (cooldown/
## disabled) without exposing raw cooldown timers.
func is_exploration_attack_ready() -> bool:
	return _is_input_active() and _exploration_attack_cooldown_remaining <= 0.0


func is_exploration_skill_ready() -> bool:
	return _is_input_active() and _exploration_skill_cooldown_remaining <= 0.0


func _camera_relative_direction(input_direction: Vector2) -> Vector3:
	if input_direction.is_zero_approx():
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_direction.x, 0.0, input_direction.y).normalized()

	var camera_right := camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var camera_forward := -camera.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	return (camera_right * input_direction.x + camera_forward * -input_direction.y).normalized()


func _clamp_to_playable_bounds() -> void:
	global_position.x = clampf(
		global_position.x,
		playable_bounds.position.x,
		playable_bounds.end.x
	)
	global_position.z = clampf(
		global_position.z,
		playable_bounds.position.y,
		playable_bounds.end.y
	)


func _update_character_visual(
	delta: float,
	input_direction: Vector2,
	world_direction: Vector3
) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := not world_direction.is_zero_approx() and horizontal_speed > 0.2

	var camera := get_viewport().get_camera_3d()
	if camera != null and not world_direction.is_zero_approx():
		var camera_right := camera.global_basis.x
		camera_right.y = 0.0
		if absf(world_direction.dot(camera_right)) > 0.05:
			character_visual.flip_h = world_direction.dot(camera_right) < 0.0
	elif absf(input_direction.x) > 0.05:
		character_visual.flip_h = input_direction.x < 0.0

	if is_moving:
		_bob_time += delta * moving_bob_speed
		character_visual.position.y = _visual_rest_position.y + sin(_bob_time) * moving_bob_height
		character_visual.speed_scale = 1.45
		var shadow_pulse := 1.0 - absf(sin(_bob_time)) * 0.08
		shadow.scale = _shadow_rest_scale * Vector3(shadow_pulse, 1.0, shadow_pulse)
	else:
		character_visual.position.y = move_toward(
			character_visual.position.y,
			_visual_rest_position.y,
			0.8 * delta
		)
		character_visual.speed_scale = 1.0
		shadow.scale = shadow.scale.lerp(_shadow_rest_scale, minf(delta * 10.0, 1.0))

	if is_moving != _was_moving:
		_was_moving = is_moving
		movement_state_changed.emit(is_moving)


func _update_facing_direction() -> void:
	# Bucket the last movement direction into front/back/left/right relative
	# to the camera. "front" = walking toward the camera, "back" = walking
	# away from it. Purely a data foundation: nothing currently reads
	# _facing_direction to change what's rendered (billboard stays active
	# until a directional sprite set exists for a given character).
	var camera := get_viewport().get_camera_3d()
	var forward_axis := Vector3.FORWARD
	var right_axis := Vector3.RIGHT
	if camera != null:
		forward_axis = -camera.global_basis.z
		forward_axis.y = 0.0
		if forward_axis.length_squared() > 0.0001:
			forward_axis = forward_axis.normalized()
		right_axis = camera.global_basis.x
		right_axis.y = 0.0
		if right_axis.length_squared() > 0.0001:
			right_axis = right_axis.normalized()

	var forward_dot := _last_move_direction.dot(forward_axis)
	var right_dot := _last_move_direction.dot(right_axis)
	var new_direction: StringName
	if absf(forward_dot) >= absf(right_dot):
		new_direction = &"back" if forward_dot > 0.0 else &"front"
	else:
		new_direction = &"right" if right_dot > 0.0 else &"left"

	if new_direction != _facing_direction:
		_facing_direction = new_direction
		facing_direction_changed.emit(_facing_direction)


func _process_exploration_actions(delta: float) -> void:
	_exploration_attack_cooldown_remaining = maxf(_exploration_attack_cooldown_remaining - delta, 0.0)
	_exploration_skill_cooldown_remaining = maxf(_exploration_skill_cooldown_remaining - delta, 0.0)

	if not _is_input_active():
		return

	if Input.is_action_just_pressed("exploration_attack"):
		try_exploration_attack()
	if Input.is_action_just_pressed("exploration_skill"):
		try_exploration_skill()


## Block 15 Part 0: returns the best available forward direction for attack
## cone checks. Priority: last move direction → camera forward → direction
## toward the nearest attackable target in range (so a stationary player
## who has not yet moved can still land a hit without cursor targeting).
func get_forward_direction() -> Vector3:
	# If the player has moved, trust their last movement direction.
	if not _last_move_direction.is_zero_approx():
		return _last_move_direction.normalized()

	var nearest_target := _nearest_attackable_target(_exploration_attack_range * 1.5)
	if nearest_target != null:
		var to_target := nearest_target.global_position - global_position
		to_target.y = 0.0
		if not to_target.is_zero_approx():
			return to_target.normalized()

	# If standing still, try camera forward.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var cam_forward := -camera.global_basis.z
		cam_forward.y = 0.0
		if not cam_forward.is_zero_approx():
			# Refine: if there is exactly one attackable target nearby,
			# prefer the direction toward it so the cone check cannot fail
			# when the player stands near an enemy without having moved.
			var best_target: Node3D = null
			var best_dist := _exploration_attack_range * 1.5
			for candidate_variant in get_tree().get_nodes_in_group(EXPLORATION_ATTACKABLE_GROUP):
				var candidate := candidate_variant as Node3D
				if candidate == null or not is_instance_valid(candidate):
					continue
				var to_c := candidate.global_position - global_position
				to_c.y = 0.0
				var dist := to_c.length()
				if dist < best_dist:
					best_dist = dist
					best_target = candidate
			if best_target != null:
				var to_target := best_target.global_position - global_position
				to_target.y = 0.0
				if not to_target.is_zero_approx():
					return to_target.normalized()
			return cam_forward.normalized()

	return Vector3.FORWARD


## Block 15 Part 0: cone threshold widened from 0.3 (72.5°) to -0.1 (~96°)
## so a player roughly facing an enemy will hit without precise alignment.
func _find_exploration_attack_target() -> Node3D:
	return _best_attackable_target(_exploration_attack_range, -0.1)


func _find_exploration_skill_targets() -> Array[Node3D]:
	var forward := get_forward_direction()
	var skill_range := exploration_skill_range
	var targets: Array[Node3D] = []
	for candidate_variant in get_tree().get_nodes_in_group(EXPLORATION_ATTACKABLE_GROUP):
		var candidate := candidate_variant as Node3D
		if candidate == null or not is_instance_valid(candidate):
			continue
		var to_candidate := candidate.global_position - global_position
		to_candidate.y = 0.0
		var distance := to_candidate.length()
		if distance < 0.001 or distance > skill_range:
			continue
		# Cone check: allow a 120-degree cone (dot >= 0.0) for skill volume
		if to_candidate.normalized().dot(forward) < 0.0:
			continue
		targets.append(candidate)
	return targets


func _refresh_current_exploration_target() -> void:
	if not _is_input_active():
		_set_current_exploration_target(null)
		return
	_set_current_exploration_target(_find_exploration_attack_target())


func _set_current_exploration_target(target: Node3D) -> void:
	if target == _current_exploration_target:
		return
	var previous := _current_exploration_target
	_current_exploration_target = target
	_set_target_indicator(previous, false)
	_set_target_indicator(_current_exploration_target, true)
	exploration_target_changed.emit(_current_exploration_target)


func _set_target_indicator(target: Node3D, visible_state: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("set_target_indicator_visible"):
		target.call("set_target_indicator_visible", visible_state)


func _nearest_attackable_target(max_range: float) -> Node3D:
	var best_target: Node3D = null
	var best_distance := max_range
	for candidate_variant in get_tree().get_nodes_in_group(EXPLORATION_ATTACKABLE_GROUP):
		var candidate := candidate_variant as Node3D
		if not _is_attackable_candidate(candidate):
			continue
		var to_candidate := candidate.global_position - global_position
		to_candidate.y = 0.0
		var distance := to_candidate.length()
		if distance < 0.001 or distance > best_distance:
			continue
		best_distance = distance
		best_target = candidate
	return best_target


func _best_attackable_target(max_range: float, cone_threshold: float) -> Node3D:
	var forward := get_forward_direction()
	var best_target: Node3D = null
	var best_distance := max_range
	for candidate_variant in get_tree().get_nodes_in_group(EXPLORATION_ATTACKABLE_GROUP):
		var candidate := candidate_variant as Node3D
		if not _is_attackable_candidate(candidate):
			continue
		var to_candidate := candidate.global_position - global_position
		to_candidate.y = 0.0
		var distance := to_candidate.length()
		if distance < 0.001 or distance > best_distance:
			continue
		if to_candidate.normalized().dot(forward) < cone_threshold:
			continue
		best_distance = distance
		best_target = candidate
	return best_target


func _is_valid_exploration_target(
	target: Node3D,
	max_range: float,
	cone_threshold: float
) -> bool:
	if not _is_attackable_candidate(target):
		return false
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.001 or distance > max_range:
		return false
	return to_target.normalized().dot(get_forward_direction()) >= cone_threshold


func _is_attackable_candidate(candidate: Node3D) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and candidate.is_in_group(EXPLORATION_ATTACKABLE_GROUP)
		and (not candidate.has_method("is_disabled") or not bool(candidate.call("is_disabled")))
	)


func _spawn_attack_vfx() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	if character_visual != null and is_instance_valid(character_visual):
		var tween := create_tween()
		tween.tween_property(character_visual, "scale", Vector3(1.18, 1.18, 1.18), 0.08)
		tween.tween_property(character_visual, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
	
	var vfx_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 0.08, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.9, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 1.0, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	vfx_node.mesh = mesh
	
	var forward := get_forward_direction()
	get_parent().add_child(vfx_node)
	vfx_node.global_position = global_position + forward * 1.0 + Vector3(0.0, 0.5, 0.0)
	
	var vfx_tween := vfx_node.create_tween()
	vfx_tween.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	vfx_tween.tween_callback(vfx_node.queue_free)


## Block 15 Part 0b: skill VFX made clearly observable.
## Three distinct beats: character pulse → expanding ring wave → energy pillar.
func _spawn_skill_vfx() -> void:
	if not is_inside_tree() or get_parent() == null:
		return

	# 1. Character scale pulse (larger than Basic, with a golden glow tint)
	if character_visual != null and is_instance_valid(character_visual):
		var tween := create_tween()
		tween.tween_property(character_visual, "scale", Vector3(1.42, 1.42, 1.42), 0.10)
		tween.parallel().tween_property(character_visual, "modulate", Color(1.0, 0.88, 0.35, 1.0), 0.10)
		tween.tween_property(character_visual, "scale", Vector3(1.0, 1.0, 1.0), 0.22)
		tween.parallel().tween_property(character_visual, "modulate", Color.WHITE, 0.22)

	var parent := get_parent()
	var origin := global_position

	# 2. Expanding ring wave (flat torus expanding outward)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.3
	ring_mesh.outer_radius = 0.45
	ring_mesh.rings = 24
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.9, 0.72, 0.22, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.75, 0.3, 1.0)
	ring_mat.emission_energy_multiplier = 2.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mesh.material = ring_mat
	ring.mesh = ring_mesh
	parent.add_child(ring)
	ring.global_position = origin + Vector3(0.0, 0.05, 0.0)

	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector3(6.0, 1.0, 6.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.45)
	ring_tween.chain().tween_callback(ring.queue_free)

	# 3. Energy pillar rising from the ground (cylinder expanding upward)
	var pillar := MeshInstance3D.new()
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.08
	pillar_mesh.bottom_radius = 0.38
	pillar_mesh.height = 2.8
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(1.0, 0.88, 0.35, 0.75)
	pillar_mat.emission_enabled = true
	pillar_mat.emission = Color(0.95, 0.72, 0.22, 1.0)
	pillar_mat.emission_energy_multiplier = 1.6
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mesh.material = pillar_mat
	pillar.mesh = pillar_mesh
	parent.add_child(pillar)
	pillar.global_position = origin + Vector3(0.0, 1.4, 0.0)
	pillar.scale = Vector3(1.0, 0.01, 1.0)

	var pillar_tween := pillar.create_tween()
	pillar_tween.tween_property(pillar, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pillar_tween.tween_interval(0.15)
	pillar_tween.tween_property(pillar_mat, "albedo_color:a", 0.0, 0.30)
	pillar_tween.chain().tween_callback(pillar.queue_free)





func _process_interaction_input() -> void:
	# Action priority: a blocked exploration state (checked first, above)
	# suppresses everything; interaction lives on its own key, independent of
	# attack/skill, so pressing interact never also fires an attack.
	if not _is_input_active() or _current_interactable == null:
		return
	if not Input.is_action_just_pressed("interact"):
		return
	var interactable := _current_interactable
	if not is_instance_valid(interactable):
		return
	if interactable.has_method("can_interact") and not interactable.call("can_interact", self):
		return
	if interactable.has_method("interact"):
		interactable.call("interact", self)
	interacted.emit(interactable)


func _refresh_current_interactable() -> void:
	var nearest: Node = null
	var nearest_distance := INF
	for interactable_variant in _nearby_interactables:
		if not is_instance_valid(interactable_variant):
			continue
		var interactable3d := interactable_variant as Node3D
		if interactable3d == null:
			continue
		if interactable3d.has_method("can_interact") and not interactable3d.call("can_interact", self):
			continue
		var distance := global_position.distance_to(interactable3d.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = interactable3d

	if nearest != _current_interactable:
		_current_interactable = nearest
		interactable_target_changed.emit(_current_interactable)
