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
	auto_commit_on_target_selected: bool = false
) -> bool:
	if request_source == PendingBattleCommand.RequestSource.INTERRUPT_REQUEST:
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
