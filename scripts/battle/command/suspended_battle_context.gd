extends RefCounted
class_name SuspendedBattleContext

## Snapshot of in-flight battle state captured at a safe interrupt window, so
## a queued off-turn Ultimate (Block 9B+) can run and the original turn can
## resume afterward. See docs/battle_system_spec.md, "Suspended battle
## context" for the authoritative rules.
##
## Block 9A: this class is a data-only skeleton. Nothing in production
## constructs, stores, or resumes a SuspendedBattleContext yet.
##
## Rules this class enforces on itself:
## - resume_token guards against being resumed more than once.
## - A discarded context can never be resumed.
## Rules the future caller (Block 9B+) must enforce, not this class:
## - Only construct at a safe interrupt window (never mid damage resolution,
##   never while another Ultimate is active).
## - Discard on victory/defeat or scene exit instead of resuming.

var suspended_state: int = -1
var current_turn_owner: StringName = &""
var current_actor: Node = null
var current_target: Node = null
var current_action_id: StringName = &""
var current_action_phase: StringName = &""
var current_commit_token: int = 0
var current_turn_token: int = 0
var pending_effect_status: StringName = &""
var active_ui_state: int = -1
var camera_state: Dictionary = {}
var input_lock_state: bool = true
var target_highlight_state: Dictionary = {}
var enemy_action_context: Dictionary = {}
var resume_policy: StringName = &"resume_from_safe_point"
var resume_token: int = 0
var is_resumed: bool = false
var is_discarded: bool = false
var created_at_msec: int = 0


func _init() -> void:
	created_at_msec = Time.get_ticks_msec()


## Returns true and marks the context consumed the first time it is called.
## Returns false on every call after the first, and after discard().
func mark_resumed() -> bool:
	if is_resumed or is_discarded:
		return false
	is_resumed = true
	return true


## Permanently invalidates the context (victory/defeat/scene exit). A
## discarded context can never be resumed, even if mark_resumed() has not
## been called yet.
func discard() -> void:
	is_discarded = true


func can_resume() -> bool:
	return not is_resumed and not is_discarded
