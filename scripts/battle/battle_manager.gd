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
const BattleTargetingSystemScript := preload("res://scripts/battle/battle_targeting_system.gd")
const BattleLegacyCommandPanelsScript := preload("res://scripts/battle/battle_legacy_command_panels.gd")
const BattleStageLayoutScript := preload("res://scripts/battle/battle_stage_layout.gd")
const BattleEncounterSpawnerScript := preload("res://scripts/battle/battle_encounter_spawner.gd")
const BattleEnemyTurnControllerScript := preload("res://scripts/battle/battle_enemy_turn_controller.gd")
const TakashiSkillActionScript := preload("res://scripts/battle/takashi_skill_action.gd")
const TakashiUltimateDirectorScript := preload("res://scripts/battle/takashi_ultimate_director.gd")
const BattleFlowCoordinatorScript := preload("res://scripts/battle/battle_flow_coordinator.gd")






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
var ultimate_frames: Array[Texture2D]:
	get: return takashi_ultimate_director.ultimate_frames if takashi_ultimate_director != null else []
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
var battle_ui_visible_before_ultimate: bool:
	get: return takashi_ultimate_director.battle_ui_visible_before_ultimate if takashi_ultimate_director != null else true
	set(v):
		if takashi_ultimate_director != null: takashi_ultimate_director.battle_ui_visible_before_ultimate = v
var enemy_impact_fvx_sprite: Sprite2D:
	get: return takashi_ultimate_effects.enemy_impact_fvx_sprite if takashi_ultimate_effects != null else null
var enemy_impact_fvx_glow_sprite: Sprite2D:
	get: return takashi_ultimate_effects.enemy_impact_fvx_glow_sprite if takashi_ultimate_effects != null else null
var _ultimate_cutscene_snapshot: Dictionary:
	get: return takashi_ultimate_director.ultimate_cutscene_snapshot if takashi_ultimate_director != null else {}

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
var enemy_turn_controller = BattleEnemyTurnControllerScript.new()
var takashi_skill_action = TakashiSkillActionScript.new()
var takashi_ultimate_director = TakashiUltimateDirectorScript.new()
var battle_flow_coordinator = BattleFlowCoordinatorScript.new()




var active_enemy_attack_token: int:
	get:
		return enemy_turn_controller.active_enemy_attack_token if enemy_turn_controller != null else 0
	set(value):
		if enemy_turn_controller != null:
			enemy_turn_controller.active_enemy_attack_token = value

var enemy_hit_tokens: Dictionary:
	get:
		return enemy_turn_controller.enemy_hit_tokens if enemy_turn_controller != null else {}

var enemy_recovery_tokens: Dictionary:
	get:
		return enemy_turn_controller.enemy_recovery_tokens if enemy_turn_controller != null else {}

var enemy_turn_completion_tokens: Dictionary:
	get:
		return enemy_turn_controller.enemy_turn_completion_tokens if enemy_turn_controller != null else {}

var enemy_action_in_progress: bool:
	get:
		return enemy_turn_controller.enemy_action_in_progress if enemy_turn_controller != null else false
	set(value):
		if enemy_turn_controller != null:
			enemy_turn_controller.enemy_action_in_progress = value

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
	_global_selected_target = BattleTargetingSystemScript.cycle_global_target(
		_get_basic_attack_candidate_targets(),
		_global_selected_target,
		direction
	)
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
	return BattleTargetingSystemScript.pick_target_at_screen_position(
		screen_position,
		candidates,
		battle_presentation_3d
	)


func _target_highlight_position(
	target: Combatant,
	fallback_offset: Vector2,
	vertical_ratio: float
) -> Vector2:
	return BattleTargetingSystemScript.get_target_highlight_position(
		target,
		fallback_offset,
		vertical_ratio,
		battle_presentation_3d
	)


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
	if battle_flow_coordinator != null:
		battle_flow_coordinator.restart_battle(self)


func _configure_encounter() -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.configure_encounter(self)


func _configure_from_encounter_context(context: EncounterContext) -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.configure_from_encounter_context(self, context)



func _spawn_additional_encounter_enemies() -> void:
	BattleEncounterSpawnerScript.spawn_additional_enemies(
		_pending_extra_battle_enemy_ids,
		enemy,
		enemy_formation,
		get_parent(),
		get_enemy_battle_profile_data,
		ENEMY_MAX_HP,
		ENEMY_BASE_DAMAGE
	)


func _encounter_formation_slot_position(index: int) -> Vector2:
	return BattleEncounterSpawnerScript.get_formation_slot_position(index, enemy, enemy_formation)


func _stop_exploration_music() -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.stop_exploration_music(self)


func _apply_encounter_presentation() -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.apply_encounter_presentation(self)


func _reset_battle_values() -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.reset_battle_values(self)


func _apply_persisted_player_runtime_state() -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.apply_persisted_player_runtime_state(self)


func _apply_opening_advantage_effects() -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.apply_opening_advantage_effects(self)


func _persist_player_runtime_state() -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.persist_player_runtime_state(self)



func _apply_runtime_layout() -> void:
	BattleStageLayoutScript.apply_runtime_layout(
		get_viewport(),
		battle_camera,
		forest_background,
		sky,
		forest_line,
		ground,
		bottom_vignette,
		player,
		enemy,
		player_ground_shadow,
		enemy_ground_shadow,
		takashi_animator
	)


func _apply_stage_grounding(viewport_size: Vector2, player_home_position: Vector2, enemy_home_position: Vector2) -> void:
	if bottom_vignette != null:
		bottom_vignette.polygon = BattleStageLayoutScript.build_bottom_vignette_polygon(viewport_size)
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
	return BattleTargetingSystemScript.cycle_command_target(
		basic_command_adapter.get_pending_command(),
		_get_basic_attack_candidate_targets(),
		direction,
		basic_command_adapter
	)


func _select_basic_target_at_position(screen_position: Vector2) -> bool:
	if not _has_pending_basic_command():
		return false
	return BattleTargetingSystemScript.select_target_at_position(
		basic_command_adapter.get_pending_command(),
		_get_basic_attack_candidate_targets(),
		screen_position,
		basic_command_adapter,
		battle_presentation_3d
	)


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
	basic_target_highlight = BattleTargetingSystemScript.create_reticle(
		battle_scene,
		"BasicTargetHighlight",
		Color(0.98, 0.78, 0.28, 0.96),
		4.0,
		62.0,
		78.0,
		32,
		30
	)


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

	BattleTargetingSystemScript.sync_reticle(
		basic_target_highlight,
		target,
		Vector2(0.0, -72.0),
		0.48,
		0.008,
		battle_presentation_3d
	)


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
	return BattleTargetingSystemScript.cycle_command_target(
		skill_command_adapter.get_pending_command(),
		_get_skill_candidate_targets(),
		direction,
		skill_command_adapter
	)


func _select_skill_target_at_position(screen_position: Vector2) -> bool:
	if not _has_pending_skill_command():
		return false
	return BattleTargetingSystemScript.select_target_at_position(
		skill_command_adapter.get_pending_command(),
		_get_skill_candidate_targets(),
		screen_position,
		skill_command_adapter,
		battle_presentation_3d
	)


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
	skill_target_highlight = BattleTargetingSystemScript.create_reticle(
		battle_scene,
		"SkillTargetHighlight",
		Color(0.42, 0.96, 1.0, 0.98),
		4.0,
		70.0,
		86.0,
		36,
		31
	)


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
	BattleTargetingSystemScript.sync_reticle(
		skill_target_highlight,
		target,
		Vector2(0.0, -76.0),
		0.5,
		-0.01,
		battle_presentation_3d
	)


func _create_skill_command_panel() -> void:
	if skill_command_panel != null or canvas_layer == null:
		return
	var elements := BattleLegacyCommandPanelsScript.create_skill_command_panel(
		canvas_layer,
		_confirm_skill_command,
		_cancel_skill_command
	)
	if elements.is_empty():
		return
	skill_command_panel = elements["panel"]
	skill_ready_label = elements["ready_label"]
	skill_cost_label = elements["cost_label"]
	skill_target_label = elements["target_label"]
	skill_confirm_button = elements["confirm_button"]
	skill_cancel_button = elements["cancel_button"]


func _set_skill_command_panel_visible(is_visible: bool) -> void:
	if skill_command_panel != null:
		skill_command_panel.visible = is_visible


func _update_skill_command_panel(command: PendingBattleCommand) -> void:
	var labels := {
		"ready": skill_ready_label,
		"cost": skill_cost_label,
		"target": skill_target_label
	}
	BattleLegacyCommandPanelsScript.update_skill_panel(
		labels,
		skill_confirm_button,
		_selected_skill_target(command),
		command,
		skill_points,
		MAX_SKILL_POINTS
	)



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
	return BattleTargetingSystemScript.cycle_command_target(
		ultimate_command_adapter.get_pending_command(),
		_get_ultimate_candidate_targets(),
		direction,
		ultimate_command_adapter
	)


func _select_ultimate_target_at_position(screen_position: Vector2) -> bool:
	if not _has_pending_ultimate_command():
		return false
	return BattleTargetingSystemScript.select_target_at_position(
		ultimate_command_adapter.get_pending_command(),
		_get_ultimate_candidate_targets(),
		screen_position,
		ultimate_command_adapter,
		battle_presentation_3d
	)


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
	ultimate_target_highlight = BattleTargetingSystemScript.create_reticle(
		battle_scene,
		"UltimateTargetHighlight",
		Color(0.72, 0.95, 1.0, 0.98),
		4.0,
		78.0,
		94.0,
		40,
		32
	)


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
	BattleTargetingSystemScript.sync_reticle(
		ultimate_target_highlight,
		target,
		Vector2(0.0, -80.0),
		0.52,
		0.012,
		battle_presentation_3d
	)


func _create_ultimate_command_panel() -> void:
	if ultimate_command_panel != null or canvas_layer == null:
		return
	var elements := BattleLegacyCommandPanelsScript.create_ultimate_command_panel(
		canvas_layer,
		_confirm_ultimate_command,
		_cancel_ultimate_command
	)
	if elements.is_empty():
		return
	ultimate_command_panel = elements["panel"]
	ultimate_ready_label = elements["ready_label"]
	ultimate_cost_label = elements["cost_label"]
	ultimate_target_label = elements["target_label"]
	ultimate_confirm_button = elements["confirm_button"]
	ultimate_cancel_button = elements["cancel_button"]


func _set_ultimate_command_panel_visible(is_visible: bool) -> void:
	if ultimate_command_panel != null:
		ultimate_command_panel.visible = is_visible


func _update_ultimate_command_panel(command: PendingBattleCommand) -> void:
	var labels := {
		"ready": ultimate_ready_label,
		"cost": ultimate_cost_label,
		"target": ultimate_target_label
	}
	BattleLegacyCommandPanelsScript.update_ultimate_panel(
		labels,
		ultimate_confirm_button,
		_selected_ultimate_target(command),
		command,
		ultimate_energy,
		MAX_ULTIMATE_ENERGY
	)



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
	return enemy_turn_controller.is_committed_enemy_attack(token)


func _enemy_attack_guard(token: int) -> bool:
	return enemy_turn_controller.enemy_attack_guard(
		token,
		is_inside_tree(),
		state,
		_is_battle_over(),
		enemy,
		player,
		BattleState.ENEMY_TURN
	)


func _enemy_recovery_guard(token: int) -> bool:
	return enemy_turn_controller.enemy_recovery_guard(
		token,
		is_inside_tree(),
		state,
		_is_battle_over(),
		enemy,
		player,
		BattleState.ENEMY_TURN
	)


func _enemy_turn_completion_guard(token: int) -> bool:
	return enemy_turn_controller.enemy_turn_completion_guard(
		token,
		is_inside_tree(),
		state,
		_is_battle_over(),
		enemy,
		player,
		BattleState.ENEMY_TURN
	)


func _consume_enemy_hit(token: int) -> bool:
	return enemy_turn_controller.consume_enemy_hit(token)


func _consume_enemy_recovery(token: int) -> bool:
	return enemy_turn_controller.consume_enemy_recovery(token)


func _consume_enemy_turn_completion(token: int) -> bool:
	return enemy_turn_controller.consume_enemy_turn_completion(token)


func _clear_enemy_attack_token(token: int) -> void:
	enemy_turn_controller.clear_enemy_attack_token(token)


func _reset_enemy_attack_runtime() -> void:
	if enemy_turn_controller != null:
		enemy_turn_controller.reset_enemy_attack_runtime()


func _enemy_attack() -> void:
	await enemy_turn_controller.execute_attack(self)



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
	if takashi_ultimate_director != null:
		await takashi_ultimate_director.run_ultimate_sequence(self, target, command)


func _abort_ultimate_cutscene_visuals() -> void:
	if takashi_ultimate_director != null:
		takashi_ultimate_director.abort_cutscene_visuals(self)


func _enter_ultimate_cutscene_presentation(target: Combatant) -> void:
	if takashi_ultimate_director != null:
		takashi_ultimate_director.enter_cutscene_presentation(self, target)


func _exit_ultimate_cutscene_presentation() -> void:
	if takashi_ultimate_director != null:
		takashi_ultimate_director.exit_cutscene_presentation(self)


func _show_combatant_for_ultimate_cutscene(combatant: Combatant) -> void:
	if takashi_ultimate_director != null:
		takashi_ultimate_director.show_combatant_for_cutscene(combatant)


func _set_battle_ui_for_ultimate(visible: bool) -> void:
	if takashi_ultimate_director != null:
		takashi_ultimate_director.set_battle_ui_for_ultimate(self, visible)


func _start_ultimate_camera_zoom_in() -> void:
	if takashi_ultimate_director != null:
		takashi_ultimate_director.start_ultimate_camera_zoom_in(self)


func _wait_for_remaining_ultimate_zoom_in() -> void:
	if takashi_ultimate_director != null:
		await takashi_ultimate_director.wait_for_remaining_ultimate_zoom_in(self)


func _play_ultimate_camera_zoom_out() -> void:
	if takashi_ultimate_director != null:
		await takashi_ultimate_director.play_ultimate_camera_zoom_out(self)


func _play_takashi_ulti_pre_animation() -> void:
	if takashi_animator != null:
		await takashi_animator.play_ulti_pre_animation(get_tree(), func(): return state == BattleState.ACTION_RESOLUTION)


func _play_takashi_ulti_post_animation() -> void:
	if takashi_animator != null:
		await takashi_animator.play_ulti_post_animation(get_tree(), func(): return state == BattleState.ACTION_RESOLUTION)


func _load_ultimate_frames() -> void:
	if takashi_ultimate_director != null:
		takashi_ultimate_director.load_ultimate_frames(ULTIMATE_FRAME_COUNT)


func _play_ultimate_sequence() -> void:
	if takashi_ultimate_director != null:
		await takashi_ultimate_director.play_ultimate_sequence(self)



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
	if takashi_skill_action != null:
		takashi_skill_action.spawn_triangle_rift_effect(self, target, large)


func _execute_triangle_rift(
	target: Combatant = null,
	command: PendingBattleCommand = null,
	spend_cost_before_cast: bool = false
) -> void:
	if takashi_skill_action != null:
		await takashi_skill_action.execute_triangle_rift(self, target, command, spend_cost_before_cast)


func _resolve_triangle_rift_damage(
	target: Combatant = null,
	command: PendingBattleCommand = null
) -> void:
	if takashi_skill_action != null:
		await takashi_skill_action.resolve_triangle_rift_damage(self, target, command)


func _spawn_triangle_rift_projectile(origin: Node2D, target: Node2D) -> void:
	if takashi_skill_action != null:
		takashi_skill_action.spawn_triangle_rift_projectile(self, origin, target)


func _play_triangle_rift_impact(
	target: Node2D,
	command: PendingBattleCommand = null
) -> void:
	if takashi_skill_action != null:
		await takashi_skill_action.play_triangle_rift_impact(self, target, command)



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
	if battle_vfx != null:
		battle_vfx.play_sriing_burst(target.global_position, BASIC_CETAR_TEXT_RISE)
	_shake_target_once(target, BASIC_CETAR_TARGET_SHAKE * 0.65, BASIC_CETAR_INTERVAL * 0.75)
	_shake_camera_with_strength(BASIC_CETAR_CAMERA_SHAKE * 0.65)
	await get_tree().create_timer(0.045).timeout

	for hit_index in range(BASIC_CETAR_HIT_COUNT):
		if not _basic_impact_guard(command, target):
			return

		_play_cetar_sfx(hit_index)
		if battle_vfx != null:
			battle_vfx.play_cetar_hit_burst(target.global_position, hit_index, BASIC_CETAR_TEXT_RISE)
		_shake_target_once(target, BASIC_CETAR_TARGET_SHAKE + float(hit_index) * 1.5, BASIC_CETAR_INTERVAL * 0.75)
		_shake_camera_with_strength(BASIC_CETAR_CAMERA_SHAKE + float(hit_index) * 0.8)
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
	if battle_flow_coordinator != null:
		await battle_flow_coordinator.win(self, log_text)


func _lose(log_text: String) -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.lose(self, log_text)



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
	if battle_flow_coordinator != null:
		return battle_flow_coordinator.all_enemies_defeated(self)
	return enemy.is_defeated()



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
	pass


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
