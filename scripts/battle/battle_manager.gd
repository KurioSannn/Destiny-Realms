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
		player_ground_shadow.position = player_home_position + Vector2(0.0, 58.0)

	if enemy_ground_shadow != null:
		enemy_ground_shadow.position = enemy_home_position + Vector2(0.0, 48.0)


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
	_set_player_action_texture(TAKASHI_ULTIMATE_TEXTURE)
	_update_action_buttons(false)
	ui.set_turn_text("Octagram Fragment")
	ui.set_battle_log("Octagram Fragment awakens.")
	ultimate_energy = 0
	_refresh_energy_ui()
	await _play_ultimate_sequence()
	if state != BattleState.ACTION_RESOLUTION:
		return

	await player.play_ultimate_feedback()
	if state != BattleState.ACTION_RESOLUTION:
		return

	await player.play_skill_movement(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		return

	_play_impact_sfx()
	_spawn_ultimate_impact_effect(enemy)
	enemy.take_damage(ULTIMATE_DAMAGE)
	_show_floating_damage(enemy, ULTIMATE_DAMAGE)
	await enemy.play_hit_feedback()
	_shake_camera()
	_finish_player_action("Octagram Fragment deals %d damage and consumes all energy." % ULTIMATE_DAMAGE)


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

	ultimate_frame_player.visible = true
	ultimate_frame_player.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if ultimate_audio_player != null and ultimate_audio_player.stream != null:
		ultimate_audio_player.stop()
		ultimate_audio_player.play()

	var frame_duration: float = 1.0 / ULTIMATE_FRAME_RATE
	for frame_texture in ultimate_frames:
		if state != BattleState.ACTION_RESOLUTION:
			break
		ultimate_frame_player.texture = frame_texture
		await get_tree().create_timer(frame_duration).timeout

	if ultimate_audio_player != null:
		ultimate_audio_player.stop()
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
	stream.buffer_length = 0.45
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

	playback.clear_buffer()
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

	playback.clear_buffer()
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

	playback.clear_buffer()
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


func _play_sring_sfx() -> void:
	if sring_sfx_player == null:
		return

	sring_sfx_player.stop()
	sring_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = sring_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	playback.clear_buffer()
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

	playback.clear_buffer()
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

	playback.clear_buffer()
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

	playback.clear_buffer()
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var current_hz: float = lerpf(start_hz, end_hz, progress)
		var envelope: float = pow(1.0 - progress, 2.0)
		phase += TAU * current_hz / SFX_SAMPLE_RATE
		var tone: float = sin(phase)
		var noise: float = randf_range(-1.0, 1.0)
		var sample: float = ((tone * (1.0 - noise_mix)) + (noise * noise_mix)) * envelope * volume
		playback.push_frame(Vector2(sample, sample))


func _spawn_basic_slash_effect(target: Node2D) -> void:
	var impact_position: Vector2 = target.global_position + Vector2(-10.0, -118.0)
	_spawn_slash_sprite(impact_position, -0.45, Color(1.0, 0.97, 0.86, 0.92), 1.0)


func _spawn_enemy_claw_effect(target: Node2D) -> void:
	var impact_position: Vector2 = target.global_position + Vector2(10.0, -112.0)
	_spawn_slash_sprite(impact_position, 0.5, Color(1.0, 0.5, 0.58, 0.88), 0.85)


func _spawn_slash_sprite(start_position: Vector2, rotation_radians: float, color: Color, scale_multiplier: float) -> void:
	if effect_layer == null:
		return

	var slash: Sprite2D = Sprite2D.new()
	slash.texture = EFFECT_SLASH_TEXTURE
	slash.position = start_position
	slash.rotation = rotation_radians
	slash.modulate = color
	var start_scale: float = 0.08 * scale_multiplier
	slash.scale = Vector2(start_scale, start_scale)
	effect_layer.add_child(slash)

	var end_scale: float = 0.13 * scale_multiplier
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(slash, "scale", Vector2(end_scale, end_scale), 0.1)
	tween.parallel().tween_property(slash, "position", start_position + Vector2(42.0, -8.0), 0.1)
	tween.tween_property(slash, "modulate:a", 0.0, 0.12)
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


func _spawn_ultimate_impact_effect(target: Node2D) -> void:
	_play_screen_flash(Color(0.95, 0.95, 1.0, 0.38), 0.18)
	_spawn_triangle_rift_effect(target, true)
	_spawn_hit_spark(target, Color(1.0, 0.86, 0.34, 1.0))


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
	if battle_camera == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(battle_camera, "offset", Vector2(CAMERA_SHAKE_OFFSET, 0.0), 0.03)
	tween.tween_property(battle_camera, "offset", Vector2(-CAMERA_SHAKE_OFFSET, 0.0), 0.05)
	tween.tween_property(battle_camera, "offset", Vector2.ZERO, 0.04)


func _reset_camera() -> void:
	if battle_camera != null:
		battle_camera.offset = Vector2.ZERO


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
		player_action_sprite.texture = texture


func _setup_takashi_idle_frames() -> void:
	takashi_idle_frames = _load_texture_frames(TAKASHI_IDLE_FRAME_PATHS)


func _setup_takashi_basic_frames() -> void:
	takashi_basic_frames = _load_texture_frames(TAKASHI_BASIC_FRAME_PATHS)


func _setup_takashi_skill_frames() -> void:
	takashi_skill_frames = _load_texture_frames(TAKASHI_SKILL_FRAME_PATHS)


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
		player_action_sprite.texture = TAKASHI_IDLE_TEXTURE
		return

	idle_animation_playing = true
	idle_frame_index = 0
	idle_frame_elapsed = 0.0
	player_action_sprite.texture = takashi_idle_frames[idle_frame_index]


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
		player_action_sprite.texture = TAKASHI_BASIC_TEXTURE
		return

	basic_animation_playing = true
	basic_frame_index = 0
	basic_frame_elapsed = 0.0
	player_action_sprite.texture = takashi_basic_frames[basic_frame_index]


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
		player_action_sprite.texture = TAKASHI_SKILL_TEXTURE
		return

	skill_animation_playing = true
	skill_frame_index = 0
	skill_frame_elapsed = 0.0
	player_action_sprite.texture = takashi_skill_frames[skill_frame_index]


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
		player_action_sprite.texture = takashi_idle_frames[idle_frame_index]


func _advance_player_basic_animation(delta: float) -> void:
	if not basic_animation_playing or player_action_sprite == null or takashi_basic_frames.is_empty():
		return

	basic_frame_elapsed += delta
	var frame_duration: float = 1.0 / TAKASHI_BASIC_FRAME_RATE
	while basic_frame_elapsed >= frame_duration:
		basic_frame_elapsed -= frame_duration
		basic_frame_index = (basic_frame_index + 1) % takashi_basic_frames.size()
		player_action_sprite.texture = takashi_basic_frames[basic_frame_index]


func _advance_player_skill_animation(delta: float) -> void:
	if not skill_animation_playing or player_action_sprite == null or takashi_skill_frames.is_empty():
		return

	skill_frame_elapsed += delta
	var frame_duration: float = 1.0 / TAKASHI_SKILL_FRAME_RATE
	while skill_frame_elapsed >= frame_duration:
		skill_frame_elapsed -= frame_duration
		skill_frame_index = (skill_frame_index + 1) % takashi_skill_frames.size()
		player_action_sprite.texture = takashi_skill_frames[skill_frame_index]
