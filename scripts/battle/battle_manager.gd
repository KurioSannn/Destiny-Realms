extends Node
class_name BattleManager

enum BattleState {
	PLAYER_TURN,
	ACTION_RESOLUTION,
	ENEMY_TURN,
	WIN,
	LOSE
}

const PLAYER_MAX_HP: int = 100
const ENEMY_MAX_HP: int = 120
const BASIC_ATTACK_DAMAGE: int = 12
const BASIC_ATTACK_TIMING_BONUS_DAMAGE: int = 8
const BASIC_ATTACK_ENERGY: int = 25
const BASIC_ATTACK_TIMING_BONUS_ENERGY: int = 5
const SKILL_DAMAGE: int = 25
const SKILL_ENERGY: int = 15
const SKILL_POINT_GAIN_BASIC: int = 1
const SKILL_POINT_COST_SKILL: int = 1
const MAX_SKILL_POINTS: int = 5
const START_SKILL_POINTS: int = MAX_SKILL_POINTS
const ULTIMATE_DAMAGE: int = 45
const MAX_ULTIMATE_ENERGY: int = 100
const ENEMY_BASE_DAMAGE: int = 14
const TURN_DELAY_SECONDS: float = 0.6
const FLOATING_TEXT_RISE: float = 42.0
const CAMERA_SHAKE_OFFSET: float = 6.0
const BASIC_CETAR_HIT_COUNT: int = 3
const BASIC_CETAR_INTERVAL: float = 0.055
const BASIC_CETAR_TARGET_SHAKE: float = 8.0
const BASIC_CETAR_CAMERA_SHAKE: float = 4.0
const BASIC_CETAR_TEXT_RISE: float = 28.0
const SKILL_RIFT_PROJECTILE_DURATION: float = 0.22
const SKILL_RIFT_IMPACT_PULSE_COUNT: int = 3
const SKILL_RIFT_IMPACT_INTERVAL: float = 0.06
const SKILL_RIFT_CAMERA_SHAKE: float = 7.0
const SKILL_RIFT_TARGET_SHAKE: float = 10.0
const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const PLAYER_VIEWPORT_POSITION: Vector2 = Vector2(0.34, 0.70)
const ENEMY_VIEWPORT_POSITION: Vector2 = Vector2(0.68, 0.70)
const PLAYER_ACTION_SPRITE_SCALE: Vector2 = Vector2(0.18, 0.18)
const PLAYER_ACTION_SPRITE_GROUND_Y: float = 46.0
const PROLOGUE_SCENE_PATH: String = "res://scenes/prologue/prologue_scene.tscn"
const ENDING_SCENE_PATH: String = "res://scenes/ending/ending_scene.tscn"
const ULTIMATE_FRAME_COUNT: int = 88
const ULTIMATE_FRAME_RATE: float = 15.0
const ULTIMATE_FRAME_PATH_FORMAT: String = "res://public/ultimate_frames/takashi_ultimate_%03d.jpg"
const ULTIMATE_AUDIO_PATH: String = "res://public/TakashiUltimateAudio.ogg"
const TAKASHI_IDLE_TEXTURE: Texture2D = preload("res://public/IdleTaka.png")
const TAKASHI_IDLE_FRAME_RATE: float = 5.0
const TAKASHI_IDLE_FRAME_PATHS: Array[String] = [
	"res://public/idle_Takashi/1.png",
	"res://public/idle_Takashi/2.png",
	"res://public/idle_Takashi/3.png",
	"res://public/idle_Takashi/4.png"
]
const TAKASHI_BASIC_TEXTURE: Texture2D = preload("res://public/BasicAttackTaka.png")
const TAKASHI_BASIC_FRAME_RATE: float = 5.0
const TAKASHI_BASIC_FRAME_PATHS: Array[String] = [
	"res://public/idleattack/a1.png",
	"res://public/idleattack/a2.png",
	"res://public/idleattack/a3.png",
	"res://public/idleattack/a4.png"
]
const TAKASHI_SKILL_TEXTURE: Texture2D = preload("res://public/SkillTaka.png")
const TAKASHI_SKILL_FRAME_RATE: float = 5.0
const TAKASHI_SKILL_FRAME_PATHS: Array[String] = [
	"res://public/idleskill/s1.png",
	"res://public/idleskill/s2.png",
	"res://public/idleskill/s3.png",
	"res://public/idleskill/s4.png"
]
const TAKASHI_ULTIMATE_TEXTURE: Texture2D = preload("res://public/UltiTaka.png")
const TAKASHI_ULTI_PRE_FRAME_RATE: float = 4.0
const TAKASHI_ULTI_PRE_FRAME_PATHS: Array[String] = [
	"res://public/ultiidle/u1.png",
	"res://public/ultiidle/u2.png",
	"res://public/ultiidle/u3.png"
]
const TAKASHI_ULTI_POST_FRAME_RATE: float = 5.0
const TAKASHI_ULTI_POST_FRAME_PATHS: Array[String] = [
	"res://public/ultiidle/u4.png",
	"res://public/ultiidle/u5.png",
	"res://public/ultiidle/u6.png",
	"res://public/ultiidle/u7.png"
]
const TAKASHI_ULTIMATE_FVX_FRAME_RATE: float = 9.0
const TAKASHI_ULTIMATE_FVX_TARGET_HEIGHT: float = 360.0
const TAKASHI_ULTIMATE_FVX_ENEMY_FOCUS_SCALE: float = 0.55
const TAKASHI_ULTIMATE_FVX_OFFSET: Vector2 = Vector2(0.0, -36.0)
const TAKASHI_ULTIMATE_FVX_FRAME_PATHS: Array[String] = [
	"res://public/fvx/FVX1.png",
	"res://public/fvx/FVX2.png",
	"res://public/fvx/FVX3.png"
]
const TAKASHI_ULTIMATE_GLOW_SHADER_CODE: String = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float glow_radius = 7.0;
uniform float glow_strength = 1.4;
uniform float core_alpha = 0.16;

float sample_ring(sampler2D tex, vec2 uv, vec2 offset) {
	float total = 0.0;
	total += texture(tex, uv + vec2(offset.x, 0.0)).a;
	total += texture(tex, uv + vec2(-offset.x, 0.0)).a;
	total += texture(tex, uv + vec2(0.0, offset.y)).a;
	total += texture(tex, uv + vec2(0.0, -offset.y)).a;
	total += texture(tex, uv + vec2(offset.x, offset.y)).a;
	total += texture(tex, uv + vec2(-offset.x, offset.y)).a;
	total += texture(tex, uv + vec2(offset.x, -offset.y)).a;
	total += texture(tex, uv + vec2(-offset.x, -offset.y)).a;
	return total / 8.0;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 near_offset = TEXTURE_PIXEL_SIZE * glow_radius;
	vec2 mid_offset = near_offset * 2.2;
	vec2 far_offset = near_offset * 3.8;

	float near_ring = sample_ring(TEXTURE, UV, near_offset);
	float mid_ring = sample_ring(TEXTURE, UV, mid_offset);
	float far_ring = sample_ring(TEXTURE, UV, far_offset);
	float outer = (near_ring * 0.5) + (mid_ring * 0.32) + (far_ring * 0.18);

	float raw_aura = (outer * glow_strength) + (source.a * core_alpha);
	float aura = 1.0 - exp(-raw_aura * 1.6);
	COLOR = vec4(glow_color.rgb, aura * glow_color.a);
}
"""
const ULTIMATE_CAMERA_ZOOM: Vector2 = Vector2(1.85, 1.85)
const ULTIMATE_CAMERA_FOCUS_OFFSET: Vector2 = Vector2(12.0, -92.0)
const ULTIMATE_ZOOM_DURATION: float = 0.6
const ULTIMATE_ZOOM_OUT_DURATION: float = 0.28
const ENEMY_IMPACT_FOCUS_OFFSET: Vector2 = Vector2(0.0, -125.0)
const ENEMY_IMPACT_ZOOM_DURATION: float = 0.38
const ENEMY_IMPACT_ZOOM_OUT_DURATION: float = 0.32
const ENEMY_IMPACT_FVX_TARGET_HEIGHT: float = 320.0
const ENEMY_IMPACT_WIND_VOLUME_SCALE: float = 0.55
const OCTAGRAM_CHIME_DURATION: float = 0.8
const OCTAGRAM_CHIME_VOLUME: float = 0.46
const EFFECT_SLASH_TEXTURE: Texture2D = preload("res://public/effects/slash.png")
const EFFECT_SPLASH_TEXTURE: Texture2D = preload("res://public/effects/Splash.png")
const EFFECT_PARTICLE_TEXTURE: Texture2D = preload("res://public/effects/Particle Efect.png")
const SFX_SAMPLE_RATE: float = 22050.0
const BASIC_SFX_START_HZ: float = 520.0
const BASIC_SFX_END_HZ: float = 180.0
const BASIC_SFX_DURATION: float = 0.24
const BASIC_SFX_VOLUME: float = 0.38
const BASIC_SFX_SHIMMER_MIX: float = 0.08
const BASIC_SFX_SUB_MIX: float = 0.2
const BASIC_SFX_NOISE_MIX: float = 0.26
const BASIC_SFX_CRYSTAL_MIX: float = 0.62
const ULTIMATE_ZOOM_WIND_DURATION: float = 0.55
const ULTIMATE_ZOOM_WIND_VOLUME: float = 0.52
const ULTIMATE_ZOOM_OUT_WIND_DURATION: float = 0.42
const ULTIMATE_SHATTER_DURATION: float = 0.78
const ULTIMATE_SHATTER_VOLUME: float = 1.1
const ULTIMATE_HIT_SFX_DURATION: float = 0.74
const ULTIMATE_HIT_SFX_VOLUME: float = 1.08
const ULTIMATE_CHARGE_RUMBLE_DURATION: float = 0.82
const ULTIMATE_CHARGE_RUMBLE_VOLUME: float = 0.78
const ULTIMATE_GLASS_BURST_DURATION: float = 0.56
const ULTIMATE_GLASS_BURST_VOLUME: float = 0.82
const ULTIMATE_DEEP_BOOM_DURATION: float = 0.88
const ULTIMATE_DEEP_BOOM_VOLUME: float = 0.96
const ULTIMATE_CRING_NOISE_DURATION: float = 0.62
const ULTIMATE_CRING_NOISE_VOLUME: float = 0.74
const ULTIMATE_AUDIO_VOLUME_DB: float = 5.0
const SKILL_SFX_START_HZ: float = 210.0
const SKILL_SFX_END_HZ: float = 920.0
const IMPACT_SFX_START_HZ: float = 120.0
const IMPACT_SFX_END_HZ: float = 46.0

@onready var player: Combatant = $"../Player"
@onready var enemy: Combatant = $"../Enemy"
@onready var ui: BattleUI = $"../CanvasLayer/BattleUI"
@onready var timing_bar: TimingBar = $"../CanvasLayer/BattleUI/TimingBar"
@onready var battle_scene: Node2D = $".."
@onready var battle_camera: Camera2D = get_node_or_null("../BattleCamera") as Camera2D
@onready var forest_background: Sprite2D = get_node_or_null("../Background/ForestBackground") as Sprite2D
@onready var sky: Polygon2D = get_node_or_null("../Background/Sky") as Polygon2D
@onready var forest_line: Polygon2D = get_node_or_null("../Background/ForestLine") as Polygon2D
@onready var ground: Polygon2D = get_node_or_null("../Background/Ground") as Polygon2D
@onready var battle_bgm: AudioStreamPlayer = get_node_or_null("../BattleBgm") as AudioStreamPlayer
@onready var battle_intro_overlay: ColorRect = get_node_or_null("../CanvasLayer/BattleIntroOverlay") as ColorRect
@onready var battle_intro_label: Label = get_node_or_null("../CanvasLayer/BattleIntroOverlay/IntroLabel") as Label
@onready var ultimate_frame_player: TextureRect = get_node_or_null("../CanvasLayer/UltimateFramePlayer") as TextureRect
@onready var ultimate_audio_player: AudioStreamPlayer = get_node_or_null("../CanvasLayer/UltimateAudioPlayer") as AudioStreamPlayer
@onready var player_action_sprite: Sprite2D = get_node_or_null("../Player/ActionSprite") as Sprite2D
@onready var canvas_layer: CanvasLayer = get_node_or_null("../CanvasLayer") as CanvasLayer
@onready var bottom_vignette: Polygon2D = get_node_or_null("../StageGroundEffects/BottomVignette") as Polygon2D
@onready var player_ground_shadow: Polygon2D = get_node_or_null("../StageGroundEffects/PlayerGroundShadow") as Polygon2D
@onready var enemy_ground_shadow: Polygon2D = get_node_or_null("../StageGroundEffects/EnemyGroundShadow") as Polygon2D

var state: int = BattleState.PLAYER_TURN
var ultimate_energy: int = 0
var skill_points: int = START_SKILL_POINTS
var ultimate_frames: Array[Texture2D] = []
var effect_layer: Node2D
var screen_flash: ColorRect
var basic_sfx_player: AudioStreamPlayer
var skill_sfx_player: AudioStreamPlayer
var impact_sfx_player: AudioStreamPlayer
var cetar_sfx_player: AudioStreamPlayer
var sring_sfx_player: AudioStreamPlayer
var skill_release_sfx_player: AudioStreamPlayer
var rift_crack_sfx_player: AudioStreamPlayer
var ultimate_zoom_sfx_player: AudioStreamPlayer
var ultimate_shatter_sfx_player: AudioStreamPlayer
var octagram_chime_sfx_player: AudioStreamPlayer
var ultimate_charge_sfx_player: AudioStreamPlayer
var ultimate_glass_sfx_player: AudioStreamPlayer
var ultimate_boom_sfx_player: AudioStreamPlayer
var ultimate_cring_sfx_player: AudioStreamPlayer
var takashi_idle_frames: Array[Texture2D] = []
var idle_animation_playing: bool = false
var idle_frame_index: int = 0
var idle_frame_elapsed: float = 0.0
var takashi_basic_frames: Array[Texture2D] = []
var basic_animation_playing: bool = false
var basic_frame_index: int = 0
var basic_frame_elapsed: float = 0.0
var takashi_skill_frames: Array[Texture2D] = []
var skill_animation_playing: bool = false
var skill_frame_index: int = 0
var skill_frame_elapsed: float = 0.0
var takashi_ulti_pre_frames: Array[Texture2D] = []
var takashi_ulti_post_frames: Array[Texture2D] = []
var takashi_ultimate_fvx_frames: Array[Texture2D] = []
var takashi_ultimate_fvx_sprite: Sprite2D
var takashi_ultimate_fvx_glow_sprite: Sprite2D
var takashi_ultimate_character_glow_sprite: Sprite2D
var takashi_ultimate_fvx_playing: bool = false
var takashi_ultimate_fvx_frame_index: int = 0
var takashi_ultimate_fvx_frame_elapsed: float = 0.0
var battle_ui_visible_before_ultimate: bool = true
var enemy_impact_fvx_sprite: Sprite2D
var enemy_impact_fvx_glow_sprite: Sprite2D


func _ready() -> void:
	_setup_battle_bgm()
	player.setup("Takashi", PLAYER_MAX_HP, BASIC_ATTACK_DAMAGE)
	enemy.setup("Lesser Abyss", ENEMY_MAX_HP, ENEMY_BASE_DAMAGE)

	ui.attack_pressed.connect(_on_attack_pressed)
	ui.skill_pressed.connect(_on_skill_pressed)
	ui.ultimate_pressed.connect(_on_ultimate_pressed)
	ui.restart_pressed.connect(_on_restart_pressed)
	ui.confirm_pressed.connect(_on_confirm_pressed)
	if battle_camera != null:
		battle_camera.enabled = true
	if ultimate_frame_player != null:
		ultimate_frame_player.visible = false
	if ultimate_audio_player != null:
		ultimate_audio_player.stream = load(ULTIMATE_AUDIO_PATH) as AudioStream
	_setup_takashi_idle_frames()
	_setup_takashi_basic_frames()
	_setup_takashi_skill_frames()
	_setup_takashi_ulti_pre_frames()
	_setup_takashi_ulti_post_frames()
	_setup_takashi_ultimate_fvx_frames()
	_start_player_idle_animation()
	_load_ultimate_frames()

	await get_tree().process_frame
	_setup_battle_effects()
	_apply_runtime_layout()
	restart_battle()
	_play_battle_intro_effect()


func _process(delta: float) -> void:
	_advance_player_idle_animation(delta)
	_advance_player_basic_animation(delta)
	_advance_player_skill_animation(delta)
	_advance_takashi_ultimate_fvx(delta)


func restart_battle() -> void:
	_start_player_idle_animation()
	_reset_battle_values()
	_begin_player_turn("A Lesser Abyss appears. Choose Takashi's first action.")


func _reset_battle_values() -> void:
	player.reset_hp()
	enemy.reset_hp()
	ultimate_energy = 0
	skill_points = START_SKILL_POINTS
	_reset_camera()
	_hide_takashi_ultimate_glow_effect()
	timing_bar.cancel_window()
	ui.set_timing_mode(false)
	ui.set_restart_visible(false)
	_refresh_player_status_ui()
	_refresh_energy_ui()
	_refresh_skill_points_ui()


func _apply_runtime_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	if battle_camera != null:
		battle_camera.enabled = true
		battle_camera.position = viewport_size * 0.5
		battle_camera.offset = Vector2.ZERO

	if forest_background != null and forest_background.texture != null:
		var texture_size: Vector2 = forest_background.texture.get_size()
		var cover_scale: float = maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
		forest_background.position = Vector2.ZERO
		forest_background.scale = Vector2(cover_scale, cover_scale)

	if sky != null:
		sky.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(viewport_size.x, 0.0),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if forest_line != null:
		forest_line.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.31),
			Vector2(viewport_size.x * 0.08, viewport_size.y * 0.22),
			Vector2(viewport_size.x * 0.16, viewport_size.y * 0.34),
			Vector2(viewport_size.x * 0.28, viewport_size.y * 0.21),
			Vector2(viewport_size.x * 0.43, viewport_size.y * 0.36),
			Vector2(viewport_size.x * 0.57, viewport_size.y * 0.22),
			Vector2(viewport_size.x * 0.72, viewport_size.y * 0.36),
			Vector2(viewport_size.x * 0.86, viewport_size.y * 0.21),
			Vector2(viewport_size.x, viewport_size.y * 0.31),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if ground != null:
		ground.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.72),
			Vector2(viewport_size.x, viewport_size.y * 0.69),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])

	player.z_index = 5
	enemy.z_index = 5
	var player_home_position: Vector2 = Vector2(viewport_size.x * PLAYER_VIEWPORT_POSITION.x, viewport_size.y * PLAYER_VIEWPORT_POSITION.y)
	var enemy_home_position: Vector2 = Vector2(viewport_size.x * ENEMY_VIEWPORT_POSITION.x, viewport_size.y * ENEMY_VIEWPORT_POSITION.y)
	player.set_home_position(player_home_position)
	enemy.set_home_position(enemy_home_position)
	_apply_player_action_sprite_grounding()
	_apply_stage_grounding(viewport_size, player_home_position, enemy_home_position)


func _apply_stage_grounding(viewport_size: Vector2, player_home_position: Vector2, enemy_home_position: Vector2) -> void:
	if bottom_vignette != null:
		bottom_vignette.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.74),
			Vector2(viewport_size.x, viewport_size.y * 0.70),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])

	if player_ground_shadow != null:
		player_ground_shadow.position = player_home_position + Vector2(0.0, PLAYER_ACTION_SPRITE_GROUND_Y + 4.0)

	if enemy_ground_shadow != null:
		enemy_ground_shadow.position = enemy_home_position + Vector2(0.0, 48.0)


func _apply_player_action_sprite_grounding() -> void:
	if player_action_sprite == null:
		return

	player_action_sprite.scale = PLAYER_ACTION_SPRITE_SCALE
	if player_action_sprite.texture == null:
		return

	var texture_size: Vector2 = player_action_sprite.texture.get_size()
	var visual_bottom: float = texture_size.y
	var image: Image = player_action_sprite.texture.get_image()
	if image != null:
		var used_rect: Rect2i = image.get_used_rect()
		if used_rect.size.y > 0:
			visual_bottom = float(used_rect.position.y + used_rect.size.y)

	var visual_bottom_from_center: float = visual_bottom - texture_size.y * 0.5
	player_action_sprite.position.y = PLAYER_ACTION_SPRITE_GROUND_Y - visual_bottom_from_center * PLAYER_ACTION_SPRITE_SCALE.y


func _play_battle_intro_effect() -> void:
	if battle_intro_overlay == null:
		return

	battle_intro_overlay.visible = true
	battle_intro_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if battle_intro_label != null:
		battle_intro_label.position.x = 0.0
		battle_intro_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var label_tween: Tween = create_tween()
		label_tween.tween_property(battle_intro_label, "position:x", 22.0, 0.32)
		label_tween.tween_property(battle_intro_label, "modulate:a", 0.0, 0.35)

	var overlay_tween: Tween = create_tween()
	overlay_tween.tween_interval(0.28)
	overlay_tween.tween_property(battle_intro_overlay, "modulate:a", 0.0, 0.45)
	overlay_tween.tween_callback(Callable(self, "_hide_battle_intro_overlay"))


func _hide_battle_intro_overlay() -> void:
	if battle_intro_overlay != null:
		battle_intro_overlay.visible = false


func _begin_player_turn(log_text: String = "Your turn. Choose an action.") -> void:
	if _is_battle_over():
		return

	state = BattleState.PLAYER_TURN
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	ui.set_restart_visible(true)
	ui.set_turn_order_highlight(true)
	_update_action_buttons(true)


func _begin_enemy_turn(log_text: String = "Enemy is preparing to attack.") -> void:
	if _is_battle_over():
		return

	state = BattleState.ENEMY_TURN
	_start_player_idle_animation()
	ui.set_turn_text("Enemy Turn")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	ui.set_turn_order_highlight(false)
	_update_action_buttons(false)

	await get_tree().create_timer(TURN_DELAY_SECONDS).timeout
	if state == BattleState.ENEMY_TURN:
		_enemy_attack()


func _enemy_attack() -> void:
	var damage: int = enemy.base_attack_damage
	var log_text: String = "Enemy attacks for %d damage." % damage

	await enemy.play_attack_movement(player)
	if state != BattleState.ENEMY_TURN:
		return

	_play_impact_sfx()
	_spawn_enemy_claw_effect(player)
	_spawn_hit_spark(player, Color(1.0, 0.4, 0.42, 1.0))
	player.take_damage(damage)
	_refresh_player_status_ui()
	_show_floating_damage(player, damage)
	await player.play_hit_feedback()
	_shake_camera()

	if player.is_defeated():
		_lose("You were defeated.")
		return

	_begin_player_turn(log_text)


func _on_attack_pressed() -> void:
	if state != BattleState.PLAYER_TURN:
		return

	state = BattleState.ACTION_RESOLUTION
	_set_player_action_texture(TAKASHI_BASIC_TEXTURE)
	_update_action_buttons(false)
	ui.set_turn_text("Void Strike")
	ui.set_battle_log("Void Strike!")
	await _resolve_basic_attack()


func _resolve_basic_attack() -> void:
	if state != BattleState.ACTION_RESOLUTION:
		return

	var damage: int = BASIC_ATTACK_DAMAGE
	var energy_gain: int = BASIC_ATTACK_ENERGY

	_play_basic_sfx()
	await player.play_attack_movement(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		return

	_spawn_basic_slash_effect(enemy)
	await get_tree().create_timer(0.08).timeout
	if state != BattleState.ACTION_RESOLUTION:
		return

	enemy.take_damage(damage)
	_show_floating_damage(enemy, damage)
	await _play_basic_cetar_impact(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		return

	await enemy.play_hit_feedback()
	_shake_camera()
	_add_ultimate_energy(energy_gain)
	_add_skill_points(SKILL_POINT_GAIN_BASIC)
	_finish_player_action("Void Strike deals %d damage, gains %d energy, and restores %d Skill Point." % [damage, energy_gain, SKILL_POINT_GAIN_BASIC])


func _on_confirm_pressed() -> void:
	if state == BattleState.PLAYER_TURN:
		_on_attack_pressed()


func _on_skill_pressed() -> void:
	if state != BattleState.PLAYER_TURN or skill_points < SKILL_POINT_COST_SKILL:
		return

	state = BattleState.ACTION_RESOLUTION
	_set_player_action_texture(TAKASHI_SKILL_TEXTURE)
	_play_skill_sfx()
	_update_action_buttons(false)
	ui.set_turn_text("Triangle Rift")
	ui.set_battle_log("Triangle Rift charging...")
	_spend_skill_points(SKILL_POINT_COST_SKILL)
	_spawn_skill_charge_effect(player)
	await ui.play_skill_cast_feedback()
	if state != BattleState.ACTION_RESOLUTION:
		return

	ui.set_battle_log("Triangle Rift spends %d Skill Point and generates %d energy." % [SKILL_POINT_COST_SKILL, SKILL_ENERGY])
	await player.play_skill_movement(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		return

	await _resolve_triangle_rift_damage()
	if state != BattleState.ACTION_RESOLUTION:
		return

	_add_ultimate_energy(SKILL_ENERGY)
	_finish_player_action("Triangle Rift deals %d damage." % SKILL_DAMAGE)


func _on_ultimate_pressed() -> void:
	if state != BattleState.PLAYER_TURN or ultimate_energy < MAX_ULTIMATE_ENERGY:
		return

	state = BattleState.ACTION_RESOLUTION
	_update_action_buttons(false)
	ui.set_turn_text("Octagram Fragment")
	ui.set_battle_log("Octagram Fragment awakens.")
	ultimate_energy = 0
	_refresh_energy_ui()

	_set_battle_ui_for_ultimate(false)
	_start_ultimate_camera_zoom_in()
	await _play_takashi_ultimate_fvx_intro()
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		_set_battle_ui_for_ultimate(true)
		return
	await _play_takashi_ulti_pre_animation()
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		_set_battle_ui_for_ultimate(true)
		return
	await _wait_for_remaining_ultimate_zoom_in()
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		_set_battle_ui_for_ultimate(true)
		return

	await _play_ultimate_sequence()
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		_set_battle_ui_for_ultimate(true)
		return

	_play_ultimate_shatter_sfx()
	_play_ultimate_glass_burst_sfx(0.9)
	_play_ultimate_cring_noise_sfx(0.65)
	_play_ultimate_deep_boom_sfx(0.65)
	_play_screen_flash(Color(0.72, 0.95, 1.0, 0.24), 0.12)
	_shake_camera_with_strength(7.0)
	await _play_takashi_ulti_post_animation()
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		_set_battle_ui_for_ultimate(true)
		return

	await _play_ultimate_camera_zoom_out()
	_set_battle_ui_for_ultimate(true)
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		return

	await player.play_ultimate_feedback()
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		return

	await player.play_skill_movement(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		return

	await _play_enemy_octagram_impact()
	if state != BattleState.ACTION_RESOLUTION:
		_hide_takashi_ultimate_glow_effect()
		_hide_enemy_impact_fvx()
		return

	enemy.take_damage(ULTIMATE_DAMAGE)
	_show_floating_damage(enemy, ULTIMATE_DAMAGE)
	await enemy.play_hit_feedback()
	await _fade_out_takashi_ultimate_glow_effect(0.26)
	await _play_enemy_impact_camera_zoom_out()
	_shake_camera()
	_finish_player_action("Octagram Fragment deals %d damage and consumes all energy." % ULTIMATE_DAMAGE)


func _set_battle_ui_for_ultimate(visible: bool) -> void:
	if ui == null:
		return

	if visible:
		ui.visible = battle_ui_visible_before_ultimate
		return

	battle_ui_visible_before_ultimate = ui.visible
	ui.visible = false


func _start_ultimate_camera_zoom_in() -> void:
	if battle_camera == null:
		return

	_play_ultimate_zoom_sfx()
	var target_position: Vector2 = player.global_position + ULTIMATE_CAMERA_FOCUS_OFFSET
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(battle_camera, "position", target_position, ULTIMATE_ZOOM_DURATION)
	tween.parallel().tween_property(battle_camera, "zoom", ULTIMATE_CAMERA_ZOOM, ULTIMATE_ZOOM_DURATION)
	tween.parallel().tween_property(battle_camera, "offset", Vector2.ZERO, ULTIMATE_ZOOM_DURATION)


func _wait_for_remaining_ultimate_zoom_in() -> void:
	var pre_animation_duration: float = 0.0
	if TAKASHI_ULTI_PRE_FRAME_RATE > 0.0:
		pre_animation_duration = float(takashi_ulti_pre_frames.size()) / TAKASHI_ULTI_PRE_FRAME_RATE

	var remaining_duration: float = ULTIMATE_ZOOM_DURATION - pre_animation_duration
	if remaining_duration <= 0.0:
		return

	await get_tree().create_timer(remaining_duration).timeout


func _play_ultimate_camera_zoom_out() -> void:
	if battle_camera == null:
		return

	_play_ultimate_zoom_out_wind_sfx()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(battle_camera, "position", viewport_size * 0.5, ULTIMATE_ZOOM_OUT_DURATION)
	tween.parallel().tween_property(battle_camera, "zoom", Vector2.ONE, ULTIMATE_ZOOM_OUT_DURATION)
	tween.parallel().tween_property(battle_camera, "offset", Vector2.ZERO, ULTIMATE_ZOOM_OUT_DURATION)
	await tween.finished


func _play_takashi_ulti_pre_animation() -> void:
	if player_action_sprite == null or takashi_ulti_pre_frames.is_empty():
		return

	_stop_player_idle_animation()
	_stop_player_basic_animation()
	_stop_player_skill_animation()
	var frame_duration: float = 1.0 / TAKASHI_ULTI_PRE_FRAME_RATE
	for frame_texture in takashi_ulti_pre_frames:
		if state != BattleState.ACTION_RESOLUTION:
			return
		_set_player_action_frame(frame_texture)
		await get_tree().create_timer(frame_duration).timeout


func _play_takashi_ulti_post_animation() -> void:
	if player_action_sprite == null or takashi_ulti_post_frames.is_empty():
		return

	var frame_duration: float = 1.0 / TAKASHI_ULTI_POST_FRAME_RATE
	for frame_texture in takashi_ulti_post_frames:
		if state != BattleState.ACTION_RESOLUTION:
			return
		_set_player_action_frame(frame_texture)
		await get_tree().create_timer(frame_duration).timeout


func _load_ultimate_frames() -> void:
	ultimate_frames.clear()
	for frame_index in range(1, ULTIMATE_FRAME_COUNT + 1):
		var frame_path: String = ULTIMATE_FRAME_PATH_FORMAT % frame_index
		var frame_texture: Texture2D = load(frame_path) as Texture2D
		if frame_texture != null:
			ultimate_frames.append(frame_texture)


func _play_ultimate_sequence() -> void:
	if ultimate_frame_player == null or ultimate_frames.is_empty():
		return

	if ultimate_audio_player != null:
		ultimate_audio_player.stop()
		ultimate_audio_player.volume_db = ULTIMATE_AUDIO_VOLUME_DB
		ultimate_audio_player.play()

	ultimate_frame_player.visible = true
	ultimate_frame_player.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var frame_duration: float = 1.0 / ULTIMATE_FRAME_RATE
	for frame_texture in ultimate_frames:
		if state != BattleState.ACTION_RESOLUTION:
			break
		ultimate_frame_player.texture = frame_texture
		await get_tree().create_timer(frame_duration).timeout

	ultimate_frame_player.texture = null
	ultimate_frame_player.visible = false


func _setup_battle_effects() -> void:
	effect_layer = Node2D.new()
	effect_layer.name = "RuntimeBattleEffects"
	effect_layer.z_index = 12
	battle_scene.add_child(effect_layer)

	if canvas_layer != null:
		screen_flash = ColorRect.new()
		screen_flash.name = "RuntimeImpactFlash"
		screen_flash.visible = false
		screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen_flash.color = Color(1.0, 1.0, 1.0, 0.0)
		canvas_layer.add_child(screen_flash)

	basic_sfx_player = _create_generated_sfx_player("RuntimeBasicAttackSfx")
	skill_sfx_player = _create_generated_sfx_player("RuntimeSkillSfx")
	impact_sfx_player = _create_generated_sfx_player("RuntimeImpactSfx")
	cetar_sfx_player = _create_generated_sfx_player("RuntimeCetarSfx")
	sring_sfx_player = _create_generated_sfx_player("RuntimeSringSfx")
	skill_release_sfx_player = _create_generated_sfx_player("RuntimeSkillReleaseSfx")
	rift_crack_sfx_player = _create_generated_sfx_player("RuntimeRiftCrackSfx")
	ultimate_zoom_sfx_player = _create_generated_sfx_player("RuntimeUltimateZoomSfx")
	ultimate_shatter_sfx_player = _create_generated_sfx_player("RuntimeUltimateShatterSfx")
	octagram_chime_sfx_player = _create_generated_sfx_player("RuntimeOctagramChimeSfx")
	ultimate_charge_sfx_player = _create_generated_sfx_player("RuntimeUltimateChargeSfx")
	ultimate_glass_sfx_player = _create_generated_sfx_player("RuntimeUltimateGlassSfx")
	ultimate_boom_sfx_player = _create_generated_sfx_player("RuntimeUltimateBoomSfx")
	ultimate_cring_sfx_player = _create_generated_sfx_player("RuntimeUltimateCringNoiseSfx")
	_setup_takashi_ultimate_effect_nodes()


func _setup_takashi_ultimate_effect_nodes() -> void:
	if player == null:
		return

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
	_sync_takashi_ultimate_effect_layout()
	_setup_enemy_impact_fvx_nodes()


func _setup_enemy_impact_fvx_nodes() -> void:
	if enemy == null:
		return

	enemy_impact_fvx_glow_sprite = Sprite2D.new()
	enemy_impact_fvx_glow_sprite.name = "RuntimeEnemyImpactFVXGlow"
	enemy_impact_fvx_glow_sprite.visible = false
	enemy_impact_fvx_glow_sprite.z_index = -3
	enemy_impact_fvx_glow_sprite.centered = true
	enemy_impact_fvx_glow_sprite.material = _create_png_glow_shader_material(Color(0.42, 0.88, 1.0, 1.0), 18.0, 1.5, 0.16)
	enemy.add_child(enemy_impact_fvx_glow_sprite)

	enemy_impact_fvx_sprite = Sprite2D.new()
	enemy_impact_fvx_sprite.name = "RuntimeEnemyImpactFVX"
	enemy_impact_fvx_sprite.visible = false
	enemy_impact_fvx_sprite.z_index = -2
	enemy_impact_fvx_sprite.centered = true
	enemy_impact_fvx_sprite.material = _create_additive_canvas_material()
	enemy.add_child(enemy_impact_fvx_sprite)
	_sync_enemy_impact_fvx_layout()


func _create_additive_canvas_material() -> CanvasItemMaterial:
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _create_png_glow_shader_material(glow_color: Color, glow_radius: float, glow_strength: float, core_alpha: float) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = TAKASHI_ULTIMATE_GLOW_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("glow_radius", glow_radius)
	material.set_shader_parameter("glow_strength", glow_strength)
	material.set_shader_parameter("core_alpha", core_alpha)
	return material


func _play_takashi_ultimate_fvx_intro() -> void:
	if takashi_ultimate_fvx_frames.is_empty():
		_show_takashi_ultimate_character_glow()
		_play_ultimate_charge_rumble_sfx(0.75)
		return

	_show_takashi_ultimate_character_glow()
	_play_ultimate_charge_rumble_sfx(0.9)
	var frame_count: int = mini(takashi_ultimate_fvx_frames.size(), 3)
	for frame_index in range(frame_count):
		if state != BattleState.ACTION_RESOLUTION:
			return
		await _play_takashi_ultimate_fvx_step(frame_index, frame_index == frame_count - 1)

	_hold_takashi_ultimate_fvx()


func _play_takashi_ultimate_fvx_step(frame_index: int, keep_visible: bool) -> void:
	if takashi_ultimate_fvx_sprite == null or takashi_ultimate_fvx_glow_sprite == null:
		return
	if frame_index < 0 or frame_index >= takashi_ultimate_fvx_frames.size():
		return

	_play_ultimate_fvx_step_sfx(frame_index, keep_visible)
	takashi_ultimate_fvx_playing = false
	var frame_texture: Texture2D = takashi_ultimate_fvx_frames[frame_index]
	takashi_ultimate_fvx_frame_index = frame_index
	takashi_ultimate_fvx_sprite.texture = frame_texture
	takashi_ultimate_fvx_glow_sprite.texture = frame_texture
	_sync_takashi_ultimate_effect_layout()

	var base_scale: Vector2 = _get_takashi_ultimate_fvx_scale(frame_texture)
	takashi_ultimate_fvx_sprite.visible = true
	takashi_ultimate_fvx_glow_sprite.visible = true
	takashi_ultimate_fvx_sprite.modulate = Color(0.55, 0.92, 1.0, 0.0)
	takashi_ultimate_fvx_glow_sprite.modulate = Color(0.6, 0.95, 1.0, 0.0)
	takashi_ultimate_fvx_sprite.scale = base_scale * 0.84
	takashi_ultimate_fvx_glow_sprite.scale = base_scale * 1.28
	takashi_ultimate_fvx_sprite.rotation = -0.32
	takashi_ultimate_fvx_glow_sprite.rotation = -0.32

	var tween: Tween = create_tween()
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


func _show_takashi_ultimate_character_glow() -> void:
	if player_action_sprite != null:
		player_action_sprite.self_modulate = Color(1.0, 1.12, 1.22, 1.0)
	if takashi_ultimate_character_glow_sprite == null:
		return

	_sync_takashi_ultimate_glow_frame()
	takashi_ultimate_character_glow_sprite.visible = true
	takashi_ultimate_character_glow_sprite.modulate = Color(0.56, 0.9, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(takashi_ultimate_character_glow_sprite, "modulate:a", 0.62, 0.28)


func _hold_takashi_ultimate_fvx() -> void:
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
	_sync_takashi_ultimate_effect_layout()


func _advance_takashi_ultimate_fvx(delta: float) -> void:
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


func _fade_out_takashi_ultimate_glow_effect(duration: float) -> void:
	takashi_ultimate_fvx_playing = false
	if player_action_sprite != null:
		player_action_sprite.self_modulate = Color.WHITE

	var tween: Tween = create_tween()
	var has_tween_target: bool = false
	if takashi_ultimate_fvx_sprite != null and takashi_ultimate_fvx_sprite.visible:
		tween.tween_property(takashi_ultimate_fvx_sprite, "modulate:a", 0.0, duration)
		has_tween_target = true
	if takashi_ultimate_fvx_glow_sprite != null and takashi_ultimate_fvx_glow_sprite.visible:
		if has_tween_target:
			tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "modulate:a", 0.0, duration)
		else:
			tween.tween_property(takashi_ultimate_fvx_glow_sprite, "modulate:a", 0.0, duration)
		has_tween_target = true
	if takashi_ultimate_character_glow_sprite != null and takashi_ultimate_character_glow_sprite.visible:
		if has_tween_target:
			tween.parallel().tween_property(takashi_ultimate_character_glow_sprite, "modulate:a", 0.0, duration)
		else:
			tween.tween_property(takashi_ultimate_character_glow_sprite, "modulate:a", 0.0, duration)
		has_tween_target = true

	if has_tween_target:
		await tween.finished
	_hide_takashi_ultimate_glow_effect()


func _hide_takashi_ultimate_glow_effect() -> void:
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


func _sync_takashi_ultimate_effect_layout() -> void:
	_sync_takashi_ultimate_glow_frame()
	if takashi_ultimate_fvx_sprite == null:
		return

	var fvx_texture: Texture2D = takashi_ultimate_fvx_sprite.texture
	var base_scale: Vector2 = _get_takashi_ultimate_fvx_scale(fvx_texture)
	var fvx_position: Vector2 = TAKASHI_ULTIMATE_FVX_OFFSET
	if player_action_sprite != null:
		fvx_position += player_action_sprite.position

	takashi_ultimate_fvx_sprite.position = fvx_position
	takashi_ultimate_fvx_sprite.scale = base_scale
	if takashi_ultimate_fvx_glow_sprite != null:
		takashi_ultimate_fvx_glow_sprite.position = fvx_position
		takashi_ultimate_fvx_glow_sprite.scale = base_scale * 1.5


func _sync_takashi_ultimate_glow_frame() -> void:
	if takashi_ultimate_character_glow_sprite == null or player_action_sprite == null:
		return

	takashi_ultimate_character_glow_sprite.texture = player_action_sprite.texture
	takashi_ultimate_character_glow_sprite.position = player_action_sprite.position
	takashi_ultimate_character_glow_sprite.scale = player_action_sprite.scale * 1.18


func _get_takashi_ultimate_fvx_scale(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE

	var texture_size: Vector2 = texture.get_size()
	if texture_size.y <= 0.0:
		return Vector2.ONE

	var scale_value: float = TAKASHI_ULTIMATE_FVX_TARGET_HEIGHT / texture_size.y
	return Vector2(scale_value, scale_value)


func _shrink_takashi_ultimate_fvx_for_enemy_focus() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if takashi_ultimate_fvx_sprite != null and takashi_ultimate_fvx_sprite.visible:
		tween.tween_property(takashi_ultimate_fvx_sprite, "scale", takashi_ultimate_fvx_sprite.scale * TAKASHI_ULTIMATE_FVX_ENEMY_FOCUS_SCALE, 0.3)
	if takashi_ultimate_fvx_glow_sprite != null and takashi_ultimate_fvx_glow_sprite.visible:
		tween.parallel().tween_property(takashi_ultimate_fvx_glow_sprite, "scale", takashi_ultimate_fvx_glow_sprite.scale * TAKASHI_ULTIMATE_FVX_ENEMY_FOCUS_SCALE, 0.3)


func _play_enemy_octagram_impact() -> void:
	_shrink_takashi_ultimate_fvx_for_enemy_focus()
	_start_enemy_impact_camera_zoom_in()
	_play_enemy_octagram_wind_sfx()
	_play_ultimate_charge_rumble_sfx(0.7)
	_play_octagram_chime_sfx()
	await _play_enemy_octagram_fvx_buildup()
	if state != BattleState.ACTION_RESOLUTION:
		_hide_enemy_impact_fvx()
		return

	_play_ultimate_shatter_sfx()
	_play_ultimate_enemy_hit_sfx()
	_play_ultimate_glass_burst_sfx(1.15)
	_play_ultimate_cring_noise_sfx(1.25)
	_play_ultimate_deep_boom_sfx(1.05)
	_play_screen_flash(Color(0.65, 0.92, 1.0, 0.4), 0.16)
	_shake_camera_with_strength(9.0)
	_spawn_triangle_rift_effect(enemy, true)
	_spawn_hit_spark(enemy, Color(0.55, 0.92, 1.0, 1.0))
	await get_tree().create_timer(0.05).timeout
	await _fade_out_enemy_impact_fvx(0.22)


func _start_enemy_impact_camera_zoom_in() -> void:
	if battle_camera == null:
		return

	var target_position: Vector2 = enemy.global_position + ENEMY_IMPACT_FOCUS_OFFSET
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(battle_camera, "position", target_position, ENEMY_IMPACT_ZOOM_DURATION)
	tween.parallel().tween_property(battle_camera, "zoom", ULTIMATE_CAMERA_ZOOM, ENEMY_IMPACT_ZOOM_DURATION)
	tween.parallel().tween_property(battle_camera, "offset", Vector2.ZERO, ENEMY_IMPACT_ZOOM_DURATION)


func _play_enemy_impact_camera_zoom_out() -> void:
	if battle_camera == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(battle_camera, "position", viewport_size * 0.5, ENEMY_IMPACT_ZOOM_OUT_DURATION)
	tween.parallel().tween_property(battle_camera, "zoom", Vector2.ONE, ENEMY_IMPACT_ZOOM_OUT_DURATION)
	tween.parallel().tween_property(battle_camera, "offset", Vector2.ZERO, ENEMY_IMPACT_ZOOM_OUT_DURATION)
	await tween.finished


func _play_enemy_octagram_fvx_buildup() -> void:
	if takashi_ultimate_fvx_frames.is_empty():
		return

	var frame_count: int = mini(takashi_ultimate_fvx_frames.size(), 3)
	for frame_index in range(frame_count):
		if state != BattleState.ACTION_RESOLUTION:
			return
		await _play_enemy_impact_fvx_step(frame_index, frame_index == frame_count - 1)


func _play_enemy_impact_fvx_step(frame_index: int, keep_visible: bool) -> void:
	if enemy_impact_fvx_sprite == null or enemy_impact_fvx_glow_sprite == null:
		return
	if frame_index < 0 or frame_index >= takashi_ultimate_fvx_frames.size():
		return

	var frame_texture: Texture2D = takashi_ultimate_fvx_frames[frame_index]
	enemy_impact_fvx_sprite.texture = frame_texture
	enemy_impact_fvx_glow_sprite.texture = frame_texture
	_sync_enemy_impact_fvx_layout()

	var base_scale: Vector2 = _get_enemy_impact_fvx_scale(frame_texture)
	enemy_impact_fvx_sprite.visible = true
	enemy_impact_fvx_glow_sprite.visible = true
	enemy_impact_fvx_sprite.modulate = Color(0.55, 0.9, 1.0, 0.0)
	enemy_impact_fvx_glow_sprite.modulate = Color(0.6, 0.94, 1.0, 0.0)
	enemy_impact_fvx_sprite.scale = base_scale * 0.8
	enemy_impact_fvx_glow_sprite.scale = base_scale * 1.24
	enemy_impact_fvx_sprite.rotation = 0.3
	enemy_impact_fvx_glow_sprite.rotation = 0.3

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(enemy_impact_fvx_sprite, "modulate:a", 0.8, 0.16)
	tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", 0.78, 0.16)
	tween.parallel().tween_property(enemy_impact_fvx_sprite, "scale", base_scale, 0.18)
	tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "scale", base_scale * 1.5, 0.18)
	tween.parallel().tween_property(enemy_impact_fvx_sprite, "rotation", -0.36, 0.28)
	tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "rotation", -0.36, 0.28)
	tween.tween_interval(0.04)
	if keep_visible:
		tween.tween_property(enemy_impact_fvx_sprite, "modulate:a", 0.92, 0.08)
		tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", 0.86, 0.08)
	else:
		var rest_alpha: float = 0.16 + (float(frame_index) * 0.12)
		tween.tween_property(enemy_impact_fvx_sprite, "modulate:a", rest_alpha, 0.14)
		tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", rest_alpha, 0.14)
	await tween.finished


func _fade_out_enemy_impact_fvx(duration: float) -> void:
	var tween: Tween = create_tween()
	var has_tween_target: bool = false
	if enemy_impact_fvx_sprite != null and enemy_impact_fvx_sprite.visible:
		tween.tween_property(enemy_impact_fvx_sprite, "modulate:a", 0.0, duration)
		has_tween_target = true
	if enemy_impact_fvx_glow_sprite != null and enemy_impact_fvx_glow_sprite.visible:
		if has_tween_target:
			tween.parallel().tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", 0.0, duration)
		else:
			tween.tween_property(enemy_impact_fvx_glow_sprite, "modulate:a", 0.0, duration)
		has_tween_target = true

	if has_tween_target:
		await tween.finished
	_hide_enemy_impact_fvx()


func _hide_enemy_impact_fvx() -> void:
	if enemy_impact_fvx_sprite != null:
		enemy_impact_fvx_sprite.visible = false
		enemy_impact_fvx_sprite.rotation = 0.0
		enemy_impact_fvx_sprite.modulate = Color(0.55, 0.9, 1.0, 0.0)
	if enemy_impact_fvx_glow_sprite != null:
		enemy_impact_fvx_glow_sprite.visible = false
		enemy_impact_fvx_glow_sprite.rotation = 0.0
		enemy_impact_fvx_glow_sprite.modulate = Color(0.6, 0.94, 1.0, 0.0)


func _sync_enemy_impact_fvx_layout() -> void:
	if enemy_impact_fvx_sprite == null:
		return

	var fvx_texture: Texture2D = enemy_impact_fvx_sprite.texture
	var base_scale: Vector2 = _get_enemy_impact_fvx_scale(fvx_texture)
	enemy_impact_fvx_sprite.position = ENEMY_IMPACT_FOCUS_OFFSET
	enemy_impact_fvx_sprite.scale = base_scale
	if enemy_impact_fvx_glow_sprite != null:
		enemy_impact_fvx_glow_sprite.position = ENEMY_IMPACT_FOCUS_OFFSET
		enemy_impact_fvx_glow_sprite.scale = base_scale * 1.5


func _get_enemy_impact_fvx_scale(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE

	var texture_size: Vector2 = texture.get_size()
	if texture_size.y <= 0.0:
		return Vector2.ONE

	var scale_value: float = ENEMY_IMPACT_FVX_TARGET_HEIGHT / texture_size.y
	return Vector2(scale_value, scale_value)


func _setup_battle_bgm() -> void:
	if battle_bgm == null:
		return

	if not battle_bgm.finished.is_connected(_restart_battle_bgm):
		battle_bgm.finished.connect(_restart_battle_bgm)
	if not battle_bgm.playing:
		battle_bgm.play()


func _restart_battle_bgm() -> void:
	if battle_bgm != null:
		battle_bgm.play()


func _create_generated_sfx_player(player_name: String) -> AudioStreamPlayer:
	var player_node: AudioStreamPlayer = AudioStreamPlayer.new()
	player_node.name = player_name
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = SFX_SAMPLE_RATE
	stream.buffer_length = 1.25
	player_node.stream = stream
	battle_scene.add_child(player_node)
	return player_node


func _play_basic_sfx() -> void:
	_play_cosmic_basic_sfx()


func _play_skill_sfx() -> void:
	if skill_sfx_player == null:
		return

	skill_sfx_player.stop()
	skill_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = skill_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.36
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var low_phase: float = 0.0
	var rift_phase: float = 0.0
	var shimmer_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var build: float = pow(progress, 0.55)
		var fade: float = minf(progress / 0.04, 1.0) * pow(1.0 - progress * 0.2, 1.2)
		var pulse: float = 0.78 + 0.22 * sin(progress * TAU * 9.0)

		low_phase += TAU * lerpf(58.0, 86.0, build) / SFX_SAMPLE_RATE
		rift_phase += TAU * lerpf(180.0, 520.0, build) / SFX_SAMPLE_RATE
		shimmer_phase += TAU * lerpf(980.0, 2600.0, build) / SFX_SAMPLE_RATE

		var low_rumble: float = sin(low_phase) * 0.42
		var rift_tone: float = (sin(rift_phase) + sin(rift_phase * 1.51) * 0.45) * 0.34
		var cold_shimmer: float = sin(shimmer_phase) * 0.12 * build
		var air: float = randf_range(-1.0, 1.0) * 0.08 * build
		var sample: float = (low_rumble + rift_tone + cold_shimmer + air) * fade * pulse * 0.34
		playback.push_frame(Vector2(sample * 0.95, sample * 1.05))


func _play_skill_release_sfx() -> void:
	if skill_release_sfx_player == null:
		return

	skill_release_sfx_player.stop()
	skill_release_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = skill_release_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.28
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var sweep_phase: float = 0.0
	var blade_phase: float = 0.0
	var sub_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var sweep_progress: float = pow(progress, 0.38)
		var attack: float = minf(progress / 0.018, 1.0)
		var tail: float = pow(1.0 - progress, 1.85)
		var envelope: float = attack * tail
		var transient: float = pow(maxf(1.0 - progress * 9.5, 0.0), 2.0)

		sweep_phase += TAU * lerpf(420.0, 4200.0, sweep_progress) / SFX_SAMPLE_RATE
		blade_phase += TAU * lerpf(1500.0, 5200.0, sweep_progress) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(92.0, 48.0, progress) / SFX_SAMPLE_RATE

		var rift_sweep: float = (sin(sweep_phase) + sin(sweep_phase * 1.33) * 0.35) * envelope * 0.42
		var high_blade: float = sin(blade_phase) * envelope * 0.22
		var sub_drop: float = sin(sub_phase) * pow(1.0 - progress, 2.4) * 0.28
		var burst_air: float = randf_range(-1.0, 1.0) * (0.32 * transient + 0.08 * envelope)
		var sample: float = (rift_sweep + high_blade + sub_drop + burst_air) * 0.44
		var pan: float = lerpf(-0.16, 0.18, progress)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_rift_crack_sfx() -> void:
	if rift_crack_sfx_player == null:
		return

	rift_crack_sfx_player.stop()
	rift_crack_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = rift_crack_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.24
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var crack_phase_a: float = 0.0
	var crack_phase_b: float = 0.0
	var crack_phase_c: float = 0.0
	var sub_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var attack: float = minf(progress / 0.006, 1.0)
		var tail: float = pow(1.0 - progress, 2.45)
		var envelope: float = attack * tail
		var first_crack: float = pow(maxf(1.0 - progress * 15.0, 0.0), 2.0)
		var second_crack: float = pow(maxf(1.0 - absf(progress - 0.32) * 12.0, 0.0), 2.0) * 0.72
		var crack_gate: float = maxf(first_crack, second_crack)

		crack_phase_a += TAU * lerpf(3400.0, 920.0, progress) / SFX_SAMPLE_RATE
		crack_phase_b += TAU * lerpf(4700.0, 1300.0, progress) / SFX_SAMPLE_RATE
		crack_phase_c += TAU * lerpf(1600.0, 520.0, progress) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(68.0, 34.0, progress) / SFX_SAMPLE_RATE

		var rift_crack: float = (
			sin(crack_phase_a) * 0.28 +
			sin(crack_phase_b) * 0.21 +
			sin(crack_phase_c) * 0.26
		) * crack_gate
		var tear_noise: float = randf_range(-1.0, 1.0) * (0.55 * crack_gate + 0.12 * envelope)
		var sub_hit: float = sin(sub_phase) * envelope * 0.45
		var sample: float = (rift_crack + tear_noise + sub_hit) * 0.46
		var pan: float = randf_range(-0.08, 0.08)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_impact_sfx() -> void:
	_play_generated_sfx(impact_sfx_player, IMPACT_SFX_START_HZ, IMPACT_SFX_END_HZ, 0.24, 0.55, 0.28)


func _play_ultimate_fvx_step_sfx(frame_index: int, keep_visible: bool) -> void:
	var intensity: float = 0.42 + float(frame_index) * 0.18
	if keep_visible:
		intensity = 0.95
	_play_ultimate_glass_burst_sfx(intensity)
	_play_ultimate_deep_boom_sfx(intensity * 0.58)


func _play_ultimate_charge_rumble_sfx(intensity: float = 1.0) -> void:
	if ultimate_charge_sfx_player == null:
		return

	ultimate_charge_sfx_player.stop()
	ultimate_charge_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_charge_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_CHARGE_RUMBLE_DURATION)
	var sub_phase: float = 0.0
	var pulse_phase: float = 0.0
	var shimmer_phase: float = 0.0
	var noise_low: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var build: float = pow(progress, 0.62)
		var attack: float = minf(progress / 0.12, 1.0)
		var tail: float = pow(maxf(1.0 - progress * 0.16, 0.0), 0.8)
		var envelope: float = attack * tail

		sub_phase += TAU * lerpf(36.0, 72.0, build) / SFX_SAMPLE_RATE
		pulse_phase += TAU * lerpf(96.0, 164.0, build) / SFX_SAMPLE_RATE
		shimmer_phase += TAU * lerpf(880.0, 3600.0, build) / SFX_SAMPLE_RATE
		noise_low = lerpf(noise_low, randf_range(-1.0, 1.0), 0.09)

		var sub: float = sin(sub_phase) * (0.62 + build * 0.28)
		var pulse: float = sin(pulse_phase) * (0.28 + 0.18 * sin(progress * TAU * 7.0))
		var shimmer: float = sin(shimmer_phase) * build * 0.12
		var air: float = noise_low * (0.18 + build * 0.24)
		var raw_sample: float = (sub + pulse + shimmer + air) * envelope * ULTIMATE_CHARGE_RUMBLE_VOLUME * intensity
		var sample: float = tanh(raw_sample * 1.25) / 1.25
		var pan: float = sin(progress * TAU * 1.1) * 0.12
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_ultimate_glass_burst_sfx(intensity: float = 1.0) -> void:
	if ultimate_glass_sfx_player == null:
		return

	ultimate_glass_sfx_player.stop()
	ultimate_glass_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_glass_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_GLASS_BURST_DURATION)
	var glass_phase_a: float = 0.0
	var glass_phase_b: float = 0.0
	var glass_phase_c: float = 0.0
	var glass_phase_d: float = 0.0
	var noise_smooth: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var snap_gate: float = pow(maxf(1.0 - progress * 48.0, 0.0), 1.7)
		var shard_gate_a: float = pow(maxf(1.0 - absf(progress - 0.12) * 14.0, 0.0), 2.0)
		var shard_gate_b: float = pow(maxf(1.0 - absf(progress - 0.28) * 10.0, 0.0), 2.0) * 0.72
		var shard_gate_c: float = pow(maxf(1.0 - absf(progress - 0.48) * 7.0, 0.0), 2.0) * 0.44
		var tail: float = pow(maxf(1.0 - progress, 0.0), 2.05)
		var shard_gate: float = maxf(snap_gate, maxf(shard_gate_a, maxf(shard_gate_b, shard_gate_c)))

		glass_phase_a += TAU * lerpf(9200.0, 3200.0, progress) / SFX_SAMPLE_RATE
		glass_phase_b += TAU * lerpf(6800.0, 2500.0, progress) / SFX_SAMPLE_RATE
		glass_phase_c += TAU * lerpf(5200.0, 1800.0, progress) / SFX_SAMPLE_RATE
		glass_phase_d += TAU * lerpf(3600.0, 1200.0, progress) / SFX_SAMPLE_RATE
		noise_smooth = lerpf(noise_smooth, randf_range(-1.0, 1.0), 0.36)

		var glass_tone: float = (
			sin(glass_phase_a) * 0.34 +
			sin(glass_phase_b) * 0.27 +
			sin(glass_phase_c) * 0.2 +
			sin(glass_phase_d) * 0.14
		)
		var snap: float = randf_range(-1.0, 1.0) * snap_gate * 1.35
		var shard_click: float = randf_range(-1.0, 1.0) * shard_gate * randf_range(0.2, 1.0)
		var crushed_noise: float = floor(noise_smooth * 14.0) / 14.0
		var shard_noise: float = (crushed_noise * 0.72 + shard_click * 0.46) * (shard_gate * 0.96 + tail * 0.16)
		var sparkle: float = glass_tone * (shard_gate * 0.86 + tail * 0.24)
		var raw_sample: float = (snap + shard_noise + sparkle) * ULTIMATE_GLASS_BURST_VOLUME * intensity
		var sample: float = clampf(tanh(raw_sample * 1.95) / 1.62, -0.82, 0.82)
		var pan: float = sin(progress * TAU * 3.2) * 0.24 + randf_range(-0.08, 0.08) * shard_gate
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_ultimate_deep_boom_sfx(intensity: float = 1.0) -> void:
	if ultimate_boom_sfx_player == null:
		return

	ultimate_boom_sfx_player.stop()
	ultimate_boom_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_boom_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_DEEP_BOOM_DURATION)
	var sub_phase: float = 0.0
	var body_phase: float = 0.0
	var pressure_noise: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var attack: float = minf(progress / 0.018, 1.0)
		var tail: float = pow(maxf(1.0 - progress, 0.0), 1.85)
		var envelope: float = attack * tail
		var punch_gate: float = pow(maxf(1.0 - progress * 9.0, 0.0), 1.45)
		var second_gate: float = pow(maxf(1.0 - absf(progress - 0.19) * 5.4, 0.0), 1.8) * 0.58

		sub_phase += TAU * lerpf(58.0, 24.0, pow(progress, 0.7)) / SFX_SAMPLE_RATE
		body_phase += TAU * lerpf(132.0, 42.0, progress) / SFX_SAMPLE_RATE
		pressure_noise = lerpf(pressure_noise, randf_range(-1.0, 1.0), 0.12)

		var sub: float = sin(sub_phase) * (punch_gate * 1.15 + second_gate * 0.85 + envelope * 0.2)
		var body: float = sin(body_phase) * (punch_gate * 0.55 + second_gate * 0.4)
		var pressure: float = pressure_noise * envelope * 0.24
		var raw_sample: float = (sub + body + pressure) * ULTIMATE_DEEP_BOOM_VOLUME * intensity
		var sample: float = tanh(raw_sample * 1.45) / 1.45
		playback.push_frame(Vector2(sample, sample))


func _play_ultimate_cring_noise_sfx(intensity: float = 1.0) -> void:
	if ultimate_cring_sfx_player == null:
		return

	ultimate_cring_sfx_player.stop()
	ultimate_cring_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_cring_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_CRING_NOISE_DURATION)
	var scrape_phase_a: float = 0.0
	var scrape_phase_b: float = 0.0
	var ring_phase: float = 0.0
	var harsh_noise: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var tail: float = pow(maxf(1.0 - progress, 0.0), 1.7)
		var snap_gate: float = pow(maxf(1.0 - progress * 36.0, 0.0), 1.4)
		var scrape_gate: float = maxf(
			pow(maxf(1.0 - absf(progress - 0.1) * 10.0, 0.0), 2.0),
			pow(maxf(1.0 - absf(progress - 0.31) * 7.5, 0.0), 2.0) * 0.72
		)

		scrape_phase_a += TAU * lerpf(10600.0, 2800.0, progress) / SFX_SAMPLE_RATE
		scrape_phase_b += TAU * lerpf(7900.0, 2100.0, pow(progress, 0.72)) / SFX_SAMPLE_RATE
		ring_phase += TAU * lerpf(4800.0, 900.0, progress) / SFX_SAMPLE_RATE
		harsh_noise = lerpf(harsh_noise, randf_range(-1.0, 1.0), 0.64)

		var bitcrush_rate: float = 18.0
		var crushed_noise: float = floor(harsh_noise * bitcrush_rate) / bitcrush_rate
		var scrape: float = (sin(scrape_phase_a) * 0.42 + sin(scrape_phase_b) * 0.34) * (scrape_gate + tail * 0.18)
		var ring: float = sin(ring_phase) * (scrape_gate * 0.28 + tail * 0.12)
		var crack: float = randf_range(-1.0, 1.0) * snap_gate * 1.18
		var static_spray: float = crushed_noise * (scrape_gate * 0.9 + tail * 0.22)
		var raw_sample: float = (scrape + ring + crack + static_spray) * ULTIMATE_CRING_NOISE_VOLUME * intensity
		var sample: float = clampf(raw_sample, -0.82, 0.82)
		var pan: float = sin(progress * TAU * 5.0) * 0.26 + randf_range(-0.12, 0.12) * (snap_gate + scrape_gate)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_ultimate_enemy_hit_sfx() -> void:
	if impact_sfx_player == null:
		return

	impact_sfx_player.stop()
	impact_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = impact_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_HIT_SFX_DURATION)
	var sub_phase: float = 0.0
	var boom_phase: float = 0.0
	var metal_phase: float = 0.0
	var cring_phase: float = 0.0
	var glass_phase_a: float = 0.0
	var glass_phase_b: float = 0.0
	var glass_phase_c: float = 0.0
	var air_low: float = 0.0
	var air_high: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var attack: float = minf(progress / 0.008, 1.0)
		var tail: float = pow(maxf(1.0 - progress, 0.0), 1.45)
		var envelope: float = attack * tail
		var snap_gate: float = pow(maxf(1.0 - progress * 42.0, 0.0), 2.0)
		var first_boom_gate: float = pow(maxf(1.0 - absf(progress - 0.055) * 8.0, 0.0), 2.0)
		var second_boom_gate: float = pow(maxf(1.0 - absf(progress - 0.18) * 6.5, 0.0), 2.0) * 0.78
		var crunch_gate: float = pow(maxf(1.0 - absf(progress - 0.075) * 13.0, 0.0), 2.0)
		var glass_gate: float = maxf(
			pow(maxf(1.0 - absf(progress - 0.12) * 10.0, 0.0), 2.0),
			pow(maxf(1.0 - absf(progress - 0.34) * 7.0, 0.0), 2.0) * 0.58
		)
		var sparkle_tail: float = pow(maxf(1.0 - progress, 0.0), 2.4)

		sub_phase += TAU * lerpf(62.0, 24.0, pow(progress, 0.55)) / SFX_SAMPLE_RATE
		boom_phase += TAU * lerpf(118.0, 38.0, progress) / SFX_SAMPLE_RATE
		metal_phase += TAU * lerpf(980.0, 210.0, pow(progress, 0.42)) / SFX_SAMPLE_RATE
		cring_phase += TAU * lerpf(6900.0, 1200.0, pow(progress, 0.58)) / SFX_SAMPLE_RATE
		glass_phase_a += TAU * lerpf(7600.0, 3100.0, progress) / SFX_SAMPLE_RATE
		glass_phase_b += TAU * lerpf(5400.0, 2400.0, progress) / SFX_SAMPLE_RATE
		glass_phase_c += TAU * lerpf(3900.0, 1500.0, progress) / SFX_SAMPLE_RATE

		var raw_noise: float = randf_range(-1.0, 1.0)
		air_low = lerpf(air_low, raw_noise, 0.18)
		air_high = lerpf(air_high, raw_noise - air_low, 0.42)

		var snap: float = randf_range(-1.0, 1.0) * snap_gate * 1.25
		var sub_drop: float = sin(sub_phase) * (first_boom_gate * 1.35 + second_boom_gate * 0.86 + envelope * 0.16)
		var boom_body: float = sin(boom_phase) * (first_boom_gate * 0.72 + second_boom_gate * 0.55)
		var metal_slam: float = sin(metal_phase) * envelope * 0.28
		var cring: float = sin(cring_phase) * (crunch_gate * 0.48 + glass_gate * 0.22)
		var glass: float = (
			sin(glass_phase_a) * 0.34 +
			sin(glass_phase_b) * 0.24 +
			sin(glass_phase_c) * 0.18
		) * (glass_gate + sparkle_tail * 0.16)
		var click: float = randf_range(-1.0, 1.0) * crunch_gate * 0.82
		var bitcrush: float = floor((air_high + air_low) * 12.0) / 12.0
		var crackle: float = (bitcrush * 0.92 + air_high * 0.4) * (snap_gate * 0.82 + glass_gate * 0.68 + envelope * 0.16)
		var wind_after: float = air_low * envelope * 0.22

		var raw_sample: float = (snap + sub_drop + boom_body + metal_slam + cring + glass + click + crackle + wind_after) * ULTIMATE_HIT_SFX_VOLUME
		var sample: float = clampf(tanh(raw_sample * 2.15) / 1.72, -0.86, 0.86)
		var pan: float = sin(progress * TAU * 2.15) * 0.18 + randf_range(-0.04, 0.04) * (snap_gate + glass_gate)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_ultimate_zoom_sfx() -> void:
	_play_filtered_wind_sfx(ultimate_zoom_sfx_player, ULTIMATE_ZOOM_WIND_DURATION, 350.0, 2000.0, 0.65, -0.18, 0.18, 1.0)


func _play_ultimate_zoom_out_wind_sfx() -> void:
	_play_filtered_wind_sfx(ultimate_zoom_sfx_player, ULTIMATE_ZOOM_OUT_WIND_DURATION, 2000.0, 350.0, 0.7, 0.18, -0.18, 1.0)


func _play_enemy_octagram_wind_sfx() -> void:
	_play_filtered_wind_sfx(ultimate_zoom_sfx_player, ULTIMATE_ZOOM_WIND_DURATION, 350.0, 2000.0, 0.65, -0.18, 0.18, ENEMY_IMPACT_WIND_VOLUME_SCALE)


func _play_filtered_wind_sfx(player_node: AudioStreamPlayer, duration: float, start_cutoff_hz: float, end_cutoff_hz: float, sweep_curve: float, pan_start: float, pan_end: float, volume_scale: float = 1.0) -> void:
	if player_node == null:
		return

	player_node.stop()
	player_node.play()
	var playback: AudioStreamGeneratorPlayback = player_node.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var low_cutoff_hz: float = 140.0
	var lp_fast: float = 0.0
	var lp_slow: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var attack: float = minf(progress / 0.22, 1.0)
		attack = attack * attack
		var tail: float = pow(1.0 - progress, 1.15)
		var envelope: float = attack * tail

		var fast_cutoff_hz: float = lerpf(start_cutoff_hz, end_cutoff_hz, pow(progress, sweep_curve))
		var fast_alpha: float = 1.0 - exp(-TAU * fast_cutoff_hz / SFX_SAMPLE_RATE)
		var slow_alpha: float = 1.0 - exp(-TAU * low_cutoff_hz / SFX_SAMPLE_RATE)

		var raw_noise: float = randf_range(-1.0, 1.0)
		lp_fast += fast_alpha * (raw_noise - lp_fast)
		lp_slow += slow_alpha * (raw_noise - lp_slow)

		var whoosh: float = (lp_fast - lp_slow) * 1.5
		var flutter: float = 0.88 + 0.12 * sin(progress * TAU * 9.0)
		var sample: float = whoosh * envelope * flutter * ULTIMATE_ZOOM_WIND_VOLUME * volume_scale
		var pan: float = lerpf(pan_start, pan_end, progress)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_octagram_chime_sfx() -> void:
	if octagram_chime_sfx_player == null:
		return

	octagram_chime_sfx_player.stop()
	octagram_chime_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = octagram_chime_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * OCTAGRAM_CHIME_DURATION)
	var phase_a: float = 0.0
	var phase_b: float = 0.0
	var phase_c: float = 0.0
	var phase_d: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var attack: float = minf(progress / 0.012, 1.0)
		var decay: float = pow(1.0 - progress, 1.5)
		var envelope: float = attack * decay

		phase_a += TAU * 2650.0 / SFX_SAMPLE_RATE
		phase_b += TAU * 3480.0 / SFX_SAMPLE_RATE
		phase_c += TAU * 4180.0 / SFX_SAMPLE_RATE
		phase_d += TAU * 5240.0 / SFX_SAMPLE_RATE

		var bell: float = (
			sin(phase_a) * 0.34 +
			sin(phase_b) * 0.26 +
			sin(phase_c) * 0.2 +
			sin(phase_d) * 0.14
		)
		var shimmer: float = 0.86 + 0.14 * sin(progress * TAU * 7.0)
		var sample: float = bell * envelope * shimmer * OCTAGRAM_CHIME_VOLUME
		playback.push_frame(Vector2(sample, sample))


func _play_ultimate_shatter_sfx() -> void:
	if ultimate_shatter_sfx_player == null:
		return

	ultimate_shatter_sfx_player.stop()
	ultimate_shatter_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_shatter_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_SHATTER_DURATION)
	var glass_phase_a: float = 0.0
	var glass_phase_b: float = 0.0
	var glass_phase_c: float = 0.0
	var glass_phase_d: float = 0.0
	var cring_phase: float = 0.0
	var sub_phase: float = 0.0
	var smoothed_noise: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var initial_crack: float = pow(maxf(1.0 - progress * 18.0, 0.0), 2.4)
		var second_crack: float = pow(maxf(1.0 - absf(progress - 0.16) * 18.0, 0.0), 2.2)
		var third_crack: float = pow(maxf(1.0 - absf(progress - 0.31) * 15.0, 0.0), 2.0)
		var sparkle_tail: float = pow(maxf(1.0 - progress, 0.0), 1.45)
		var crack_gate: float = maxf(initial_crack, maxf(second_crack * 0.82, third_crack * 0.62))

		glass_phase_a += TAU * lerpf(7200.0, 3900.0, progress) / SFX_SAMPLE_RATE
		glass_phase_b += TAU * lerpf(5600.0, 2800.0, progress) / SFX_SAMPLE_RATE
		glass_phase_c += TAU * lerpf(4200.0, 2200.0, progress) / SFX_SAMPLE_RATE
		glass_phase_d += TAU * lerpf(3100.0, 1550.0, progress) / SFX_SAMPLE_RATE
		cring_phase += TAU * lerpf(8800.0, 3600.0, pow(progress, 0.72)) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(78.0, 26.0, progress) / SFX_SAMPLE_RATE

		smoothed_noise = lerpf(smoothed_noise, randf_range(-1.0, 1.0), 0.34)
		var snap_noise: float = randf_range(-1.0, 1.0)

		var glass_tone: float = (
			sin(glass_phase_a) * 0.28 +
			sin(glass_phase_b) * 0.22 +
			sin(glass_phase_c) * 0.18 +
			sin(glass_phase_d) * 0.14
		)
		var cring_gate: float = pow(maxf(1.0 - absf(progress - 0.23) * 7.0, 0.0), 2.0)
		var cring_tail: float = pow(maxf(1.0 - absf(progress - 0.46) * 4.2, 0.0), 2.0) * 0.55
		var cring: float = sin(cring_phase) * (cring_gate + cring_tail) * 0.20
		var crack_noise: float = smoothed_noise * (crack_gate * 0.86 + sparkle_tail * 0.16)
		var sparkle: float = glass_tone * (crack_gate * 0.75 + sparkle_tail * 0.28)
		var snap_gate: float = pow(maxf(1.0 - progress * 55.0, 0.0), 1.6)
		var snap: float = snap_noise * snap_gate * 1.1
		var boom_one_gate: float = pow(maxf(1.0 - progress * 3.4, 0.0), 1.5)
		var boom_two_gate: float = pow(maxf(1.0 - absf(progress - 0.17) * 4.6, 0.0), 1.6)
		var boom: float = sin(sub_phase) * (boom_one_gate * 1.1 + boom_two_gate * 0.85)
		var raw_sample: float = (crack_noise + sparkle + cring + boom + snap) * ULTIMATE_SHATTER_VOLUME
		var sample: float = tanh(raw_sample * 1.9) / 1.9
		var pan: float = sin(progress * TAU * 1.7) * 0.16
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_sring_sfx() -> void:
	if sring_sfx_player == null:
		return

	sring_sfx_player.stop()
	sring_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = sring_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.18
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var phase: float = 0.0
	var edge_phase: float = 0.0
	var glass_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var sweep_progress: float = pow(progress, 0.35)
		var current_hz: float = lerpf(6800.0, 920.0, sweep_progress)
		var attack: float = minf(progress / 0.012, 1.0)
		var tail: float = pow(1.0 - progress, 2.35)
		var envelope: float = attack * tail
		var transient: float = pow(maxf(1.0 - progress * 18.0, 0.0), 2.0)

		phase += TAU * current_hz / SFX_SAMPLE_RATE
		edge_phase += TAU * (current_hz * 1.47) / SFX_SAMPLE_RATE
		glass_phase += TAU * lerpf(5200.0, 2100.0, progress) / SFX_SAMPLE_RATE

		var blade: float = (sin(phase) * 0.65 + sin(edge_phase) * 0.28) * envelope
		var glass_ring: float = sin(glass_phase) * envelope * 0.22
		var air: float = randf_range(-1.0, 1.0) * (0.18 * envelope + 0.34 * transient)
		var sample: float = (blade + glass_ring + air) * 0.28
		var pan: float = lerpf(-0.18, 0.22, progress)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_cetar_sfx(hit_index: int) -> void:
	if cetar_sfx_player == null:
		return

	cetar_sfx_player.stop()
	cetar_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = cetar_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.16
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var pitch_offset: float = float(hit_index) * 180.0
	var glass_phase_a: float = 0.0
	var glass_phase_b: float = 0.0
	var glass_phase_c: float = 0.0
	var sub_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var attack: float = minf(progress / 0.006, 1.0)
		var tail: float = pow(1.0 - progress, 2.8)
		var envelope: float = attack * tail
		var crack_gate: float = pow(maxf(1.0 - progress * 11.0, 0.0), 2.0)
		var shard_gate_a: float = pow(maxf(1.0 - absf(progress - 0.22) * 12.0, 0.0), 2.0)
		var shard_gate_b: float = pow(maxf(1.0 - absf(progress - 0.43) * 10.0, 0.0), 2.0) * 0.75
		var shard_gate: float = maxf(crack_gate, maxf(shard_gate_a, shard_gate_b))

		glass_phase_a += TAU * (5400.0 + pitch_offset) / SFX_SAMPLE_RATE
		glass_phase_b += TAU * (7200.0 + pitch_offset * 0.7) / SFX_SAMPLE_RATE
		glass_phase_c += TAU * (3900.0 + pitch_offset * 0.45) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(118.0, 54.0, progress) / SFX_SAMPLE_RATE

		var glass_ring: float = (
			sin(glass_phase_a) * 0.34 +
			sin(glass_phase_b) * 0.26 +
			sin(glass_phase_c) * 0.22
		) * shard_gate
		var crack_noise: float = randf_range(-1.0, 1.0) * shard_gate * 0.88
		var low_hit: float = sin(sub_phase) * envelope * 0.34
		var sample: float = (glass_ring + crack_noise + low_hit) * 0.36
		var pan: float = -0.08 + float(hit_index) * 0.08
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_cosmic_basic_sfx() -> void:
	if basic_sfx_player == null:
		return

	basic_sfx_player.stop()
	basic_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = basic_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * BASIC_SFX_DURATION)
	var phase: float = 0.0
	var edge_phase: float = 0.0
	var shimmer_phase: float = 0.0
	var crystal_phase_a: float = 0.0
	var crystal_phase_b: float = 0.0
	var crystal_phase_c: float = 0.0
	var sub_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var drop_progress: float = pow(progress, 0.42)
		var current_hz: float = lerpf(BASIC_SFX_START_HZ, BASIC_SFX_END_HZ, drop_progress)
		var attack: float = minf(progress / 0.01, 1.0)
		var tail: float = pow(1.0 - progress, 2.15)
		var envelope: float = attack * tail
		var transient: float = pow(maxf(1.0 - (progress * 16.0), 0.0), 2.0)

		phase += TAU * current_hz / SFX_SAMPLE_RATE
		edge_phase += TAU * (current_hz * 1.72) / SFX_SAMPLE_RATE
		shimmer_phase += TAU * lerpf(2400.0, 780.0, progress) / SFX_SAMPLE_RATE
		crystal_phase_a += TAU * lerpf(5200.0, 2700.0, progress) / SFX_SAMPLE_RATE
		crystal_phase_b += TAU * lerpf(6400.0, 3400.0, progress) / SFX_SAMPLE_RATE
		crystal_phase_c += TAU * lerpf(3800.0, 2100.0, progress) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(82.0, 38.0, progress) / SFX_SAMPLE_RATE

		var core: float = (sin(phase) * 0.58 + sin(edge_phase) * 0.42) * envelope
		var slash_snap: float = randf_range(-1.0, 1.0) * BASIC_SFX_NOISE_MIX * transient * 1.55
		var slash_air: float = randf_range(-1.0, 1.0) * BASIC_SFX_NOISE_MIX * envelope * 0.34
		var shimmer: float = sin(shimmer_phase) * BASIC_SFX_SHIMMER_MIX * pow(maxf(1.0 - absf(progress - 0.28) * 5.0, 0.0), 2.0)
		var crystal_hit: float = pow(maxf(1.0 - absf(progress - 0.42) * 26.0, 0.0), 2.0)
		var crystal_splinter: float = pow(maxf(1.0 - absf(progress - 0.52) * 20.0, 0.0), 2.0) * 0.78
		var crystal_tail: float = pow(maxf(1.0 - absf(progress - 0.66) * 14.0, 0.0), 2.0) * 0.45
		var crystal_gate: float = maxf(crystal_hit, maxf(crystal_splinter, crystal_tail))
		var crystal_ring: float = (
			sin(crystal_phase_a) * 0.35 +
			sin(crystal_phase_b) * 0.28 +
			sin(crystal_phase_c) * 0.22
		) * crystal_gate
		var crystal_noise: float = randf_range(-1.0, 1.0) * crystal_gate * 0.9
		var crystal: float = (crystal_ring + crystal_noise) * BASIC_SFX_CRYSTAL_MIX
		var sub_envelope: float = pow(maxf(1.0 - (progress * 2.4), 0.0), 1.7)
		var sub: float = sin(sub_phase) * sub_envelope * BASIC_SFX_SUB_MIX

		var sample: float = (core + slash_snap + slash_air + shimmer + crystal + sub) * BASIC_SFX_VOLUME
		var pan: float = lerpf(-0.12, 0.16, progress)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_generated_sfx(player_node: AudioStreamPlayer, start_hz: float, end_hz: float, duration: float, noise_mix: float, volume: float, shimmer_mix: float = 0.0) -> void:
	if player_node == null:
		return

	player_node.stop()
	player_node.play()
	var playback: AudioStreamGeneratorPlayback = player_node.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var phase: float = 0.0
	var shimmer_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var current_hz: float = lerpf(start_hz, end_hz, progress)
		var envelope: float = pow(1.0 - progress, 2.0)
		phase += TAU * current_hz / SFX_SAMPLE_RATE
		var tone: float = sin(phase)

		var combined_tone: float = tone
		if shimmer_mix > 0.0:
			shimmer_phase += TAU * (current_hz * 2.01) / SFX_SAMPLE_RATE
			var shimmer_tone: float = sin(shimmer_phase)
			var tremolo: float = 0.65 + 0.35 * sin(progress * TAU * 7.0)
			combined_tone = lerpf(tone, shimmer_tone * tremolo, shimmer_mix)

		var noise: float = randf_range(-1.0, 1.0)
		var sample: float = ((combined_tone * (1.0 - noise_mix)) + (noise * noise_mix)) * envelope * volume
		playback.push_frame(Vector2(sample, sample))


func _spawn_basic_slash_effect(target: Node2D) -> void:
	var start_position: Vector2 = player.global_position + Vector2(0.0, -118.0)
	var end_position: Vector2 = target.global_position + Vector2(-10.0, -118.0)
	_spawn_slash_projectile(start_position, end_position, Color(1.0, 0.97, 0.86, 0.92), 1.0)


func _spawn_enemy_claw_effect(target: Node2D) -> void:
	var start_position: Vector2 = enemy.global_position + Vector2(0.0, -112.0)
	var end_position: Vector2 = target.global_position + Vector2(10.0, -112.0)
	_spawn_slash_projectile(start_position, end_position, Color(1.0, 0.5, 0.58, 0.88), 0.85)


func _spawn_slash_projectile(start_position: Vector2, end_position: Vector2, color: Color, scale_multiplier: float) -> void:
	if effect_layer == null:
		return

	var slash: Sprite2D = Sprite2D.new()
	slash.texture = EFFECT_SLASH_TEXTURE
	slash.flip_h = true
	slash.position = start_position
	slash.rotation = (end_position - start_position).angle()
	slash.modulate = color
	var start_scale: float = 0.07 * scale_multiplier
	slash.scale = Vector2(start_scale, start_scale)
	effect_layer.add_child(slash)

	var end_scale: float = 0.14 * scale_multiplier
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(slash, "position", end_position, 0.16)
	tween.parallel().tween_property(slash, "scale", Vector2(end_scale, end_scale), 0.16)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(slash.queue_free)


func _spawn_skill_charge_effect(origin: Node2D) -> void:
	if effect_layer == null:
		return

	var charge_position: Vector2 = origin.global_position + Vector2(6.0, -132.0)
	for index in range(2):
		var particle: Sprite2D = Sprite2D.new()
		particle.texture = EFFECT_PARTICLE_TEXTURE
		particle.position = charge_position
		particle.rotation = float(index) * 0.55
		particle.modulate = Color(0.6, 0.9, 1.0, 0.62 - (float(index) * 0.18))
		particle.scale = Vector2(0.08, 0.08)
		effect_layer.add_child(particle)

		var end_scale: float = 0.16 + (float(index) * 0.04)
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector2(end_scale, end_scale), 0.24)
		tween.parallel().tween_property(particle, "rotation", particle.rotation + 1.1, 0.24)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.24)
		tween.tween_callback(particle.queue_free)


func _spawn_triangle_rift_effect(target: Node2D, large: bool) -> void:
	if effect_layer == null:
		return

	var rift_position: Vector2 = target.global_position + Vector2(0.0, -118.0)
	var ring_count: int = 3 if large else 2
	for index in range(ring_count):
		var particle: Sprite2D = Sprite2D.new()
		particle.texture = EFFECT_PARTICLE_TEXTURE
		particle.position = rift_position
		particle.rotation = -0.65 + (float(index) * 0.42)
		particle.modulate = Color(0.55, 0.95, 1.0, 0.82 - (float(index) * 0.16))
		particle.scale = Vector2(0.09, 0.09)
		effect_layer.add_child(particle)

		var end_scale: float = 0.2 + (float(index) * 0.05)
		if large:
			end_scale += 0.08
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector2(end_scale, end_scale), 0.22)
		tween.parallel().tween_property(particle, "rotation", particle.rotation + 1.25, 0.22)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.22)
		tween.tween_callback(particle.queue_free)


func _resolve_triangle_rift_damage() -> void:
	if state != BattleState.ACTION_RESOLUTION:
		return

	_play_skill_release_sfx()
	_spawn_triangle_rift_projectile(player, enemy)

	await get_tree().create_timer(SKILL_RIFT_PROJECTILE_DURATION).timeout
	if state != BattleState.ACTION_RESOLUTION:
		return

	enemy.take_damage(SKILL_DAMAGE)
	_show_floating_damage(enemy, SKILL_DAMAGE)

	await _play_triangle_rift_impact(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		return

	await enemy.play_hit_feedback()


func _spawn_triangle_rift_projectile(origin: Node2D, target: Node2D) -> void:
	if effect_layer == null or origin == null or target == null:
		return

	var start_position: Vector2 = origin.global_position + Vector2(28.0, -128.0)
	var end_position: Vector2 = target.global_position + Vector2(-8.0, -118.0)

	var projectile: Sprite2D = Sprite2D.new()
	projectile.texture = EFFECT_PARTICLE_TEXTURE
	projectile.position = start_position
	projectile.rotation = (end_position - start_position).angle()
	projectile.modulate = Color(0.45, 0.95, 1.0, 0.95)
	projectile.scale = Vector2(0.08, 0.08)
	projectile.z_index = 18
	effect_layer.add_child(projectile)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(projectile, "position", end_position, SKILL_RIFT_PROJECTILE_DURATION)
	tween.parallel().tween_property(projectile, "scale", Vector2(0.18, 0.18), SKILL_RIFT_PROJECTILE_DURATION)
	tween.parallel().tween_property(projectile, "rotation", projectile.rotation + 0.8, SKILL_RIFT_PROJECTILE_DURATION)
	tween.parallel().tween_property(projectile, "modulate:a", 0.0, SKILL_RIFT_PROJECTILE_DURATION + 0.04)
	tween.tween_callback(projectile.queue_free)


func _play_triangle_rift_impact(target: Node2D) -> void:
	if effect_layer == null or target == null:
		return

	_play_rift_crack_sfx()
	_play_screen_flash(Color(0.55, 0.92, 1.0, 0.22), 0.09)
	_spawn_triangle_rift_effect(target, false)
	_spawn_hit_spark(target, Color(0.45, 0.92, 1.0, 1.0))
	_spawn_triangle_rift_break(target, 0)
	_shake_camera_with_strength(SKILL_RIFT_CAMERA_SHAKE)

	await _shake_target_once(target, SKILL_RIFT_TARGET_SHAKE, 0.055)

	for pulse_index in range(SKILL_RIFT_IMPACT_PULSE_COUNT):
		if state != BattleState.ACTION_RESOLUTION:
			return

		_play_rift_crack_sfx()
		_spawn_triangle_rift_break(target, pulse_index + 1)
		_spawn_rift_crack_slashes(target, pulse_index)
		_spawn_rift_after_particles(target, pulse_index)
		_shake_camera_with_strength(SKILL_RIFT_CAMERA_SHAKE + float(pulse_index) * 1.5)

		await _shake_target_once(target, SKILL_RIFT_TARGET_SHAKE + float(pulse_index) * 2.0, 0.045)
		await get_tree().create_timer(SKILL_RIFT_IMPACT_INTERVAL).timeout


func _spawn_triangle_rift_break(target: Node2D, pulse_index: int) -> void:
	if effect_layer == null or target == null:
		return

	var impact_position: Vector2 = target.global_position + Vector2(0.0, -118.0)

	var burst: Sprite2D = Sprite2D.new()
	burst.texture = EFFECT_PARTICLE_TEXTURE
	burst.position = impact_position
	burst.rotation = randf_range(-0.45, 0.45)
	burst.modulate = Color(0.42, 0.95, 1.0, 0.92)
	burst.scale = Vector2(0.08, 0.08)
	burst.z_index = 19
	effect_layer.add_child(burst)

	var end_scale: float = 0.26 + float(pulse_index) * 0.05
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "scale", Vector2(end_scale, end_scale), 0.10)
	tween.parallel().tween_property(burst, "rotation", burst.rotation + randf_range(-1.4, 1.4), 0.16)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.18)
	tween.tween_callback(burst.queue_free)


func _spawn_rift_crack_slashes(target: Node2D, pulse_index: int) -> void:
	if effect_layer == null or target == null:
		return

	var impact_position: Vector2 = target.global_position + Vector2(0.0, -118.0)
	var slash_count: int = 3

	for index in range(slash_count):
		var slash: Sprite2D = Sprite2D.new()
		slash.texture = EFFECT_SLASH_TEXTURE
		slash.position = impact_position + Vector2(randf_range(-18.0, 18.0), randf_range(-16.0, 12.0))
		slash.rotation = deg_to_rad(randf_range(-58.0, 58.0))
		slash.modulate = Color(0.68, 0.96, 1.0, 0.78)
		slash.scale = Vector2(0.04, 0.04)
		slash.z_index = 20
		effect_layer.add_child(slash)

		var end_scale: float = 0.12 + float(pulse_index) * 0.025
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "scale", Vector2(end_scale, end_scale), 0.08)
		tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.14)
		tween.parallel().tween_property(slash, "rotation", slash.rotation + deg_to_rad(randf_range(-16.0, 16.0)), 0.14)
		tween.tween_callback(slash.queue_free)


func _spawn_rift_after_particles(target: Node2D, pulse_index: int) -> void:
	if effect_layer == null or target == null:
		return

	var impact_position: Vector2 = target.global_position + Vector2(0.0, -118.0)
	var particle_count: int = 9 + pulse_index * 2

	for index in range(particle_count):
		var particle: Sprite2D = Sprite2D.new()
		particle.texture = EFFECT_PARTICLE_TEXTURE
		particle.position = impact_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		particle.rotation = randf_range(-PI, PI)
		particle.modulate = Color(
			randf_range(0.35, 0.7),
			randf_range(0.86, 1.0),
			1.0,
			randf_range(0.58, 0.9)
		)
		var start_scale: float = randf_range(0.03, 0.065)
		particle.scale = Vector2(start_scale, start_scale)
		particle.z_index = 21
		effect_layer.add_child(particle)

		var angle: float = randf_range(-PI, PI)
		var distance: float = randf_range(24.0, 66.0) + float(pulse_index) * 8.0
		var end_position: Vector2 = impact_position + Vector2(cos(angle), sin(angle)) * distance

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", end_position, 0.24)
		tween.parallel().tween_property(particle, "rotation", particle.rotation + randf_range(-2.0, 2.0), 0.24)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.24)
		tween.tween_callback(particle.queue_free)


func _spawn_hit_spark(target: Node2D, color: Color) -> void:
	if effect_layer == null:
		return

	var spark_position: Vector2 = target.global_position + Vector2(0.0, -110.0)
	var spark: Sprite2D = Sprite2D.new()
	spark.texture = EFFECT_SPLASH_TEXTURE
	spark.position = spark_position
	spark.modulate = color
	spark.scale = Vector2(0.05, 0.05)
	effect_layer.add_child(spark)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.11)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.16)
	tween.tween_callback(spark.queue_free)


func _play_basic_cetar_impact(target: Node2D) -> void:
	_play_sring_sfx()
	_spawn_hit_spark(target, Color(1.0, 0.95, 0.62, 1.0))
	_spawn_cetar_text(target, "SRIING", Color(0.78, 0.96, 1.0, 1.0))
	_play_screen_flash(Color(0.92, 0.97, 1.0, 0.22), 0.08)
	_shake_target_once(target, BASIC_CETAR_TARGET_SHAKE * 0.65, BASIC_CETAR_INTERVAL * 0.75)
	_shake_camera_with_strength(BASIC_CETAR_CAMERA_SHAKE * 0.65)
	await get_tree().create_timer(0.045).timeout

	for hit_index in range(BASIC_CETAR_HIT_COUNT):
		if state != BattleState.ACTION_RESOLUTION:
			return

		_play_cetar_sfx(hit_index)
		_spawn_hit_spark(target, Color(1.0, 0.84, 0.32, 1.0))
		_spawn_cetar_slash_cross(target, hit_index)
		_spawn_cetar_triangle_shards(target, hit_index)
		_spawn_cetar_text(target, "CETAR", Color(1.0, 0.86, 0.38, 1.0))
		_shake_target_once(target, BASIC_CETAR_TARGET_SHAKE + float(hit_index) * 1.5, BASIC_CETAR_INTERVAL * 0.75)
		_shake_camera_with_strength(BASIC_CETAR_CAMERA_SHAKE + float(hit_index) * 0.8)
		_play_screen_flash(Color(1.0, 0.92, 0.62, 0.18), 0.06)
		await get_tree().create_timer(BASIC_CETAR_INTERVAL).timeout


func _spawn_cetar_slash_cross(target: Node2D, burst_index: int) -> void:
	if effect_layer == null:
		return

	var center_position: Vector2 = target.global_position + Vector2(0.0, -112.0)
	var angles: Array[float] = [-0.72, 0.68, -0.08]
	var colors: Array[Color] = [
		Color(1.0, 0.96, 0.68, 0.9),
		Color(0.68, 0.96, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.78)
	]

	for slash_index in range(angles.size()):
		var slash: Sprite2D = Sprite2D.new()
		slash.texture = EFFECT_SLASH_TEXTURE
		slash.flip_h = slash_index % 2 == 0
		slash.position = center_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		slash.rotation = angles[slash_index] + float(burst_index) * 0.14
		slash.modulate = colors[slash_index]
		var start_scale: float = 0.09 + float(burst_index) * 0.012 + float(slash_index) * 0.01
		slash.scale = Vector2(start_scale, start_scale)
		effect_layer.add_child(slash)

		var end_scale: float = start_scale + 0.13
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "scale", Vector2(end_scale, end_scale), 0.11)
		tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.13)
		tween.parallel().tween_property(slash, "position", slash.position + Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)), 0.13)
		tween.tween_callback(slash.queue_free)


func _spawn_cetar_triangle_shards(target: Node2D, burst_index: int) -> void:
	if effect_layer == null:
		return

	var shard_origin: Vector2 = target.global_position + Vector2(0.0, -112.0)
	var shard_count: int = 7 + burst_index
	for shard_index in range(shard_count):
		var particle: Sprite2D = Sprite2D.new()
		particle.texture = EFFECT_PARTICLE_TEXTURE
		particle.position = shard_origin + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
		particle.rotation = randf_range(-PI, PI)
		particle.modulate = Color(0.78, 0.96, 1.0, 0.78)
		var start_scale: float = randf_range(0.035, 0.055)
		particle.scale = Vector2(start_scale, start_scale)
		effect_layer.add_child(particle)

		var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(-PI, PI))
		var distance: float = randf_range(28.0, 62.0) + float(burst_index) * 6.0
		var end_position: Vector2 = particle.position + direction * distance
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", end_position, 0.18)
		tween.parallel().tween_property(particle, "rotation", particle.rotation + randf_range(-2.4, 2.4), 0.18)
		tween.parallel().tween_property(particle, "scale", Vector2(start_scale * 1.65, start_scale * 1.65), 0.12)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.2)
		tween.tween_callback(particle.queue_free)


func _spawn_cetar_text(target: Node2D, text_value: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.z_index = 22
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	battle_scene.add_child(label)

	var start_position: Vector2 = target.position + Vector2(randf_range(-34.0, 18.0), randf_range(-142.0, -112.0))
	label.position = start_position
	label.rotation = randf_range(-0.12, 0.12)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", start_position + Vector2(randf_range(-8.0, 8.0), -BASIC_CETAR_TEXT_RISE), 0.28)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.28)
	tween.tween_callback(label.queue_free)


func _play_screen_flash(color: Color, duration: float) -> void:
	if screen_flash == null:
		return

	screen_flash.visible = true
	screen_flash.color = color
	screen_flash.modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(screen_flash, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(self, "_hide_screen_flash"))


func _hide_screen_flash() -> void:
	if screen_flash != null:
		screen_flash.visible = false
		screen_flash.modulate = Color.WHITE


func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file(PROLOGUE_SCENE_PATH)


func _win(log_text: String) -> void:
	state = BattleState.WIN
	timing_bar.cancel_window()
	ui.set_turn_text("Victory")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	_update_action_buttons(false)
	ui.set_restart_visible(true)
	await get_tree().create_timer(0.8).timeout
	if state == BattleState.WIN:
		get_tree().change_scene_to_file(ENDING_SCENE_PATH)


func _lose(log_text: String) -> void:
	state = BattleState.LOSE
	timing_bar.cancel_window()
	ui.set_turn_text("Defeat")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	_update_action_buttons(false)
	ui.set_restart_visible(true)


func _refresh_energy_ui() -> void:
	ui.set_energy(ultimate_energy, MAX_ULTIMATE_ENERGY)


func _refresh_player_status_ui() -> void:
	ui.set_player_status_hp(player.current_hp, player.max_hp)


func _refresh_skill_points_ui() -> void:
	ui.set_skill_points(skill_points, MAX_SKILL_POINTS)


func _update_action_buttons(enabled: bool) -> void:
	ui.set_actions_enabled(enabled, ultimate_energy >= MAX_ULTIMATE_ENERGY, skill_points >= SKILL_POINT_COST_SKILL)


func _add_ultimate_energy(amount: int) -> void:
	ultimate_energy = mini(ultimate_energy + amount, MAX_ULTIMATE_ENERGY)
	_refresh_energy_ui()


func _add_skill_points(amount: int) -> void:
	skill_points = mini(skill_points + amount, MAX_SKILL_POINTS)
	_refresh_skill_points_ui()


func _spend_skill_points(amount: int) -> void:
	skill_points = maxi(skill_points - amount, 0)
	_refresh_skill_points_ui()


func _finish_player_action(log_text: String) -> void:
	_refresh_energy_ui()
	_refresh_skill_points_ui()
	_start_player_idle_animation()
	if enemy.is_defeated():
		_win("Enemy defeated. You win!")
		return

	_begin_enemy_turn(log_text)


func _is_battle_over() -> bool:
	return state == BattleState.WIN or state == BattleState.LOSE


func _show_floating_damage(target: Combatant, damage: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % damage
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	battle_scene.add_child(label)

	var start_position: Vector2 = target.position + Vector2(-18.0, -105.0)
	label.position = start_position

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", start_position + Vector2(0.0, -FLOATING_TEXT_RISE), 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)


func _shake_camera() -> void:
	_shake_camera_with_strength(CAMERA_SHAKE_OFFSET)


func _shake_camera_with_strength(strength: float) -> void:
	if battle_camera == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(battle_camera, "offset", Vector2(strength, randf_range(-1.5, 1.5)), 0.025)
	tween.tween_property(battle_camera, "offset", Vector2(-strength, randf_range(-1.5, 1.5)), 0.035)
	tween.tween_property(battle_camera, "offset", Vector2.ZERO, 0.035)


func _shake_target_once(target: Node2D, strength: float, duration: float) -> Signal:
	if target == null:
		return get_tree().process_frame

	var original_position: Vector2 = target.position
	var half_duration: float = duration * 0.5
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		target,
		"position",
		original_position + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength * 0.35, strength * 0.35)
		),
		half_duration
	)
	tween.tween_property(target, "position", original_position, half_duration)
	return tween.finished


func _reset_camera() -> void:
	if battle_camera != null:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
			viewport_size = BASE_VIEWPORT_SIZE
		battle_camera.position = viewport_size * 0.5
		battle_camera.offset = Vector2.ZERO
		battle_camera.zoom = Vector2.ONE


func _set_player_action_texture(texture: Texture2D) -> void:
	if texture == TAKASHI_IDLE_TEXTURE:
		_start_player_idle_animation()
		return

	if texture == TAKASHI_BASIC_TEXTURE:
		_start_player_basic_animation()
		return

	if texture == TAKASHI_SKILL_TEXTURE:
		_start_player_skill_animation()
		return

	_stop_player_idle_animation()
	_stop_player_basic_animation()
	_stop_player_skill_animation()
	if player_action_sprite != null and texture != null:
		_set_player_action_frame(texture)


func _set_player_action_frame(texture: Texture2D) -> void:
	if player_action_sprite == null or texture == null:
		return

	player_action_sprite.texture = texture
	_apply_player_action_sprite_grounding()
	_sync_takashi_ultimate_glow_frame()


func _setup_takashi_idle_frames() -> void:
	takashi_idle_frames = _load_texture_frames(TAKASHI_IDLE_FRAME_PATHS)


func _setup_takashi_basic_frames() -> void:
	takashi_basic_frames = _load_texture_frames(TAKASHI_BASIC_FRAME_PATHS)


func _setup_takashi_skill_frames() -> void:
	takashi_skill_frames = _load_texture_frames(TAKASHI_SKILL_FRAME_PATHS)


func _setup_takashi_ulti_pre_frames() -> void:
	takashi_ulti_pre_frames = _load_texture_frames(TAKASHI_ULTI_PRE_FRAME_PATHS)


func _setup_takashi_ulti_post_frames() -> void:
	takashi_ulti_post_frames = _load_texture_frames(TAKASHI_ULTI_POST_FRAME_PATHS)


func _setup_takashi_ultimate_fvx_frames() -> void:
	takashi_ultimate_fvx_frames = _load_texture_frames(TAKASHI_ULTIMATE_FVX_FRAME_PATHS)


func _load_texture_frames(frame_paths: Array[String]) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_path in frame_paths:
		if not FileAccess.file_exists(frame_path):
			continue

		var frame_texture: Texture2D = load(frame_path) as Texture2D
		if frame_texture != null:
			frames.append(frame_texture)
	return frames


func _start_player_idle_animation() -> void:
	if player_action_sprite == null:
		return

	_stop_player_basic_animation()
	_stop_player_skill_animation()
	if takashi_idle_frames.is_empty():
		_set_player_action_frame(TAKASHI_IDLE_TEXTURE)
		return

	idle_animation_playing = true
	idle_frame_index = 0
	idle_frame_elapsed = 0.0
	_set_player_action_frame(takashi_idle_frames[idle_frame_index])


func _stop_player_idle_animation() -> void:
	if not idle_animation_playing:
		return

	idle_animation_playing = false


func _start_player_basic_animation() -> void:
	if player_action_sprite == null:
		return

	_stop_player_idle_animation()
	_stop_player_skill_animation()
	if takashi_basic_frames.is_empty():
		_set_player_action_frame(TAKASHI_BASIC_TEXTURE)
		return

	basic_animation_playing = true
	basic_frame_index = 0
	basic_frame_elapsed = 0.0
	_set_player_action_frame(takashi_basic_frames[basic_frame_index])


func _stop_player_basic_animation() -> void:
	if not basic_animation_playing:
		return

	basic_animation_playing = false


func _start_player_skill_animation() -> void:
	if player_action_sprite == null:
		return

	_stop_player_idle_animation()
	_stop_player_basic_animation()
	if takashi_skill_frames.is_empty():
		_set_player_action_frame(TAKASHI_SKILL_TEXTURE)
		return

	skill_animation_playing = true
	skill_frame_index = 0
	skill_frame_elapsed = 0.0
	_set_player_action_frame(takashi_skill_frames[skill_frame_index])


func _stop_player_skill_animation() -> void:
	if not skill_animation_playing:
		return

	skill_animation_playing = false


func _advance_player_idle_animation(delta: float) -> void:
	if not idle_animation_playing or player_action_sprite == null or takashi_idle_frames.is_empty():
		return

	idle_frame_elapsed += delta
	var frame_duration: float = 1.0 / TAKASHI_IDLE_FRAME_RATE
	while idle_frame_elapsed >= frame_duration:
		idle_frame_elapsed -= frame_duration
		idle_frame_index = (idle_frame_index + 1) % takashi_idle_frames.size()
		_set_player_action_frame(takashi_idle_frames[idle_frame_index])


func _advance_player_basic_animation(delta: float) -> void:
	if not basic_animation_playing or player_action_sprite == null or takashi_basic_frames.is_empty():
		return

	basic_frame_elapsed += delta
	var frame_duration: float = 1.0 / TAKASHI_BASIC_FRAME_RATE
	while basic_frame_elapsed >= frame_duration:
		basic_frame_elapsed -= frame_duration
		basic_frame_index = (basic_frame_index + 1) % takashi_basic_frames.size()
		_set_player_action_frame(takashi_basic_frames[basic_frame_index])


func _advance_player_skill_animation(delta: float) -> void:
	if not skill_animation_playing or player_action_sprite == null or takashi_skill_frames.is_empty():
		return

	skill_frame_elapsed += delta
	var frame_duration: float = 1.0 / TAKASHI_SKILL_FRAME_RATE
	while skill_frame_elapsed >= frame_duration:
		skill_frame_elapsed -= frame_duration
		if skill_frame_index >= takashi_skill_frames.size() - 1:
			skill_animation_playing = false
			return

		skill_frame_index += 1
		_set_player_action_frame(takashi_skill_frames[skill_frame_index])
