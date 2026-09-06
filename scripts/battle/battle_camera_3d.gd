extends Node3D
class_name BattleCamera3D


## Block 15: cinematic camera for 3D battle presentation.
## Distinct from ExplorationCamera3D -- different responsibilities.
##
## Camera responds to COMMAND STATE, never owns command state.
## BattlePresentation3D tells this camera which preset to use;
## this camera executes smooth transitions between them.
##
## Presets:
##   IDLE             -- default between commands, shows full arena
##   PLAYER_BASIC     -- basic attack staging
##   PLAYER_SKILL     -- skill cinematic framing
##   PLAYER_ULTIMATE  -- yields to 2D Ultimate cutscene, then restores
##   ENEMY_ATTACK     -- enemy action framing
##   TARGET_SELECT    -- hover/select framing
##   VICTORY          -- end-of-battle pull-back

enum Preset {
	IDLE,
	PLAYER_BASIC,
	PLAYER_SKILL,
	PLAYER_ULTIMATE,
	ENEMY_ATTACK,
	TARGET_SELECT,
	VICTORY,
}

@export var transition_duration: float = 0.28
@export var return_duration: float = 0.22

## Formation reference positions — set by BattlePresentation3D after formation resolves.
var party_center: Vector3 = Vector3(-2.0, 0.0, 0.0)
var enemy_center: Vector3 = Vector3(2.5, 0.0, 0.0)
var arena_center: Vector3 = Vector3(0.0, 0.0, 0.0)

var _current_preset: Preset = Preset.IDLE
var _camera: Camera3D

## Per-arena IDLE override (Block 15.2: arena-specific camera framing).
## Set by BattlePresentation3D from the active BattleEnvironmentProfile.
## Only IDLE is overridden -- the close-up action presets stay shared,
## since they frame a single actor rather than the diorama.
var _idle_pos_override: Vector3 = Vector3.ZERO
var _idle_look_override: Vector3 = Vector3.ZERO
var _has_idle_override: bool = false
var _tween: Tween

## Preset definitions: [position_offset_from_arena_center, look_at_offset, fov]
## Positions are relative to arena_center.
## Block 15.1 rework -- reframed for an HSR/Persona-style turn-based read.
## The old IDLE sat at eye height 2.8m and only 7.5m back with a 55° FOV,
## which cropped the formation and shoved arena props into the foreground.
## Every preset now sits higher and further out, angled slightly off-axis so
## the party reads in the near-left and the enemies in the far-right --
## the standard three-quarter turn-based composition -- with a tighter FOV
## so the actors stay large without the lens distorting the diorama.
const PRESET_CONFIGS: Dictionary = {
	Preset.IDLE: {
		"pos": Vector3(-1.4, 4.0, 8.6),
		"look": Vector3(0.6, 1.05, -0.5),
		"fov": 44.0,
	},
	## Pushes in over the attacker's shoulder toward the enemy line.
	Preset.PLAYER_BASIC: {
		"pos": Vector3(-3.4, 2.9, 5.2),
		"look": Vector3(1.7, 1.05, -0.3),
		"fov": 42.0,
	},
	## Lower, tighter, more dramatic for the skill cinematic.
	Preset.PLAYER_SKILL: {
		"pos": Vector3(-3.9, 2.2, 4.4),
		"look": Vector3(1.5, 1.25, -0.4),
		"fov": 39.0,
	},
	## Tight ready-focus before yielding to the full-screen Ultimate cutscene.
	Preset.PLAYER_ULTIMATE: {
		"pos": Vector3(-3.7, 2.45, 4.9),
		"look": Vector3(-1.4, 1.18, -0.25),
		"fov": 38.0,
	},
	## Mirrored to the enemy side so their turn reads as a counter-attack.
	Preset.ENEMY_ATTACK: {
		"pos": Vector3(3.6, 3.0, 5.6),
		"look": Vector3(-1.6, 1.05, 0.3),
		"fov": 43.0,
	},
	## Leans toward the enemy line while the player picks a target.
	Preset.TARGET_SELECT: {
		"pos": Vector3(-0.2, 3.6, 7.4),
		"look": Vector3(1.6, 1.05, -0.7),
		"fov": 41.0,
	},
	## Pulls back and up to show the cleared field.
	Preset.VICTORY: {
		"pos": Vector3(-1.0, 5.4, 10.4),
		"look": Vector3(0.2, 0.85, -0.6),
		"fov": 50.0,
	},
}


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "BattleCamera3DInner"
	_camera.fov = 55.0
	add_child(_camera)
	_camera.make_current()
	_apply_preset_immediate(Preset.IDLE)


func set_formation_refs(
	p_party_center: Vector3,
	p_enemy_center: Vector3,
	p_arena_center: Vector3
) -> void:
	party_center = p_party_center
	enemy_center = p_enemy_center
	arena_center = p_arena_center
	_apply_preset_immediate(_current_preset)


## Applies an arena-specific IDLE framing (position/look offsets from
## arena_center). Pass the same defaults as the shared IDLE preset to
## effectively clear the override.
func apply_arena_camera_offsets(pos_offset: Vector3, look_offset: Vector3) -> void:
	_idle_pos_override = pos_offset
	_idle_look_override = look_offset
	_has_idle_override = true
	if _current_preset == Preset.IDLE:
		_apply_preset_immediate(Preset.IDLE)


func transition_to(preset: Preset) -> void:
	if preset == _current_preset:
		return
	_current_preset = preset
	_animate_to_preset(preset, transition_duration)


func snap_to(preset: Preset) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_look_tween_start = false
	_current_preset = preset
	_apply_preset_immediate(preset)


func return_to_idle() -> void:
	transition_to(Preset.IDLE)


func get_current_preset() -> Preset:
	return _current_preset


func get_camera() -> Camera3D:
	return _camera


var _shake_tween: Tween


func shake(strength: float, duration: float = 0.12) -> void:
	if _camera == null:
		return
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
	var shake_magnitude: float = clampf(strength * 0.025, 0.04, 0.35)
	_shake_tween = create_tween()
	_shake_tween.tween_property(_camera, "h_offset", shake_magnitude, duration * 0.25).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_camera, "h_offset", -shake_magnitude * 0.7, duration * 0.35).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_camera, "h_offset", 0.0, duration * 0.4).set_trans(Tween.TRANS_SINE)


func _apply_preset_immediate(preset: Preset) -> void:
	if _camera == null:
		return
	var cfg := _preset_config(preset)
	_camera.position = arena_center + cfg["pos"]
	_camera.look_at(arena_center + cfg["look"], Vector3.UP)
	_camera.fov = cfg["fov"]


func _animate_to_preset(preset: Preset, duration: float) -> void:
	if _camera == null:
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	_look_tween_start = false

	var cfg := _preset_config(preset)
	var target_pos: Vector3 = arena_center + cfg["pos"]
	var target_look: Vector3 = arena_center + cfg["look"]
	var target_fov: float = cfg["fov"]

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_camera, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "fov", target_fov, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Look-at via rotation tween using a helper method
	_tween.tween_method(_smooth_look_at.bind(target_look), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


var _look_from: Quaternion = Quaternion.IDENTITY
var _look_to: Quaternion = Quaternion.IDENTITY
var _look_tween_start: bool = false


func _smooth_look_at(t: float, target_look: Vector3) -> void:
	if _camera == null:
		return
	if not _look_tween_start:
		_look_tween_start = true
		_look_from = _camera.quaternion
		var temp_node := Node3D.new()
		add_child(temp_node)
		temp_node.global_position = _camera.global_position
		temp_node.look_at(target_look, Vector3.UP)
		_look_to = temp_node.quaternion
		temp_node.queue_free()
	if t >= 0.999:
		_look_tween_start = false
	_camera.quaternion = _look_from.slerp(_look_to, t)


func _preset_config(preset: Preset) -> Dictionary:
	var cfg: Dictionary = PRESET_CONFIGS.get(preset, PRESET_CONFIGS[Preset.IDLE])
	if preset == Preset.IDLE and _has_idle_override:
		return {
			"pos": _idle_pos_override,
			"look": _idle_look_override,
			"fov": cfg["fov"],
		}
	return cfg
