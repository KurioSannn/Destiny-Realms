extends CharacterBody2D
class_name WorldPlayer

signal movement_state_changed(is_moving: bool)

@export_category("Movement")
@export var move_speed: float = 285.0
@export var acceleration: float = 1250.0
@export var vertical_speed_multiplier: float = 0.72
@export var walkable_polygon: PackedVector2Array = PackedVector2Array()

@export_category("Presentation")
@export var moving_bob_height: float = 3.0
@export var moving_bob_speed: float = 12.0

@onready var character_visual: AnimatedSprite2D = $CharacterVisual
@onready var shadow: Polygon2D = $Shadow

var _movement_enabled: bool = true
var _was_moving: bool = false
var _bob_time: float = 0.0
var _visual_rest_position: Vector2
var _shadow_rest_scale: Vector2


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

	var projected_direction := Vector2(
		input_direction.x,
		input_direction.y * vertical_speed_multiplier
	)
	var target_velocity := projected_direction * move_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	_move_inside_walkable_area(delta)
	_update_character_visual(delta, input_direction)


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO


func _move_inside_walkable_area(delta: float) -> void:
	var start_position := global_position
	var desired_position := start_position + velocity * delta

	if _is_walkable(desired_position):
		global_position = desired_position
		return

	var resolved_position := start_position
	var x_candidate := Vector2(desired_position.x, resolved_position.y)
	if _is_walkable(x_candidate):
		resolved_position.x = x_candidate.x
	else:
		velocity.x = 0.0

	var y_candidate := Vector2(resolved_position.x, desired_position.y)
	if _is_walkable(y_candidate):
		resolved_position.y = y_candidate.y
	else:
		velocity.y = 0.0

	global_position = resolved_position


func _is_walkable(point: Vector2) -> bool:
	if walkable_polygon.size() < 3:
		return true
	return Geometry2D.is_point_in_polygon(point, walkable_polygon)


func _update_character_visual(delta: float, input_direction: Vector2) -> void:
	var is_moving := input_direction.length_squared() > 0.01 and velocity.length_squared() > 25.0

	if absf(input_direction.x) > 0.05:
		character_visual.flip_h = input_direction.x < 0.0

	if is_moving:
		_bob_time += delta * moving_bob_speed
		character_visual.position.y = _visual_rest_position.y + sin(_bob_time) * moving_bob_height
		character_visual.speed_scale = 1.45
		var shadow_pulse := 1.0 - absf(sin(_bob_time)) * 0.06
		shadow.scale = _shadow_rest_scale * Vector2(shadow_pulse, shadow_pulse)
	else:
		character_visual.position.y = move_toward(
			character_visual.position.y,
			_visual_rest_position.y,
			22.0 * delta
		)
		character_visual.speed_scale = 1.0
		shadow.scale = shadow.scale.lerp(_shadow_rest_scale, minf(delta * 10.0, 1.0))

	if is_moving != _was_moving:
		_was_moving = is_moving
		movement_state_changed.emit(is_moving)
