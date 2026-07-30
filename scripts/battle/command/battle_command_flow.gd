extends Node
class_name BattleCommandFlow

signal command_started(command)
signal command_ready(command)
signal target_selection_started(command)
signal target_changed(command, targets)
signal command_confirmed(command)
signal command_committed(command)
signal command_cancelled(command)
signal command_execution_started(command)
signal command_resolved(command)
signal command_failed(command, reason)
signal flow_state_changed(battle_state, animation_state, ui_state)

enum BattleFlowState {
	TURN_READY,
	COMMAND_SELECT,
	COMMAND_READY_IDLE,
	TARGET_SELECT,
	COMMAND_CONFIRM,
	ACTION_EXECUTION,
	DAMAGE_AND_EFFECT_RESOLUTION,
	ACTION_RECOVERY,
	VICTORY,
	DEFEAT,
}

enum CharacterAnimationState {
	BATTLE_IDLE,
	BASIC_READY,
	SKILL_READY,
	ULTIMATE_READY,
	BASIC_ACTION,
	SKILL_ACTION,
	ULTIMATE_ACTION,
	RECOVERY,
	HIT,
	DEFEATED,
}

enum UiInteractionState {
	COMMAND_BUTTONS_ACTIVE,
	TARGET_CURSOR_ACTIVE,
	CONFIRM_CANCEL_ACTIVE,
	INPUT_LOCKED,
}

var battle_state: int = BattleFlowState.COMMAND_SELECT
var animation_state: int = CharacterAnimationState.BATTLE_IDLE
var ui_state: int = UiInteractionState.COMMAND_BUTTONS_ACTIVE
var pending_command: PendingBattleCommand

var _sequence_index: int = 0
var _commit_sequence: int = 0
var _consumed_tokens: Dictionary = {}
var _resource_validator: Callable
var _resource_committer: Callable


func configure_resource_callbacks(
	validator: Callable,
	committer: Callable
) -> void:
	_resource_validator = validator
	_resource_committer = committer


func begin_command(
	actor: Node,
	command_type: int,
	action_id: StringName,
	target_rule: int,
	candidate_targets: Array[Node],
	skill_point_cost: int = 0,
	energy_cost: int = 0,
	source_turn: int = 0,
	source_state: int = BattleFlowState.COMMAND_SELECT,
	request_source: int = PendingBattleCommand.RequestSource.TURN_COMMAND,
	requires_ready_idle: bool = true,
	requires_confirm: bool = true,
	auto_commit_on_target_selected: bool = false,
	interrupt_authorized: bool = false,
	auto_commit_on_begin: bool = true
) -> bool:
	# Block 9E: auto_commit_on_target_selected controls two previously-fused
	# behaviors that needed to be split — (1) the immediate commit below,
	# when begin_command() itself finds only one candidate target, and
	# (2) commit-on-click in set_pending_target()/set_pending_targets()
	# further down. auto_commit_on_begin gates ONLY (1); it defaults to
	# true so every existing caller (Basic Attack fast flow) is unaffected.
	# Skill/Ultimate (Block 9E) pass auto_commit_on_target_selected = true
	# (so clicking a target commits) but auto_commit_on_begin = false (so
	# ready idle is still shown even when there is only one live enemy —
	# committing then requires a second explicit input: pressing the same
	# command again, or clicking the target).
	#
	# Block 9B: INTERRUPT_REQUEST is still rejected unless the caller passes
	# interrupt_authorized = true. No existing caller does — Basic/Skill/
	# on-turn Ultimate, the debug scene, and the contract test all omit this
	# argument, so they keep getting rejected exactly as before this block.
	# Only BattleManager's safe-window-B queue processing (Block 9B) passes
	# true, and only after its own process-time validation already ran.
	if (
		request_source == PendingBattleCommand.RequestSource.INTERRUPT_REQUEST
		and not interrupt_authorized
	):
		_fail(null, &"off_turn_interrupt_not_available")
		return false
	if battle_state != BattleFlowState.COMMAND_SELECT:
		_fail(pending_command, &"command_input_not_available")
		return false
	if has_pending_command():
		_fail(pending_command, &"actor_already_has_pending_command")
		return false

	_sequence_index += 1
	pending_command = PendingBattleCommand.new(
		_sequence_index,
		actor,
		command_type,
		action_id,
		target_rule,
		candidate_targets,
		skill_point_cost,
		energy_cost,
		source_turn,
		source_state,
		request_source,
		_sequence_index
	)
	pending_command.requires_ready_idle = requires_ready_idle
	pending_command.requires_confirm = requires_confirm
	pending_command.auto_commit_on_target_selected = auto_commit_on_target_selected
	pending_command.refresh_candidates()
	pending_command.finalize_automatic_targets()
	if not pending_command.has_valid_actor():
		_fail_and_clear(&"invalid_actor")
		return false
	if pending_command.requires_target() and pending_command.candidate_targets.is_empty():
		_fail_and_clear(&"no_valid_targets")
		return false

	command_started.emit(pending_command)
	if pending_command.requires_ready_idle:
		_set_states(
			BattleFlowState.COMMAND_READY_IDLE,
			_ready_animation_for(command_type),
			UiInteractionState.CONFIRM_CANCEL_ACTIVE
		)
		command_ready.emit(pending_command)

	if pending_command.requires_target():
		if pending_command.target_rule in [
			PendingBattleCommand.TargetRule.SINGLE_ENEMY,
			PendingBattleCommand.TargetRule.SINGLE_ALLY,
		]:
			pending_command.select_target(pending_command.candidate_targets[0])
		_set_states(
			BattleFlowState.TARGET_SELECT,
			_ready_animation_for(command_type),
			UiInteractionState.TARGET_CURSOR_ACTIVE
		)
		target_selection_started.emit(pending_command)
		target_changed.emit(
			pending_command,
			pending_command.selected_targets.duplicate()
		)
		if (
			pending_command.auto_commit_on_target_selected
			and auto_commit_on_begin
			and pending_command.candidate_targets.size() <= 1
		):
			return confirm_pending_command()
	elif not pending_command.requires_confirm:
		return confirm_pending_command()
	return true


func set_pending_target(target: Node) -> bool:
	if not has_pending_command() or battle_state != BattleFlowState.TARGET_SELECT:
		return false
	if not pending_command.select_target(target):
		_fail(pending_command, &"invalid_target")
		return false
	target_changed.emit(
		pending_command,
		pending_command.selected_targets.duplicate()
	)
	if pending_command.auto_commit_on_target_selected:
		confirm_pending_command()
	return true


func set_pending_targets(targets: Array[Node]) -> bool:
	if not has_pending_command() or battle_state != BattleFlowState.TARGET_SELECT:
		return false
	if not pending_command.select_targets(targets):
		_fail(pending_command, &"invalid_targets")
		return false
	target_changed.emit(
		pending_command,
		pending_command.selected_targets.duplicate()
	)
	if pending_command.auto_commit_on_target_selected:
		confirm_pending_command()
	return true


func confirm_pending_command() -> bool:
	if not has_pending_command():
		return false
	if battle_state not in [
		BattleFlowState.COMMAND_READY_IDLE,
		BattleFlowState.TARGET_SELECT,
		BattleFlowState.COMMAND_CONFIRM,
	]:
		return false
	if pending_command.is_confirmed:
		return false

	pending_command.refresh_candidates()
	pending_command.finalize_automatic_targets()
	if not pending_command.has_required_targets():
		_fail_and_cancel(&"target_invalid_before_confirm")
		return false

	pending_command.is_confirmed = true
	_set_states(
		BattleFlowState.COMMAND_CONFIRM,
		animation_state,
		UiInteractionState.CONFIRM_CANCEL_ACTIVE
	)
	command_confirmed.emit(pending_command)
	return commit_pending_command()


func cancel_pending_command() -> bool:
	if not has_pending_command():
		return false
	if battle_state not in [
		BattleFlowState.COMMAND_READY_IDLE,
		BattleFlowState.TARGET_SELECT,
		BattleFlowState.COMMAND_CONFIRM,
	]:
		return false
	if not pending_command.cancel():
		return false

	var cancelled := pending_command
	pending_command = null
	_set_states(
		BattleFlowState.COMMAND_SELECT,
		CharacterAnimationState.BATTLE_IDLE,
		UiInteractionState.COMMAND_BUTTONS_ACTIVE
	)
	command_cancelled.emit(cancelled)
	return true


func commit_pending_command() -> bool:
	if not has_pending_command() or pending_command.is_committed:
		return false
	if battle_state != BattleFlowState.COMMAND_CONFIRM:
		return false
	if not pending_command.has_valid_actor():
		_fail_and_cancel(&"invalid_actor_before_commit")
		return false

	pending_command.refresh_candidates()
	pending_command.finalize_automatic_targets()
	if not pending_command.has_required_targets():
		_fail_and_cancel(&"invalid_target_before_commit")
		return false

	var validation_reason := _validate_resources(pending_command)
	if not validation_reason.is_empty():
		_fail_and_cancel(StringName(validation_reason))
		return false

	_commit_sequence += 1
	pending_command.commit_token = _commit_sequence
	pending_command.is_committed = true
	if not _commit_resources(pending_command):
		pending_command.is_committed = false
		pending_command.commit_token = 0
		_fail_and_cancel(&"resource_commit_failed")
		return false

	_set_states(
		BattleFlowState.ACTION_EXECUTION,
		_action_animation_for(pending_command.command_type),
		UiInteractionState.INPUT_LOCKED
	)
	command_committed.emit(pending_command)
	return true


func execute_committed_command() -> bool:
	if not has_pending_command():
		return false
	if not pending_command.is_committed or pending_command.execution_started:
		return false
	if _consumed_tokens.has(pending_command.commit_token):
		_fail(pending_command, &"commit_token_already_consumed")
		return false

	pending_command.execution_started = true
	command_execution_started.emit(pending_command)
	return true


func begin_resolution(command: PendingBattleCommand) -> bool:
	if not _is_active_committed_command(command):
		return false
	_set_states(
		BattleFlowState.DAMAGE_AND_EFFECT_RESOLUTION,
		animation_state,
		UiInteractionState.INPUT_LOCKED
	)
	return true


func resolve_committed_command(command: PendingBattleCommand) -> bool:
	if not _is_active_committed_command(command):
		return false
	if command.is_resolved or _consumed_tokens.has(command.commit_token):
		return false

	command.is_resolved = true
	_consumed_tokens[command.commit_token] = true
	command_resolved.emit(command)
	return true


func begin_recovery(command: PendingBattleCommand) -> bool:
	if not _is_active_committed_command(command) or not command.is_resolved:
		return false
	_set_states(
		BattleFlowState.ACTION_RECOVERY,
		CharacterAnimationState.RECOVERY,
		UiInteractionState.INPUT_LOCKED
	)
	return true


func complete_recovery(command: PendingBattleCommand) -> bool:
	if not _is_active_committed_command(command):
		return false
	pending_command = null
	_set_states(
		BattleFlowState.COMMAND_SELECT,
		CharacterAnimationState.BATTLE_IDLE,
		UiInteractionState.COMMAND_BUTTONS_ACTIVE
	)
	return true


func lock_for_outcome(victory: bool) -> void:
	pending_command = null
	_set_states(
		BattleFlowState.VICTORY if victory else BattleFlowState.DEFEAT,
		CharacterAnimationState.BATTLE_IDLE if victory
		else CharacterAnimationState.DEFEATED,
		UiInteractionState.INPUT_LOCKED
	)


func clear_pending_command() -> void:
	pending_command = null


func reset_to_command_select() -> void:
	pending_command = null
	_set_states(
		BattleFlowState.COMMAND_SELECT,
		CharacterAnimationState.BATTLE_IDLE,
		UiInteractionState.COMMAND_BUTTONS_ACTIVE
	)


func has_pending_command() -> bool:
	return pending_command != null


func get_pending_command() -> PendingBattleCommand:
	return pending_command


func is_token_active(token: int) -> bool:
	return (
		has_pending_command()
		and pending_command.is_committed
		and pending_command.commit_token == token
		and not pending_command.is_resolved
		and not _consumed_tokens.has(token)
	)


func is_token_consumed(token: int) -> bool:
	return _consumed_tokens.has(token)


## --- Block 9A off-turn interrupt stubs -------------------------------
## UPDATED Block 9D: these three methods are STILL always-false stubs and
## are STILL never called by any production code. What changed since
## Block 9A is begin_command() itself — it no longer rejects
## RequestSource.INTERRUPT_REQUEST unconditionally (see its
## `interrupt_authorized` parameter, added Block 9B). Do not read that as
## these stubs having become active: the real, and only, production path
## for an off-turn Ultimate is BattleManager calling
## `begin_command(..., interrupt_authorized = true)` directly from its own
## controlled safe-window-B processing
## (`_process_interrupt_queue_at_safe_window()` /
## `_begin_queued_ultimate()`), never through can_process_interrupt_now(),
## queue_ultimate_interrupt(), or begin_interrupt_request() below. Window A
## (mid-enemy-action interrupt) remains fully disabled as of Block 9D — if
## any of these three stubs is ever made to return something other than
## `false`, that is the signal a future block actually decided to build
## window A, not an incidental side effect.
##
## This controller models one pending command for one actor; it has no
## notion of enemy turns or which command belongs to which battle-wide
## turn. Real safe-window detection therefore cannot live here — it needs
## BattleManager-level state (whose turn it is, whether the enemy attack
## await chain is mid-flight) that this class does not have. See
## docs/battle_system_spec.md, "Safe interrupt window" for why this is a
## BattleManager-owned query, not a BattleCommandFlow-owned one.

## Always false through Block 9D. Real safe-window detection lives in
## BattleManager._process_interrupt_queue_at_safe_window(), not here — see
## the reason above. This stub exists so callers can be written against a
## stable name ahead of any future decision to move that logic here.
func can_process_interrupt_now() -> bool:
	return false


## Always false through Block 9D. No UltimateInterruptQueue is wired to
## this flow controller; queuing is BattleManager's responsibility (it
## owns the one production UltimateInterruptQueue instance directly, see
## `ultimate_interrupt_queue` in battle_manager.gd) — deliberately kept
## independent of BattleCommandFlow so the queue stays unit-testable
## without a live battle.
func queue_ultimate_interrupt(_request: UltimateInterruptRequest) -> bool:
	return false


## Always false through Block 9D. begin_command() is still the sole entry
## point for starting a pending command; as of Block 9B it can accept
## RequestSource.INTERRUPT_REQUEST, but only when the caller explicitly
## passes `interrupt_authorized = true`, and the only production caller
## that ever does is BattleManager's own safe-window-B processing. This
## stub documents an alternative future entry-point signature without
## opening a second real one now — reject reason
## `off_turn_interrupt_not_available` (see begin_command() below) is the
## actual production guard against any other caller bypassing the queue.
func begin_interrupt_request(
	_actor: Node,
	_action_id: StringName,
	_target_rule: int,
	_candidate_targets: Array[Node],
	_energy_cost: int
) -> bool:
	return false


func _validate_resources(command: PendingBattleCommand) -> String:
	if not _resource_validator.is_valid():
		return ""
	return str(_resource_validator.call(command))


func _commit_resources(command: PendingBattleCommand) -> bool:
	if not _resource_committer.is_valid():
		return true
	return bool(_resource_committer.call(command))


func _is_active_committed_command(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command == pending_command
		and command.is_committed
		and command.commit_token > 0
	)


func _ready_animation_for(command_type: int) -> int:
	match command_type:
		PendingBattleCommand.CommandType.BASIC_ATTACK:
			return CharacterAnimationState.BASIC_READY
		PendingBattleCommand.CommandType.SKILL:
			return CharacterAnimationState.SKILL_READY
		PendingBattleCommand.CommandType.ULTIMATE:
			return CharacterAnimationState.ULTIMATE_READY
	return CharacterAnimationState.BATTLE_IDLE


func _action_animation_for(command_type: int) -> int:
	match command_type:
		PendingBattleCommand.CommandType.BASIC_ATTACK:
			return CharacterAnimationState.BASIC_ACTION
		PendingBattleCommand.CommandType.SKILL:
			return CharacterAnimationState.SKILL_ACTION
		PendingBattleCommand.CommandType.ULTIMATE:
			return CharacterAnimationState.ULTIMATE_ACTION
	return CharacterAnimationState.BATTLE_IDLE


func _set_states(
	new_battle_state: int,
	new_animation_state: int,
	new_ui_state: int
) -> void:
	battle_state = new_battle_state
	animation_state = new_animation_state
	ui_state = new_ui_state
	flow_state_changed.emit(battle_state, animation_state, ui_state)


func _fail(command: PendingBattleCommand, reason: StringName) -> void:
	command_failed.emit(command, reason)


func _fail_and_clear(reason: StringName) -> void:
	var failed := pending_command
	pending_command = null
	_fail(failed, reason)
	_set_states(
		BattleFlowState.COMMAND_SELECT,
		CharacterAnimationState.BATTLE_IDLE,
		UiInteractionState.COMMAND_BUTTONS_ACTIVE
	)


func _fail_and_cancel(reason: StringName) -> void:
	var failed := pending_command
	if pending_command != null and not pending_command.is_committed:
		pending_command.cancel()
	pending_command = null
	_fail(failed, reason)
	_set_states(
		BattleFlowState.COMMAND_SELECT,
		CharacterAnimationState.BATTLE_IDLE,
		UiInteractionState.COMMAND_BUTTONS_ACTIVE
	)
