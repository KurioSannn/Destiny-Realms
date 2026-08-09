extends Camera3D
class_name ExplorationCamera3D

## Reusable production exploration camera: perspective, full 360 degree yaw
## orbit, clamped pitch, true distance-based zoom, and raycast obstruction
## avoidance. Any world scene can instance exploration_camera_3d.tscn and
## point target_path (or call set_target()) at its player.
##
## F1 is a temporary orthographic debug baseline kept for comparison only.
## F5/F6/F7 are temporary distance-comparison debug shortcuts. None of the
## three are meant to survive as permanent gameplay controls.

signal preset_changed(preset_id: int, display_name: String)

const PRESET_LEGACY := 1
const PRESET_PRODUCTION := 2

const LEGACY_PROJECTION := Camera3D.PROJECTION_ORTHOGONAL
const LEGACY_FOLLOW_OFFSET := Vector3(10.5, 12.5, 10.5)
const LEGACY_LOOK_HEIGHT := 0.85
const LEGACY_FOLLOW_DAMPING := 7.5
const LEGACY_SIZE := 15.2
const LEGACY_DISPLAY_NAME := "F1 — Legacy"
const PRODUCTION_DISPLAY_NAME := "F2 — Exploration"

@export_category("Target")
@export var target_path: NodePath = NodePath("../Player")

@export_category("Framing")
@export var look_height: float = 1.05
@export var framing_lead: Vector3 = Vector3(0.0, 0.0, -2.0)
@export var follow_damping: float = 6.8
@export var fov_degrees: float = 35.5
@export var preset_transition_seconds: float = 0.6

@export_category("Orbit")
@export var default_yaw_degrees: float = 0.0
@export var default_pitch_degrees: float = 14.5
@export var pitch_min_degrees: float = 10.0
@export var pitch_max_degrees: float = 32.0
@export var yaw_sensitivity: float = 0.15
@export var pitch_sensitivity: float = 0.12
@export var orbit_smoothing_speed: float = 9.0

@export_category("Distance Zoom")
@export var distance_default: float = 13.0
@export var distance_min: float = 7.0
@export var distance_max: float = 19.0
@export var distance_step: float = 1.0
@export var distance_smoothing_speed: float = 9.0
@export var distance_preset_close: float = 7.0
@export var distance_preset_medium: float = 11.0
@export var distance_preset_wide: float = 19.0

@export_category("Obstruction")
@export_flags_3d_physics var obstruction_collision_mask: int = 2
@export var obstruction_margin: float = 0.35
@export var obstruction_pull_in_speed: float = 45.0
@export var obstruction_restore_speed: float = 4.0
@export var obstruction_min_distance: float = 2.0

@export_category("Player Camera Control")
@export var mouse_control_enabled: bool = true
@export var debug_label_path: NodePath = NodePath("../CameraPresetDebug/Panel/Label")

var _target: Node3D
var _debug_label: Label
var _preset_tween: Tween
var _active_preset_id: int = PRESET_PRODUCTION

var _orbit_dragging: bool = false
var _yaw_target_degrees: float = 0.0
var _yaw_current_degrees: float = 0.0
var _pitch_target_degrees: float = 14.5
var _pitch_current_degrees: float = 14.5
var _distance_target: float = 13.0
var _distance_current: float = 13.0
var _effective_distance_current: float = 13.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_debug_label = get_node_or_null(debug_label_path) as Label
	_pitch_target_degrees = default_pitch_degrees
	_pitch_current_degrees = default_pitch_degrees
	_distance_target = distance_default
	_distance_current = distance_default
	_effective_distance_current = distance_default
	apply_camera_preset(PRESET_PRODUCTION, false)


func set_target(node: Node3D) -> void:
	_target = node


func set_mouse_control_enabled(enabled: bool) -> void:
	mouse_control_enabled = enabled
	if not enabled:
		_orbit_dragging = false


func get_active_preset_id() -> int:
	return _active_preset_id


func get_downward_pitch_degrees() -> float:
	if _active_preset_id == PRESET_LEGACY:
		var horizontal_distance := Vector2(LEGACY_FOLLOW_OFFSET.x, LEGACY_FOLLOW_OFFSET.z).length()
		if horizontal_distance <= 0.001:
			return 90.0
		return rad_to_deg(atan2(LEGACY_FOLLOW_OFFSET.y - LEGACY_LOOK_HEIGHT, horizontal_distance))
	return _pitch_current_degrees


func get_camera_distance() -> float:
	return _effective_distance_current


func _unhandled_input(event: InputEvent) -> void:
	var requested_preset := _preset_id_from_key_event(event)
	if requested_preset != 0:
		apply_camera_preset(requested_preset)
		get_viewport().set_input_as_handled()
		return

	var requested_distance := _distance_shortcut_from_key_event(event)
	if requested_distance >= 0.0:
		if _active_preset_id == PRESET_PRODUCTION:
			_distance_target = clampf(requested_distance, distance_min, distance_max)
		get_viewport().set_input_as_handled()
		return

	if not mouse_control_enabled or _active_preset_id != PRESET_PRODUCTION:
		return
	if get_tree() != null and get_tree().paused:
		return
	# Block 14: GameFlowState.set_context() (TRANSITION/BATTLE/etc.) must also
	# gate mouse camera input, the same way it now gates player input, or a
	# caller that forgets to also call set_mouse_control_enabled(false) leaks
	# orbit/zoom during a transition. F1/F2/F5-F7 above stay ungated -- they
	# are debug tools, not real gameplay input.
	if not GameFlowState.is_exploration_active():
		return

	if _is_reset_key_event(event):
		_reset_camera_control()
		get_viewport().set_input_as_handled()
		return
	if _handle_zoom_wheel_event(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_orbit_button_event(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_orbit_motion_event(event):
		get_viewport().set_input_as_handled()


func _preset_id_from_key_event(event: InputEvent) -> int:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return 0
	var keycode := key_event.keycode
	if keycode == KEY_NONE:
		keycode = key_event.physical_keycode
	match keycode:
		KEY_F1:
			return PRESET_LEGACY
		KEY_F2:
			return PRESET_PRODUCTION
	return 0


func _distance_shortcut_from_key_event(event: InputEvent) -> float:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return -1.0
	var keycode := key_event.keycode
	if keycode == KEY_NONE:
		keycode = key_event.physical_keycode
	match keycode:
		KEY_F5:
			return distance_preset_close
		KEY_F6:
			return distance_preset_medium
		KEY_F7:
			return distance_preset_wide
	return -1.0


func _is_reset_key_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	var keycode := key_event.keycode
	if keycode == KEY_NONE:
		keycode = key_event.physical_keycode
	return keycode == KEY_R


func _handle_zoom_wheel_event(event: InputEvent) -> bool:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return false
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_distance_target = clampf(_distance_target - distance_step, distance_min, distance_max)
		return true
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_distance_target = clampf(_distance_target + distance_step, distance_min, distance_max)
		return true
	return false


func _handle_orbit_button_event(event: InputEvent) -> bool:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return false
	if mouse_event.button_index != MOUSE_BUTTON_MIDDLE and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return false
	_orbit_dragging = mouse_event.pressed
	return true


func _handle_orbit_motion_event(event: InputEvent) -> bool:
	if not _orbit_dragging:
		return false
	var motion_event := event as InputEventMouseMotion
	if motion_event == null:
		return false
	_yaw_target_degrees = wrapf(
		_yaw_target_degrees + motion_event.relative.x * yaw_sensitivity, -180.0, 180.0
	)
	_pitch_target_degrees = clampf(
		_pitch_target_degrees - motion_event.relative.y * pitch_sensitivity,
		pitch_min_degrees,
		pitch_max_degrees
	)
	return true


func _reset_camera_control() -> void:
	_yaw_target_degrees = default_yaw_degrees
	_pitch_target_degrees = default_pitch_degrees
	_distance_target = distance_default


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_node_or_null(target_path) as Node3D
		if not is_instance_valid(_target):
			return

	_update_camera_control_smoothing(delta)

	var desired_position: Vector3
	var look_target: Vector3
	var damping: float

	if _active_preset_id == PRESET_LEGACY:
		desired_position = _target.global_position + LEGACY_FOLLOW_OFFSET
		look_target = _target.global_position + Vector3.UP * LEGACY_LOOK_HEIGHT
		damping = LEGACY_FOLLOW_DAMPING
	else:
		var pivot_position := _target.global_position + Vector3.UP * look_height + framing_lead
		_update_obstruction(pivot_position, delta)
		desired_position = pivot_position + _spherical_offset(
			_yaw_current_degrees, _pitch_current_degrees, _effective_distance_current
		)
		look_target = pivot_position
		damping = follow_damping

	var follow_weight := 1.0 - exp(-damping * delta)
	global_position = global_position.lerp(desired_position, follow_weight)
	look_at(look_target, Vector3.UP)


func _update_camera_control_smoothing(delta: float) -> void:
	var orbit_weight := 1.0 - exp(-orbit_smoothing_speed * delta)

	# Yaw is a wrapping angle: always ease along the shortest signed arc so
	# crossing the +/-180 seam never produces a long way round jump.
	var yaw_delta := wrapf(_yaw_target_degrees - _yaw_current_degrees, -180.0, 180.0)
	if absf(yaw_delta) < 0.01:
		_yaw_current_degrees = _yaw_target_degrees
	else:
		_yaw_current_degrees = wrapf(_yaw_current_degrees + yaw_delta * orbit_weight, -180.0, 180.0)

	_pitch_current_degrees = lerpf(_pitch_current_degrees, _pitch_target_degrees, orbit_weight)
	if absf(_pitch_current_degrees - _pitch_target_degrees) < 0.01:
		_pitch_current_degrees = _pitch_target_degrees

	var distance_weight := 1.0 - exp(-distance_smoothing_speed * delta)
	_distance_current = lerpf(_distance_current, _distance_target, distance_weight)
	if absf(_distance_current - _distance_target) < 0.01:
		_distance_current = _distance_target


func _spherical_offset(yaw_degrees: float, pitch_degrees: float, distance: float) -> Vector3:
	var yaw_radians := deg_to_rad(yaw_degrees)
	var pitch_radians := deg_to_rad(pitch_degrees)
	var horizontal_distance := distance * cos(pitch_radians)
	var vertical_distance := distance * sin(pitch_radians)
	return Vector3(
		sin(yaw_radians) * horizontal_distance,
		vertical_distance,
		cos(yaw_radians) * horizontal_distance
	)


func _update_obstruction(pivot_position: Vector3, delta: float) -> void:
	var clear_distance := _clear_distance(pivot_position, _distance_current)
	var target_distance := minf(_distance_current, clear_distance)
	if target_distance < _effective_distance_current - 0.001:
		_effective_distance_current = move_toward(
			_effective_distance_current, target_distance, obstruction_pull_in_speed * delta
		)
	else:
		var weight := 1.0 - exp(-obstruction_restore_speed * delta)
		_effective_distance_current = lerp(_effective_distance_current, target_distance, weight)
		if absf(_effective_distance_current - target_distance) < 0.01:
			_effective_distance_current = target_distance


func _clear_distance(pivot_position: Vector3, full_distance: float) -> float:
	if full_distance <= 0.001:
		return full_distance
	if not is_inside_tree():
		return full_distance
	var world := get_world_3d()
	if world == null:
		return full_distance
	var space_state := world.direct_space_state
	if space_state == null:
		return full_distance

	var offset := _spherical_offset(_yaw_current_degrees, _pitch_current_degrees, full_distance)
	var query := PhysicsRayQueryParameters3D.create(
		pivot_position, pivot_position + offset, obstruction_collision_mask
	)
	if is_instance_valid(_target) and _target is CollisionObject3D:
		query.exclude = [(_target as CollisionObject3D).get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return full_distance
	var hit_distance: float = pivot_position.distance_to(result.position) - obstruction_margin
	return clampf(hit_distance, obstruction_min_distance, full_distance)


func apply_camera_preset(preset_id: int, animated: bool = true) -> void:
	if preset_id != PRESET_LEGACY and preset_id != PRESET_PRODUCTION:
		push_warning("Unknown exploration camera preset: %d" % preset_id)
		return

	if _preset_tween != null and _preset_tween.is_valid():
		_preset_tween.kill()

	var target_projection: Camera3D.ProjectionType = (
		LEGACY_PROJECTION if preset_id == PRESET_LEGACY else Camera3D.PROJECTION_PERSPECTIVE
	)
	_prepare_projection_change(target_projection)
	_active_preset_id = preset_id
	_update_debug_label()
	preset_changed.emit(preset_id, _display_name(preset_id))

	var property_name := "size" if preset_id == PRESET_LEGACY else "fov"
	var property_target := LEGACY_SIZE if preset_id == PRESET_LEGACY else fov_degrees

	if not animated or preset_transition_seconds <= 0.0:
		set(property_name, property_target)
		_snap_to_preset_position()
		return

	_preset_tween = create_tween()
	_preset_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_preset_tween.tween_property(self, property_name, property_target, preset_transition_seconds)


func _display_name(preset_id: int) -> String:
	return LEGACY_DISPLAY_NAME if preset_id == PRESET_LEGACY else PRODUCTION_DISPLAY_NAME


func _prepare_projection_change(target_projection: Camera3D.ProjectionType) -> void:
	if projection == target_projection:
		return
	var focus_point := global_position - global_basis.z * 10.0
	if is_instance_valid(_target):
		focus_point = _target.global_position + Vector3.UP * look_height
	var focus_distance := maxf(global_position.distance_to(focus_point), 0.1)
	if target_projection == Camera3D.PROJECTION_PERSPECTIVE:
		fov = rad_to_deg(2.0 * atan(maxf(size, 0.1) / (2.0 * focus_distance)))
		projection = Camera3D.PROJECTION_PERSPECTIVE
	else:
		size = 2.0 * focus_distance * tan(deg_to_rad(fov) * 0.5)
		projection = Camera3D.PROJECTION_ORTHOGONAL


func _update_debug_label() -> void:
	if not is_instance_valid(_debug_label):
		return
	_debug_label.text = "Camera: %s" % _display_name(_active_preset_id)


func _snap_to_preset_position() -> void:
	if not is_instance_valid(_target):
		return
	if _active_preset_id == PRESET_LEGACY:
		global_position = _target.global_position + LEGACY_FOLLOW_OFFSET
		look_at(_target.global_position + Vector3.UP * LEGACY_LOOK_HEIGHT, Vector3.UP)
		return
	var pivot_position := _target.global_position + Vector3.UP * look_height + framing_lead
	global_position = pivot_position + _spherical_offset(
		_yaw_current_degrees, _pitch_current_degrees, _effective_distance_current
	)
	look_at(pivot_position, Vector3.UP)
