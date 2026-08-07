extends CharacterBody3D
class_name HybridPlayer3D

signal movement_state_changed(is_moving: bool)

@export_category("Movement")
@export var move_speed: float = 5.2
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var gravity: float = 28.0
@export var playable_bounds: Rect2 = Rect2(-24.0, -17.0, 48.0, 34.0)

@export_category("Presentation")
@export var moving_bob_height: float = 0.055
@export var moving_bob_speed: float = 11.0

@onready var character_visual: AnimatedSprite3D = $CharacterVisual
@onready var shadow: MeshInstance3D = $Shadow

var _movement_enabled: bool = true
var _was_moving: bool = false
var _bob_time: float = 0.0
var _visual_rest_position: Vector3
var _shadow_rest_scale: Vector3


func _ready() -> void:
	_visual_rest_position = character_visual.position
	_shadow_rest_scale = shadow.scale
	if character_visual.sprite_frames != null and character_visual.sprite_frames.has_animation(&"idle"):
		character_visual.play(&"idle")


func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if _movement_enabled:
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var ui_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if ui_direction.length_squared() > input_direction.length_squared():
			input_direction = ui_direction

	var world_direction := _camera_relative_direction(input_direction)
	var target_horizontal := world_direction * move_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var response := acceleration if not world_direction.is_zero_approx() else deceleration
	horizontal = horizontal.move_toward(target_horizontal, response * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	_clamp_to_playable_bounds()
	_update_character_visual(delta, input_direction, world_direction)


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0


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
