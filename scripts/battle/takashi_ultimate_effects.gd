extends Node
class_name TakashiUltimateEffects

## Manages 2D ultimate visual effects (FVX), character glow shaders,
## spinning runic rings, and enemy octagram impact effects during Takashi's Ultimate.

const TAKASHI_ULTIMATE_GLOW_SHADER: Shader = preload("res://shaders/battle/takashi_ultimate_glow.gdshader")

const TAKASHI_ULTIMATE_FVX_TARGET_HEIGHT: float = 230.0
const TAKASHI_ULTIMATE_FVX_ENEMY_FOCUS_SCALE: float = 0.82
const TAKASHI_ULTIMATE_FVX_OFFSET: Vector2 = Vector2(0.0, -118.0)
const TAKASHI_ULTIMATE_FVX_FRAME_RATE: float = 8.0
const TAKASHI_ULTIMATE_FVX_FRAME_PATHS: Array[String] = [
	"res://public/FVX/f1.png",
	"res://public/FVX/f2.png",
	"res://public/FVX/f3.png"
]

const ENEMY_IMPACT_FVX_OFFSET: Vector2 = Vector2(0.0, -112.0)
const ENEMY_IMPACT_FVX_TARGET_HEIGHT: float = 240.0
const ENEMY_IMPACT_CAMERA_FOCUS_OFFSET: Vector2 = Vector2(0.0, -96.0)
const ENEMY_IMPACT_CAMERA_ZOOM: Vector2 = Vector2(1.24, 1.24)
const ENEMY_IMPACT_CAMERA_ZOOM_DURATION: float = 0.32
const ENEMY_IMPACT_CAMERA_ZOOM_OUT_DURATION: float = 0.28
const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)

var player: Node2D
var enemy: Node2D
var effect_layer: Node2D
var player_action_sprite: Sprite2D

var takashi_ultimate_fvx_glow_sprite: Sprite2D
var takashi_ultimate_fvx_sprite: Sprite2D
var takashi_ultimate_character_glow_sprite: Sprite2D

var enemy_impact_fvx_glow_sprite: Sprite2D
var enemy_impact_fvx_sprite: Sprite2D

var takashi_ultimate_fvx_frames: Array[Texture2D] = []
var takashi_ultimate_fvx_playing: bool = false
var takashi_ultimate_fvx_frame_index: int = 0
var takashi_ultimate_fvx_frame_elapsed: float = 0.0


func setup(target_player: Node2D, target_enemy: Node2D, target_effect_layer: Node2D, target_action_sprite: Sprite2D) -> void:
	player = target_player
	enemy = target_enemy
	effect_layer = target_effect_layer
	player_action_sprite = target_action_sprite
	_load_fvx_frames()
	_setup_nodes()


func _load_fvx_frames() -> void:
	takashi_ultimate_fvx_frames.clear()
	for frame_path in TAKASHI_ULTIMATE_FVX_FRAME_PATHS:
		if not FileAccess.file_exists(frame_path):
			continue
		var texture := load(frame_path) as Texture2D
		if texture != null:
			takashi_ultimate_fvx_frames.append(texture)


func _setup_nodes() -> void:
	if player != null:
		takashi_ultimate_fvx_glow_sprite = Sprite2D.new()
		takashi_ultimate_fvx_glow_sprite.name = "RuntimeTakashiUltimateFVXGlow"
		takashi_ultimate_fvx_glow_sprite.visible = false
		takashi_ultimate_fvx_glow_sprite.z_index = -3
		takashi_ultimate_fvx_glow_sprite.centered = true
		takashi_ultimate_fvx_glow_sprite.material = _create_png_glow_shader_material(Color(0.44, 0.9, 1.0, 1.0), 18.0, 1.5, 0.16)
		player.add_child(takashi_ultimate_fvx_glow_sprite)

		takashi_ultimate_fvx_sprite = Sprite2D.new()
		takashi_ultimate_fvx_sprite.name = "RuntimeTakashiUltimateFVX"
		takashi_ultimate_fvx_sprite.visible = false
		takashi_ultimate_fvx_sprite.z_index = -2
		takashi_ultimate_fvx_sprite.centered = true
		takashi_ultimate_fvx_sprite.material = _create_additive_canvas_material()
		player.add_child(takashi_ultimate_fvx_sprite)

		takashi_ultimate_character_glow_sprite = Sprite2D.new()
		takashi_ultimate_character_glow_sprite.name = "RuntimeTakashiUltimateCharacterGlow"
		takashi_ultimate_character_glow_sprite.visible = false
		takashi_ultimate_character_glow_sprite.z_index = -1
		takashi_ultimate_character_glow_sprite.centered = true
		takashi_ultimate_character_glow_sprite.material = _create_png_glow_shader_material(Color(0.5, 0.92, 1.0, 1.0), 13.0, 1.3, 0.14)
		player.add_child(takashi_ultimate_character_glow_sprite)
		sync_effect_layout()

	var parent_node: Node = effect_layer if effect_layer != null else enemy
	if parent_node != null:
		enemy_impact_fvx_glow_sprite = Sprite2D.new()
		enemy_impact_fvx_glow_sprite.name = "RuntimeEnemyImpactFVXGlow"
		enemy_impact_fvx_glow_sprite.visible = false
		enemy_impact_fvx_glow_sprite.z_index = -3
		enemy_impact_fvx_glow_sprite.centered = true
		enemy_impact_fvx_glow_sprite.material = _create_png_glow_shader_material(Color(0.42, 0.88, 1.0, 1.0), 18.0, 1.5, 0.16)
		parent_node.add_child(enemy_impact_fvx_glow_sprite)

		enemy_impact_fvx_sprite = Sprite2D.new()
		enemy_impact_fvx_sprite.name = "RuntimeEnemyImpactFVX"
		enemy_impact_fvx_sprite.visible = false
		enemy_impact_fvx_sprite.z_index = -2
		enemy_impact_fvx_sprite.centered = true
		enemy_impact_fvx_sprite.material = _create_additive_canvas_material()
		parent_node.add_child(enemy_impact_fvx_sprite)
		sync_enemy_impact_fvx_layout(enemy)


func _create_additive_canvas_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _create_png_glow_shader_material(glow_color: Color, glow_radius: float, glow_strength: float, core_alpha: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TAKASHI_ULTIMATE_GLOW_SHADER
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("glow_radius", glow_radius)
	material.set_shader_parameter("glow_strength", glow_strength)
	material.set_shader_parameter("core_alpha", core_alpha)
	return material


func show_takashi_ultimate_character_glow() -> void:
	if player_action_sprite != null:
		player_action_sprite.self_modulate = Color(1.0, 1.12, 1.22, 1.0)
	if takashi_ultimate_character_glow_sprite == null:
		return

	sync_takashi_ultimate_glow_frame()
	takashi_ultimate_character_glow_sprite.visible = true
	takashi_ultimate_character_glow_sprite.modulate = Color(0.56, 0.9, 1.0, 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(takashi_ultimate_character_glow_sprite, "modulate:a", 0.62, 0.28)


func play_takashi_ultimate_fvx_intro(is_valid_state: Callable = Callable(), play_sfx_callable: Callable = Callable()) -> void:
	if takashi_ultimate_fvx_frames.is_empty():
		show_takashi_ultimate_character_glow()
		if play_sfx_callable.is_valid():
			play_sfx_callable.call(&"rumble", 0.75)
		return

	show_takashi_ultimate_character_glow()
	if play_sfx_callable.is_valid():
		play_sfx_callable.call(&"rumble", 0.9)

	var frame_count: int = mini(takashi_ultimate_fvx_frames.size(), 3)
	for frame_index in range(frame_count):
		if is_valid_state.is_valid() and not is_valid_state.call():
			return
		await play_takashi_ultimate_fvx_step(frame_index, frame_index == frame_count - 1, play_sfx_callable)

	hold_takashi_ultimate_fvx()


func play_takashi_ultimate_fvx_step(frame_index: int, keep_visible: bool, play_sfx_callable: Callable = Callable()) -> void:
	if takashi_ultimate_fvx_sprite == null or takashi_ultimate_fvx_glow_sprite == null:
		return
	if frame_index < 0 or frame_index >= takashi_ultimate_fvx_frames.size():
		return

	if play_sfx_callable.is_valid():
		play_sfx_callable.call(&"step", frame_index, keep_visible)

	takashi_ultimate_fvx_playing = false
	var frame_texture: Texture2D = takashi_ultimate_fvx_frames[frame_index]
	takashi_ultimate_fvx_frame_index = frame_index
	takashi_ultimate_fvx_sprite.texture = frame_texture
	takashi_ultimate_fvx_glow_sprite.texture = frame_texture
	sync_effect_layout()

	var base_scale: Vector2 = get_takashi_ultimate_fvx_scale(frame_texture)
	takashi_ultimate_fvx_sprite.visible = true
	takashi_ultimate_fvx_glow_sprite.visible = true
	takashi_ultimate_fvx_sprite.modulate = Color(0.55, 0.92, 1.0, 0.0)
	takashi_ultimate_fvx_glow_sprite.modulate = Color(0.6, 0.95, 1.0, 0.0)
	takashi_ultimate_fvx_sprite.scale = base_scale * 0.84
	takashi_ultimate_fvx_glow_sprite.scale = base_scale * 1.28
	takashi_ultimate_fvx_sprite.rotation = -0.32
	takashi_ultimate_fvx_glow_sprite.rotation = -0.32

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(takashi_ultimate_fvx_sprite, "modulate:a", 0.78, 0.2)
	tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "modulate:a", 0.78, 0.2)
	tween.parallel().tween_property(takashi_ultimate_fvx_sprite, "scale", base_scale, 0.24)
	tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "scale", base_scale * 1.55, 0.24)
	tween.parallel().tween_property(takashi_ultimate_fvx_sprite, "rotation", 0.42, 0.4)
	tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "rotation", 0.42, 0.4)
	tween.tween_interval(0.08)
	if keep_visible:
		tween.tween_property(takashi_ultimate_fvx_sprite, "modulate:a", 0.68, 0.14)
		tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "modulate:a", 0.64, 0.14)
	else:
		var rest_alpha: float = 0.14 + (float(frame_index) * 0.1)
		tween.tween_property(takashi_ultimate_fvx_sprite, "modulate:a", rest_alpha, 0.18)
		tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "modulate:a", rest_alpha, 0.18)
	await tween.finished


func hold_takashi_ultimate_fvx() -> void:
	takashi_ultimate_fvx_playing = true
	takashi_ultimate_fvx_frame_elapsed = 0.0
	if not takashi_ultimate_fvx_frames.is_empty():
		var hold_index: int = mini(2, takashi_ultimate_fvx_frames.size() - 1)
		var hold_texture: Texture2D = takashi_ultimate_fvx_frames[hold_index]
		takashi_ultimate_fvx_frame_index = hold_index
		if takashi_ultimate_fvx_sprite != null:
			takashi_ultimate_fvx_sprite.texture = hold_texture
			takashi_ultimate_fvx_sprite.visible = true
		if takashi_ultimate_fvx_glow_sprite != null:
			takashi_ultimate_fvx_glow_sprite.texture = hold_texture
			takashi_ultimate_fvx_glow_sprite.visible = true
	sync_effect_layout()


func advance(delta: float) -> void:
	if not takashi_ultimate_fvx_playing:
		return
	if takashi_ultimate_fvx_sprite == null or takashi_ultimate_fvx_glow_sprite == null:
		return

	takashi_ultimate_fvx_frame_elapsed += delta
	var flicker: float = 0.72 + 0.28 * sin(takashi_ultimate_fvx_frame_elapsed * TAKASHI_ULTIMATE_FVX_FRAME_RATE * 0.85)
	takashi_ultimate_fvx_sprite.rotation += delta * 0.5
	takashi_ultimate_fvx_glow_sprite.rotation = takashi_ultimate_fvx_sprite.rotation
	takashi_ultimate_fvx_sprite.modulate = Color(0.58, 0.94, 1.0, 0.58 + flicker * 0.24)
	takashi_ultimate_fvx_glow_sprite.modulate = Color(0.62, 0.96, 1.0, 0.46 + flicker * 0.36)
	if takashi_ultimate_character_glow_sprite != null:
		takashi_ultimate_character_glow_sprite.modulate = Color(0.56, 0.9, 1.0, 0.42 + flicker * 0.28)


func fade_out_takashi_ultimate_glow_effect(duration: float) -> void:
	takashi_ultimate_fvx_playing = false
	if player_action_sprite != null:
		player_action_sprite.self_modulate = Color.WHITE

	var has_fvx: bool = takashi_ultimate_fvx_sprite != null and takashi_ultimate_fvx_sprite.visible
	var has_fvx_glow: bool = takashi_ultimate_fvx_glow_sprite != null and takashi_ultimate_fvx_glow_sprite.visible
	var has_char_glow: bool = takashi_ultimate_character_glow_sprite != null and takashi_ultimate_character_glow_sprite.visible

	if has_fvx or has_fvx_glow or has_char_glow:
		var tween := create_tween()
		if has_fvx:
			tween.tween_property(takashi_ultimate_fvx_sprite, "modulate:a", 0.0, duration)
		if has_fvx_glow:
			if has_fvx:
				tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "modulate:a", 0.0, duration)
			else:
				tween.tween_property(takashi_ultimate_fvx_glow_sprite, "modulate:a", 0.0, duration)
		if has_char_glow:
			if has_fvx or has_fvx_glow:
				tween.parallel().tween_property(takashi_ultimate_character_glow_sprite, "modulate:a", 0.0, duration)
			else:
				tween.tween_property(takashi_ultimate_character_glow_sprite, "modulate:a", 0.0, duration)
		await tween.finished
	hide_takashi_ultimate_glow_effect()


func hide_takashi_ultimate_glow_effect() -> void:
	takashi_ultimate_fvx_playing = false
	takashi_ultimate_fvx_frame_elapsed = 0.0
	if player_action_sprite != null:
		player_action_sprite.self_modulate = Color.WHITE
	if takashi_ultimate_fvx_sprite != null:
		takashi_ultimate_fvx_sprite.visible = false
		takashi_ultimate_fvx_sprite.rotation = 0.0
		takashi_ultimate_fvx_sprite.modulate = Color(0.58, 0.94, 1.0, 0.0)
	if takashi_ultimate_fvx_glow_sprite != null:
		takashi_ultimate_fvx_glow_sprite.visible = false
		takashi_ultimate_fvx_glow_sprite.rotation = 0.0
		takashi_ultimate_fvx_glow_sprite.modulate = Color(0.62, 0.96, 1.0, 0.0)
	if takashi_ultimate_character_glow_sprite != null:
		takashi_ultimate_character_glow_sprite.visible = false
		takashi_ultimate_character_glow_sprite.modulate = Color(0.56, 0.9, 1.0, 0.0)


func sync_effect_layout() -> void:
	sync_takashi_ultimate_glow_frame()
	if takashi_ultimate_fvx_sprite == null:
		return

	var fvx_texture: Texture2D = takashi_ultimate_fvx_sprite.texture
	var base_scale: Vector2 = get_takashi_ultimate_fvx_scale(fvx_texture)
	var fvx_position: Vector2 = TAKASHI_ULTIMATE_FVX_OFFSET
	if player_action_sprite != null:
		fvx_position += player_action_sprite.position

	takashi_ultimate_fvx_sprite.position = fvx_position
	takashi_ultimate_fvx_sprite.scale = base_scale
	if takashi_ultimate_fvx_glow_sprite != null:
		takashi_ultimate_fvx_glow_sprite.position = fvx_position
		takashi_ultimate_fvx_glow_sprite.scale = base_scale * 1.5


func sync_takashi_ultimate_glow_frame() -> void:
	if takashi_ultimate_character_glow_sprite == null or player_action_sprite == null:
		return

	takashi_ultimate_character_glow_sprite.texture = player_action_sprite.texture
	takashi_ultimate_character_glow_sprite.position = player_action_sprite.position
	takashi_ultimate_character_glow_sprite.scale = player_action_sprite.scale * 1.18


func get_takashi_ultimate_fvx_scale(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE

	var texture_size: Vector2 = texture.get_size()
	if texture_size.y <= 0.0:
		return Vector2.ONE

	var scale_value: float = TAKASHI_ULTIMATE_FVX_TARGET_HEIGHT / texture_size.y
	return Vector2(scale_value, scale_value)


func shrink_takashi_ultimate_fvx_for_enemy_focus() -> void:
	var has_fvx: bool = takashi_ultimate_fvx_sprite != null and takashi_ultimate_fvx_sprite.visible
	var has_glow: bool = takashi_ultimate_fvx_glow_sprite != null and takashi_ultimate_fvx_glow_sprite.visible
	if not has_fvx and not has_glow:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if has_fvx:
		tween.tween_property(takashi_ultimate_fvx_sprite, "scale", takashi_ultimate_fvx_sprite.scale * TAKASHI_ULTIMATE_FVX_ENEMY_FOCUS_SCALE, 0.3)
	if has_glow:
		if has_fvx:
			tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "scale", takashi_ultimate_fvx_glow_sprite.scale * TAKASHI_ULTIMATE_FVX_ENEMY_FOCUS_SCALE, 0.3)
		else:
			tween.tween_property(takashi_ultimate_fvx_glow_sprite, "scale", takashi_ultimate_fvx_glow_sprite.scale * TAKASHI_ULTIMATE_FVX_ENEMY_FOCUS_SCALE, 0.3)


func play_enemy_octagram_impact(target: Node2D, camera: Camera2D, is_valid_state: Callable = Callable(), play_sfx_callable: Callable = Callable()) -> void:
	shrink_takashi_ultimate_fvx_for_enemy_focus()
	start_enemy_impact_camera_zoom_in(target, camera)
	if play_sfx_callable.is_valid():
		play_sfx_callable.call(&"enemy_wind")
		play_sfx_callable.call(&"chime")
	sync_enemy_impact_fvx_layout(target)
	await play_enemy_octagram_fvx_buildup(target, is_valid_state)


func start_enemy_impact_camera_zoom_in(target: Node2D, camera: Camera2D) -> void:
	if camera == null:
		return

	var target_position: Vector2 = (target.global_position if target != null else Vector2.ZERO) + ENEMY_IMPACT_CAMERA_FOCUS_OFFSET
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", target_position, ENEMY_IMPACT_CAMERA_ZOOM_DURATION)
	tween.parallel().tween_property(camera, "zoom", ENEMY_IMPACT_CAMERA_ZOOM, ENEMY_IMPACT_CAMERA_ZOOM_DURATION)
	tween.parallel().tween_property(camera, "offset", Vector2.ZERO, ENEMY_IMPACT_CAMERA_ZOOM_DURATION)


func play_enemy_impact_camera_zoom_out(camera: Camera2D, viewport_size: Vector2) -> void:
	if camera == null:
		return

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", viewport_size * 0.5, ENEMY_IMPACT_CAMERA_ZOOM_OUT_DURATION)
	tween.parallel().tween_property(camera, "zoom", Vector2.ONE, ENEMY_IMPACT_CAMERA_ZOOM_OUT_DURATION)
	tween.parallel().tween_property(camera, "offset", Vector2.ZERO, ENEMY_IMPACT_CAMERA_ZOOM_OUT_DURATION)
	await tween.finished


func play_enemy_octagram_fvx_buildup(target: Node2D, is_valid_state: Callable = Callable()) -> void:
	if takashi_ultimate_fvx_frames.is_empty():
		return

	var frame_count: int = mini(takashi_ultimate_fvx_frames.size(), 3)
	for frame_index in range(frame_count):
		if is_valid_state.is_valid() and not is_valid_state.call():
			return
		await play_enemy_impact_fvx_step(frame_index, frame_index == frame_count - 1, target)


func play_enemy_impact_fvx_step(frame_index: int, keep_visible: bool, target: Node2D) -> void:
	if enemy_impact_fvx_sprite == null or enemy_impact_fvx_glow_sprite == null:
		return
	if frame_index < 0 or frame_index >= takashi_ultimate_fvx_frames.size():
		return

	var frame_texture: Texture2D = takashi_ultimate_fvx_frames[frame_index]
	enemy_impact_fvx_sprite.texture = frame_texture
	enemy_impact_fvx_glow_sprite.texture = frame_texture
	sync_enemy_impact_fvx_layout(target)

	var base_scale: Vector2 = get_enemy_impact_fvx_scale(frame_texture)
	enemy_impact_fvx_sprite.visible = true
	enemy_impact_fvx_glow_sprite.visible = true
	enemy_impact_fvx_sprite.modulate = Color(0.48, 0.88, 1.0, 0.0)
	enemy_impact_fvx_glow_sprite.modulate = Color(0.55, 0.94, 1.0, 0.0)
	enemy_impact_fvx_sprite.scale = base_scale * 0.8
	enemy_impact_fvx_glow_sprite.scale = base_scale * 1.2
	enemy_impact_fvx_sprite.rotation = -0.45
	enemy_impact_fvx_glow_sprite.rotation = -0.45

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(enemy_impact_fvx_sprite, "modulate:a", 0.72, 0.16)
	tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", 0.72, 0.16)
	tween.parallel().tween_property(enemy_impact_fvx_sprite, "scale", base_scale, 0.18)
	tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "scale", base_scale * 1.48, 0.18)
	tween.parallel().tween_property(enemy_impact_fvx_sprite, "rotation", 0.52, 0.32)
	tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "rotation", 0.52, 0.32)
	tween.tween_interval(0.04)
	if keep_visible:
		tween.tween_property(enemy_impact_fvx_sprite, "modulate:a", 0.62, 0.12)
		tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", 0.58, 0.12)
	else:
		var rest_alpha: float = 0.16 + (float(frame_index) * 0.12)
		tween.tween_property(enemy_impact_fvx_sprite, "modulate:a", rest_alpha, 0.14)
		tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", rest_alpha, 0.14)
	await tween.finished


func fade_out_enemy_impact_fvx(duration: float) -> void:
	var has_impact: bool = enemy_impact_fvx_sprite != null and enemy_impact_fvx_sprite.visible
	var has_glow: bool = enemy_impact_fvx_glow_sprite != null and enemy_impact_fvx_glow_sprite.visible

	if has_impact or has_glow:
		var tween := create_tween()
		if has_impact:
			tween.tween_property(enemy_impact_fvx_sprite, "modulate:a", 0.0, duration)
		if has_glow:
			if has_impact:
				tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", 0.0, duration)
			else:
				tween.tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", 0.0, duration)
		await tween.finished
	hide_enemy_impact_fvx()


func hide_enemy_impact_fvx() -> void:
	if enemy_impact_fvx_sprite != null:
		enemy_impact_fvx_sprite.visible = false
		enemy_impact_fvx_sprite.rotation = 0.0
		enemy_impact_fvx_sprite.modulate = Color(0.48, 0.88, 1.0, 0.0)
	if enemy_impact_fvx_glow_sprite != null:
		enemy_impact_fvx_glow_sprite.visible = false
		enemy_impact_fvx_glow_sprite.rotation = 0.0
		enemy_impact_fvx_glow_sprite.modulate = Color(0.55, 0.94, 1.0, 0.0)


func sync_enemy_impact_fvx_layout(target: Node2D = null) -> void:
	if enemy_impact_fvx_sprite == null:
		return

	var fvx_texture: Texture2D = enemy_impact_fvx_sprite.texture
	var base_scale: Vector2 = get_enemy_impact_fvx_scale(fvx_texture)
	var impact_position: Vector2 = ENEMY_IMPACT_FVX_OFFSET
	if target != null:
		impact_position += target.global_position if effect_layer != null else target.position

	enemy_impact_fvx_sprite.position = impact_position
	enemy_impact_fvx_sprite.scale = base_scale
	if enemy_impact_fvx_glow_sprite != null:
		enemy_impact_fvx_glow_sprite.position = impact_position
		enemy_impact_fvx_glow_sprite.scale = base_scale * 1.45


func get_enemy_impact_fvx_scale(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE

	var texture_size: Vector2 = texture.get_size()
	if texture_size.y <= 0.0:
		return Vector2.ONE

	var scale_value: float = ENEMY_IMPACT_FVX_TARGET_HEIGHT / texture_size.y
	return Vector2(scale_value, scale_value)
