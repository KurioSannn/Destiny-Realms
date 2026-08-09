extends Node3D
class_name BattleActor3D

## Block 15: one battle combatant's 3D presentation. Mirrors HP/alive state
## from the 2D Combatant; owns no battle-state authority.
##
## Block 15.1 rework -- the original version assumed every actor was a
## billboard Sprite3D with a hardcoded pixel_size, which made a 1024px
## character sprite render ~5 metres tall next to a 1.8m-scaled world. Now:
##   - the actor's ORIGIN IS ITS FEET (y = 0 sits on the arena floor)
##   - visuals are normalised to a requested world height, whatever the
##     source resolution / model bounds happen to be
##   - an actor may be a billboard sprite OR a real 3D model (the monster
##     GLTFs already used by exploration enemies), so battle and field show
##     the same creature instead of a stale leftover texture

enum ActorState {
	IDLE,
	ATTACK,
	SKILL,
	ULTIMATE,
	HIT,
	DEFEATED,
}

signal actor_death_presented(actor)

@export var actor_id: StringName = &""
@export var is_player_side: bool = true

@onready var sprite: Sprite3D = $Sprite3D
@onready var model_root: Node3D = $ModelRoot
@onready var shadow: MeshInstance3D = $Shadow
@onready var target_marker: Node3D = $TargetMarker
@onready var hp_label_3d: Label3D = $HpLabel3D

## Animation frame data (same source paths BattleManager uses for Takashi).
var idle_frames: Array[Texture2D] = []
var attack_frames: Array[Texture2D] = []
var skill_frames: Array[Texture2D] = []
var idle_frame_rate: float = 5.0
var attack_frame_rate: float = 5.0
var skill_frame_rate: float = 5.0

## Height in metres this actor should occupy, feet-to-head.
var world_height: float = 1.8

var current_state: ActorState = ActorState.IDLE
var _frame_index: int = 0
var _frame_elapsed: float = 0.0
var _is_animating: bool = false
var _is_defeated: bool = false
var _target_selected: bool = false
var _uses_model: bool = false
var _model_yaw_offset: float = 0.0
var _target_highlight_tween: Tween
var _death_tween: Tween
var _hit_tween: Tween
var _home_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_home_position = position
	if target_marker != null:
		target_marker.visible = false


func _process(delta: float) -> void:
	if target_marker != null and target_marker.visible:
		target_marker.rotation.y += delta * 1.5
	if _uses_model and not _is_defeated and model_root != null:
		# Gentle idle bob so a static monster model does not read as frozen.
		model_root.position.y = sin(float(Time.get_ticks_msec()) * 0.0022) * 0.045
	if not _is_animating:
		return
	_advance_current_animation(delta)


# --- Visual setup -----------------------------------------------------------

## Billboard sprite driven by animation frames (party characters).
func setup_frames(
	p_idle: Array[Texture2D],
	p_attack: Array[Texture2D],
	p_skill: Array[Texture2D],
	p_idle_rate: float = 5.0,
	p_attack_rate: float = 5.0,
	p_skill_rate: float = 5.0,
	p_world_height: float = 1.8
) -> void:
	idle_frames = p_idle
	attack_frames = p_attack
	skill_frames = p_skill
	idle_frame_rate = p_idle_rate
	attack_frame_rate = p_attack_rate
	skill_frame_rate = p_skill_rate
	world_height = p_world_height
	_uses_model = false
	if sprite != null:
		sprite.visible = true
	if not idle_frames.is_empty():
		_normalise_sprite_scale(idle_frames[0])
	_apply_layout()
	play_idle()


## Single static billboard texture (enemies without an animated sheet).
func setup_static_texture(texture: Texture2D, p_world_height: float = 1.9) -> void:
	world_height = p_world_height
	_uses_model = false
	if sprite != null and texture != null:
		sprite.visible = true
		sprite.texture = texture
		_normalise_sprite_scale(texture)
	_apply_layout()
	play_idle()


## Real 3D model (the monster GLTFs shared with exploration). Normalised so
## the model's own bounding box ends up `p_world_height` metres tall with
## its feet on the actor origin, regardless of the asset's authored scale.
func setup_model_visual(
	model_scene_path: String,
	p_world_height: float = 1.7,
	p_yaw_offset_degrees: float = 0.0
) -> bool:
	if model_root == null:
		return false
	var packed := load(model_scene_path) as PackedScene
	if packed == null:
		push_warning("BattleActor3D: could not load model '%s'" % model_scene_path)
		return false
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return false

	world_height = p_world_height
	_uses_model = true
	_model_yaw_offset = deg_to_rad(p_yaw_offset_degrees)
	if sprite != null:
		sprite.visible = false
	for child in model_root.get_children():
		child.queue_free()
	model_root.add_child(instance)

	var bounds := _merged_aabb(instance)
	if bounds.size.y > 0.001:
		var scale_factor := world_height / bounds.size.y
		instance.scale = Vector3.ONE * scale_factor
		# Drop the model so its lowest point rests on the actor origin.
		instance.position.y = -bounds.position.y * scale_factor
	_apply_layout()
	play_idle()
	return true


## Faces the actor toward a world position (models only -- billboards always
## face camera). Keeps party and enemies looking at each other.
func face_toward(world_position: Vector3) -> void:
	if not _uses_model or model_root == null:
		return
	var flat := world_position - global_position
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return
	model_root.look_at(global_position + flat, Vector3.UP)
	model_root.rotate_y(_model_yaw_offset)


func _normalise_sprite_scale(reference: Texture2D) -> void:
	if sprite == null or reference == null:
		return
	var texture_height := float(reference.get_height())
	if texture_height <= 0.0:
		return
	sprite.pixel_size = world_height / texture_height


func _apply_layout() -> void:
	# Origin is the feet: lift the billboard by half its height so it stands
	# on the floor instead of being buried to the waist.
	if sprite != null and not _uses_model:
		sprite.position.y = world_height * 0.5
	if shadow != null:
		shadow.position.y = 0.02
		var radius := clampf(world_height * 0.3, 0.28, 0.75)
		var shadow_mesh := shadow.mesh as CylinderMesh
		if shadow_mesh != null:
			shadow_mesh.top_radius = radius
			shadow_mesh.bottom_radius = radius
	if target_marker != null:
		target_marker.position.y = 0.03
	if hp_label_3d != null:
		hp_label_3d.position.y = world_height + 0.32


func _merged_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for node in _all_descendants(root):
		var mesh_instance := node as VisualInstance3D
		if mesh_instance == null:
			continue
		var node_aabb := mesh_instance.get_aabb()
		# Express the child's bounds in the model root's own space.
		var local_transform: Transform3D = root.global_transform.affine_inverse() * mesh_instance.global_transform
		node_aabb = local_transform * node_aabb
		if found:
			result = result.merge(node_aabb)
		else:
			result = node_aabb
			found = true
	return result


func _all_descendants(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child in root.get_children():
		nodes.append_array(_all_descendants(child))
	return nodes


# --- Animation states -------------------------------------------------------

func play_idle() -> void:
	if _is_defeated:
		return
	current_state = ActorState.IDLE
	_frame_index = 0
	_frame_elapsed = 0.0
	_is_animating = not _uses_model and not idle_frames.is_empty()
	if _is_animating:
		sprite.texture = idle_frames[0]


func play_attack(on_complete: Callable = Callable()) -> void:
	if _is_defeated:
		return
	current_state = ActorState.ATTACK
	_frame_index = 0
	_frame_elapsed = 0.0
	_is_animating = not _uses_model and not attack_frames.is_empty()
	if _is_animating:
		sprite.texture = attack_frames[0]
	_queue_return_to_idle_after(maxi(attack_frames.size(), 1), attack_frame_rate, on_complete)


func play_skill(on_complete: Callable = Callable()) -> void:
	if _is_defeated:
		return
	current_state = ActorState.SKILL
	_frame_index = 0
	_frame_elapsed = 0.0
	_is_animating = not _uses_model and not skill_frames.is_empty()
	if _is_animating:
		sprite.texture = skill_frames[0]
	_queue_return_to_idle_after(maxi(skill_frames.size(), 1), skill_frame_rate, on_complete)


## Short lunge toward a target and back -- gives an attack a readable
## direction instead of resolving silently in place.
func play_lunge_toward(world_position: Vector3, distance: float = 0.85) -> void:
	if _is_defeated:
		return
	var direction := world_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	face_toward(world_position)
	var lunge_target := _home_position + direction.normalized() * distance
	var tween := create_tween()
	tween.tween_property(self, "position", lunge_target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.12)
	tween.tween_property(self, "position", _home_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func play_hit() -> void:
	if _is_defeated:
		return
	var visual := _visual_node()
	if visual == null:
		return
	if _hit_tween != null and _hit_tween.is_running():
		_hit_tween.kill()
	var base_x: float = visual.position.x
	_hit_tween = create_tween()
	_hit_tween.tween_property(visual, "position:x", base_x + 0.14, 0.05)
	_hit_tween.tween_property(visual, "position:x", base_x - 0.09, 0.04)
	_hit_tween.tween_property(visual, "position:x", base_x, 0.06)


func play_defeated() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	_is_animating = false
	current_state = ActorState.DEFEATED
	set_target_selected(false)
	set_target_marker_visible(false)

	if _death_tween != null and _death_tween.is_running():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	var visual := _visual_node()
	if visual != null:
		_death_tween.tween_property(visual, "scale", Vector3(0.85, 0.05, 0.85) if _uses_model else Vector3.ONE * 0.85, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if sprite != null and not _uses_model:
		_death_tween.tween_property(sprite, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if shadow != null:
		_death_tween.tween_property(shadow, "scale", Vector3.ZERO, 0.45)
	if hp_label_3d != null:
		_death_tween.tween_property(hp_label_3d, "modulate:a", 0.0, 0.35)
	_death_tween.chain().tween_callback(func():
		if _uses_model and model_root != null:
			model_root.visible = false
		actor_death_presented.emit(self)
	)


func _visual_node() -> Node3D:
	return model_root if _uses_model else sprite


# --- HP / targeting ---------------------------------------------------------

func update_hp_display(current_hp: int, max_hp: int) -> void:
	if hp_label_3d == null:
		return
	hp_label_3d.text = "%d/%d" % [current_hp, max_hp]
	var ratio := 0.0 if max_hp <= 0 else float(current_hp) / float(max_hp)
	if ratio > 0.6:
		hp_label_3d.modulate = Color(0.42, 0.92, 0.52, 1.0)
	elif ratio > 0.3:
		hp_label_3d.modulate = Color(0.98, 0.76, 0.24, 1.0)
	else:
		hp_label_3d.modulate = Color(0.94, 0.34, 0.36, 1.0)


func set_target_selected(selected: bool) -> void:
	if _is_defeated:
		selected = false
	_target_selected = selected
	set_target_marker_visible(selected)
	if sprite != null and not _uses_model:
		sprite.modulate = Color(1.14, 1.14, 1.02, 1.0) if selected else Color.WHITE


func set_target_marker_visible(visible_state: bool) -> void:
	var should_show := visible_state and not _is_defeated
	if target_marker != null:
		target_marker.visible = should_show
	if should_show and _target_highlight_tween == null:
		_start_target_marker_pulse()
	elif not should_show and _target_highlight_tween != null:
		_target_highlight_tween.kill()
		_target_highlight_tween = null


func _start_target_marker_pulse() -> void:
	if target_marker == null:
		return
	_target_highlight_tween = create_tween()
	_target_highlight_tween.set_loops()
	_target_highlight_tween.tween_property(target_marker, "scale", Vector3(1.18, 1.18, 1.18), 0.55)
	_target_highlight_tween.tween_property(target_marker, "scale", Vector3.ONE, 0.55)


func is_defeated() -> bool:
	return _is_defeated


func is_target_selected() -> bool:
	return _target_selected


func uses_model() -> bool:
	return _uses_model


# --- Frame animation --------------------------------------------------------

func _advance_current_animation(delta: float) -> void:
	var frames: Array[Texture2D]
	var rate: float
	match current_state:
		ActorState.IDLE:
			frames = idle_frames
			rate = idle_frame_rate
		ActorState.ATTACK:
			frames = attack_frames
			rate = attack_frame_rate
		ActorState.SKILL:
			frames = skill_frames
			rate = skill_frame_rate
		_:
			return

	if frames.is_empty() or sprite == null:
		return

	_frame_elapsed += delta
	var frame_duration := 1.0 / maxf(rate, 0.1)
	while _frame_elapsed >= frame_duration:
		_frame_elapsed -= frame_duration
		_frame_index = (_frame_index + 1) % frames.size()
		sprite.texture = frames[_frame_index]


func _queue_return_to_idle_after(frame_count: int, rate: float, on_complete: Callable) -> void:
	if frame_count <= 0 or rate <= 0.0:
		if on_complete.is_valid():
			on_complete.call()
		play_idle()
		return
	var duration := float(frame_count) / rate + 0.05
	get_tree().create_timer(duration).timeout.connect(func():
		if on_complete.is_valid():
			on_complete.call()
		play_idle()
	, CONNECT_ONE_SHOT)
