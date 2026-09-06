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
## Block 9H: combat feel tuning. A short, purely cosmetic "impact hold" --
## a brief pause after damage/the floating number already appear and
## before the existing hit-feedback/multi-hit continuation -- so the
## moment of impact reads as a distinct beat instead of blending into the
## follow-up animation. Local (a single get_tree().create_timer() await,
## the same primitive already used throughout this file), never a global
## Engine.time_scale change, and always placed strictly after
## take_damage()/resource mutation already happened -- it can delay
## cosmetic follow-through but can never delay, duplicate, or block
## authoritative resolution. Durations scale with each action's existing
## weight (Basic lightest, Ultimate heaviest, matching the baseline audit
## in docs/battle_system_spec.md, "Block 9H implementation status").
const BASIC_IMPACT_HOLD_SECONDS: float = 0.03
const SKILL_IMPACT_HOLD_SECONDS: float = 0.05
const ULTIMATE_IMPACT_HOLD_SECONDS: float = 0.08
const ENEMY_IMPACT_HOLD_SECONDS: float = 0.05
const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const PLAYER_VIEWPORT_POSITION: Vector2 = Vector2(0.34, 0.70)
const ENEMY_VIEWPORT_POSITION: Vector2 = Vector2(0.68, 0.70)
const PLAYER_ACTION_SPRITE_SCALE: Vector2 = Vector2(0.18, 0.18)
const PLAYER_ACTION_SPRITE_GROUND_Y: float = 46.0
const PROLOGUE_SCENE_PATH: String = "res://scenes/prologue/prologue_scene.tscn"
const ENDING_SCENE_PATH: String = "res://scenes/ending/ending_scene.tscn"
const GRASSLANDS_SCENE_PATH: String = "res://scenes/grasslands/grasslands_scene.tscn"
const BANDIT_ENCOUNTER_ID: StringName = &"clover_bandit"
const BANDIT_BGM_PATH: String = "res://public/The_Clover_Clash.mp3"
const BANDIT_BACKGROUND_PATH: String = "res://public/grasslands/old_stone_crossing.png"
## Block 14: minimal enemy-id -> stats lookup so an EncounterContext's
## battle_enemy_ids (StringName) can configure a battle without the
## exploration side duplicating battle stats in its own resources. Existing
## bandit configuration in _configure_encounter() is untouched and does not
## use this table.
const BATTLE_ENEMY_RESOURCES: Dictionary = {
	&"lesser_abyss": preload("res://resources/battle_enemies/lesser_abyss.tres"),
	&"clover_bandit": preload("res://resources/battle_enemies/clover_bandit.tres"),
}
const BATTLE_ENEMY_FALLBACK_CATALOG: Dictionary = {
	&"lesser_abyss": {"name": "Lesser Abyss", "max_hp": 120, "damage": 14},
	&"clover_bandit": {"name": "Bandit Captain", "max_hp": 150, "damage": 12},
}
const BATTLE_ENEMY_CATALOG: Dictionary = BATTLE_ENEMY_FALLBACK_CATALOG

const BattleEnemyProfileScript = preload("res://scripts/battle/battle_enemy_profile.gd")

static func get_enemy_battle_profile_data(enemy_id: StringName) -> Dictionary:
	if BATTLE_ENEMY_RESOURCES.has(enemy_id):
		var profile = BATTLE_ENEMY_RESOURCES[enemy_id]
		if profile is BattleEnemyProfileScript or (profile != null and profile.has_method("to_dict")):
			return profile.to_dict()
	return BATTLE_ENEMY_FALLBACK_CATALOG.get(enemy_id, {})

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
const TAKASHI_ULTIMATE_GLOW_SHADER: Shader = preload("res://shaders/battle/takashi_ultimate_glow.gdshader")

const ULTIMATE_CAMERA_ZOOM: Vector2 = Vector2(1.85, 1.85)
const ULTIMATE_CAMERA_FOCUS_OFFSET: Vector2 = Vector2(12.0, -92.0)
const ULTIMATE_ZOOM_DURATION: float = 0.6
const ULTIMATE_ZOOM_OUT_DURATION: float = 0.28
const ENEMY_IMPACT_FOCUS_OFFSET: Vector2 = Vector2(0.0, -125.0)
const ENEMY_IMPACT_ZOOM_DURATION: float = 0.38
const ENEMY_IMPACT_ZOOM_OUT_DURATION: float = 0.32
const ENEMY_IMPACT_FVX_TARGET_HEIGHT: float = 320.0
const EFFECT_SLASH_TEXTURE: Texture2D = preload("res://public/effects/slash.png")
const EFFECT_SPLASH_TEXTURE: Texture2D = preload("res://public/effects/Splash.png")
const EFFECT_PARTICLE_TEXTURE: Texture2D = preload("res://public/effects/Particle Efect.png")
const ULTIMATE_AUDIO_VOLUME_DB: float = 5.0
const BasicAttackAdapter := preload(
	"res://scripts/battle/command/basic_attack_command_adapter.gd"
)
const SkillCommandAdapterScript := preload(
	"res://scripts/battle/command/skill_command_adapter.gd"
)
const UltimateCommandAdapterScript := preload(
	"res://scripts/battle/command/ultimate_command_adapter.gd"
)
const BattleVfxScript := preload("res://scripts/battle/battle_vfx.gd")
const TakashiBattleAnimatorScript := preload("res://scripts/battle/takashi_battle_animator.gd")
const TakashiUltimateEffectsScript := preload("res://scripts/battle/takashi_ultimate_effects.gd")


@export var use_new_basic_command_flow: bool = true
@export var use_new_skill_command_flow: bool = true
@export var use_new_ultimate_command_flow: bool = true

@onready var player: Combatant = $"../Player"
@onready var enemy: Combatant = $"../Enemy"
## Block 14.5: named formation slots for dynamically spawned encounter-group
## enemies (EnemySlot0 mirrors the primary Enemy node's own position, for
## reference only -- the primary node is never moved). Optional so this
## still works if an older/duplicated battle_scene.tscn lacks the group.
@onready var enemy_formation: Node2D = get_node_or_null("../EnemyFormation")
@onready var ui: BattleUI = $"../CanvasLayer/BattleUI"
@onready var timing_bar: TimingBar = $"../CanvasLayer/BattleUI/TimingBar"
@onready var battle_scene: Node2D = $".."
@onready var battle_camera: Camera2D = get_node_or_null("../BattleCamera") as Camera2D
@onready var battle_presentation_3d: BattlePresentation3D = get_node_or_null("../BattlePresentation3D") as BattlePresentation3D
## Block 9H: the only fire-and-forget camera tween in this file (every
## other camera tween -- Ultimate zoom in/out, enemy impact zoom -- is
## always awaited by its caller before continuing). Tracked so
## _reset_camera() can kill it: without this, a shake still mid-flight
## when _win()/_lose() fires could keep overwriting the just-reset
## offset for the shake's remaining ~0.1s, leaving a stray offset
## briefly visible instead of the guaranteed-clean camera state.
var _camera_shake_tween: Tween
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
@onready var enemy_action_sprite: Sprite2D = get_node_or_null("../Enemy/ActionSprite") as Sprite2D
@onready var enemy_placeholder_visual: CanvasItem = get_node_or_null("../Enemy/PlaceholderVisual") as CanvasItem
@onready var enemy_title_label: Label = get_node_or_null("../CanvasLayer/BattleUI/EnemyStatusPanel/EnemyTitleLabel") as Label
@onready var encounter_label: Label = get_node_or_null("../CanvasLayer/BattleUI/BattleHeaderPanel/EncounterLabel") as Label
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
var battle_sfx: BattleSfx
var battle_vfx: Node
var takashi_animator: Node
var takashi_ultimate_effects: Node
var takashi_idle_frames: Array[Texture2D] = []
## Block 15.1: real animation state now lives on takashi_animator
## (TakashiBattleAnimator) since the frame-ticking extraction. These stay as
## read-only mirrors -- rather than plain stored bools that nothing updates
## -- so any code (or test) still reading BattleManager's own
## idle/basic/skill_animation_playing/looping sees the real, current state
## instead of a permanently-false leftover.
var idle_animation_playing: bool:
	get: return takashi_animator.idle_animation_playing if takashi_animator != null else false
var idle_frame_index: int = 0
var idle_frame_elapsed: float = 0.0
var takashi_basic_frames: Array[Texture2D] = []
var basic_animation_playing: bool:
	get: return takashi_animator.basic_animation_playing if takashi_animator != null else false
var basic_frame_index: int = 0
var basic_frame_elapsed: float = 0.0
var takashi_skill_frames: Array[Texture2D] = []
var skill_animation_playing: bool:
	get: return takashi_animator.skill_animation_playing if takashi_animator != null else false
var skill_frame_index: int = 0
var skill_frame_elapsed: float = 0.0
var takashi_ulti_pre_frames: Array[Texture2D] = []
var takashi_ulti_post_frames: Array[Texture2D] = []
var takashi_ultimate_fvx_frames: Array[Texture2D]:
	get: return takashi_ultimate_effects.takashi_ultimate_fvx_frames if takashi_ultimate_effects != null else []
var takashi_ultimate_fvx_sprite: Sprite2D:
	get: return takashi_ultimate_effects.takashi_ultimate_fvx_sprite if takashi_ultimate_effects != null else null
var takashi_ultimate_fvx_glow_sprite: Sprite2D:
	get: return takashi_ultimate_effects.takashi_ultimate_fvx_glow_sprite if takashi_ultimate_effects != null else null
var takashi_ultimate_character_glow_sprite: Sprite2D:
	get: return takashi_ultimate_effects.takashi_ultimate_character_glow_sprite if takashi_ultimate_effects != null else null
var takashi_ultimate_fvx_playing: bool:
	get: return takashi_ultimate_effects.takashi_ultimate_fvx_playing if takashi_ultimate_effects != null else false
var takashi_ultimate_fvx_frame_index: int = 0
var takashi_ultimate_fvx_frame_elapsed: float = 0.0
var battle_ui_visible_before_ultimate: bool = true
var enemy_impact_fvx_sprite: Sprite2D:
	get: return takashi_ultimate_effects.enemy_impact_fvx_sprite if takashi_ultimate_effects != null else null
var enemy_impact_fvx_glow_sprite: Sprite2D:
	get: return takashi_ultimate_effects.enemy_impact_fvx_glow_sprite if takashi_ultimate_effects != null else null
var _ultimate_cutscene_snapshot: Dictionary = {}
var _global_selected_target: Combatant = null
var basic_command_adapter
var basic_target_highlight: Line2D
var active_basic_command_token: int = 0
var basic_recovery_tokens: Dictionary = {}
var basic_turn_completion_tokens: Dictionary = {}
var skill_command_adapter
var skill_target_highlight: Line2D
var skill_command_panel: Panel
var skill_ready_label: Label
var skill_target_label: Label
var skill_cost_label: Label
var skill_confirm_button: Button
var skill_cancel_button: Button
var active_skill_command_token: int = 0
var skill_recovery_tokens: Dictionary = {}
var skill_turn_completion_tokens: Dictionary = {}
var skill_hit_tokens: Dictionary = {}
var skill_animation_looping: bool:
	get: return takashi_animator.skill_animation_looping if takashi_animator != null else false
	set(value):
		if takashi_animator != null:
			takashi_animator.skill_animation_looping = value
var ultimate_command_adapter
var ultimate_target_highlight: Line2D
var ultimate_command_panel: Panel
var ultimate_ready_label: Label
var ultimate_target_label: Label
var ultimate_cost_label: Label
var ultimate_confirm_button: Button
var ultimate_cancel_button: Button
var active_ultimate_command_token: int = 0
var ultimate_recovery_tokens: Dictionary = {}
var ultimate_turn_completion_tokens: Dictionary = {}
var ultimate_hit_tokens: Dictionary = {}
var ultimate_interrupt_queue: UltimateInterruptQueue
var is_processing_interrupt_queue: bool = false
var active_interrupt_request: UltimateInterruptRequest = null
## Block 9F: which safe window (&"before_enemy_commit" / A1, or
## &"after_enemy_recovery" / B) is currently processing active_interrupt_request.
## This *is* the resume policy selector -- see _resume_after_interrupt().
var active_interrupt_window: StringName = &""
var interrupt_resume_token: int = 0
var _consumed_interrupt_resume_tokens: Dictionary = {}
var _processed_interrupt_request_ids: Dictionary = {}
var active_enemy_attack_token: int = 0
var enemy_hit_tokens: Dictionary = {}
var enemy_recovery_tokens: Dictionary = {}
var enemy_turn_completion_tokens: Dictionary = {}
var enemy_action_in_progress: bool = false
var _enemy_attack_token_sequence: int = 0
var encounter_enemy_name: String = "Lesser Abyss"
var encounter_enemy_max_hp: int = ENEMY_MAX_HP
var encounter_enemy_damage: int = ENEMY_BASE_DAMAGE
var encounter_opening_log: String = "A Lesser Abyss appears. Choose Takashi's first action."
var encounter_victory_log: String = ""
var encounter_victory_scene_path: String = ENDING_SCENE_PATH
var encounter_retry_scene_path: String = PROLOGUE_SCENE_PATH
var encounter_intro_text: String = "BATTLE START"
var encounter_bgm_path: String = ""
var encounter_background_path: String = ""
var is_bandit_encounter: bool = false
## Block 14: battle_enemy_ids beyond the first, spawned as extra Combatant
## siblings after enemy.setup() -- same pattern already proven safe by
## tests/battle/test_multi_enemy_targeting_production.gd (no BattleManager
## changes were needed for _all_enemies_defeated() to already support this).
var _pending_extra_battle_enemy_ids: Array[StringName] = []


func _ready() -> void:
	_configure_encounter()
	_stop_exploration_music()
	_apply_encounter_presentation()
	_setup_battle_bgm()
	player.setup("Takashi", PLAYER_MAX_HP, BASIC_ATTACK_DAMAGE)
	enemy.setup(encounter_enemy_name, encounter_enemy_max_hp, encounter_enemy_damage)

	if EncounterCoordinator.has_active_encounter():
		GameFlowState.set_context(GameFlowState.InputContext.BATTLE)

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
	takashi_animator = TakashiBattleAnimatorScript.new()
	takashi_animator.name = "TakashiBattleAnimator"
	add_child(takashi_animator)
	takashi_animator.setup(player_action_sprite)
	takashi_animator.frame_changed.connect(func(_tex): _sync_takashi_ultimate_glow_frame())
	takashi_idle_frames = takashi_animator.takashi_idle_frames
	takashi_basic_frames = takashi_animator.takashi_basic_frames
	takashi_skill_frames = takashi_animator.takashi_skill_frames
	takashi_ulti_pre_frames = takashi_animator.takashi_ulti_pre_frames
	takashi_ulti_post_frames = takashi_animator.takashi_ulti_post_frames
	_setup_takashi_ultimate_fvx_frames()
	_start_player_idle_animation()
	_load_ultimate_frames()

	if battle_presentation_3d != null:
		# Block 15 fix: this reference was never being set, so
		# BattlePresentation3D's own battle_manager stayed null forever --
		# every battle_manager-gated step (enemy actor spawning, hiding the
		# 2D layer, HP/target sync) silently no-op'd, leaving the 2D and 3D
		# presentations rendered on top of each other simultaneously.
		battle_presentation_3d.battle_manager = self

	await get_tree().process_frame
	_spawn_additional_encounter_enemies()
	if battle_presentation_3d != null:
		battle_presentation_3d.refresh_enemy_actor_roster()
	_setup_battle_effects()
	_apply_runtime_layout()
	_setup_basic_command_runtime()
	_setup_skill_command_runtime()
	_setup_ultimate_command_runtime()
	_setup_ultimate_interrupt_queue()
	restart_battle()
	_play_battle_intro_effect()


func _process(delta: float) -> void:
	if takashi_animator != null:
		takashi_animator.advance(delta)
	_advance_takashi_ultimate_fvx(delta)
	_sync_basic_target_highlight()
	_sync_skill_target_highlight()
	_sync_ultimate_target_highlight()


func _unhandled_input(event: InputEvent) -> void:
	if _uses_new_basic_command_flow() and _has_pending_basic_command():
		if event.is_action_pressed("ui_cancel"):
			if _cancel_basic_attack_command():
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			if _cycle_basic_target(-1):
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			if _cycle_basic_target(1):
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if (
				mouse_event.button_index == MOUSE_BUTTON_LEFT
				and mouse_event.pressed
				and _select_basic_target_at_position(mouse_event.position)
			):
				get_viewport().set_input_as_handled()
		return

	if _uses_new_skill_command_flow() and _has_pending_skill_command():
		if event.is_action_pressed("ui_cancel"):
			if _cancel_skill_command():
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			if _cycle_skill_target(-1):
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			if _cycle_skill_target(1):
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if (
				mouse_event.button_index == MOUSE_BUTTON_LEFT
				and mouse_event.pressed
				and _select_skill_target_at_position(mouse_event.position)
			):
				get_viewport().set_input_as_handled()
		return

	if _uses_new_ultimate_command_flow() and _has_pending_ultimate_command():
		if event.is_action_pressed("ui_cancel"):
			_show_ultimate_locked_message()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			if _cycle_ultimate_target(-1):
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			if _cycle_ultimate_target(1):
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if (
				mouse_event.button_index == MOUSE_BUTTON_LEFT
				and mouse_event.pressed
				and _select_ultimate_target_at_position(mouse_event.position)
			):
				get_viewport().set_input_as_handled()
		return

	if state == BattleState.PLAYER_TURN and not _has_pending_basic_command() and not _has_pending_skill_command() and not _has_pending_ultimate_command():
		if event.is_action_pressed("ui_left"):
			_cycle_global_target(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_cycle_global_target(1)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
				var closest_target := _pick_target_at_screen_position(
					mouse_event.position,
					_get_basic_attack_candidate_targets()
				)
				if closest_target != null:
					_global_selected_target = closest_target
					if basic_target_highlight != null and not _uses_3d_target_markers():
						basic_target_highlight.visible = true
					get_viewport().set_input_as_handled()
		return

func _cycle_global_target(direction: int) -> void:
	var candidates := _get_basic_attack_candidate_targets()
	if candidates.size() < 2:
		return
	var current_index := 0
	if _global_selected_target != null:
		current_index = candidates.find(_global_selected_target)
		if current_index < 0:
			current_index = 0
	var next_index := wrapi(current_index + direction, 0, candidates.size())
	_global_selected_target = candidates[next_index] as Combatant
	if basic_target_highlight != null and not _uses_3d_target_markers():
		basic_target_highlight.visible = true


func _uses_3d_target_markers() -> bool:
	return battle_presentation_3d != null and is_instance_valid(battle_presentation_3d)


func _preselect_pending_target_without_commit(
	command: PendingBattleCommand,
	target: Combatant
) -> bool:
	if command == null or command.is_committed or command.is_cancelled:
		return false
	if target == null or not is_instance_valid(target) or target.is_defeated():
		return false
	return command.select_target(target)


func get_current_target_marker_target() -> Combatant:
	if _has_pending_basic_command():
		return _selected_basic_target(basic_command_adapter.get_pending_command())
	if _has_pending_skill_command():
		return _selected_skill_target(skill_command_adapter.get_pending_command())
	if _has_pending_ultimate_command():
		return _selected_ultimate_target(ultimate_command_adapter.get_pending_command())
	if state == BattleState.PLAYER_TURN:
		return _global_selected_target
	return null


func _pick_target_at_screen_position(
	screen_position: Vector2,
	candidates: Array[Node]
) -> Combatant:
	if battle_presentation_3d != null:
		var picked_3d := battle_presentation_3d.pick_enemy_combatant_at_screen_position(
			screen_position,
			candidates
		)
		if picked_3d != null:
			return picked_3d

	var closest_target: Combatant
	var closest_distance := INF
	for candidate in candidates:
		var combatant := candidate as Combatant
		if combatant == null:
			continue
		var distance := screen_position.distance_to(combatant.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = combatant
	if closest_target == null or closest_distance > 170.0:
		return null
	return closest_target


func _target_highlight_position(
	target: Combatant,
	fallback_offset: Vector2,
	vertical_ratio: float
) -> Vector2:
	if battle_presentation_3d != null:
		var projected := battle_presentation_3d.get_enemy_screen_position(target, vertical_ratio)
		if not is_inf(projected.x) and not is_inf(projected.y):
			return projected
	return target.global_position + fallback_offset


func _exit_tree() -> void:
	active_basic_command_token = 0
	if basic_command_adapter != null:
		basic_command_adapter.reset()
	active_skill_command_token = 0
	if skill_command_adapter != null:
		skill_command_adapter.reset()
	active_ultimate_command_token = 0
	if ultimate_command_adapter != null:
		ultimate_command_adapter.reset()
	_reset_ultimate_interrupt_queue()
	_reset_enemy_attack_runtime()


func restart_battle() -> void:
	_start_player_idle_animation()
	_reset_battle_values()
	_begin_player_turn(encounter_opening_log)


func _configure_encounter() -> void:
	if EncounterCoordinator.has_active_encounter():
		_configure_from_encounter_context(EncounterCoordinator.get_active_context())
		return

	var progress := get_node_or_null("/root/WorldProgress")
	if progress == null:
		return
	if StringName(progress.get("active_battle_id")) != BANDIT_ENCOUNTER_ID:
		return

	is_bandit_encounter = true
	encounter_enemy_name = "Bandit Captain"
	encounter_enemy_max_hp = 150
	encounter_enemy_damage = 12
	encounter_opening_log = "Makoto and Mitsuki hold off the raiders. Break the captain's guard."
	encounter_victory_log = "The captain falls. The old road to Werdonia is open again."
	encounter_victory_scene_path = GRASSLANDS_SCENE_PATH
	encounter_retry_scene_path = ""
	encounter_intro_text = "THE CLOVER CLASH"
	encounter_bgm_path = BANDIT_BGM_PATH
	encounter_background_path = BANDIT_BACKGROUND_PATH


## Block 14: configures the encounter from an accepted EncounterContext
## instead of the legacy WorldProgress.active_battle_id flag. Reuses every
## existing field _apply_encounter_presentation()/UI already read from --
## no new presentation plumbing.
func _configure_from_encounter_context(context: EncounterContext) -> void:
	if context == null or context.battle_enemy_ids.is_empty():
		push_error("BattleManager: active EncounterContext is invalid (null or empty roster); using default encounter")
		return
	var primary_id: StringName = context.battle_enemy_ids[0]
	var primary_data: Dictionary = get_enemy_battle_profile_data(primary_id)
	if primary_data.is_empty():
		push_error("BattleManager: unknown battle_enemy_id '%s'; using default encounter" % primary_id)
		return

	is_bandit_encounter = false
	encounter_enemy_name = primary_data.get("name", encounter_enemy_name)
	encounter_enemy_max_hp = primary_data.get("max_hp", ENEMY_MAX_HP)
	encounter_enemy_damage = primary_data.get("damage", ENEMY_BASE_DAMAGE)
	encounter_opening_log = "A %s blocks the path. Choose Takashi's first action." % encounter_enemy_name
	encounter_victory_log = ""
	encounter_victory_scene_path = (
		context.source_world_scene if not context.source_world_scene.is_empty() else ENDING_SCENE_PATH
	)
	encounter_retry_scene_path = ""
	encounter_intro_text = "ENCOUNTER"
	encounter_bgm_path = ""
	encounter_background_path = ""
	_pending_extra_battle_enemy_ids = context.battle_enemy_ids.slice(1)


## Block 14.5: extra roster members beyond the primary `enemy` node.
## Duplicates `enemy` (script, visual body, HP bar, name label all included)
## rather than a bare Combatant.new() -- a bare Combatant has no
## PlaceholderVisual/HpBar children at all, which made every dynamically
## spawned encounter-group enemy completely invisible with no HP display,
## even though it was fully alive and targetable. Placed via the named
## EnemyFormation marker slots in battle_scene.tscn (falls back to a
## computed offset if an older scene copy lacks them) and scaled down
## slightly so a 2-3 enemy group fits the stage without running off-screen.
const ENCOUNTER_GROUP_SCALE: float = 0.62

func _spawn_additional_encounter_enemies() -> void:
	if _pending_extra_battle_enemy_ids.is_empty():
		return
	for index in range(_pending_extra_battle_enemy_ids.size()):
		var extra_id: StringName = _pending_extra_battle_enemy_ids[index]
		var data: Dictionary = get_enemy_battle_profile_data(extra_id)
		if data.is_empty():
			push_error("BattleManager: unknown extra battle_enemy_id '%s'; skipping roster slot" % extra_id)
			continue
		var extra_enemy := enemy.duplicate() as Combatant
		extra_enemy.name = "EncounterEnemy%d" % (index + 2)
		extra_enemy.position = _encounter_formation_slot_position(index)
		extra_enemy.home_scale = Vector2.ONE * ENCOUNTER_GROUP_SCALE
		get_parent().add_child(extra_enemy)
		extra_enemy.set_home_position(extra_enemy.position)
		extra_enemy.setup(
			data.get("name", "Lesser Abyss"), data.get("max_hp", ENEMY_MAX_HP), data.get("damage", ENEMY_BASE_DAMAGE)
		)
	_pending_extra_battle_enemy_ids.clear()


## `index` is 0-based across the *extra* roster (index 0 == the first enemy
## beyond the primary), matching EnemySlot1, EnemySlot2, ... in
## battle_scene.tscn's EnemyFormation group.
func _encounter_formation_slot_position(index: int) -> Vector2:
	if enemy_formation != null:
		var slot := enemy_formation.get_node_or_null("EnemySlot%d" % (index + 1))
		if slot is Node2D:
			return (slot as Node2D).position
	return enemy.position + Vector2(140.0 * float(index + 1), 0.0)


func _stop_exploration_music() -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.call("stop_music", 0.0)


func _apply_encounter_presentation() -> void:
	if not encounter_background_path.is_empty() and forest_background != null:
		forest_background.texture = load(encounter_background_path) as Texture2D

	if not encounter_bgm_path.is_empty() and battle_bgm != null:
		battle_bgm.stop()
		battle_bgm.stream = load(encounter_bgm_path) as AudioStream

	if enemy_placeholder_visual != null:
		enemy_placeholder_visual.visible = not is_bandit_encounter
	if enemy_action_sprite != null:
		enemy_action_sprite.visible = is_bandit_encounter
	if enemy_title_label != null:
		enemy_title_label.text = encounter_enemy_name
	if encounter_label != null:
		encounter_label.text = encounter_enemy_name
	if battle_intro_label != null:
		battle_intro_label.text = encounter_intro_text


func _reset_battle_values() -> void:
	player.reset_hp()
	enemy.reset_hp()
	ultimate_energy = 0
	skill_points = START_SKILL_POINTS
	_apply_persisted_player_runtime_state()
	_apply_opening_advantage_effects()
	_reset_camera()
	_hide_takashi_ultimate_glow_effect()
	_global_selected_target = null
	_reset_basic_command_runtime()
	_reset_skill_command_runtime()
	_reset_ultimate_command_runtime()
	_reset_enemy_attack_runtime()
	timing_bar.cancel_window()
	ui.set_timing_mode(false)
	ui.set_restart_visible(false)
	_refresh_player_status_ui()
	_refresh_energy_ui()
	_refresh_skill_points_ui()


## Block 14: HP/Energy must not silently reset just because a battle scene
## loaded. PartyRuntimeState.ensure_initialized() is idempotent -- the first
## battle of a session creates the state at full HP/starting Energy
## (identical to today's behavior), every battle after that continues from
## wherever the previous one left off.
func _apply_persisted_player_runtime_state() -> void:
	var state: CharacterRuntimeState = PartyRuntimeState.ensure_initialized(
		&"takashi", PLAYER_MAX_HP, MAX_ULTIMATE_ENERGY, 0
	)
	player.current_hp = clampi(state.current_hp, 0, player.max_hp)
	ultimate_energy = clampi(state.current_energy, 0, MAX_ULTIMATE_ENERGY)


## Block 14 Part F: maps EncounterContext.opening_advantage onto the safest
## existing seam (Combatant.take_damage(), already used everywhere in normal
## combat resolution) rather than touching turn order/scheduling -- the
## player already always acts first every battle (state defaults to
## PLAYER_TURN), so "who goes first" cannot be the differentiator. NEUTRAL
## changes nothing; PLAYER_ADVANTAGE/ENEMY_ADVANTAGE apply a modest opening
## hit representing the field strike that decided who was ambushed.
func _apply_opening_advantage_effects() -> void:
	if not EncounterCoordinator.has_active_encounter():
		return
	var context: EncounterContext = EncounterCoordinator.get_active_context()
	if context == null:
		return
	match context.opening_advantage:
		EncounterContext.OpeningAdvantage.PLAYER_ADVANTAGE:
			enemy.take_damage(roundi(float(enemy.max_hp) * 0.15))
		EncounterContext.OpeningAdvantage.ENEMY_ADVANTAGE:
			player.take_damage(roundi(float(player.max_hp) * 0.10))
		_:
			pass
	_refresh_player_status_ui()


## Block 14: writes the battle-concluded HP/Energy back as the new
## authoritative runtime state. Called from both _win() and _lose() so the
## legacy bandit encounter also benefits (a fresh PartyRuntimeState entry at
## full HP means a first-ever battle is unaffected either way).
func _persist_player_runtime_state() -> void:
	PartyRuntimeState.apply_battle_result(&"takashi", player.current_hp, ultimate_energy, player.is_defeated())


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
	if takashi_animator != null:
		takashi_animator.apply_grounding()



func _setup_basic_command_runtime() -> void:
	_setup_basic_command_adapter()
	_create_basic_target_highlight()


func _setup_basic_command_adapter() -> void:
	if basic_command_adapter != null:
		return
	basic_command_adapter = BasicAttackAdapter.new()
	basic_command_adapter.name = "BasicAttackCommandAdapter"
	add_child(basic_command_adapter)
	basic_command_adapter.configure(
		player,
		_get_basic_attack_candidate_targets,
		_validate_basic_attack_command,
		_commit_basic_attack_command_resources
	)
	basic_command_adapter.target_changed.connect(_on_basic_command_target_changed)
	basic_command_adapter.basic_cancelled.connect(_on_basic_command_cancelled)
	basic_command_adapter.basic_committed.connect(_on_basic_command_committed)
	basic_command_adapter.basic_failed.connect(_on_basic_command_failed)


func _reset_basic_command_runtime() -> void:
	active_basic_command_token = 0
	basic_recovery_tokens.clear()
	basic_turn_completion_tokens.clear()
	if basic_command_adapter != null:
		basic_command_adapter.reset()
	_hide_basic_target_highlight()


func _uses_new_basic_command_flow() -> bool:
	return use_new_basic_command_flow and basic_command_adapter != null


func _begin_basic_attack_command() -> bool:
	if not _uses_new_basic_command_flow():
		return false
	if state != BattleState.PLAYER_TURN or _is_battle_over():
		return false
	if _has_pending_basic_command() or _has_pending_skill_command():
		return false
	var preferred_target := _global_selected_target
	var started = basic_command_adapter.begin_basic()
	if started:
		var command: PendingBattleCommand = basic_command_adapter.get_pending_command()
		if (
			not command.is_committed
			and not command.is_cancelled
			and preferred_target != null
			and is_instance_valid(preferred_target)
			and not preferred_target.is_defeated()
		):
			if _preselect_pending_target_without_commit(command, preferred_target):
				_on_basic_command_target_changed(command, command.selected_targets.duplicate())
		if command != null and not command.is_committed and not command.is_cancelled:
			_confirm_basic_attack_command()
	return started


func _confirm_basic_attack_command() -> bool:
	if not _has_pending_basic_command():
		return false
	_repair_basic_pending_target()
	return basic_command_adapter.confirm_basic()


func _cancel_basic_attack_command() -> bool:
	if not _has_pending_basic_command():
		return false
	return basic_command_adapter.cancel_basic()


func _has_pending_basic_command() -> bool:
	return (
		basic_command_adapter != null
		and basic_command_adapter.has_pending_basic()
	)


func _on_basic_command_target_changed(
	command: PendingBattleCommand,
	_targets: Array
) -> void:
	var selected := _selected_basic_target(command)
	if selected != null:
		_global_selected_target = selected
	if command.candidate_targets.size() <= 1:
		return
	_show_basic_target_highlight(command)
	ui.set_battle_log("Select target")


func _on_basic_command_cancelled(_command: PendingBattleCommand) -> void:
	active_basic_command_token = 0
	_hide_basic_target_highlight()
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log("Void Strike cancelled.")
	_update_action_buttons(true)


func _on_basic_command_committed(command: PendingBattleCommand) -> void:
	_hide_basic_target_highlight()
	_update_action_buttons(false)
	ui.set_battle_input_enabled(false)
	call_deferred("_execute_committed_basic_attack", command)


func _on_basic_command_failed(
	_command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_basic_command_token = 0
	_hide_basic_target_highlight()
	if _is_battle_over():
		return
	state = BattleState.PLAYER_TURN
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log(_basic_command_failure_message(reason))
	_update_action_buttons(true)


func _execute_committed_basic_attack(command: PendingBattleCommand) -> void:
	if not _uses_new_basic_command_flow():
		return
	if not _is_committed_basic_command(command):
		return
	if not basic_command_adapter.execute_committed_command():
		return

	var target := _selected_basic_target(command)
	if target == null:
		_abort_committed_basic_command(command, &"target_missing_during_execution")
		return

	active_basic_command_token = command.commit_token
	state = BattleState.ACTION_RESOLUTION
	_set_player_action_texture(TAKASHI_BASIC_TEXTURE)
	if battle_presentation_3d != null:
		battle_presentation_3d.play_party_attack()
	ui.set_turn_text("Void Strike")
	ui.set_battle_log("Void Strike!")
	await _resolve_basic_attack(target, command)


func _finish_basic_command_resolution(
	command: PendingBattleCommand,
	log_text: String
) -> void:
	if not _is_committed_basic_command(command):
		return
	if not basic_command_adapter.resolve_committed_command(command):
		return
	if not basic_command_adapter.begin_recovery(command):
		return

	var token := command.commit_token
	if basic_recovery_tokens.has(token):
		return
	basic_recovery_tokens[token] = true
	_start_player_idle_animation()
	_hide_basic_target_highlight()
	if not _basic_recovery_guard(command):
		return
	if not basic_command_adapter.complete_recovery(command):
		return
	if basic_turn_completion_tokens.has(token):
		return
	basic_turn_completion_tokens[token] = true
	active_basic_command_token = 0
	_finish_player_action(log_text)


func _abort_committed_basic_command(
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_basic_command_token = 0
	if basic_command_adapter != null:
		basic_command_adapter.fail_basic(command, reason)
		basic_command_adapter.reset()


func _validate_basic_attack_command(command: PendingBattleCommand) -> String:
	if command == null:
		return "missing_command"
	if command.command_type != PendingBattleCommand.CommandType.BASIC_ATTACK:
		return "unsupported_command"
	if _is_battle_over():
		return "battle_already_finished"
	if state != BattleState.PLAYER_TURN:
		return "battle_state_not_player_turn"
	if active_basic_command_token != 0 or active_skill_command_token != 0:
		return "action_execution_already_active"
	if not is_instance_valid(player) or player.is_defeated():
		return "actor_invalid"
	if not command.has_required_targets():
		return "target_invalid"
	if _selected_basic_target(command) == null:
		return "target_not_targetable"
	return ""


func _commit_basic_attack_command_resources(
	command: PendingBattleCommand
) -> bool:
	return _validate_basic_attack_command(command).is_empty()


func _get_basic_attack_candidate_targets() -> Array[Node]:
	var targets: Array[Node] = []
	if battle_scene == null:
		return targets
	for child in battle_scene.get_children():
		if _is_basic_attack_targetable(child):
			targets.append(child)
	return targets


func _is_basic_attack_targetable(target: Node) -> bool:
	return (
		target is Combatant
		and target != player
		and is_instance_valid(target)
		and not (target as Combatant).is_defeated()
	)


func _selected_basic_target(command: PendingBattleCommand) -> Combatant:
	if command == null or command.selected_targets.is_empty():
		return null
	var target := command.selected_targets[0] as Combatant
	if target == null or not _is_basic_attack_targetable(target):
		return null
	return target


## Block 9G: revalidates the *already-selected* target only -- refreshes
## candidate_targets against the current battle state and re-checks
## whether the specific target the player already chose is still alive
## and valid. Deliberately does NOT auto-select a different candidate
## when the selected target has died, even if another live enemy exists:
## silently switching the pending command to a different target the
## player never chose would let commit succeed against the wrong enemy.
## In a single-enemy battle this distinction was invisible (candidate_targets
## was always empty once the only enemy died, so the old fallback never
## actually fired) -- see docs/battle_system_spec.md, "Block 9G
## implementation status" for the multi-enemy audit that found it.
func _repair_basic_pending_target() -> bool:
	var command: PendingBattleCommand = basic_command_adapter.get_pending_command()
	if command == null:
		return false

	command.candidate_targets.assign(_get_basic_attack_candidate_targets())
	command.refresh_candidates()
	return _selected_basic_target(command) != null


func _cycle_basic_target(direction: int) -> bool:
	if not _has_pending_basic_command():
		return false
	var command: PendingBattleCommand = basic_command_adapter.get_pending_command()
	command.candidate_targets.assign(_get_basic_attack_candidate_targets())
	command.refresh_candidates()
	if command.candidate_targets.size() < 2:
		return false

	var current_index := 0
	if not command.selected_targets.is_empty():
		current_index = command.candidate_targets.find(command.selected_targets[0])
	if current_index < 0:
		current_index = 0
	var next_index := wrapi(
		current_index + direction,
		0,
		command.candidate_targets.size()
	)
	return basic_command_adapter.select_target(command.candidate_targets[next_index])


func _select_basic_target_at_position(screen_position: Vector2) -> bool:
	if not _has_pending_basic_command():
		return false
	var command: PendingBattleCommand = basic_command_adapter.get_pending_command()
	command.candidate_targets.assign(_get_basic_attack_candidate_targets())
	command.refresh_candidates()
	var closest_target := _pick_target_at_screen_position(screen_position, command.candidate_targets)
	if closest_target == null:
		return false
	return basic_command_adapter.select_target(closest_target)


func _basic_execution_guard(
	command: PendingBattleCommand,
	target: Combatant,
	require_live_target: bool = true
) -> bool:
	if (
		not is_inside_tree()
		or state != BattleState.ACTION_RESOLUTION
		or _is_battle_over()
		or not is_instance_valid(player)
		or player.is_defeated()
		or target == null
		or not is_instance_valid(target)
		or (require_live_target and target.is_defeated())
	):
		return false
	if command == null:
		return true
	return (
		basic_command_adapter != null
		and command == basic_command_adapter.get_pending_command()
		and command.is_committed
		and active_basic_command_token == command.commit_token
		and basic_command_adapter.is_token_active(command.commit_token)
	)


func _basic_impact_guard(
	command: PendingBattleCommand,
	target: Node2D
) -> bool:
	if command == null:
		return state == BattleState.ACTION_RESOLUTION and is_inside_tree()
	var combatant := target as Combatant
	if combatant == null:
		return false
	return _basic_execution_guard(command, combatant, false)


func _basic_recovery_guard(command: PendingBattleCommand) -> bool:
	return (
		is_inside_tree()
		and state == BattleState.ACTION_RESOLUTION
		and not _is_battle_over()
		and basic_command_adapter != null
		and command == basic_command_adapter.get_pending_command()
		and command.is_committed
		and command.is_resolved
		and active_basic_command_token == command.commit_token
	)


func _is_committed_basic_command(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command.command_type == PendingBattleCommand.CommandType.BASIC_ATTACK
		and command.is_committed
		and command.commit_token > 0
	)


func _basic_command_failure_message(reason: StringName) -> String:
	match reason:
		&"target_invalid_before_confirm", &"target_not_targetable":
			return "Void Strike target is no longer valid."
		&"no_valid_targets", &"target_missing_during_execution":
			return "Void Strike has no valid target."
		&"battle_state_not_player_turn", &"action_execution_already_active":
			return "Void Strike is not available right now."
	return "Void Strike was cancelled safely."


func _create_basic_target_highlight() -> void:
	if basic_target_highlight != null or battle_scene == null:
		return
	basic_target_highlight = Line2D.new()
	basic_target_highlight.name = "BasicTargetHighlight"
	basic_target_highlight.width = 4.0
	basic_target_highlight.default_color = Color(0.98, 0.78, 0.28, 0.96)
	basic_target_highlight.closed = true
	basic_target_highlight.z_index = 30
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		basic_target_highlight.add_point(
			Vector2(cos(angle) * 62.0, sin(angle) * 78.0)
		)
	battle_scene.add_child(basic_target_highlight)
	basic_target_highlight.visible = false


func _show_basic_target_highlight(command: PendingBattleCommand) -> void:
	if basic_target_highlight == null:
		return
	if _uses_3d_target_markers():
		basic_target_highlight.visible = false
		return
	basic_target_highlight.visible = _selected_basic_target(command) != null
	_sync_basic_target_highlight()


func _hide_basic_target_highlight() -> void:
	if basic_target_highlight == null:
		return
	if _uses_3d_target_markers():
		basic_target_highlight.visible = false
		return
	if state == BattleState.PLAYER_TURN and not _has_pending_skill_command() and not _has_pending_ultimate_command() and _global_selected_target != null:
		basic_target_highlight.visible = true
	else:
		basic_target_highlight.visible = false


func _sync_basic_target_highlight() -> void:
	if basic_target_highlight == null:
		return
	if _uses_3d_target_markers():
		basic_target_highlight.visible = false
		return

	var target: Combatant = null
	if _has_pending_basic_command():
		target = _selected_basic_target(basic_command_adapter.get_pending_command())
	elif state == BattleState.PLAYER_TURN and not _has_pending_skill_command() and not _has_pending_ultimate_command():
		target = _global_selected_target

	if target == null or not is_instance_valid(target) or target.is_defeated():
		if _global_selected_target == target:
			_global_selected_target = null
		basic_target_highlight.visible = false
		return

	basic_target_highlight.visible = true
	basic_target_highlight.global_position = _target_highlight_position(target, Vector2(0.0, -72.0), 0.48)
	basic_target_highlight.rotation += 0.008


func _setup_skill_command_runtime() -> void:
	_setup_skill_command_adapter()
	_create_skill_target_highlight()
	_create_skill_command_panel()


func _setup_skill_command_adapter() -> void:
	if skill_command_adapter != null:
		return
	skill_command_adapter = SkillCommandAdapterScript.new()
	skill_command_adapter.name = "SkillCommandAdapter"
	add_child(skill_command_adapter)
	skill_command_adapter.configure(
		player,
		_get_skill_candidate_targets,
		_validate_skill_command,
		_commit_skill_command_resources
	)
	skill_command_adapter.skill_ready.connect(_on_skill_command_ready)
	skill_command_adapter.target_changed.connect(_on_skill_command_target_changed)
	skill_command_adapter.skill_cancelled.connect(_on_skill_command_cancelled)
	skill_command_adapter.skill_committed.connect(_on_skill_command_committed)
	skill_command_adapter.skill_failed.connect(_on_skill_command_failed)


func _reset_skill_command_runtime() -> void:
	active_skill_command_token = 0
	skill_recovery_tokens.clear()
	skill_turn_completion_tokens.clear()
	skill_hit_tokens.clear()
	if skill_command_adapter != null:
		skill_command_adapter.reset()
	_hide_skill_target_highlight()
	_set_skill_command_panel_visible(false)
	skill_animation_looping = false


func _uses_new_skill_command_flow() -> bool:
	return use_new_skill_command_flow and skill_command_adapter != null


func _begin_skill_command() -> bool:
	if not _uses_new_skill_command_flow():
		return false
	if state != BattleState.PLAYER_TURN or _is_battle_over():
		return false
	if _has_pending_basic_command() or _has_pending_skill_command():
		return false
	if skill_points < SKILL_POINT_COST_SKILL:
		ui.set_battle_log("Triangle Rift needs %d Skill Point." % SKILL_POINT_COST_SKILL)
		return false
	var preferred_target := _global_selected_target
	var started = skill_command_adapter.begin_skill(
		&"triangle_rift",
		PendingBattleCommand.TargetRule.SINGLE_ENEMY,
		SKILL_POINT_COST_SKILL
	)
	if started:
		var command: PendingBattleCommand = skill_command_adapter.get_pending_command()
		if _preselect_pending_target_without_commit(command, preferred_target):
			_on_skill_command_target_changed(command, command.selected_targets.duplicate())
	return started


func _confirm_skill_command() -> bool:
	if not _has_pending_skill_command():
		return false
	_repair_skill_pending_target()
	return skill_command_adapter.confirm_skill()


func _cancel_skill_command() -> bool:
	if not _has_pending_skill_command():
		return false
	return skill_command_adapter.cancel_skill()


func _has_pending_skill_command() -> bool:
	return (
		skill_command_adapter != null
		and skill_command_adapter.has_pending_skill()
	)


## Block 9E: no confirm/cancel panel in production — press Skill again or
## click the target to commit. skill_command_panel/skill_confirm_button/
## skill_cancel_button are kept constructed (see _create_skill_command_panel())
## as an unused legacy fallback, documented in
## docs/battle_command_flow_implementation.md, "Block 9E"; this handler
## deliberately no longer calls _set_skill_command_panel_visible(true).
## Buttons stay enabled (not disabled like before Block 9E) during ready
## idle -- committing lives with the Skill/target-click input handlers now,
## and Basic/Ultimate must stay clickable so pressing them can cancel this
## pending Skill and return to default select, matching how Basic's own
## multi-target pending already left buttons enabled (Block 8.5).
func _on_skill_command_ready(command: PendingBattleCommand) -> void:
	_start_skill_ready_idle()
	if battle_presentation_3d != null:
		battle_presentation_3d.camera_transition(BattleCamera3D.Preset.PLAYER_SKILL)
	_update_action_buttons(true)
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Triangle Rift")
	ui.set_battle_log("Triangle Rift ready. Press Skill again or choose a target.")
	_update_skill_command_panel(command)


func _on_skill_command_target_changed(
	command: PendingBattleCommand,
	_targets: Array
) -> void:
	var selected := _selected_skill_target(command)
	if selected != null:
		_global_selected_target = selected
	_update_skill_command_panel(command)
	_show_skill_target_highlight(command)


func _on_skill_command_cancelled(_command: PendingBattleCommand) -> void:
	active_skill_command_token = 0
	_stop_player_skill_animation()
	_start_player_idle_animation()
	if battle_presentation_3d != null:
		battle_presentation_3d.camera_return_to_idle()
	_hide_skill_target_highlight()
	_set_skill_command_panel_visible(false)
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log("Triangle Rift cancelled.")
	_update_action_buttons(true)


func _on_skill_command_committed(command: PendingBattleCommand) -> void:
	_hide_skill_target_highlight()
	_set_skill_command_panel_visible(false)
	_update_action_buttons(false)
	ui.set_battle_input_enabled(false)
	call_deferred("_execute_committed_skill", command)


func _on_skill_command_failed(
	_command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_skill_command_token = 0
	_stop_player_skill_animation()
	_start_player_idle_animation()
	if battle_presentation_3d != null:
		battle_presentation_3d.camera_return_to_idle()
	_hide_skill_target_highlight()
	_set_skill_command_panel_visible(false)
	if _is_battle_over():
		return
	state = BattleState.PLAYER_TURN
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log(_skill_command_failure_message(reason))
	_update_action_buttons(true)


func _start_skill_ready_idle() -> void:
	_start_player_skill_animation(true)
	if takashi_skill_frames.is_empty():
		_play_screen_flash(Color(0.42, 0.95, 1.0, 0.12), 0.08)


func _execute_committed_skill(command: PendingBattleCommand) -> void:
	if not _uses_new_skill_command_flow():
		return
	if not _is_committed_skill_command(command):
		return
	if not skill_command_adapter.execute_committed_command():
		return

	var target := _selected_skill_target(command)
	if target == null:
		_abort_committed_skill_command(command, &"target_missing_during_execution")
		return

	active_skill_command_token = command.commit_token
	state = BattleState.ACTION_RESOLUTION
	_set_player_action_texture(TAKASHI_SKILL_TEXTURE)
	if battle_presentation_3d != null:
		battle_presentation_3d.play_party_skill()
	_play_skill_sfx()
	_update_action_buttons(false)
	ui.set_turn_text("Triangle Rift")
	ui.set_battle_log("Triangle Rift charging...")
	await _execute_triangle_rift(target, command)


func _finish_skill_command_resolution(
	command: PendingBattleCommand,
	log_text: String
) -> void:
	if not _is_committed_skill_command(command):
		return
	if not skill_command_adapter.resolve_committed_command(command):
		return
	if not skill_command_adapter.begin_recovery(command):
		return

	var token := command.commit_token
	if skill_recovery_tokens.has(token):
		return
	skill_recovery_tokens[token] = true
	_start_player_idle_animation()
	_hide_skill_target_highlight()
	if not _skill_recovery_guard(command):
		return
	if not skill_command_adapter.complete_recovery(command):
		return
	if skill_turn_completion_tokens.has(token):
		return
	skill_turn_completion_tokens[token] = true
	active_skill_command_token = 0
	_finish_player_action(log_text)


func _abort_committed_skill_command(
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_skill_command_token = 0
	if skill_command_adapter != null:
		skill_command_adapter.fail_skill(command, reason)
		skill_command_adapter.reset()


func _validate_skill_command(command: PendingBattleCommand) -> String:
	if command == null:
		return "missing_command"
	if command.command_type != PendingBattleCommand.CommandType.SKILL:
		return "unsupported_command"
	if command.action_id != &"triangle_rift":
		return "unsupported_skill"
	if _is_battle_over():
		return "battle_already_finished"
	if state != BattleState.PLAYER_TURN:
		return "battle_state_not_player_turn"
	if active_basic_command_token != 0 or active_skill_command_token != 0:
		return "action_execution_already_active"
	if not is_instance_valid(player) or player.is_defeated():
		return "actor_invalid"
	if skill_points < command.skill_point_cost:
		return "not_enough_skill_points"
	if not command.has_required_targets():
		return "target_invalid"
	if _selected_skill_target(command) == null:
		return "target_not_targetable"
	return ""


func _commit_skill_command_resources(
	command: PendingBattleCommand
) -> bool:
	if not _validate_skill_command(command).is_empty():
		return false
	if command.skill_point_cost > 0:
		_spend_skill_points(command.skill_point_cost)
	return true


func _get_skill_candidate_targets() -> Array[Node]:
	var targets: Array[Node] = []
	if battle_scene == null:
		return targets
	for child in battle_scene.get_children():
		if _is_skill_targetable(child):
			targets.append(child)
	return targets


func _is_skill_targetable(target: Node) -> bool:
	return (
		target is Combatant
		and target != player
		and is_instance_valid(target)
		and not (target as Combatant).is_defeated()
	)


func _selected_skill_target(command: PendingBattleCommand) -> Combatant:
	if command == null or command.selected_targets.is_empty():
		return null
	var target := command.selected_targets[0] as Combatant
	if target == null or not _is_skill_targetable(target):
		return null
	return target


## Block 9G: see _repair_basic_pending_target()'s doc comment -- same
## fix, same reason. Does not auto-select a different live enemy when the
## selected target has died.
func _repair_skill_pending_target() -> bool:
	var command: PendingBattleCommand = skill_command_adapter.get_pending_command()
	if command == null:
		return false

	command.candidate_targets.assign(_get_skill_candidate_targets())
	command.refresh_candidates()
	return _selected_skill_target(command) != null


func _cycle_skill_target(direction: int) -> bool:
	if not _has_pending_skill_command():
		return false
	var command: PendingBattleCommand = skill_command_adapter.get_pending_command()
	command.candidate_targets.assign(_get_skill_candidate_targets())
	command.refresh_candidates()
	if command.candidate_targets.size() < 2:
		return false

	var current_index := 0
	if not command.selected_targets.is_empty():
		current_index = command.candidate_targets.find(command.selected_targets[0])
	if current_index < 0:
		current_index = 0
	var next_index := wrapi(
		current_index + direction,
		0,
		command.candidate_targets.size()
	)
	return skill_command_adapter.select_target(command.candidate_targets[next_index])


func _select_skill_target_at_position(screen_position: Vector2) -> bool:
	if not _has_pending_skill_command():
		return false
	var command: PendingBattleCommand = skill_command_adapter.get_pending_command()
	command.candidate_targets.assign(_get_skill_candidate_targets())
	command.refresh_candidates()
	var closest_target := _pick_target_at_screen_position(screen_position, command.candidate_targets)
	if closest_target == null:
		return false
	return skill_command_adapter.select_target(closest_target)


func _skill_execution_guard(
	command: PendingBattleCommand,
	target: Combatant,
	require_live_target: bool = true
) -> bool:
	if (
		not is_inside_tree()
		or state != BattleState.ACTION_RESOLUTION
		or _is_battle_over()
		or not is_instance_valid(player)
		or player.is_defeated()
		or target == null
		or not is_instance_valid(target)
		or (require_live_target and target.is_defeated())
	):
		return false
	if command == null:
		return true
	return (
		skill_command_adapter != null
		and command == skill_command_adapter.get_pending_command()
		and command.is_committed
		and active_skill_command_token == command.commit_token
		and skill_command_adapter.is_token_active(command.commit_token)
	)


func _skill_impact_guard(
	command: PendingBattleCommand,
	target: Node2D
) -> bool:
	if command == null:
		return state == BattleState.ACTION_RESOLUTION and is_inside_tree()
	var combatant := target as Combatant
	if combatant == null:
		return false
	return _skill_execution_guard(command, combatant, false)


func _skill_recovery_guard(command: PendingBattleCommand) -> bool:
	return (
		is_inside_tree()
		and state == BattleState.ACTION_RESOLUTION
		and not _is_battle_over()
		and skill_command_adapter != null
		and command == skill_command_adapter.get_pending_command()
		and command.is_committed
		and command.is_resolved
		and active_skill_command_token == command.commit_token
	)


func _is_committed_skill_command(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command.command_type == PendingBattleCommand.CommandType.SKILL
		and command.is_committed
		and command.commit_token > 0
	)


func _consume_skill_hit(
	command: PendingBattleCommand,
	hit_index: int
) -> bool:
	if command == null:
		return true
	var key := "%d:%d" % [command.commit_token, hit_index]
	if skill_hit_tokens.has(key):
		return false
	skill_hit_tokens[key] = true
	return true


func _skill_command_failure_message(reason: StringName) -> String:
	match reason:
		&"not_enough_skill_points":
			return "Triangle Rift needs %d Skill Point." % SKILL_POINT_COST_SKILL
		&"target_invalid_before_confirm", &"target_not_targetable":
			return "Triangle Rift target is no longer valid."
		&"no_valid_targets", &"target_missing_during_execution":
			return "Triangle Rift has no valid target."
		&"battle_state_not_player_turn", &"action_execution_already_active":
			return "Triangle Rift is not available right now."
	return "Triangle Rift was cancelled safely."


func _create_skill_target_highlight() -> void:
	if skill_target_highlight != null or battle_scene == null:
		return
	skill_target_highlight = Line2D.new()
	skill_target_highlight.name = "SkillTargetHighlight"
	skill_target_highlight.width = 4.0
	skill_target_highlight.default_color = Color(0.42, 0.96, 1.0, 0.98)
	skill_target_highlight.closed = true
	skill_target_highlight.z_index = 31
	for index in range(36):
		var angle := TAU * float(index) / 36.0
		skill_target_highlight.add_point(
			Vector2(cos(angle) * 70.0, sin(angle) * 86.0)
		)
	battle_scene.add_child(skill_target_highlight)
	skill_target_highlight.visible = false


func _show_skill_target_highlight(command: PendingBattleCommand) -> void:
	if skill_target_highlight == null:
		return
	if _uses_3d_target_markers():
		skill_target_highlight.visible = false
		return
	skill_target_highlight.visible = _selected_skill_target(command) != null
	_sync_skill_target_highlight()


func _hide_skill_target_highlight() -> void:
	if skill_target_highlight != null:
		skill_target_highlight.visible = false


func _sync_skill_target_highlight() -> void:
	if skill_target_highlight == null or not skill_target_highlight.visible:
		return
	if _uses_3d_target_markers():
		skill_target_highlight.visible = false
		return
	if not _has_pending_skill_command():
		skill_target_highlight.visible = false
		return
	var target := _selected_skill_target(skill_command_adapter.get_pending_command())
	if target == null:
		skill_target_highlight.visible = false
		return
	skill_target_highlight.global_position = _target_highlight_position(target, Vector2(0.0, -76.0), 0.5)
	skill_target_highlight.rotation -= 0.01


func _create_skill_command_panel() -> void:
	if skill_command_panel != null or canvas_layer == null:
		return

	skill_command_panel = Panel.new()
	skill_command_panel.name = "SkillCommandPanel"
	skill_command_panel.visible = false
	skill_command_panel.anchor_left = 0.5
	skill_command_panel.anchor_right = 0.5
	skill_command_panel.anchor_top = 1.0
	skill_command_panel.anchor_bottom = 1.0
	skill_command_panel.offset_left = -170.0
	skill_command_panel.offset_right = 170.0
	skill_command_panel.offset_top = -254.0
	skill_command_panel.offset_bottom = -116.0
	skill_command_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	skill_command_panel.add_theme_stylebox_override(
		"panel",
		_make_skill_command_panel_style()
	)
	canvas_layer.add_child(skill_command_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	skill_command_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)

	skill_ready_label = Label.new()
	skill_ready_label.text = "Triangle Rift Ready"
	skill_ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_ready_label.add_theme_font_size_override("font_size", 15)
	skill_ready_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.98, 1.0, 1.0)
	)
	rows.add_child(skill_ready_label)

	skill_cost_label = Label.new()
	skill_cost_label.text = "Cost: -"
	skill_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_cost_label.add_theme_font_size_override("font_size", 12)
	skill_cost_label.add_theme_color_override(
		"font_color",
		Color(0.98, 0.92, 0.74, 1.0)
	)
	rows.add_child(skill_cost_label)

	skill_target_label = Label.new()
	skill_target_label.text = "Target: -"
	skill_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_target_label.add_theme_font_size_override("font_size", 13)
	skill_target_label.add_theme_color_override(
		"font_color",
		Color(0.84, 0.92, 1.0, 1.0)
	)
	rows.add_child(skill_target_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	rows.add_child(buttons)

	skill_confirm_button = Button.new()
	skill_confirm_button.text = "Confirm"
	skill_confirm_button.custom_minimum_size = Vector2(104.0, 32.0)
	skill_confirm_button.pressed.connect(_confirm_skill_command)
	buttons.add_child(skill_confirm_button)

	skill_cancel_button = Button.new()
	skill_cancel_button.text = "Cancel"
	skill_cancel_button.custom_minimum_size = Vector2(104.0, 32.0)
	skill_cancel_button.pressed.connect(_cancel_skill_command)
	buttons.add_child(skill_cancel_button)


func _make_skill_command_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.04, 0.058, 0.94)
	style.border_color = Color(0.42, 0.96, 1.0, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


func _set_skill_command_panel_visible(is_visible: bool) -> void:
	if skill_command_panel != null:
		skill_command_panel.visible = is_visible


func _update_skill_command_panel(command: PendingBattleCommand) -> void:
	if skill_target_label == null:
		return
	var target_name := "-"
	var target := _selected_skill_target(command)
	if target != null:
		target_name = target.combatant_name
	skill_target_label.text = "Target: %s" % target_name
	if skill_cost_label != null and command != null:
		skill_cost_label.text = "Cost: %d SP | SP %d/%d" % [
			command.skill_point_cost,
			skill_points,
			MAX_SKILL_POINTS
		]
	if skill_confirm_button != null:
		skill_confirm_button.disabled = target == null


func _setup_ultimate_command_runtime() -> void:
	_setup_ultimate_command_adapter()
	_create_ultimate_target_highlight()
	_create_ultimate_command_panel()


func _setup_ultimate_command_adapter() -> void:
	if ultimate_command_adapter != null:
		return
	ultimate_command_adapter = UltimateCommandAdapterScript.new()
	ultimate_command_adapter.name = "UltimateCommandAdapter"
	add_child(ultimate_command_adapter)
	ultimate_command_adapter.configure(
		player,
		_get_ultimate_candidate_targets,
		_validate_ultimate_command,
		_commit_ultimate_command_resources
	)
	ultimate_command_adapter.ultimate_ready.connect(_on_ultimate_command_ready)
	ultimate_command_adapter.target_changed.connect(_on_ultimate_command_target_changed)
	ultimate_command_adapter.ultimate_cancelled.connect(_on_ultimate_command_cancelled)
	ultimate_command_adapter.ultimate_committed.connect(_on_ultimate_command_committed)
	ultimate_command_adapter.ultimate_failed.connect(_on_ultimate_command_failed)


func _reset_ultimate_command_runtime() -> void:
	active_ultimate_command_token = 0
	ultimate_recovery_tokens.clear()
	ultimate_turn_completion_tokens.clear()
	ultimate_hit_tokens.clear()
	if ultimate_command_adapter != null:
		ultimate_command_adapter.reset()
	_hide_ultimate_target_highlight()
	_set_ultimate_command_panel_visible(false)
	_reset_ultimate_interrupt_queue()


func _uses_new_ultimate_command_flow() -> bool:
	return use_new_ultimate_command_flow and ultimate_command_adapter != null


## --- Block 9B off-turn interrupt queue integration ---------------------

func _setup_ultimate_interrupt_queue() -> void:
	if ultimate_interrupt_queue != null:
		return
	ultimate_interrupt_queue = UltimateInterruptQueue.new()
	ultimate_interrupt_queue.configure(
		_interrupt_energy_lookup,
		_is_battle_over,
		_is_ultimate_active_or_processing
	)


func _reset_ultimate_interrupt_queue() -> void:
	if ultimate_interrupt_queue != null:
		ultimate_interrupt_queue.clear()
	is_processing_interrupt_queue = false
	active_interrupt_request = null
	active_interrupt_window = &""
	_processed_interrupt_request_ids.clear()
	_consumed_interrupt_resume_tokens.clear()


## Block 9D: interrupt_resume_token was write-only through Block 9C (issued
## in _begin_queued_ultimate(), never checked) -- double-resume was only
## prevented incidentally, by is_processing_interrupt_queue already being
## false by the time a second resume path could run. This makes that
## guarantee explicit and independently testable: each resume token may
## reach _begin_player_turn()/_win() exactly once, matching the same
## single-consumption pattern as enemy_hit_tokens/enemy_recovery_tokens.
func _consume_interrupt_resume_token(token: int) -> bool:
	if token == 0 or _consumed_interrupt_resume_tokens.has(token):
		return false
	_consumed_interrupt_resume_tokens[token] = true
	return true


func _interrupt_energy_lookup(_actor: Node) -> int:
	return ultimate_energy


func _is_ultimate_active_or_processing() -> bool:
	return active_ultimate_command_token != 0 or is_processing_interrupt_queue


## True only while ENEMY_TURN is genuinely in progress and nothing else
## (a committed command, an already-active Ultimate, an existing queued
## request for this actor) makes an off-turn request unsafe to even queue.
## Used both to gate the Ultimate button's independent interactable state
## and as the first check inside request_off_turn_ultimate().
func _can_request_off_turn_ultimate_input() -> bool:
	return (
		state == BattleState.ENEMY_TURN
		and _uses_new_ultimate_command_flow()
		and not is_processing_interrupt_queue
		and active_ultimate_command_token == 0
		and not _has_pending_ultimate_command()
	)


## Off-turn Ultimate request entry point. This only enqueues — it never
## spends Energy, never starts ready idle, never selects a target, never
## starts a cut-in, and never changes whose turn it is. See
## docs/battle_system_spec.md, "Block 9B implementation status" for the
## full request lifecycle.
func request_off_turn_ultimate(actor: Node) -> bool:
	if ultimate_interrupt_queue == null or not _uses_new_ultimate_command_flow():
		ui.set_battle_log("Cannot use Ultimate now.")
		return false
	if state == BattleState.PLAYER_TURN or _is_battle_over():
		ui.set_battle_log("Cannot use Ultimate now.")
		return false
	if is_processing_interrupt_queue or active_ultimate_command_token != 0:
		ui.set_battle_log("Cannot use Ultimate now.")
		return false

	var request := ultimate_interrupt_queue.request_ultimate(
		actor,
		&"octagram_fragment",
		MAX_ULTIMATE_ENERGY,
		state,
		0
	)
	if request.validation_status != UltimateInterruptRequest.ValidationStatus.ACCEPTED:
		ui.set_battle_log(_interrupt_request_failure_message(request.reject_reason))
		return false

	var actor_name: String = actor.combatant_name if actor is Combatant else "Ultimate"
	ui.set_battle_log("Ultimate queued: %s" % actor_name)
	return true


func _interrupt_request_failure_message(reason: StringName) -> String:
	match reason:
		&"duplicate_request":
			return "Ultimate already queued."
		&"insufficient_energy":
			return "Not enough Energy."
	return "Cannot use Ultimate now."


## Safe window hook, called from exactly two places and nowhere else:
## - &"before_enemy_commit" (Window A1, Block 9F): once from
##   _begin_enemy_turn(), after the pre-attack delay but before
##   _enemy_attack() is ever called -- resume policy
##   AFTER_INTERRUPT_CONTINUE_ENEMY_ACTION.
## - &"after_enemy_recovery" (Window B, Block 9B/9D): once from
##   _resume_after_enemy_action(), after _enemy_attack() has fully
##   finished -- resume policy AFTER_INTERRUPT_CONTINUE_TO_PLAYER_TURN.
## Returns true if a queued Ultimate was actually begun (in which case its
## own cancel/fail/finish handlers are responsible for eventually calling
## _resume_after_interrupt() exactly once) or false if there was nothing
## safe/valid to process (in which case the caller proceeds with its own
## normal continuation -- _enemy_attack() for A1, _begin_player_turn() for
## B). Never processes more than one request per call.
##
## Block 9F: both windows share every guard below unchanged from Block
## 9B/9D. This is deliberate, not an oversight -- `enemy_action_in_progress`
## and `active_enemy_attack_token != 0` are false at A1's call site for the
## same reason they are false at B's: neither call site runs while
## _enemy_attack() is actually mid-flight (A1 runs strictly before it
## starts; B runs strictly after it finishes). If either guard is ever
## true when this function runs, that already means something is
## unsafe, regardless of which window asked -- so one guard chain serves
## both correctly, with the window_id argument only selecting the resume
## policy on completion, not which checks apply.
func _process_interrupt_queue_at_safe_window(window_id: StringName) -> bool:
	if window_id != &"after_enemy_recovery" and window_id != &"before_enemy_commit":
		return false
	if not is_inside_tree() or _is_battle_over():
		return false
	if ultimate_interrupt_queue == null or ultimate_interrupt_queue.is_empty():
		return false
	if is_processing_interrupt_queue or enemy_action_in_progress:
		return false
	if active_enemy_attack_token != 0:
		return false
	if (
		active_basic_command_token != 0
		or active_skill_command_token != 0
		or active_ultimate_command_token != 0
	):
		return false
	if (
		_has_pending_basic_command()
		or _has_pending_skill_command()
		or _has_pending_ultimate_command()
	):
		return false

	while not ultimate_interrupt_queue.is_empty():
		var request: UltimateInterruptRequest = ultimate_interrupt_queue.dequeue_next()
		if request == null:
			return false
		if _processed_interrupt_request_ids.has(request.unique_request_id):
			continue
		var reason := ultimate_interrupt_queue.revalidate(request)
		if not reason.is_empty():
			_processed_interrupt_request_ids[request.unique_request_id] = true
			continue
		return _begin_queued_ultimate(request, window_id)

	return false


## Starts the queued Ultimate through the exact on-turn command flow
## (UltimateCommandAdapter.begin_ultimate -> BattleCommandFlow.begin_command),
## with request_source = INTERRUPT_REQUEST and interrupt_authorized = true
## so BattleCommandFlow's normal rejection is bypassed for this one call
## only. `state` is set to PLAYER_TURN first because every existing
## Ultimate validation function (_validate_ultimate_command,
## _begin_ultimate_command's own guard) already requires
## `state == PLAYER_TURN`; this is genuinely accurate here too, since both
## safe windows are, by construction, a moment where nothing else is
## active and it is safe for the player to act -- window A1 (Block 9F)
## sits strictly before _enemy_attack() starts, window B (Block 9B) sits
## strictly after it finishes.
##
## Block 9D audit (see docs/battle_system_spec.md, "Block 9D implementation
## status" for the full write-up): this `state = PLAYER_TURN` assignment is
## a deliberately kept bridge, not forgotten cleanup. Only one guard has a
## hard functional dependency on it (_validate_ultimate_command, at commit
## time) -- but roughly ten other `state == PLAYER_TURN` checks across this
## file (Basic/Skill begin-command guards, the Attack/Skill/Confirm button
## handlers) were written assuming that value means "genuinely idle, safe
## for new input," and none of them were designed or tested against a
## queued-Ultimate-in-flight condition. The bridge is what makes all of
## that already-tested machinery (including button-disabling, which is what
## actually keeps Basic/Skill unreachable during this window -- see
## _on_ultimate_command_ready) apply to the queued path for free. Removing
## it would mean auditing and probably duplicating guard logic at every one
## of those call sites, which is a materially larger and riskier change
## than anything else in Block 9D. It stays, and this comment is the
## documented technical debt: state == PLAYER_TURN during this window does
## NOT mean a normal player turn is active -- always check
## is_processing_interrupt_queue first if that distinction matters.
func _begin_queued_ultimate(request: UltimateInterruptRequest, window_id: StringName) -> bool:
	_processed_interrupt_request_ids[request.unique_request_id] = true
	is_processing_interrupt_queue = true
	active_interrupt_request = request
	active_interrupt_window = window_id
	interrupt_resume_token += 1
	var resume_token := interrupt_resume_token

	state = BattleState.PLAYER_TURN
	ultimate_command_adapter.begin_ultimate(
		&"octagram_fragment",
		PendingBattleCommand.TargetRule.SINGLE_ENEMY,
		request.energy_cost,
		0,
		PendingBattleCommand.RequestSource.INTERRUPT_REQUEST,
		true
	)

	if _has_pending_ultimate_command():
		return true

	# begin_ultimate() failed before (or without) creating a pending command.
	# _on_ultimate_command_failed already ran synchronously above as part of
	# that call and, for an interrupt-sourced command, already reset the
	# flags above and resumed via _resume_after_interrupt() itself. This
	# block only fires as a defensive fallback for the rare case its own
	# guard could not identify the failure as interrupt-sourced (e.g. a
	# foreign pending command already existed) — so the battle can never
	# get stuck waiting on a request that never actually started.
	if is_processing_interrupt_queue and _consume_interrupt_resume_token(resume_token):
		is_processing_interrupt_queue = false
		active_interrupt_request = null
		_resume_after_interrupt()
	return false


## Block 9F: resume policy dispatch shared by both safe windows. Reads and
## clears active_interrupt_window (set by _begin_queued_ultimate()) to
## decide whether resuming means returning to a normal player turn
## (window B, Block 9B/9D, AFTER_INTERRUPT_CONTINUE_TO_PLAYER_TURN) or
## continuing the enemy's own attack (window A1, Block 9F,
## AFTER_INTERRUPT_CONTINUE_ENEMY_ACTION). The two policies are never
## mixed: exactly one of them runs per call, chosen solely by which window
## actually began this request. `log_text` defaults to
## _begin_player_turn()'s own default so omitting it here behaves
## identically to the pre-Block-9F direct call.
func _resume_after_interrupt(log_text: String = "Your turn. Choose an action.") -> void:
	var window := active_interrupt_window
	active_interrupt_window = &""
	if window == &"before_enemy_commit":
		_resume_enemy_action_after_a1()
		return
	_begin_player_turn(log_text)


## AFTER_INTERRUPT_CONTINUE_ENEMY_ACTION (Block 9F). Window A1 fires
## before _enemy_attack() has ever run for this enemy turn, so there is no
## suspended mid-action state to restore -- resuming means restoring
## `state` to ENEMY_TURN (the bridge in _begin_queued_ultimate() moved it
## to PLAYER_TURN for the Ultimate's own validation) and letting
## _enemy_attack() run exactly as _begin_enemy_turn() would have called it
## directly. Damage value, movement, and timing are untouched; a fresh
## enemy attack token is generated by _enemy_attack() itself the normal
## way — this function does not touch enemy guard tokens.
func _resume_enemy_action_after_a1() -> void:
	if _is_battle_over() or not is_inside_tree():
		return
	state = BattleState.ENEMY_TURN
	_enemy_attack()


## Resume policy for Block 9B: AFTER_INTERRUPT_CONTINUE_TO_PLAYER_TURN.
## Safe window B occurs after the enemy action has fully completed, so
## there is no suspended mid-action state to restore — resuming means
## exactly one call to _begin_player_turn(). See
## docs/battle_system_spec.md, "Block 9B implementation status" for why a
## full SuspendedBattleContext is not instantiated here (Block 9F's window
## A1 makes the same "no mid-action state to preserve" call, for the
## mirror-image reason: A1 sits strictly before the enemy action starts).
##
## Block 9D: guarded by _consume_interrupt_resume_token() as a second,
## independent layer against ever resolving/resuming the same queued
## Ultimate twice, on top of BattleCommandFlow's own commit-token
## consumption.
##
## Block 9F: routes through _resume_after_interrupt() so a lethal confirm
## at window A1 still wins the battle exactly as it does at window B
## (the _all_enemies_defeated() check below is window-agnostic), while a
## non-lethal confirm resumes whichever window actually began this
## request.
##
## Block 9G: uses _all_enemies_defeated() rather than enemy.is_defeated()
## -- in a multi-enemy battle, a queued Ultimate that kills only the
## targeted enemy must not end the battle while another enemy is still
## alive; see _all_enemies_defeated()'s doc comment.
func _finish_interrupt_ultimate_action(log_text: String) -> void:
	if not _consume_interrupt_resume_token(interrupt_resume_token):
		return
	_refresh_energy_ui()
	_refresh_skill_points_ui()
	_start_player_idle_animation()
	is_processing_interrupt_queue = false
	active_interrupt_request = null
	if _all_enemies_defeated():
		active_interrupt_window = &""
		_win("Enemy defeated. You win!")
		return
	_resume_after_interrupt(log_text)


func _begin_ultimate_command() -> bool:
	if not _uses_new_ultimate_command_flow():
		return false
	if state != BattleState.PLAYER_TURN or _is_battle_over():
		return false
	if (
		_has_pending_basic_command()
		or _has_pending_skill_command()
		or _has_pending_ultimate_command()
	):
		return false
	if ultimate_energy < MAX_ULTIMATE_ENERGY:
		ui.set_battle_log("Octagram Fragment needs full Energy.")
		return false
	var preferred_target := _global_selected_target
	var started = ultimate_command_adapter.begin_ultimate(
		&"octagram_fragment",
		PendingBattleCommand.TargetRule.SINGLE_ENEMY,
		MAX_ULTIMATE_ENERGY
	)
	if started:
		var command: PendingBattleCommand = ultimate_command_adapter.get_pending_command()
		if _preselect_pending_target_without_commit(command, preferred_target):
			_on_ultimate_command_target_changed(command, command.selected_targets.duplicate())
	return started


func _confirm_ultimate_command() -> bool:
	if not _has_pending_ultimate_command():
		return false
	_repair_ultimate_pending_target()
	return ultimate_command_adapter.confirm_ultimate()


func _cancel_ultimate_command() -> bool:
	if not _has_pending_ultimate_command():
		return false
	_show_ultimate_locked_message()
	return false


func _has_pending_ultimate_command() -> bool:
	return (
		ultimate_command_adapter != null
		and ultimate_command_adapter.has_pending_ultimate()
	)


## Block 9E: no confirm/cancel panel in production — press Ultimate again
## or click the target to commit. This fires identically for on-turn and
## queued/off-turn (safe window B) Ultimate, since both are just a pending
## ULTIMATE command underneath. ultimate_command_panel/ultimate_confirm_button/
## ultimate_cancel_button are kept constructed (see
## _create_ultimate_command_panel()) as an unused legacy fallback,
## documented in docs/battle_command_flow_implementation.md, "Block 9E";
## this handler deliberately no longer calls
## _set_ultimate_command_panel_visible(true).
## Buttons stay enabled during ready idle so the same Ultimate button can
## commit on a second press. Basic/Skill/Escape are deliberately locked
## out while Ultimate is pending; unlike Skill, Ultimate ready idle cannot
## be cancelled by changing commands.
func _on_ultimate_command_ready(command: PendingBattleCommand) -> void:
	_start_ultimate_ready_idle()
	if battle_presentation_3d != null:
		battle_presentation_3d.camera_transition(BattleCamera3D.Preset.PLAYER_ULTIMATE)
	_update_action_buttons(true)
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Octagram Fragment")
	ui.set_battle_log("Octagram Fragment ready. Press Ultimate again or choose a target.")
	_update_ultimate_command_panel(command)


func _on_ultimate_command_target_changed(
	command: PendingBattleCommand,
	_targets: Array
) -> void:
	var selected := _selected_ultimate_target(command)
	if selected != null:
		_global_selected_target = selected
	_update_ultimate_command_panel(command)
	_show_ultimate_target_highlight(command)


func _on_ultimate_command_cancelled(command: PendingBattleCommand) -> void:
	var was_interrupt := _is_interrupt_sourced(command)
	active_ultimate_command_token = 0
	_start_player_idle_animation()
	if battle_presentation_3d != null:
		battle_presentation_3d.camera_return_to_idle()
	_hide_ultimate_target_highlight()
	_set_ultimate_command_panel_visible(false)
	if was_interrupt:
		if not _consume_interrupt_resume_token(interrupt_resume_token):
			return
		is_processing_interrupt_queue = false
		active_interrupt_request = null
		_resume_after_interrupt("Octagram Fragment cancelled.")
		return
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log("Octagram Fragment cancelled.")
	_update_action_buttons(true)


func _on_ultimate_command_committed(command: PendingBattleCommand) -> void:
	_hide_ultimate_target_highlight()
	_set_ultimate_command_panel_visible(false)
	_update_action_buttons(false)
	ui.set_battle_input_enabled(false)
	call_deferred("_execute_committed_ultimate", command)


func _on_ultimate_command_failed(
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	var was_interrupt := _is_interrupt_sourced(command)
	active_ultimate_command_token = 0
	_start_player_idle_animation()
	_exit_ultimate_cutscene_presentation()
	if battle_presentation_3d != null:
		battle_presentation_3d.camera_return_to_idle()
	_hide_ultimate_target_highlight()
	_set_ultimate_command_panel_visible(false)
	if _is_battle_over():
		return
	if was_interrupt:
		if not _consume_interrupt_resume_token(interrupt_resume_token):
			return
		is_processing_interrupt_queue = false
		active_interrupt_request = null
		_resume_after_interrupt(_ultimate_command_failure_message(reason))
		return
	state = BattleState.PLAYER_TURN
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log(_ultimate_command_failure_message(reason))
	_update_action_buttons(true)


## True when `command` was started via the Block 9B off-turn interrupt
## queue rather than the normal on-turn Ultimate button.
func _is_interrupt_sourced(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command.request_source == PendingBattleCommand.RequestSource.INTERRUPT_REQUEST
	)


func _start_ultimate_ready_idle() -> void:
	_stop_player_idle_animation()
	_stop_player_basic_animation()
	_stop_player_skill_animation()
	_set_player_action_texture(TAKASHI_ULTIMATE_TEXTURE)


func _execute_committed_ultimate(command: PendingBattleCommand) -> void:
	if not _uses_new_ultimate_command_flow():
		return
	if not _is_committed_ultimate_command(command):
		return
	if not ultimate_command_adapter.execute_committed_command():
		return

	var target := _selected_ultimate_target(command)
	if target == null:
		_abort_committed_ultimate_command(command, &"target_missing_during_execution")
		return

	active_ultimate_command_token = command.commit_token
	state = BattleState.ACTION_RESOLUTION
	_update_action_buttons(false)
	ui.set_turn_text("Octagram Fragment")
	ui.set_battle_log("Octagram Fragment awakens.")
	await _run_ultimate_sequence(target, command)


func _finish_ultimate_command_resolution(
	command: PendingBattleCommand,
	log_text: String,
	is_interrupt: bool = false
) -> void:
	if not _is_committed_ultimate_command(command):
		return
	if not ultimate_command_adapter.resolve_committed_command(command):
		return
	if not ultimate_command_adapter.begin_recovery(command):
		return

	var token := command.commit_token
	if ultimate_recovery_tokens.has(token):
		return
	ultimate_recovery_tokens[token] = true
	_start_player_idle_animation()
	_hide_ultimate_target_highlight()
	if not _ultimate_recovery_guard(command):
		return
	if not ultimate_command_adapter.complete_recovery(command):
		return
	if ultimate_turn_completion_tokens.has(token):
		return
	ultimate_turn_completion_tokens[token] = true
	active_ultimate_command_token = 0
	if is_interrupt:
		_finish_interrupt_ultimate_action(log_text)
	else:
		_finish_player_action(log_text)


func _abort_committed_ultimate_command(
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_ultimate_command_token = 0
	_abort_ultimate_cutscene_visuals()
	if ultimate_command_adapter != null:
		ultimate_command_adapter.fail_ultimate(command, reason)
		ultimate_command_adapter.reset()


## Block 9D: named per the bridge audit in docs/battle_system_spec.md,
## "Block 9D implementation status" so this specific check has a
## documented, greppable identity. Still just `state == PLAYER_TURN` --
## the audit found removing the `state = PLAYER_TURN` bridge in
## _begin_queued_ultimate() unsafe to do broadly (see that function's doc
## comment), so this helper does not widen what's accepted, it only names
## the one check that genuinely depends on the bridge.
func _is_ultimate_command_state_allowed() -> bool:
	return state == BattleState.PLAYER_TURN


func _validate_ultimate_command(command: PendingBattleCommand) -> String:
	if command == null:
		return "missing_command"
	if command.command_type != PendingBattleCommand.CommandType.ULTIMATE:
		return "unsupported_command"
	if command.action_id != &"octagram_fragment":
		return "unsupported_ultimate"
	if _is_battle_over():
		return "battle_already_finished"
	if not _is_ultimate_command_state_allowed():
		return "battle_state_not_player_turn"
	if (
		active_basic_command_token != 0
		or active_skill_command_token != 0
		or active_ultimate_command_token != 0
	):
		return "action_execution_already_active"
	if not is_instance_valid(player) or player.is_defeated():
		return "actor_invalid"
	if ultimate_energy < command.energy_cost:
		return "not_enough_energy"
	if not command.has_required_targets():
		return "target_invalid"
	if _selected_ultimate_target(command) == null:
		return "target_not_targetable"
	return ""


func _commit_ultimate_command_resources(
	command: PendingBattleCommand
) -> bool:
	if not _validate_ultimate_command(command).is_empty():
		return false
	ultimate_energy = maxi(ultimate_energy - command.energy_cost, 0)
	_refresh_energy_ui()
	return true


func _get_ultimate_candidate_targets() -> Array[Node]:
	var targets: Array[Node] = []
	if battle_scene == null:
		return targets
	for child in battle_scene.get_children():
		if _is_ultimate_targetable(child):
			targets.append(child)
	return targets


func _is_ultimate_targetable(target: Node) -> bool:
	return (
		target is Combatant
		and target != player
		and is_instance_valid(target)
		and not (target as Combatant).is_defeated()
	)


func _selected_ultimate_target(command: PendingBattleCommand) -> Combatant:
	if command == null or command.selected_targets.is_empty():
		return null
	var target := command.selected_targets[0] as Combatant
	if target == null or not _is_ultimate_targetable(target):
		return null
	return target


## Block 9G: see _repair_basic_pending_target()'s doc comment -- same
## fix, same reason. Does not auto-select a different live enemy when the
## selected target has died. This also covers off-turn Ultimate (A1/B):
## a queued request's target is revalidated, never silently swapped, at
## commit time.
func _repair_ultimate_pending_target() -> bool:
	var command: PendingBattleCommand = ultimate_command_adapter.get_pending_command()
	if command == null:
		return false

	command.candidate_targets.assign(_get_ultimate_candidate_targets())
	command.refresh_candidates()
	return _selected_ultimate_target(command) != null


func _cycle_ultimate_target(direction: int) -> bool:
	if not _has_pending_ultimate_command():
		return false
	var command: PendingBattleCommand = ultimate_command_adapter.get_pending_command()
	command.candidate_targets.assign(_get_ultimate_candidate_targets())
	command.refresh_candidates()
	if command.candidate_targets.size() < 2:
		return false

	var current_index := 0
	if not command.selected_targets.is_empty():
		current_index = command.candidate_targets.find(command.selected_targets[0])
	if current_index < 0:
		current_index = 0
	var next_index := wrapi(
		current_index + direction,
		0,
		command.candidate_targets.size()
	)
	return ultimate_command_adapter.select_target(command.candidate_targets[next_index])


func _select_ultimate_target_at_position(screen_position: Vector2) -> bool:
	if not _has_pending_ultimate_command():
		return false
	var command: PendingBattleCommand = ultimate_command_adapter.get_pending_command()
	command.candidate_targets.assign(_get_ultimate_candidate_targets())
	command.refresh_candidates()
	var closest_target := _pick_target_at_screen_position(screen_position, command.candidate_targets)
	if closest_target == null:
		return false
	return ultimate_command_adapter.select_target(closest_target)


func _ultimate_execution_guard(
	command: PendingBattleCommand,
	target: Combatant,
	require_live_target: bool = true
) -> bool:
	if (
		not is_inside_tree()
		or state != BattleState.ACTION_RESOLUTION
		or _is_battle_over()
		or not is_instance_valid(player)
		or player.is_defeated()
		or target == null
		or not is_instance_valid(target)
		or (require_live_target and target.is_defeated())
	):
		return false
	if command == null:
		return true
	return (
		ultimate_command_adapter != null
		and command == ultimate_command_adapter.get_pending_command()
		and command.is_committed
		and active_ultimate_command_token == command.commit_token
		and ultimate_command_adapter.is_token_active(command.commit_token)
	)


func _ultimate_recovery_guard(command: PendingBattleCommand) -> bool:
	return (
		is_inside_tree()
		and state == BattleState.ACTION_RESOLUTION
		and not _is_battle_over()
		and ultimate_command_adapter != null
		and command == ultimate_command_adapter.get_pending_command()
		and command.is_committed
		and command.is_resolved
		and active_ultimate_command_token == command.commit_token
	)


func _is_committed_ultimate_command(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command.command_type == PendingBattleCommand.CommandType.ULTIMATE
		and command.is_committed
		and command.commit_token > 0
	)


func _consume_ultimate_hit(
	command: PendingBattleCommand,
	hit_index: int
) -> bool:
	if command == null:
		return true
	var key := "%d:%d" % [command.commit_token, hit_index]
	if ultimate_hit_tokens.has(key):
		return false
	ultimate_hit_tokens[key] = true
	return true


func _ultimate_command_failure_message(reason: StringName) -> String:
	match reason:
		&"not_enough_energy":
			return "Octagram Fragment needs full Energy."
		&"target_invalid_before_confirm", &"target_not_targetable":
			return "Octagram Fragment target is no longer valid."
		&"no_valid_targets", &"target_missing_during_execution":
			return "Octagram Fragment has no valid target."
		&"battle_state_not_player_turn", &"action_execution_already_active":
			return "Octagram Fragment is not available right now."
	return "Octagram Fragment was cancelled safely."


func _create_ultimate_target_highlight() -> void:
	if ultimate_target_highlight != null or battle_scene == null:
		return
	ultimate_target_highlight = Line2D.new()
	ultimate_target_highlight.name = "UltimateTargetHighlight"
	ultimate_target_highlight.width = 4.0
	ultimate_target_highlight.default_color = Color(0.72, 0.95, 1.0, 0.98)
	ultimate_target_highlight.closed = true
	ultimate_target_highlight.z_index = 32
	for index in range(40):
		var angle := TAU * float(index) / 40.0
		ultimate_target_highlight.add_point(
			Vector2(cos(angle) * 78.0, sin(angle) * 94.0)
		)
	battle_scene.add_child(ultimate_target_highlight)
	ultimate_target_highlight.visible = false


func _show_ultimate_target_highlight(command: PendingBattleCommand) -> void:
	if ultimate_target_highlight == null:
		return
	if _uses_3d_target_markers():
		ultimate_target_highlight.visible = false
		return
	ultimate_target_highlight.visible = _selected_ultimate_target(command) != null
	_sync_ultimate_target_highlight()


func _hide_ultimate_target_highlight() -> void:
	if ultimate_target_highlight != null:
		ultimate_target_highlight.visible = false


func _sync_ultimate_target_highlight() -> void:
	if ultimate_target_highlight == null or not ultimate_target_highlight.visible:
		return
	if _uses_3d_target_markers():
		ultimate_target_highlight.visible = false
		return
	if not _has_pending_ultimate_command():
		ultimate_target_highlight.visible = false
		return
	var target := _selected_ultimate_target(ultimate_command_adapter.get_pending_command())
	if target == null:
		ultimate_target_highlight.visible = false
		return
	ultimate_target_highlight.global_position = _target_highlight_position(target, Vector2(0.0, -80.0), 0.52)
	ultimate_target_highlight.rotation += 0.012


func _create_ultimate_command_panel() -> void:
	if ultimate_command_panel != null or canvas_layer == null:
		return

	ultimate_command_panel = Panel.new()
	ultimate_command_panel.name = "UltimateCommandPanel"
	ultimate_command_panel.visible = false
	ultimate_command_panel.anchor_left = 0.5
	ultimate_command_panel.anchor_right = 0.5
	ultimate_command_panel.anchor_top = 1.0
	ultimate_command_panel.anchor_bottom = 1.0
	ultimate_command_panel.offset_left = -180.0
	ultimate_command_panel.offset_right = 180.0
	ultimate_command_panel.offset_top = -258.0
	ultimate_command_panel.offset_bottom = -120.0
	ultimate_command_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ultimate_command_panel.add_theme_stylebox_override(
		"panel",
		_make_ultimate_command_panel_style()
	)
	canvas_layer.add_child(ultimate_command_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	ultimate_command_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)

	ultimate_ready_label = Label.new()
	ultimate_ready_label.text = "Octagram Fragment Ready"
	ultimate_ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_ready_label.add_theme_font_size_override("font_size", 15)
	ultimate_ready_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.95, 1.0, 1.0)
	)
	rows.add_child(ultimate_ready_label)

	ultimate_cost_label = Label.new()
	ultimate_cost_label.text = "Energy: -"
	ultimate_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_cost_label.add_theme_font_size_override("font_size", 12)
	ultimate_cost_label.add_theme_color_override(
		"font_color",
		Color(0.98, 0.92, 0.74, 1.0)
	)
	rows.add_child(ultimate_cost_label)

	ultimate_target_label = Label.new()
	ultimate_target_label.text = "Target: -"
	ultimate_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_target_label.add_theme_font_size_override("font_size", 13)
	ultimate_target_label.add_theme_color_override(
		"font_color",
		Color(0.84, 0.92, 1.0, 1.0)
	)
	rows.add_child(ultimate_target_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	rows.add_child(buttons)

	ultimate_confirm_button = Button.new()
	ultimate_confirm_button.text = "Confirm"
	ultimate_confirm_button.custom_minimum_size = Vector2(104.0, 32.0)
	ultimate_confirm_button.pressed.connect(_confirm_ultimate_command)
	buttons.add_child(ultimate_confirm_button)

	ultimate_cancel_button = Button.new()
	ultimate_cancel_button.text = "Cancel"
	ultimate_cancel_button.custom_minimum_size = Vector2(104.0, 32.0)
	ultimate_cancel_button.pressed.connect(_cancel_ultimate_command)
	buttons.add_child(ultimate_cancel_button)


func _make_ultimate_command_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.94)
	style.border_color = Color(0.72, 0.95, 1.0, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


func _set_ultimate_command_panel_visible(is_visible: bool) -> void:
	if ultimate_command_panel != null:
		ultimate_command_panel.visible = is_visible


func _update_ultimate_command_panel(command: PendingBattleCommand) -> void:
	if ultimate_target_label == null:
		return
	var target_name := "-"
	var target := _selected_ultimate_target(command)
	if target != null:
		target_name = target.combatant_name
	ultimate_target_label.text = "Target: %s" % target_name
	if ultimate_cost_label != null and command != null:
		ultimate_cost_label.text = "Energy: %d/%d" % [
			ultimate_energy,
			MAX_ULTIMATE_ENERGY
		]
	if ultimate_confirm_button != null:
		ultimate_confirm_button.disabled = target == null


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
	if _global_selected_target == null or not is_instance_valid(_global_selected_target) or _global_selected_target.is_defeated():
		var candidates := _get_basic_attack_candidate_targets()
		if not candidates.is_empty():
			_global_selected_target = candidates[0] as Combatant
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	ui.set_restart_visible(true)
	ui.set_turn_order_highlight(true)
	_update_action_buttons(true)


## Block 9F: safe window A1 opens right after the pre-attack delay below,
## before _enemy_attack() is ever called for this enemy turn — the exact
## point docs/battle_system_spec.md's Block 9A audit identified as "safe
## in principle, but there is no hook today." _process_interrupt_queue_at_safe_window()
## processes at most one queued Ultimate here; if it does, that Ultimate's
## own cancel/fail/finish handlers (via _resume_after_interrupt() ->
## _resume_enemy_action_after_a1()) are responsible for calling
## _enemy_attack() afterward, not this function. If nothing was processed,
## _enemy_attack() is called directly below exactly as before Block 9F.
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
	if state != BattleState.ENEMY_TURN:
		return
	var processed_at_a1: bool = await _process_interrupt_queue_at_safe_window(&"before_enemy_commit")
	if _is_battle_over() or not is_inside_tree():
		return
	if not processed_at_a1 and state == BattleState.ENEMY_TURN:
		_enemy_attack()


## Block 9C: enemy attack token model. Unlike Basic/Skill/Ultimate, the
## enemy attack was never modeled through PendingBattleCommand/
## BattleCommandFlow (see docs/battle_system_spec.md's Block 9A
## characterization). Rather than build a full command flow for it —
## explicitly out of scope for Block 9C — this gives the existing ad hoc
## coroutine the same commit-token/duplicate-prevention discipline
## Basic/Skill/Ultimate already have, so a stray double-callback can never
## apply damage twice, call _lose() twice, or call
## _resume_after_enemy_action() twice. It changes nothing about damage,
## timing, movement, or animation on the normal single-invocation path.
func _is_committed_enemy_attack(token: int) -> bool:
	return token != 0 and active_enemy_attack_token == token


func _enemy_attack_guard(token: int) -> bool:
	return (
		is_inside_tree()
		and state == BattleState.ENEMY_TURN
		and not _is_battle_over()
		and is_instance_valid(enemy)
		and is_instance_valid(player)
		and _is_committed_enemy_attack(token)
	)


func _enemy_recovery_guard(token: int) -> bool:
	return _enemy_attack_guard(token) and enemy_hit_tokens.has(token)


func _enemy_turn_completion_guard(token: int) -> bool:
	return _enemy_attack_guard(token) and enemy_recovery_tokens.has(token)


func _consume_enemy_hit(token: int) -> bool:
	if enemy_hit_tokens.has(token):
		return false
	enemy_hit_tokens[token] = true
	return true


func _consume_enemy_recovery(token: int) -> bool:
	if enemy_recovery_tokens.has(token):
		return false
	enemy_recovery_tokens[token] = true
	return true


func _consume_enemy_turn_completion(token: int) -> bool:
	if enemy_turn_completion_tokens.has(token):
		return false
	enemy_turn_completion_tokens[token] = true
	return true


func _clear_enemy_attack_token(token: int) -> void:
	if active_enemy_attack_token == token:
		active_enemy_attack_token = 0
	enemy_action_in_progress = false


func _reset_enemy_attack_runtime() -> void:
	active_enemy_attack_token = 0
	enemy_hit_tokens.clear()
	enemy_recovery_tokens.clear()
	enemy_turn_completion_tokens.clear()
	enemy_action_in_progress = false


func _enemy_attack() -> void:
	_enemy_attack_token_sequence += 1
	var token: int = _enemy_attack_token_sequence
	active_enemy_attack_token = token
	enemy_action_in_progress = true

	var damage: int = enemy.base_attack_damage
	var log_text: String = "Enemy attacks for %d damage." % damage

	await enemy.play_attack_movement(player)
	if not _enemy_attack_guard(token):
		_clear_enemy_attack_token(token)
		return

	if not _consume_enemy_hit(token):
		_clear_enemy_attack_token(token)
		return
	_play_impact_sfx()
	_spawn_enemy_claw_effect(player)
	_spawn_hit_spark(player, Color(1.0, 0.4, 0.42, 1.0))
	player.take_damage(damage)
	_refresh_player_status_ui()
	_show_floating_damage(player, damage)
	if ENEMY_IMPACT_HOLD_SECONDS > 0.0:
		await get_tree().create_timer(ENEMY_IMPACT_HOLD_SECONDS).timeout
		if not _enemy_attack_guard(token):
			_clear_enemy_attack_token(token)
			return
	await player.play_hit_feedback()
	if not _enemy_recovery_guard(token) or not _consume_enemy_recovery(token):
		_clear_enemy_attack_token(token)
		return
	_shake_camera()

	if player.is_defeated():
		if not _enemy_turn_completion_guard(token) or not _consume_enemy_turn_completion(token):
			_clear_enemy_attack_token(token)
			return
		_clear_enemy_attack_token(token)
		_lose("You were defeated.")
		return

	if not _enemy_turn_completion_guard(token) or not _consume_enemy_turn_completion(token):
		_clear_enemy_attack_token(token)
		return
	_clear_enemy_attack_token(token)
	await _resume_after_enemy_action(log_text)


## Safe window B guard: the only place _enemy_attack() no longer calls
## _begin_player_turn() directly. This is the minimal change
## docs/battle_system_spec.md's Block 9B section calls for — enemy movement,
## damage, and hit feedback above are byte-for-byte unchanged; only this
## tail call was replaced, and only to add exactly one more decision point
## before player turn resumes.
func _resume_after_enemy_action(log_text: String) -> void:
	if _is_battle_over() or not is_inside_tree():
		return
	var processed: bool = await _process_interrupt_queue_at_safe_window(&"after_enemy_recovery")
	if _is_battle_over() or not is_inside_tree():
		return
	if not processed:
		_begin_player_turn(log_text)


## Block 9E: pressing a different command while Skill/Ultimate is pending
## only cancels that pending command and returns to default command
## select — it never also begins Basic in the same click. The player must
## press Attack again afterward to actually execute it. This mirrors
## _on_skill_pressed()/_on_ultimate_pressed() below.
func _on_attack_pressed() -> void:
	if state != BattleState.PLAYER_TURN:
		return
	if _has_pending_skill_command():
		_cancel_skill_command()
		return
	if _has_pending_ultimate_command():
		_show_ultimate_locked_message()
		return

	if _has_pending_basic_command():
		_confirm_basic_attack_command()
		return

	if _uses_new_basic_command_flow():
		_begin_basic_attack_command()
		return

	await _start_legacy_basic_attack()


func _start_legacy_basic_attack() -> void:
	state = BattleState.ACTION_RESOLUTION
	_set_player_action_texture(TAKASHI_BASIC_TEXTURE)
	_update_action_buttons(false)
	ui.set_battle_input_enabled(false)
	ui.set_turn_text("Void Strike")
	ui.set_battle_log("Void Strike!")
	await _resolve_basic_attack(enemy)


func _resolve_basic_attack(
	target: Combatant = null,
	command: PendingBattleCommand = null
) -> void:
	if state != BattleState.ACTION_RESOLUTION:
		return
	if target == null:
		target = enemy
	if not _basic_execution_guard(command, target):
		return

	var damage: int = BASIC_ATTACK_DAMAGE
	var energy_gain: int = BASIC_ATTACK_ENERGY

	_play_basic_sfx()
	await player.play_attack_movement(target)
	if state != BattleState.ACTION_RESOLUTION:
		return
	if not _basic_execution_guard(command, target):
		return

	_spawn_basic_slash_effect(target)
	await get_tree().create_timer(0.08).timeout
	if state != BattleState.ACTION_RESOLUTION:
		return
	if not _basic_execution_guard(command, target):
		return
	if command != null and not basic_command_adapter.begin_resolution(command):
		return

	target.take_damage(damage)
	_show_floating_damage(target, damage)
	if BASIC_IMPACT_HOLD_SECONDS > 0.0:
		await get_tree().create_timer(BASIC_IMPACT_HOLD_SECONDS).timeout
		if state != BattleState.ACTION_RESOLUTION or not _basic_execution_guard(command, target, false):
			return
	await _play_basic_cetar_impact(target, command)
	if state != BattleState.ACTION_RESOLUTION:
		return
	if not _basic_execution_guard(command, target, false):
		return

	await target.play_hit_feedback()
	if not _basic_execution_guard(command, target, false):
		return
	_shake_camera()
	_add_ultimate_energy(energy_gain)
	_add_skill_points(SKILL_POINT_GAIN_BASIC)
	var log_text := "Void Strike deals %d damage, gains %d energy, and restores %d Skill Point." % [damage, energy_gain, SKILL_POINT_GAIN_BASIC]
	if command != null:
		_finish_basic_command_resolution(command, log_text)
	else:
		_finish_player_action(log_text)


func _on_confirm_pressed() -> void:
	if _uses_new_basic_command_flow() and _has_pending_basic_command():
		_confirm_basic_attack_command()
		return
	if _uses_new_skill_command_flow() and _has_pending_skill_command():
		_confirm_skill_command()
		return
	if _uses_new_ultimate_command_flow() and _has_pending_ultimate_command():
		_confirm_ultimate_command()
		return
	if state == BattleState.PLAYER_TURN:
		await _on_attack_pressed()


## Block 9E: no confirm/cancel panel in production. Pressing Skill while
## Skill is already pending commits to the active target (this is the
## replacement for the old Confirm button — see confirm_pending_command(),
## which _confirm_skill_command() already calls). Pressing Skill while a
## *different* command (Basic/Ultimate) is pending only cancels that
## command and returns to default select; it does not also begin Skill in
## the same click, matching _on_attack_pressed() above.
func _on_skill_pressed() -> void:
	if state != BattleState.PLAYER_TURN:
		return
	if _has_pending_skill_command():
		_confirm_skill_command()
		return
	if _has_pending_basic_command():
		_cancel_basic_attack_command()
		return
	if _has_pending_ultimate_command():
		_show_ultimate_locked_message()
		return

	if _uses_new_skill_command_flow():
		_begin_skill_command()
		return

	if skill_points < SKILL_POINT_COST_SKILL:
		return
	await _start_legacy_skill()


func _start_legacy_skill() -> void:
	state = BattleState.ACTION_RESOLUTION
	_set_player_action_texture(TAKASHI_SKILL_TEXTURE)
	_play_skill_sfx()
	_update_action_buttons(false)
	ui.set_turn_text("Triangle Rift")
	ui.set_battle_log("Triangle Rift charging...")
	await _execute_triangle_rift(enemy, null, true)


## Block 9E: no confirm/cancel panel in production. Pressing Ultimate while
## an Ultimate is already pending commits to the active target — this
## covers both on-turn ready idle and a queued/off-turn Ultimate's ready
## idle during safe window B identically, since both are just a pending
## ULTIMATE command underneath (_confirm_ultimate_command() already calls
## confirm_pending_command(), which does not care whether the command was
## on-turn or interrupt-sourced). Pressing Ultimate while a *different*
## command (Basic/Skill) is pending only cancels that command and returns
## to default select. The reverse is not true: once Ultimate itself is
## pending, Basic/Skill/Escape only show the locked message.
func _on_ultimate_pressed() -> void:
	if _has_pending_ultimate_command():
		_confirm_ultimate_command()
		return
	# Block 9B: off-turn requests only ever reach here when the Ultimate
	# button was independently made interactable by
	# _can_request_off_turn_ultimate_input() (see _update_action_buttons),
	# which already requires state == ENEMY_TURN. Basic/Skill can never have
	# a pending command in that state, so routing here first does not skip
	# any cancellation the original PLAYER_TURN path used to do.
	if state != BattleState.PLAYER_TURN:
		request_off_turn_ultimate(player)
		return
	if _has_pending_basic_command():
		_cancel_basic_attack_command()
		return
	if _has_pending_skill_command():
		_cancel_skill_command()
		return

	if _uses_new_ultimate_command_flow():
		_begin_ultimate_command()
		return

	if ultimate_energy < MAX_ULTIMATE_ENERGY:
		return
	await _start_legacy_ultimate()


func _show_ultimate_locked_message() -> void:
	if ui != null:
		ui.set_battle_log("Octagram Fragment is locked in. Press Ultimate again or choose a target.")


func _start_legacy_ultimate() -> void:
	state = BattleState.ACTION_RESOLUTION
	_update_action_buttons(false)
	ui.set_turn_text("Octagram Fragment")
	ui.set_battle_log("Octagram Fragment awakens.")
	ultimate_energy = 0
	_refresh_energy_ui()
	await _run_ultimate_sequence(enemy, null)


func _run_ultimate_sequence(
	target: Combatant,
	command: PendingBattleCommand = null
) -> void:
	if not _ultimate_execution_guard(command, target):
		return

	_enter_ultimate_cutscene_presentation(target)
	_set_battle_ui_for_ultimate(false)
	_start_ultimate_camera_zoom_in()
	await _play_takashi_ultimate_fvx_intro()
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return
	await _play_takashi_ulti_pre_animation()
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return
	await _wait_for_remaining_ultimate_zoom_in()
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return

	await _play_ultimate_sequence()
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return

	_play_ultimate_shatter_sfx()
	_play_ultimate_glass_burst_sfx(0.9)
	_play_ultimate_cring_noise_sfx(0.65)
	_play_ultimate_deep_boom_sfx(0.65)
	_play_screen_flash(Color(0.72, 0.95, 1.0, 0.24), 0.12)
	_shake_camera_with_strength(7.0)
	await _play_takashi_ulti_post_animation()
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return

	await _play_ultimate_camera_zoom_out()
	_set_battle_ui_for_ultimate(true)
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return

	await player.play_ultimate_feedback()
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return

	await player.play_skill_movement(target)
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return

	await _play_enemy_octagram_impact(target)
	if not _ultimate_execution_guard(command, target):
		_abort_ultimate_cutscene_visuals()
		return

	if command != null and not ultimate_command_adapter.begin_resolution(command):
		return
	if not _consume_ultimate_hit(command, 0):
		return
	target.take_damage(ULTIMATE_DAMAGE)
	_show_floating_damage(target, ULTIMATE_DAMAGE)
	if ULTIMATE_IMPACT_HOLD_SECONDS > 0.0:
		await get_tree().create_timer(ULTIMATE_IMPACT_HOLD_SECONDS).timeout
		if not _ultimate_execution_guard(command, target, false):
			return
	await target.play_hit_feedback()
	if not _ultimate_execution_guard(command, target, false):
		return
	await _fade_out_takashi_ultimate_glow_effect(0.26)
	if not _ultimate_execution_guard(command, target, false):
		return
	await _play_enemy_impact_camera_zoom_out()
	if not _ultimate_execution_guard(command, target, false):
		_abort_ultimate_cutscene_visuals()
		return
	_exit_ultimate_cutscene_presentation()
	_shake_camera()
	var log_text := "Octagram Fragment deals %d damage and consumes all energy." % ULTIMATE_DAMAGE
	if command != null:
		_finish_ultimate_command_resolution(command, log_text, _is_interrupt_sourced(command))
	else:
		_finish_player_action(log_text)


func _abort_ultimate_cutscene_visuals() -> void:
	_hide_takashi_ultimate_glow_effect()
	_hide_enemy_impact_fvx()
	if ultimate_frame_player != null:
		ultimate_frame_player.texture = null
		ultimate_frame_player.visible = false
	if ultimate_audio_player != null:
		ultimate_audio_player.stop()
	_set_battle_ui_for_ultimate(true)
	_exit_ultimate_cutscene_presentation()


func _enter_ultimate_cutscene_presentation(target: Combatant) -> void:
	if not _uses_3d_target_markers() or not _ultimate_cutscene_snapshot.is_empty():
		return
	_ultimate_cutscene_snapshot = {
		"presentation_visible": battle_presentation_3d.visible,
		"battle_camera_enabled": battle_camera.enabled if battle_camera != null else false,
		"player_visible": player.visible if player != null else false,
		"player_modulate": player.modulate if player != null else Color.WHITE,
		"target": target,
		"target_visible": target.visible if target != null else false,
		"target_modulate": target.modulate if target != null else Color.WHITE,
	}
	battle_presentation_3d.visible = false
	if battle_camera != null:
		battle_camera.enabled = true
	_show_combatant_for_ultimate_cutscene(player)
	_show_combatant_for_ultimate_cutscene(target)


func _exit_ultimate_cutscene_presentation() -> void:
	if _ultimate_cutscene_snapshot.is_empty():
		return
	if battle_presentation_3d != null and is_instance_valid(battle_presentation_3d):
		battle_presentation_3d.visible = bool(_ultimate_cutscene_snapshot.get("presentation_visible", true))
		battle_presentation_3d.camera_return_to_idle()
	if battle_camera != null:
		battle_camera.enabled = bool(_ultimate_cutscene_snapshot.get("battle_camera_enabled", false))
	if player != null and is_instance_valid(player):
		player.visible = bool(_ultimate_cutscene_snapshot.get("player_visible", player.visible))
		player.modulate = _ultimate_cutscene_snapshot.get("player_modulate", player.modulate)
	var target := _ultimate_cutscene_snapshot.get("target") as Combatant
	if target != null and is_instance_valid(target):
		target.visible = bool(_ultimate_cutscene_snapshot.get("target_visible", target.visible))
		target.modulate = _ultimate_cutscene_snapshot.get("target_modulate", target.modulate)
	_ultimate_cutscene_snapshot.clear()


func _show_combatant_for_ultimate_cutscene(combatant: Combatant) -> void:
	if combatant == null or not is_instance_valid(combatant):
		return
	combatant.visible = true
	combatant.modulate.a = 1.0


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
	if takashi_animator != null:
		await takashi_animator.play_ulti_pre_animation(get_tree(), func(): return state == BattleState.ACTION_RESOLUTION)


func _play_takashi_ulti_post_animation() -> void:
	if takashi_animator != null:
		await takashi_animator.play_ulti_post_animation(get_tree(), func(): return state == BattleState.ACTION_RESOLUTION)


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

	battle_sfx = BattleSfx.new()
	battle_sfx.name = "BattleSfx"
	battle_scene.add_child(battle_sfx)
	battle_sfx.setup()

	battle_vfx = BattleVfxScript.new()
	battle_vfx.name = "BattleVfx"
	battle_scene.add_child(battle_vfx)
	battle_vfx.setup(effect_layer, screen_flash, battle_scene)

	takashi_ultimate_effects = TakashiUltimateEffectsScript.new()
	takashi_ultimate_effects.name = "TakashiUltimateEffects"
	battle_scene.add_child(takashi_ultimate_effects)
	takashi_ultimate_effects.setup(player, enemy, effect_layer, player_action_sprite)


func _setup_takashi_ultimate_effect_nodes() -> void:
	pass


func _setup_enemy_impact_fvx_nodes() -> void:
	pass


func _create_additive_canvas_material() -> CanvasItemMaterial:
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _create_png_glow_shader_material(glow_color: Color, glow_radius: float, glow_strength: float, core_alpha: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = TAKASHI_ULTIMATE_GLOW_SHADER
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("glow_radius", glow_radius)
	material.set_shader_parameter("glow_strength", glow_strength)
	material.set_shader_parameter("core_alpha", core_alpha)
	return material


func _play_takashi_ultimate_fvx_intro() -> void:
	if takashi_ultimate_effects != null:
		await takashi_ultimate_effects.play_takashi_ultimate_fvx_intro(
			func(): return state == BattleState.ACTION_RESOLUTION,
			func(kind, arg1 = null, arg2 = null):
				match kind:
					&"rumble": _play_ultimate_charge_rumble_sfx(arg1 if arg1 != null else 0.9)
					&"step": _play_ultimate_fvx_step_sfx(arg1, arg2)
		)


func _play_takashi_ultimate_fvx_step(frame_index: int, keep_visible: bool) -> void:
	if takashi_ultimate_effects != null:
		await takashi_ultimate_effects.play_takashi_ultimate_fvx_step(
			frame_index,
			keep_visible,
			func(kind, idx, keep): _play_ultimate_fvx_step_sfx(idx, keep)
		)


func _show_takashi_ultimate_character_glow() -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.show_takashi_ultimate_character_glow()


func _hold_takashi_ultimate_fvx() -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.hold_takashi_ultimate_fvx()


func _advance_takashi_ultimate_fvx(delta: float) -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.advance(delta)


func _fade_out_takashi_ultimate_glow_effect(duration: float) -> void:
	if takashi_ultimate_effects != null:
		await takashi_ultimate_effects.fade_out_takashi_ultimate_glow_effect(duration)


func _hide_takashi_ultimate_glow_effect() -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.hide_takashi_ultimate_glow_effect()


func _sync_takashi_ultimate_effect_layout() -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.sync_effect_layout()


func _sync_takashi_ultimate_glow_frame() -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.sync_takashi_ultimate_glow_frame()


func _get_takashi_ultimate_fvx_scale(texture: Texture2D) -> Vector2:
	if takashi_ultimate_effects != null:
		return takashi_ultimate_effects.get_takashi_ultimate_fvx_scale(texture)
	return Vector2.ONE


func _shrink_takashi_ultimate_fvx_for_enemy_focus() -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.shrink_takashi_ultimate_fvx_for_enemy_focus()


func _play_enemy_octagram_impact(target: Combatant) -> void:
	if takashi_ultimate_effects != null:
		await takashi_ultimate_effects.play_enemy_octagram_impact(
			target,
			battle_camera,
			func(): return state == BattleState.ACTION_RESOLUTION,
			func(kind):
				match kind:
					&"enemy_wind": _play_enemy_octagram_wind_sfx()
					&"chime": _play_octagram_chime_sfx()
		)


func _start_enemy_impact_camera_zoom_in(target: Combatant) -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.start_enemy_impact_camera_zoom_in(target, battle_camera)


func _play_enemy_impact_camera_zoom_out() -> void:
	if takashi_ultimate_effects != null:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else BASE_VIEWPORT_SIZE
		await takashi_ultimate_effects.play_enemy_impact_camera_zoom_out(battle_camera, vp_size)


func _play_enemy_octagram_fvx_buildup(target: Combatant) -> void:
	if takashi_ultimate_effects != null:
		await takashi_ultimate_effects.play_enemy_octagram_fvx_buildup(target, func(): return state == BattleState.ACTION_RESOLUTION)


func _play_enemy_impact_fvx_step(frame_index: int, keep_visible: bool, target: Combatant) -> void:
	if takashi_ultimate_effects != null:
		await takashi_ultimate_effects.play_enemy_impact_fvx_step(frame_index, keep_visible, target)


func _fade_out_enemy_impact_fvx(duration: float) -> void:
	if takashi_ultimate_effects != null:
		await takashi_ultimate_effects.fade_out_enemy_impact_fvx(duration)


func _hide_enemy_impact_fvx() -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.hide_enemy_impact_fvx()


func _sync_enemy_impact_fvx_layout(target: Combatant = null) -> void:
	if takashi_ultimate_effects != null:
		takashi_ultimate_effects.sync_enemy_impact_fvx_layout(target if target != null else enemy)


func _get_enemy_impact_fvx_scale(texture: Texture2D) -> Vector2:
	if takashi_ultimate_effects != null:
		return takashi_ultimate_effects.get_enemy_impact_fvx_scale(texture)
	return Vector2.ONE


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


func _play_basic_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_basic()


func _play_skill_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_skill()


func _play_skill_release_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_skill_release()


func _play_rift_crack_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_rift_crack()


func _play_impact_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_impact()


func _play_ultimate_fvx_step_sfx(frame_index: int, keep_visible: bool) -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_fvx_step(frame_index, keep_visible)


func _play_ultimate_charge_rumble_sfx(intensity: float = 1.0) -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_charge_rumble(intensity)


func _play_ultimate_glass_burst_sfx(intensity: float = 1.0) -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_glass_burst(intensity)


func _play_ultimate_deep_boom_sfx(intensity: float = 1.0) -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_deep_boom(intensity)


func _play_ultimate_cring_noise_sfx(intensity: float = 1.0) -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_cring_noise(intensity)


func _play_ultimate_enemy_hit_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_enemy_hit()


func _play_ultimate_zoom_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_zoom()


func _play_ultimate_zoom_out_wind_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_zoom_out_wind()


func _play_enemy_octagram_wind_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_enemy_octagram_wind()


func _play_octagram_chime_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_octagram_chime()


func _play_ultimate_shatter_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_ultimate_shatter()


func _play_sring_sfx() -> void:
	if battle_sfx != null:
		battle_sfx.play_sring()


func _play_cetar_sfx(hit_index: int) -> void:
	if battle_sfx != null:
		battle_sfx.play_cetar(hit_index)


func _spawn_basic_slash_effect(target: Node2D) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	var start_position: Vector2 = player.global_position + Vector2(0.0, -118.0)
	var end_position: Vector2 = target.global_position + Vector2(-10.0, -118.0)
	battle_vfx.spawn_slash_projectile(start_position, end_position, Color(1.0, 0.97, 0.86, 0.92), 1.0)


func _spawn_enemy_claw_effect(target: Node2D) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	var start_position: Vector2 = enemy.global_position + Vector2(0.0, -112.0)
	var end_position: Vector2 = target.global_position + Vector2(10.0, -112.0)
	battle_vfx.spawn_slash_projectile(start_position, end_position, Color(1.0, 0.5, 0.58, 0.88), 0.85)


func _spawn_slash_projectile(start_position: Vector2, end_position: Vector2, color: Color, scale_multiplier: float) -> void:
	if effect_layer == null or battle_vfx == null:
		return
	battle_vfx.spawn_slash_projectile(start_position, end_position, color, scale_multiplier)


func _spawn_skill_charge_effect(origin: Node2D) -> void:
	if effect_layer == null or battle_vfx == null or origin == null:
		return
	battle_vfx.spawn_skill_charge_effect(origin.global_position + Vector2(6.0, -132.0))


func _spawn_triangle_rift_effect(target: Node2D, large: bool) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	battle_vfx.spawn_triangle_rift_effect(target.global_position + Vector2(0.0, -118.0), large)



func _execute_triangle_rift(
	target: Combatant = null,
	command: PendingBattleCommand = null,
	spend_cost_before_cast: bool = false
) -> void:
	if target == null:
		target = enemy
	if not _skill_execution_guard(command, target):
		return

	if spend_cost_before_cast:
		_spend_skill_points(SKILL_POINT_COST_SKILL)
	_spawn_skill_charge_effect(player)
	await ui.play_skill_cast_feedback()
	if not _skill_execution_guard(command, target):
		return

	ui.set_battle_log("Triangle Rift spends %d Skill Point and generates %d energy." % [SKILL_POINT_COST_SKILL, SKILL_ENERGY])
	await player.play_skill_movement(target)
	if not _skill_execution_guard(command, target):
		return

	await _resolve_triangle_rift_damage(target, command)
	if not _skill_execution_guard(command, target, false):
		return

	_add_ultimate_energy(SKILL_ENERGY)
	var log_text := "Triangle Rift deals %d damage." % SKILL_DAMAGE
	if command != null:
		_finish_skill_command_resolution(command, log_text)
	else:
		_finish_player_action(log_text)


func _resolve_triangle_rift_damage(
	target: Combatant = null,
	command: PendingBattleCommand = null
) -> void:
	if target == null:
		target = enemy
	if not _skill_execution_guard(command, target):
		return

	_play_skill_release_sfx()
	_spawn_triangle_rift_projectile(player, target)

	await get_tree().create_timer(SKILL_RIFT_PROJECTILE_DURATION).timeout
	if not _skill_execution_guard(command, target):
		return
	if command != null and not skill_command_adapter.begin_resolution(command):
		return

	if not _consume_skill_hit(command, 0):
		return
	target.take_damage(SKILL_DAMAGE)
	_show_floating_damage(target, SKILL_DAMAGE)

	if SKILL_IMPACT_HOLD_SECONDS > 0.0:
		await get_tree().create_timer(SKILL_IMPACT_HOLD_SECONDS).timeout
		if not _skill_execution_guard(command, target, false):
			return

	await _play_triangle_rift_impact(target, command)
	if not _skill_execution_guard(command, target, false):
		return

	await target.play_hit_feedback()


func _spawn_triangle_rift_projectile(origin: Node2D, target: Node2D) -> void:
	if effect_layer == null or battle_vfx == null or origin == null or target == null:
		return
	var start_position: Vector2 = origin.global_position + Vector2(28.0, -128.0)
	var end_position: Vector2 = target.global_position + Vector2(-8.0, -118.0)
	battle_vfx.spawn_triangle_rift_projectile(start_position, end_position, SKILL_RIFT_PROJECTILE_DURATION)



func _play_triangle_rift_impact(
	target: Node2D,
	command: PendingBattleCommand = null
) -> void:
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
		if not _skill_impact_guard(command, target):
			return

		_play_rift_crack_sfx()
		_spawn_triangle_rift_break(target, pulse_index + 1)
		_spawn_rift_crack_slashes(target, pulse_index)
		_spawn_rift_after_particles(target, pulse_index)
		_shake_camera_with_strength(SKILL_RIFT_CAMERA_SHAKE + float(pulse_index) * 1.5)

		await _shake_target_once(target, SKILL_RIFT_TARGET_SHAKE + float(pulse_index) * 2.0, 0.045)
		await get_tree().create_timer(SKILL_RIFT_IMPACT_INTERVAL).timeout


func _spawn_triangle_rift_break(target: Node2D, pulse_index: int) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	battle_vfx.spawn_triangle_rift_break(target.global_position + Vector2(0.0, -118.0), pulse_index)


func _spawn_rift_crack_slashes(target: Node2D, pulse_index: int) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	battle_vfx.spawn_rift_crack_slashes(target.global_position + Vector2(0.0, -118.0), pulse_index)


func _spawn_rift_after_particles(target: Node2D, pulse_index: int) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	battle_vfx.spawn_rift_after_particles(target.global_position + Vector2(0.0, -118.0), pulse_index)


func _spawn_hit_spark(target: Node2D, color: Color) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	battle_vfx.spawn_hit_spark(target.global_position + Vector2(0.0, -110.0), color)



func _play_basic_cetar_impact(
	target: Node2D,
	command: PendingBattleCommand = null
) -> void:
	_play_sring_sfx()
	_spawn_hit_spark(target, Color(1.0, 0.95, 0.62, 1.0))
	_spawn_cetar_text(target, "SRIING", Color(0.78, 0.96, 1.0, 1.0))
	_play_screen_flash(Color(0.92, 0.97, 1.0, 0.22), 0.08)
	_shake_target_once(target, BASIC_CETAR_TARGET_SHAKE * 0.65, BASIC_CETAR_INTERVAL * 0.75)
	_shake_camera_with_strength(BASIC_CETAR_CAMERA_SHAKE * 0.65)
	await get_tree().create_timer(0.045).timeout

	for hit_index in range(BASIC_CETAR_HIT_COUNT):
		if not _basic_impact_guard(command, target):
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
	if effect_layer == null or battle_vfx == null or target == null:
		return
	battle_vfx.spawn_cetar_slash_cross(target.global_position + Vector2(0.0, -112.0), burst_index)


func _spawn_cetar_triangle_shards(target: Node2D, burst_index: int) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	battle_vfx.spawn_cetar_triangle_shards(target.global_position + Vector2(0.0, -112.0), burst_index)


func _spawn_cetar_text(target: Node2D, text_value: String, color: Color) -> void:
	if battle_vfx == null or target == null:
		return
	var start_position: Vector2 = target.position + Vector2(randf_range(-34.0, 18.0), randf_range(-142.0, -112.0))
	battle_vfx.spawn_cetar_text(start_position, text_value, color, BASIC_CETAR_TEXT_RISE)


func _play_screen_flash(color: Color, duration: float) -> void:
	if battle_vfx != null:
		battle_vfx.play_screen_flash(color, duration)


func _hide_screen_flash() -> void:
	if battle_vfx != null:
		battle_vfx.hide_screen_flash()



func _on_restart_pressed() -> void:
	if EncounterCoordinator.has_active_encounter():
		BattleSessionCoordinator.report_battle_result(&"victory" if state == BattleState.WIN else &"defeat")
		return
	if is_bandit_encounter:
		if state == BattleState.WIN:
			SceneTransition.change_to_file(encounter_victory_scene_path)
		else:
			SceneTransition.reload_current()
	elif not encounter_retry_scene_path.is_empty():
		SceneTransition.change_to_file(encounter_retry_scene_path)
	else:
		SceneTransition.reload_current()


func _win(log_text: String) -> void:
	state = BattleState.WIN
	active_basic_command_token = 0
	active_skill_command_token = 0
	active_ultimate_command_token = 0
	_reset_ultimate_interrupt_queue()
	_reset_enemy_attack_runtime()
	# Block 9H: the happy path already returns the camera to its default
	# position/offset/zoom via each cinematic's own zoom-out tween before
	# resolution reaches here, but nothing previously guaranteed that if a
	# shake/zoom tween was ever interrupted or skipped. An explicit reset
	# here means victory can never leave a stray camera offset behind,
	# regardless of which command ended the battle.
	_reset_camera()
	if basic_command_adapter != null:
		basic_command_adapter.lock_for_outcome(true)
	if skill_command_adapter != null:
		skill_command_adapter.lock_for_outcome(true)
	if ultimate_command_adapter != null:
		ultimate_command_adapter.lock_for_outcome(true)
	_hide_basic_target_highlight()
	_hide_skill_target_highlight()
	_set_skill_command_panel_visible(false)
	_hide_ultimate_target_highlight()
	_set_ultimate_command_panel_visible(false)
	timing_bar.cancel_window()
	ui.set_battle_input_enabled(false)
	ui.set_turn_text("Victory")
	ui.set_battle_log(encounter_victory_log if not encounter_victory_log.is_empty() else log_text)
	ui.set_timing_mode(false)
	_update_action_buttons(false)
	ui.set_restart_visible(true)
	_persist_player_runtime_state()
	if is_bandit_encounter:
		var progress := get_node_or_null("/root/WorldProgress")
		if progress != null:
			progress.call("complete_active_encounter")
	await get_tree().create_timer(0.8).timeout
	if state != BattleState.WIN:
		return
	if EncounterCoordinator.has_active_encounter():
		BattleSessionCoordinator.report_battle_result(&"victory")
	else:
		SceneTransition.change_to_file(encounter_victory_scene_path)


func _lose(log_text: String) -> void:
	state = BattleState.LOSE
	active_basic_command_token = 0
	active_skill_command_token = 0
	active_ultimate_command_token = 0
	_reset_ultimate_interrupt_queue()
	_reset_enemy_attack_runtime()
	# Block 9H: see _win()'s matching comment -- guarantees no stray camera
	# offset survives defeat either.
	_reset_camera()
	if basic_command_adapter != null:
		basic_command_adapter.lock_for_outcome(false)
	if skill_command_adapter != null:
		skill_command_adapter.lock_for_outcome(false)
	if ultimate_command_adapter != null:
		ultimate_command_adapter.lock_for_outcome(false)
	_hide_basic_target_highlight()
	_hide_skill_target_highlight()
	_set_skill_command_panel_visible(false)
	_hide_ultimate_target_highlight()
	_set_ultimate_command_panel_visible(false)
	timing_bar.cancel_window()
	ui.set_battle_input_enabled(false)
	ui.set_turn_text("Defeat")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	_update_action_buttons(false)
	ui.set_restart_visible(true)
	_persist_player_runtime_state()


func _refresh_energy_ui() -> void:
	ui.set_energy(ultimate_energy, MAX_ULTIMATE_ENERGY)


func _refresh_player_status_ui() -> void:
	ui.set_player_status_hp(player.current_hp, player.max_hp)


func _refresh_skill_points_ui() -> void:
	ui.set_skill_points(skill_points, MAX_SKILL_POINTS)


func _update_action_buttons(enabled: bool) -> void:
	ui.set_actions_enabled(
		enabled,
		ultimate_energy >= MAX_ULTIMATE_ENERGY,
		skill_points >= SKILL_POINT_COST_SKILL,
		_can_request_off_turn_ultimate_input()
	)


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
	if _all_enemies_defeated():
		_win("Enemy defeated. You win!")
		return

	_begin_enemy_turn(log_text)


## Block 9G: victory must require every enemy in the battle to be
## defeated, not just the specific `enemy` scene node. `enemy.is_defeated()`
## alone is a single-enemy assumption that would incorrectly end a
## multi-enemy battle the instant that one node dies, even if another
## Combatant (e.g. a second enemy added for target-selection testing) is
## still alive. Reuses the exact same scene-tree scan and targetability
## rule as _get_basic_attack_candidate_targets()/_get_skill_candidate_targets()/
## _get_ultimate_candidate_targets(), just inverted: true only when no
## non-player Combatant in the battle is still alive.
func _all_enemies_defeated() -> bool:
	if battle_scene == null:
		return enemy.is_defeated()
	for child in battle_scene.get_children():
		if (
			child is Combatant
			and child != player
			and is_instance_valid(child)
			and not (child as Combatant).is_defeated()
		):
			return false
	return true


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
	if battle_presentation_3d != null and is_instance_valid(battle_presentation_3d):
		battle_presentation_3d.camera_shake(strength)
		return

	if battle_camera == null:
		return

	if _camera_shake_tween != null and _camera_shake_tween.is_valid():
		_camera_shake_tween.kill()
	_camera_shake_tween = create_tween()
	_camera_shake_tween.tween_property(battle_camera, "offset", Vector2(strength, randf_range(-1.5, 1.5)), 0.025)
	_camera_shake_tween.tween_property(battle_camera, "offset", Vector2(-strength, randf_range(-1.5, 1.5)), 0.035)
	_camera_shake_tween.tween_property(battle_camera, "offset", Vector2.ZERO, 0.035)


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
		if _camera_shake_tween != null and _camera_shake_tween.is_valid():
			_camera_shake_tween.kill()
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
			viewport_size = BASE_VIEWPORT_SIZE
		battle_camera.position = viewport_size * 0.5
		battle_camera.offset = Vector2.ZERO
		battle_camera.zoom = Vector2.ONE


func _set_player_action_texture(texture: Texture2D) -> void:
	if takashi_animator != null:
		takashi_animator.set_action_texture(texture)
		return
	_stop_player_idle_animation()
	_stop_player_basic_animation()
	_stop_player_skill_animation()
	if player_action_sprite != null and texture != null:
		_set_player_action_frame(texture)


func _set_player_action_frame(texture: Texture2D) -> void:
	if takashi_animator != null:
		takashi_animator.set_action_frame(texture)
	elif player_action_sprite != null and texture != null:
		player_action_sprite.texture = texture
		_apply_player_action_sprite_grounding()
		_sync_takashi_ultimate_glow_frame()


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
	if takashi_animator != null:
		takashi_animator.start_idle()


func _stop_player_idle_animation() -> void:
	if takashi_animator != null:
		takashi_animator.stop_idle()


func _start_player_basic_animation() -> void:
	if takashi_animator != null:
		takashi_animator.start_basic()


func _stop_player_basic_animation() -> void:
	if takashi_animator != null:
		takashi_animator.stop_basic()


func _start_player_skill_animation(loop_animation: bool = false) -> void:
	if takashi_animator != null:
		takashi_animator.start_skill(loop_animation)


func _stop_player_skill_animation() -> void:
	if takashi_animator != null:
		takashi_animator.stop_skill()


func _advance_player_idle_animation(delta: float) -> void:
	if takashi_animator != null:
		takashi_animator.advance(delta)


func _advance_player_basic_animation(delta: float) -> void:
	if takashi_animator != null:
		takashi_animator.advance(delta)


func _advance_player_skill_animation(delta: float) -> void:
	if takashi_animator != null:
		takashi_animator.advance(delta)

