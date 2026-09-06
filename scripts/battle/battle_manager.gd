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
const TakashiBasicActionScript := preload("res://scripts/battle/takashi_basic_action.gd")
const BattleInterruptCoordinatorScript := preload("res://scripts/battle/battle_interrupt_coordinator.gd")
const BattleCommandCoordinatorScript := preload("res://scripts/battle/battle_command_coordinator.gd")






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

var command_coordinator = BattleCommandCoordinatorScript.new()

var _global_selected_target: Combatant:
	get: return command_coordinator.global_selected_target if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.global_selected_target = v

var basic_command_adapter:
	get: return command_coordinator.basic_command_adapter if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.basic_command_adapter = v

var basic_target_highlight: Line2D:
	get: return command_coordinator.basic_target_highlight if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.basic_target_highlight = v

var active_basic_command_token: int:
	get: return command_coordinator.active_basic_command_token if command_coordinator != null else 0
	set(v):
		if command_coordinator != null: command_coordinator.active_basic_command_token = v

var basic_recovery_tokens: Dictionary:
	get: return command_coordinator.basic_recovery_tokens if command_coordinator != null else {}
	set(v):
		if command_coordinator != null: command_coordinator.basic_recovery_tokens = v

var basic_turn_completion_tokens: Dictionary:
	get: return command_coordinator.basic_turn_completion_tokens if command_coordinator != null else {}
	set(v):
		if command_coordinator != null: command_coordinator.basic_turn_completion_tokens = v

var skill_command_adapter:
	get: return command_coordinator.skill_command_adapter if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.skill_command_adapter = v

var skill_target_highlight: Line2D:
	get: return command_coordinator.skill_target_highlight if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.skill_target_highlight = v

var skill_command_panel: Panel:
	get: return command_coordinator.skill_command_panel if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.skill_command_panel = v

var skill_ready_label: Label:
	get: return command_coordinator.skill_ready_label if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.skill_ready_label = v

var skill_target_label: Label:
	get: return command_coordinator.skill_target_label if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.skill_target_label = v

var skill_cost_label: Label:
	get: return command_coordinator.skill_cost_label if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.skill_cost_label = v

var skill_confirm_button: Button:
	get: return command_coordinator.skill_confirm_button if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.skill_confirm_button = v

var skill_cancel_button: Button:
	get: return command_coordinator.skill_cancel_button if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.skill_cancel_button = v

var active_skill_command_token: int:
	get: return command_coordinator.active_skill_command_token if command_coordinator != null else 0
	set(v):
		if command_coordinator != null: command_coordinator.active_skill_command_token = v

var skill_recovery_tokens: Dictionary:
	get: return command_coordinator.skill_recovery_tokens if command_coordinator != null else {}
	set(v):
		if command_coordinator != null: command_coordinator.skill_recovery_tokens = v

var skill_turn_completion_tokens: Dictionary:
	get: return command_coordinator.skill_turn_completion_tokens if command_coordinator != null else {}
	set(v):
		if command_coordinator != null: command_coordinator.skill_turn_completion_tokens = v

var skill_hit_tokens: Dictionary:
	get: return command_coordinator.skill_hit_tokens if command_coordinator != null else {}
	set(v):
		if command_coordinator != null: command_coordinator.skill_hit_tokens = v

var skill_animation_looping: bool:
	get: return takashi_animator.skill_animation_looping if takashi_animator != null else false
	set(value):
		if takashi_animator != null:
			takashi_animator.skill_animation_looping = value

var ultimate_command_adapter:
	get: return command_coordinator.ultimate_command_adapter if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_command_adapter = v

var ultimate_target_highlight: Line2D:
	get: return command_coordinator.ultimate_target_highlight if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_target_highlight = v

var ultimate_command_panel: Panel:
	get: return command_coordinator.ultimate_command_panel if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_command_panel = v

var ultimate_ready_label: Label:
	get: return command_coordinator.ultimate_ready_label if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_ready_label = v

var ultimate_target_label: Label:
	get: return command_coordinator.ultimate_target_label if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_target_label = v

var ultimate_cost_label: Label:
	get: return command_coordinator.ultimate_cost_label if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_cost_label = v

var ultimate_confirm_button: Button:
	get: return command_coordinator.ultimate_confirm_button if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_confirm_button = v

var ultimate_cancel_button: Button:
	get: return command_coordinator.ultimate_cancel_button if command_coordinator != null else null
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_cancel_button = v

var active_ultimate_command_token: int:
	get: return command_coordinator.active_ultimate_command_token if command_coordinator != null else 0
	set(v):
		if command_coordinator != null: command_coordinator.active_ultimate_command_token = v

var ultimate_recovery_tokens: Dictionary:
	get: return command_coordinator.ultimate_recovery_tokens if command_coordinator != null else {}
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_recovery_tokens = v

var ultimate_turn_completion_tokens: Dictionary:
	get: return command_coordinator.ultimate_turn_completion_tokens if command_coordinator != null else {}
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_turn_completion_tokens = v

var ultimate_hit_tokens: Dictionary:
	get: return command_coordinator.ultimate_hit_tokens if command_coordinator != null else {}
	set(v):
		if command_coordinator != null: command_coordinator.ultimate_hit_tokens = v

var interrupt_coordinator = BattleInterruptCoordinatorScript.new()

var ultimate_interrupt_queue: UltimateInterruptQueue:
	get:
		return interrupt_coordinator.ultimate_interrupt_queue if interrupt_coordinator != null else null
	set(value):
		if interrupt_coordinator != null:
			interrupt_coordinator.ultimate_interrupt_queue = value

var is_processing_interrupt_queue: bool:
	get:
		return interrupt_coordinator.is_processing_interrupt_queue if interrupt_coordinator != null else false
	set(value):
		if interrupt_coordinator != null:
			interrupt_coordinator.is_processing_interrupt_queue = value

var active_interrupt_request: UltimateInterruptRequest:
	get:
		return interrupt_coordinator.active_interrupt_request if interrupt_coordinator != null else null
	set(value):
		if interrupt_coordinator != null:
			interrupt_coordinator.active_interrupt_request = value

var active_interrupt_window: StringName:
	get:
		return interrupt_coordinator.active_interrupt_window if interrupt_coordinator != null else &""
	set(value):
		if interrupt_coordinator != null:
			interrupt_coordinator.active_interrupt_window = value

var interrupt_resume_token: int:
	get:
		return interrupt_coordinator.interrupt_resume_token if interrupt_coordinator != null else 0
	set(value):
		if interrupt_coordinator != null:
			interrupt_coordinator.interrupt_resume_token = value

var _consumed_interrupt_resume_tokens: Dictionary:
	get:
		return interrupt_coordinator._consumed_interrupt_resume_tokens if interrupt_coordinator != null else {}
	set(value):
		if interrupt_coordinator != null:
			interrupt_coordinator._consumed_interrupt_resume_tokens = value

var _processed_interrupt_request_ids: Dictionary:
	get:
		return interrupt_coordinator._processed_interrupt_request_ids if interrupt_coordinator != null else {}
	set(value):
		if interrupt_coordinator != null:
			interrupt_coordinator._processed_interrupt_request_ids = value

var enemy_turn_controller = BattleEnemyTurnControllerScript.new()
var takashi_skill_action = TakashiSkillActionScript.new()
var takashi_ultimate_director = TakashiUltimateDirectorScript.new()
var battle_flow_coordinator = BattleFlowCoordinatorScript.new()
var takashi_basic_action = TakashiBasicActionScript.new()




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
	if command_coordinator != null and command_coordinator.handle_unhandled_input(self, event):
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
	if command_coordinator != null:
		return command_coordinator.preselect_pending_target_without_commit(command, target)
	return false


func get_current_target_marker_target() -> Combatant:
	if command_coordinator != null:
		return command_coordinator.get_current_target_marker_target(self)
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
	if command_coordinator != null:
		command_coordinator.reset_all(self)
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



# =============================================================================
# Command Coordination (Delegated to BattleCommandCoordinator)
# =============================================================================

# --- Basic Attack Flow ---
func _setup_basic_command_runtime() -> void:
	command_coordinator.setup_basic_command_runtime(self)


func _setup_basic_command_adapter() -> void:
	command_coordinator.setup_basic_command_adapter(self)


func _reset_basic_command_runtime() -> void:
	command_coordinator.reset_basic_command_runtime(self)


func _uses_new_basic_command_flow() -> bool:
	return command_coordinator.uses_new_basic_command_flow(self)


func _begin_basic_attack_command() -> bool:
	return command_coordinator.begin_basic_attack_command(self)


func _confirm_basic_attack_command() -> bool:
	return command_coordinator.confirm_basic_attack_command(self)


func _cancel_basic_attack_command() -> bool:
	return command_coordinator.cancel_basic_attack_command(self)


func _has_pending_basic_command() -> bool:
	return command_coordinator.has_pending_basic_command()


func _on_basic_command_target_changed(command: PendingBattleCommand, targets: Array) -> void:
	command_coordinator.on_basic_command_target_changed(self, command, targets)


func _on_basic_command_cancelled(command: PendingBattleCommand) -> void:
	command_coordinator.on_basic_command_cancelled(self, command)


func _on_basic_command_committed(command: PendingBattleCommand) -> void:
	command_coordinator.on_basic_command_committed(self, command)


func _on_basic_command_failed(command: PendingBattleCommand, reason: StringName) -> void:
	command_coordinator.on_basic_command_failed(self, command, reason)


func _execute_committed_basic_attack(command: PendingBattleCommand) -> void:
	if takashi_basic_action != null:
		await takashi_basic_action.execute_committed_basic_attack(self, command)


func _finish_basic_command_resolution(command: PendingBattleCommand, log_text: String) -> void:
	command_coordinator.finish_basic_command_resolution(self, command, log_text)


func _abort_committed_basic_command(command: PendingBattleCommand, reason: StringName) -> void:
	command_coordinator.abort_committed_basic_command(self, command, reason)


func _validate_basic_attack_command(command: PendingBattleCommand) -> String:
	return command_coordinator.validate_basic_attack_command(self, command)


func _commit_basic_attack_command_resources(command: PendingBattleCommand) -> bool:
	return command_coordinator.commit_basic_attack_command_resources(self, command)


func _get_basic_attack_candidate_targets() -> Array[Node]:
	return command_coordinator.get_basic_attack_candidate_targets(self)


func _is_basic_attack_targetable(target: Node) -> bool:
	return command_coordinator.is_basic_attack_targetable(self, target)


func _selected_basic_target(command: PendingBattleCommand) -> Combatant:
	return command_coordinator.selected_basic_target(self, command)


func _repair_basic_pending_target() -> bool:
	return command_coordinator.repair_basic_pending_target(self)


func _cycle_basic_target(direction: int) -> bool:
	return command_coordinator.cycle_basic_target(self, direction)


func _select_basic_target_at_position(screen_position: Vector2) -> bool:
	return command_coordinator.select_basic_target_at_position(self, screen_position)


func _basic_execution_guard(command: PendingBattleCommand, target: Combatant, require_live_target: bool = true) -> bool:
	return command_coordinator.basic_execution_guard(self, command, target, require_live_target)


func _basic_impact_guard(command: PendingBattleCommand, target: Node2D) -> bool:
	return command_coordinator.basic_impact_guard(self, command, target)


func _basic_recovery_guard(command: PendingBattleCommand) -> bool:
	return command_coordinator.basic_recovery_guard(self, command)


func _is_committed_basic_command(command: PendingBattleCommand) -> bool:
	return command_coordinator.is_committed_basic_command(command)


func _basic_command_failure_message(reason: StringName) -> String:
	return command_coordinator.basic_command_failure_message(reason)


func _create_basic_target_highlight() -> void:
	command_coordinator.create_basic_target_highlight(self)


func _show_basic_target_highlight(command: PendingBattleCommand) -> void:
	command_coordinator.show_basic_target_highlight(self, command)


func _hide_basic_target_highlight() -> void:
	command_coordinator.hide_basic_target_highlight(self)


func _sync_basic_target_highlight() -> void:
	command_coordinator.sync_basic_target_highlight(self)


# --- Skill Command Flow ---
func _setup_skill_command_runtime() -> void:
	command_coordinator.setup_skill_command_runtime(self)


func _setup_skill_command_adapter() -> void:
	command_coordinator.setup_skill_command_adapter(self)


func _reset_skill_command_runtime() -> void:
	command_coordinator.reset_skill_command_runtime(self)


func _uses_new_skill_command_flow() -> bool:
	return command_coordinator.uses_new_skill_command_flow(self)


func _begin_skill_command() -> bool:
	return command_coordinator.begin_skill_command(self)


func _confirm_skill_command() -> bool:
	return command_coordinator.confirm_skill_command(self)


func _cancel_skill_command() -> bool:
	return command_coordinator.cancel_skill_command(self)


func _has_pending_skill_command() -> bool:
	return command_coordinator.has_pending_skill_command()


func _on_skill_command_ready(command: PendingBattleCommand) -> void:
	command_coordinator.on_skill_command_ready(self, command)


func _on_skill_command_target_changed(command: PendingBattleCommand, targets: Array) -> void:
	command_coordinator.on_skill_command_target_changed(self, command, targets)


func _on_skill_command_cancelled(command: PendingBattleCommand) -> void:
	command_coordinator.on_skill_command_cancelled(self, command)


func _on_skill_command_committed(command: PendingBattleCommand) -> void:
	command_coordinator.on_skill_command_committed(self, command)


func _on_skill_command_failed(command: PendingBattleCommand, reason: StringName) -> void:
	command_coordinator.on_skill_command_failed(self, command, reason)


func _start_skill_ready_idle() -> void:
	command_coordinator.start_skill_ready_idle(self)


func _execute_committed_skill(command: PendingBattleCommand) -> void:
	if takashi_skill_action != null:
		await takashi_skill_action.execute_committed_skill(self, command)


func _finish_skill_command_resolution(command: PendingBattleCommand, log_text: String) -> void:
	command_coordinator.finish_skill_command_resolution(self, command, log_text)


func _abort_committed_skill_command(command: PendingBattleCommand, reason: StringName) -> void:
	command_coordinator.abort_committed_skill_command(self, command, reason)


func _validate_skill_command(command: PendingBattleCommand) -> String:
	return command_coordinator.validate_skill_command(self, command)


func _commit_skill_command_resources(command: PendingBattleCommand) -> bool:
	return command_coordinator.commit_skill_command_resources(self, command)


func _get_skill_candidate_targets() -> Array[Node]:
	return command_coordinator.get_skill_candidate_targets(self)


func _is_skill_targetable(target: Node) -> bool:
	return command_coordinator.is_skill_targetable(self, target)


func _selected_skill_target(command: PendingBattleCommand) -> Combatant:
	return command_coordinator.selected_skill_target(self, command)


func _repair_skill_pending_target() -> bool:
	return command_coordinator.repair_skill_pending_target(self)


func _cycle_skill_target(direction: int) -> bool:
	return command_coordinator.cycle_skill_target(self, direction)


func _select_skill_target_at_position(screen_position: Vector2) -> bool:
	return command_coordinator.select_skill_target_at_position(self, screen_position)


func _skill_execution_guard(command: PendingBattleCommand, target: Combatant, require_live_target: bool = true) -> bool:
	return command_coordinator.skill_execution_guard(self, command, target, require_live_target)


func _skill_impact_guard(command: PendingBattleCommand, target: Node2D) -> bool:
	return command_coordinator.skill_impact_guard(self, command, target)


func _skill_recovery_guard(command: PendingBattleCommand) -> bool:
	return command_coordinator.skill_recovery_guard(self, command)


func _is_committed_skill_command(command: PendingBattleCommand) -> bool:
	return command_coordinator.is_committed_skill_command(command)


func _claim_skill_hit_token(command: PendingBattleCommand, pulse_index: int) -> bool:
	return command_coordinator.claim_skill_hit_token(command, pulse_index)


func _skill_command_failure_message(reason: StringName) -> String:
	return command_coordinator.skill_command_failure_message(reason)


func _create_skill_target_highlight() -> void:
	command_coordinator.create_skill_target_highlight(self)


func _show_skill_target_highlight(command: PendingBattleCommand) -> void:
	command_coordinator.show_skill_target_highlight(self, command)


func _hide_skill_target_highlight() -> void:
	command_coordinator.hide_skill_target_highlight(self)


func _sync_skill_target_highlight() -> void:
	command_coordinator.sync_skill_target_highlight(self)


func _create_skill_command_panel() -> void:
	command_coordinator.create_skill_command_panel(self)


func _set_skill_command_panel_visible(is_visible: bool) -> void:
	command_coordinator.set_skill_command_panel_visible(is_visible)


func _update_skill_command_panel(command: PendingBattleCommand) -> void:
	command_coordinator.update_skill_command_panel(self, command)


# --- Ultimate Command Setup & Flow ---
func _setup_ultimate_command_runtime() -> void:
	command_coordinator.setup_ultimate_command_runtime(self)


func _setup_ultimate_command_adapter() -> void:
	command_coordinator.setup_ultimate_command_adapter(self)


func _reset_ultimate_command_runtime() -> void:
	command_coordinator.reset_ultimate_command_runtime(self)


func _uses_new_ultimate_command_flow() -> bool:
	return command_coordinator.uses_new_ultimate_command_flow(self)


## --- Block 9B off-turn interrupt queue integration ---------------------

func _setup_ultimate_interrupt_queue() -> void:
	if interrupt_coordinator != null:
		interrupt_coordinator.setup(self)


func _reset_ultimate_interrupt_queue() -> void:
	if interrupt_coordinator != null:
		interrupt_coordinator.reset()


func _consume_interrupt_resume_token(token: int) -> bool:
	if interrupt_coordinator != null:
		return interrupt_coordinator.consume_interrupt_resume_token(token)
	return false


func _interrupt_energy_lookup(_actor: Node) -> int:
	return ultimate_energy


func _is_ultimate_active_or_processing() -> bool:
	if interrupt_coordinator != null:
		return interrupt_coordinator.is_ultimate_active_or_processing(self)
	return active_ultimate_command_token != 0


func _can_request_off_turn_ultimate_input() -> bool:
	if interrupt_coordinator != null:
		return interrupt_coordinator.can_request_off_turn_ultimate_input(self)
	return false


func request_off_turn_ultimate(actor: Node) -> bool:
	if interrupt_coordinator != null:
		return interrupt_coordinator.request_off_turn_ultimate(self, actor)
	return false


func _interrupt_request_failure_message(reason: StringName) -> String:
	if interrupt_coordinator != null:
		return interrupt_coordinator.interrupt_request_failure_message(reason)
	return "Cannot use Ultimate now."


func _process_interrupt_queue_at_safe_window(window_id: StringName) -> bool:
	if interrupt_coordinator != null:
		return interrupt_coordinator.process_interrupt_queue_at_safe_window(self, window_id)
	return false


func _begin_queued_ultimate(request: UltimateInterruptRequest, window_id: StringName) -> bool:
	if interrupt_coordinator != null:
		return interrupt_coordinator.begin_queued_ultimate(self, request, window_id)
	return false


func _resume_after_interrupt(log_text: String = "Your turn. Choose an action.") -> void:
	if interrupt_coordinator != null:
		interrupt_coordinator.resume_after_interrupt(self, log_text)


func _resume_enemy_action_after_a1() -> void:
	if interrupt_coordinator != null:
		interrupt_coordinator.resume_enemy_action_after_a1(self)


func _finish_interrupt_ultimate_action(log_text: String) -> void:
	if interrupt_coordinator != null:
		interrupt_coordinator.finish_interrupt_ultimate_action(self, log_text)


func _begin_ultimate_command() -> bool:
	return command_coordinator.begin_ultimate_command(self)


func _confirm_ultimate_command() -> bool:
	return command_coordinator.confirm_ultimate_command(self)


func _cancel_ultimate_command() -> bool:
	return command_coordinator.cancel_ultimate_command(self)


func _has_pending_ultimate_command() -> bool:
	return command_coordinator.has_pending_ultimate_command()


func _on_ultimate_command_ready(command: PendingBattleCommand) -> void:
	command_coordinator.on_ultimate_command_ready(self, command)


func _on_ultimate_command_target_changed(command: PendingBattleCommand, targets: Array) -> void:
	command_coordinator.on_ultimate_command_target_changed(self, command, targets)


func _on_ultimate_command_cancelled(command: PendingBattleCommand) -> void:
	command_coordinator.on_ultimate_command_cancelled(self, command)


func _on_ultimate_command_committed(command: PendingBattleCommand) -> void:
	command_coordinator.on_ultimate_command_committed(self, command)


func _on_ultimate_command_failed(command: PendingBattleCommand, reason: StringName) -> void:
	command_coordinator.on_ultimate_command_failed(self, command, reason)


func _is_interrupt_sourced(command: PendingBattleCommand) -> bool:
	return command_coordinator.is_interrupt_sourced(command)


func _start_ultimate_ready_idle() -> void:
	command_coordinator.start_ultimate_ready_idle(self)


func _execute_committed_ultimate(command: PendingBattleCommand) -> void:
	if takashi_ultimate_director != null:
		await takashi_ultimate_director.execute_committed_ultimate(self, command)


func _finish_ultimate_command_resolution(command: PendingBattleCommand, log_text: String, is_interrupt: bool = false) -> void:
	command_coordinator.finish_ultimate_command_resolution(self, command, log_text, is_interrupt)


func _abort_committed_ultimate_command(command: PendingBattleCommand, reason: StringName) -> void:
	command_coordinator.abort_committed_ultimate_command(self, command, reason)


func _is_ultimate_command_state_allowed() -> bool:
	return command_coordinator.is_ultimate_command_state_allowed(self)


func _validate_ultimate_command(command: PendingBattleCommand) -> String:
	return command_coordinator.validate_ultimate_command(self, command)


func _commit_ultimate_command_resources(command: PendingBattleCommand) -> bool:
	return command_coordinator.commit_ultimate_command_resources(self, command)


func _get_ultimate_candidate_targets() -> Array[Node]:
	return command_coordinator.get_ultimate_candidate_targets(self)


func _is_ultimate_targetable(target: Node) -> bool:
	return command_coordinator.is_ultimate_targetable(self, target)


func _selected_ultimate_target(command: PendingBattleCommand) -> Combatant:
	return command_coordinator.selected_ultimate_target(self, command)


func _repair_ultimate_pending_target() -> bool:
	return command_coordinator.repair_ultimate_pending_target(self)


func _cycle_ultimate_target(direction: int) -> bool:
	return command_coordinator.cycle_ultimate_target(self, direction)


func _select_ultimate_target_at_position(screen_position: Vector2) -> bool:
	return command_coordinator.select_ultimate_target_at_position(self, screen_position)


func _ultimate_execution_guard(command: PendingBattleCommand, target: Combatant, require_live_target: bool = true) -> bool:
	return command_coordinator.ultimate_execution_guard(self, command, target, require_live_target)


func _ultimate_impact_guard(command: PendingBattleCommand, target: Node2D) -> bool:
	return command_coordinator.ultimate_impact_guard(self, command, target)


func _ultimate_recovery_guard(command: PendingBattleCommand) -> bool:
	return command_coordinator.ultimate_recovery_guard(self, command)


func _is_committed_ultimate_command(command: PendingBattleCommand) -> bool:
	return command_coordinator.is_committed_ultimate_command(command)


func _consume_ultimate_hit(command: PendingBattleCommand, hit_index: int) -> bool:
	return command_coordinator.consume_ultimate_hit(command, hit_index)


func _claim_ultimate_hit_token(command: PendingBattleCommand, hit_index: int) -> bool:
	return command_coordinator.claim_ultimate_hit_token(command, hit_index)


func _ultimate_command_failure_message(reason: StringName) -> String:
	return command_coordinator.ultimate_command_failure_message(reason)


func _create_ultimate_target_highlight() -> void:
	command_coordinator.create_ultimate_target_highlight(self)


func _show_ultimate_target_highlight(command: PendingBattleCommand) -> void:
	command_coordinator.show_ultimate_target_highlight(self, command)


func _hide_ultimate_target_highlight() -> void:
	command_coordinator.hide_ultimate_target_highlight(self)


func _sync_ultimate_target_highlight() -> void:
	command_coordinator.sync_ultimate_target_highlight(self)


func _create_ultimate_command_panel() -> void:
	command_coordinator.create_ultimate_command_panel(self)


func _set_ultimate_command_panel_visible(is_visible: bool) -> void:
	command_coordinator.set_ultimate_command_panel_visible(is_visible)


func _update_ultimate_command_panel(command: PendingBattleCommand) -> void:
	command_coordinator.update_ultimate_command_panel(self, command)


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
	if takashi_basic_action != null:
		await takashi_basic_action.start_legacy_basic_attack(self)


func _resolve_basic_attack(
	target: Combatant = null,
	command: PendingBattleCommand = null
) -> void:
	if takashi_basic_action != null:
		await takashi_basic_action.resolve_basic_attack(self, target, command)


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
	if takashi_skill_action != null:
		await takashi_skill_action.start_legacy_skill(self)


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
	if takashi_ultimate_director != null:
		await takashi_ultimate_director.start_legacy_ultimate(self)


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
	if takashi_basic_action != null:
		takashi_basic_action.spawn_basic_slash_effect(self, target)


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


func _spawn_hit_spark(target: Node2D, color: Color) -> void:
	if effect_layer == null or battle_vfx == null or target == null:
		return
	battle_vfx.spawn_hit_spark(target.global_position + Vector2(0.0, -110.0), color)



func _play_basic_cetar_impact(
	target: Node2D,
	command: PendingBattleCommand = null
) -> void:
	if takashi_basic_action != null:
		await takashi_basic_action.play_basic_cetar_impact(self, target, command)


func _play_screen_flash(color: Color, duration: float) -> void:
	if battle_vfx != null:
		battle_vfx.play_screen_flash(color, duration)


func _hide_screen_flash() -> void:
	if battle_vfx != null:
		battle_vfx.hide_screen_flash()



func _on_restart_pressed() -> void:
	if battle_flow_coordinator != null:
		battle_flow_coordinator.on_restart_pressed(self)


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
	if battle_vfx != null:
		battle_vfx.show_floating_damage(target, damage, FLOATING_TEXT_RISE)


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
