extends Node
class_name TakashiBattleAnimator

## Manages 2D sprite frame animation and grounding for Takashi during combat encounters.

signal frame_changed(texture: Texture2D)

const PLAYER_ACTION_SPRITE_SCALE: Vector2 = Vector2(0.18, 0.18)
const PLAYER_ACTION_SPRITE_GROUND_Y: float = 46.0

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

var player_action_sprite: Sprite2D
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
var skill_animation_looping: bool = false
var skill_frame_index: int = 0
var skill_frame_elapsed: float = 0.0

var takashi_ulti_pre_frames: Array[Texture2D] = []
var takashi_ulti_post_frames: Array[Texture2D] = []


func setup(sprite: Sprite2D) -> void:
	player_action_sprite = sprite
	takashi_idle_frames = _load_texture_frames(TAKASHI_IDLE_FRAME_PATHS)
	takashi_basic_frames = _load_texture_frames(TAKASHI_BASIC_FRAME_PATHS)
	takashi_skill_frames = _load_texture_frames(TAKASHI_SKILL_FRAME_PATHS)
	takashi_ulti_pre_frames = _load_texture_frames(TAKASHI_ULTI_PRE_FRAME_PATHS)
	takashi_ulti_post_frames = _load_texture_frames(TAKASHI_ULTI_POST_FRAME_PATHS)
	apply_grounding()


func _load_texture_frames(frame_paths: Array[String]) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_path in frame_paths:
		if not FileAccess.file_exists(frame_path):
			continue
		var frame_texture: Texture2D = load(frame_path) as Texture2D
		if frame_texture != null:
			frames.append(frame_texture)
	return frames


func apply_grounding() -> void:
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


func set_action_frame(texture: Texture2D) -> void:
	if player_action_sprite == null or texture == null:
		return

	player_action_sprite.texture = texture
	apply_grounding()
	frame_changed.emit(texture)


func set_action_texture(texture: Texture2D) -> void:
	stop_idle()
	stop_basic()
	stop_skill()
	if player_action_sprite != null and texture != null:
		set_action_frame(texture)


func start_idle() -> void:
	if player_action_sprite == null:
		return

	stop_basic()
	stop_skill()
	if takashi_idle_frames.is_empty():
		set_action_frame(TAKASHI_IDLE_TEXTURE)
		return

	idle_animation_playing = true
	idle_frame_index = 0
	idle_frame_elapsed = 0.0
	set_action_frame(takashi_idle_frames[idle_frame_index])


func stop_idle() -> void:
	if not idle_animation_playing:
		return
	idle_animation_playing = false


func start_basic() -> void:
	if player_action_sprite == null:
		return

	stop_idle()
	stop_skill()
	if takashi_basic_frames.is_empty():
		set_action_frame(TAKASHI_BASIC_TEXTURE)
		return

	basic_animation_playing = true
	basic_frame_index = 0
	basic_frame_elapsed = 0.0
	set_action_frame(takashi_basic_frames[basic_frame_index])


func stop_basic() -> void:
	if not basic_animation_playing:
		return
	basic_animation_playing = false


func start_skill(loop_animation: bool = false) -> void:
	if player_action_sprite == null:
		return

	stop_idle()
	stop_basic()
	skill_animation_looping = loop_animation
	if takashi_skill_frames.is_empty():
		set_action_frame(TAKASHI_SKILL_TEXTURE)
		return

	skill_animation_playing = true
	skill_frame_index = 0
	skill_frame_elapsed = 0.0
	set_action_frame(takashi_skill_frames[skill_frame_index])


func stop_skill() -> void:
	if not skill_animation_playing:
		skill_animation_looping = false
		return
	skill_animation_playing = false
	skill_animation_looping = false


func play_ulti_pre_animation(tree: SceneTree, is_valid_state: Callable = Callable()) -> void:
	if player_action_sprite == null or takashi_ulti_pre_frames.is_empty():
		return

	stop_idle()
	stop_basic()
	stop_skill()
	var frame_duration: float = 1.0 / TAKASHI_ULTI_PRE_FRAME_RATE
	for frame_texture in takashi_ulti_pre_frames:
		if is_valid_state.is_valid() and not is_valid_state.call():
			return
		set_action_frame(frame_texture)
		if tree != null:
			await tree.create_timer(frame_duration).timeout


func play_ulti_post_animation(tree: SceneTree, is_valid_state: Callable = Callable()) -> void:
	if player_action_sprite == null or takashi_ulti_post_frames.is_empty():
		return

	var frame_duration: float = 1.0 / TAKASHI_ULTI_POST_FRAME_RATE
	for frame_texture in takashi_ulti_post_frames:
		if is_valid_state.is_valid() and not is_valid_state.call():
			return
		set_action_frame(frame_texture)
		if tree != null:
			await tree.create_timer(frame_duration).timeout


func advance(delta: float) -> void:
	_advance_idle(delta)
	_advance_basic(delta)
	_advance_skill(delta)


func _advance_idle(delta: float) -> void:
	if not idle_animation_playing or player_action_sprite == null or takashi_idle_frames.is_empty():
		return

	idle_frame_elapsed += delta
	var frame_duration: float = 1.0 / TAKASHI_IDLE_FRAME_RATE
	while idle_frame_elapsed >= frame_duration:
		idle_frame_elapsed -= frame_duration
		idle_frame_index = (idle_frame_index + 1) % takashi_idle_frames.size()
		set_action_frame(takashi_idle_frames[idle_frame_index])


func _advance_basic(delta: float) -> void:
	if not basic_animation_playing or player_action_sprite == null or takashi_basic_frames.is_empty():
		return

	basic_frame_elapsed += delta
	var frame_duration: float = 1.0 / TAKASHI_BASIC_FRAME_RATE
	while basic_frame_elapsed >= frame_duration:
		basic_frame_elapsed -= frame_duration
		basic_frame_index = (basic_frame_index + 1) % takashi_basic_frames.size()
		set_action_frame(takashi_basic_frames[basic_frame_index])


func _advance_skill(delta: float) -> void:
	if not skill_animation_playing or player_action_sprite == null or takashi_skill_frames.is_empty():
		return

	skill_frame_elapsed += delta
	var frame_duration: float = 1.0 / TAKASHI_SKILL_FRAME_RATE
	while skill_frame_elapsed >= frame_duration:
		skill_frame_elapsed -= frame_duration
		if skill_frame_index >= takashi_skill_frames.size() - 1:
			if skill_animation_looping:
				skill_frame_index = 0
				set_action_frame(takashi_skill_frames[skill_frame_index])
				continue
			skill_animation_playing = false
			return

		skill_frame_index += 1
		set_action_frame(takashi_skill_frames[skill_frame_index])
