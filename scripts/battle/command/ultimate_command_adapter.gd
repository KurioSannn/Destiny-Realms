extends Node
class_name UltimateCommandAdapter

signal ultimate_ready(command)
signal target_changed(command, targets)
signal ultimate_cancelled(command)
signal ultimate_committed(command)
signal ultimate_failed(command, reason)
signal flow_state_changed(battle_state, animation_state, ui_state)

const PendingCommand := preload("res://scripts/battle/command/pending_battle_command.gd")
const CommandFlow := preload("res://scripts/battle/command/battle_command_flow.gd")

var flow: BattleCommandFlow
var actor: Node
var target_provider: Callable
var resource_validator: Callable
var resource_committer: Callable


func configure(
	new_actor: Node,
	new_target_provider: Callable,
	new_resource_validator: Callable,
	new_resource_committer: Callable
) -> void:
	actor = new_actor
	target_provider = new_target_provider
	resource_validator = new_resource_validator
	resource_committer = new_resource_committer
	if flow == null:
		flow = CommandFlow.new()
		flow.name = "UltimateCommandFlow"
		add_child(flow)
		_connect_flow_signals()
	flow.configure_resource_callbacks(_validate_resources, _commit_resources)
	reset()


func reset() -> void:
	if flow == null:
		return
	flow.reset_to_command_select()


## Block 9E: ready idle + target selection are kept (requires_ready_idle =
## true), but there is no confirm/cancel panel step in production anymore
## (requires_confirm = false — moot here since Ultimate always requires a
## target, but set for clarity). auto_commit_on_target_selected = true
## makes clicking a valid target commit immediately; auto_commit_on_begin
## = false stops begin_command() from also auto-committing the instant
## ready idle opens against a single live enemy, so ready idle is always
## visible (both on-turn and queued/off-turn) and committing always needs
## one more explicit input (pressing Ultimate again, or clicking the
## target) — see BattleManager._on_ultimate_pressed().
func begin_ultimate(
	action_id: StringName,
	target_rule: int,
	energy_cost: int,
	source_turn: int = 0,
	request_source: int = PendingCommand.RequestSource.TURN_COMMAND,
	interrupt_authorized: bool = false
) -> bool:
	if flow == null:
		return false
	var targets := _get_candidate_targets()
	return flow.begin_command(
		actor,
		PendingCommand.CommandType.ULTIMATE,
		action_id,
		target_rule,
		targets,
		0,
		energy_cost,
		source_turn,
		CommandFlow.BattleFlowState.COMMAND_SELECT,
		request_source,
		true,
		false,
		true,
		interrupt_authorized,
		false
	)


func confirm_ultimate() -> bool:
	return flow != null and flow.confirm_pending_command()


func cancel_ultimate() -> bool:
	return flow != null and flow.cancel_pending_command()


func select_target(target: Node) -> bool:
	return flow != null and flow.set_pending_target(target)


func execute_committed_command() -> bool:
	return flow != null and flow.execute_committed_command()


func begin_resolution(command: PendingBattleCommand) -> bool:
	return flow != null and flow.begin_resolution(command)


func resolve_committed_command(command: PendingBattleCommand) -> bool:
	return flow != null and flow.resolve_committed_command(command)


func begin_recovery(command: PendingBattleCommand) -> bool:
	return flow != null and flow.begin_recovery(command)


func complete_recovery(command: PendingBattleCommand) -> bool:
	return flow != null and flow.complete_recovery(command)


func lock_for_outcome(victory: bool) -> void:
	if flow != null:
		flow.lock_for_outcome(victory)


func fail_ultimate(
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	ultimate_failed.emit(command, reason)


func has_pending_ultimate() -> bool:
	return (
		flow != null
		and flow.has_pending_command()
		and flow.get_pending_command().command_type == PendingCommand.CommandType.ULTIMATE
	)


func get_pending_command() -> PendingBattleCommand:
	if flow == null:
		return null
	return flow.get_pending_command()


func is_token_active(token: int) -> bool:
	return flow != null and flow.is_token_active(token)


func is_token_consumed(token: int) -> bool:
	return flow != null and flow.is_token_consumed(token)


func _connect_flow_signals() -> void:
	flow.command_ready.connect(_on_command_ready)
	flow.target_changed.connect(_on_target_changed)
	flow.command_cancelled.connect(_on_command_cancelled)
	flow.command_committed.connect(_on_command_committed)
	flow.command_failed.connect(_on_command_failed)
	flow.flow_state_changed.connect(_on_flow_state_changed)


func _on_command_ready(command: PendingBattleCommand) -> void:
	ultimate_ready.emit(command)


func _on_target_changed(
	command: PendingBattleCommand,
	targets: Array
) -> void:
	target_changed.emit(command, targets)


func _on_command_cancelled(command: PendingBattleCommand) -> void:
	ultimate_cancelled.emit(command)


func _on_command_committed(command: PendingBattleCommand) -> void:
	ultimate_committed.emit(command)


func _on_command_failed(
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	ultimate_failed.emit(command, reason)


func _on_flow_state_changed(
	battle_state: int,
	animation_state: int,
	ui_state: int
) -> void:
	flow_state_changed.emit(battle_state, animation_state, ui_state)


func _get_candidate_targets() -> Array[Node]:
	var targets: Array[Node] = []
	if target_provider.is_valid():
		targets.assign(target_provider.call())
	return targets


func _validate_resources(command: PendingBattleCommand) -> String:
	if resource_validator.is_valid():
		return str(resource_validator.call(command))
	return ""


func _commit_resources(command: PendingBattleCommand) -> bool:
	if resource_committer.is_valid():
		return bool(resource_committer.call(command))
	return true
