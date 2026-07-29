extends RefCounted
class_name PendingBattleCommand

enum CommandType {
	BASIC_ATTACK,
	SKILL,
	ULTIMATE,
}

enum TargetRule {
	SINGLE_ENEMY,
	ALL_ENEMIES,
	SELF,
	SINGLE_ALLY,
	ALL_ALLIES,
	NO_TARGET,
}

enum RequestSource {
	TURN_COMMAND,
	INTERRUPT_REQUEST,
}

var command_id: int = 0
var actor: Node
var command_type: int = CommandType.BASIC_ATTACK
var action_id: StringName = &""
var target_rule: int = TargetRule.SINGLE_ENEMY
var candidate_targets: Array[Node] = []
var selected_targets: Array[Node] = []
var skill_point_cost: int = 0
var energy_cost: int = 0
var source_turn: int = 0
var source_state: int = 0
var request_source: int = RequestSource.TURN_COMMAND
var is_confirmed: bool = false
var is_committed: bool = false
var is_cancelled: bool = false
var is_resolved: bool = false
var execution_started: bool = false
var commit_token: int = 0
var sequence_index: int = 0
var created_at_msec: int = 0


func _init(
	new_command_id: int,
	new_actor: Node,
	new_command_type: int,
	new_action_id: StringName,
	new_target_rule: int,
	new_candidate_targets: Array[Node],
	new_skill_point_cost: int,
	new_energy_cost: int,
	new_source_turn: int,
	new_source_state: int,
	new_request_source: int,
	new_sequence_index: int
) -> void:
	command_id = new_command_id
	actor = new_actor
	command_type = new_command_type
	action_id = new_action_id
	target_rule = new_target_rule
	candidate_targets.assign(new_candidate_targets)
	skill_point_cost = maxi(new_skill_point_cost, 0)
	energy_cost = maxi(new_energy_cost, 0)
	source_turn = new_source_turn
	source_state = new_source_state
	request_source = new_request_source
	sequence_index = new_sequence_index
	created_at_msec = Time.get_ticks_msec()


func has_valid_actor() -> bool:
	return is_instance_valid(actor) and not _node_is_defeated(actor)


func refresh_candidates() -> void:
	candidate_targets = candidate_targets.filter(_is_valid_target)
	selected_targets = selected_targets.filter(_is_valid_target)


func select_target(target: Node) -> bool:
	if is_committed or is_cancelled or not _is_valid_target(target):
		return false
	if not candidate_targets.has(target):
		return false

	selected_targets = [target]
	return true


func select_targets(targets: Array[Node]) -> bool:
	if is_committed or is_cancelled:
		return false

	var filtered: Array[Node] = []
	for target in targets:
		if _is_valid_target(target) and candidate_targets.has(target):
			filtered.append(target)
	if filtered.is_empty() and requires_target():
		return false

	selected_targets = filtered
	return true


func requires_target() -> bool:
	return target_rule not in [
		TargetRule.NO_TARGET,
		TargetRule.SELF,
	]


func has_required_targets() -> bool:
	match target_rule:
		TargetRule.SINGLE_ENEMY, TargetRule.SINGLE_ALLY:
			return selected_targets.size() == 1 and _is_valid_target(selected_targets[0])
		TargetRule.ALL_ENEMIES, TargetRule.ALL_ALLIES:
			return not candidate_targets.is_empty()
		TargetRule.SELF:
			return has_valid_actor()
		TargetRule.NO_TARGET:
			return true
	return false


func finalize_automatic_targets() -> void:
	refresh_candidates()
	match target_rule:
		TargetRule.ALL_ENEMIES, TargetRule.ALL_ALLIES:
			selected_targets.assign(candidate_targets)
		TargetRule.SELF:
			selected_targets = [actor] if has_valid_actor() else []
		TargetRule.NO_TARGET:
			selected_targets.clear()


func cancel() -> bool:
	if is_committed or is_cancelled:
		return false
	is_cancelled = true
	selected_targets.clear()
	return true


func _is_valid_target(target: Node) -> bool:
	return is_instance_valid(target) and not _node_is_defeated(target)


func _node_is_defeated(node: Node) -> bool:
	return node.has_method("is_defeated") and bool(node.call("is_defeated"))

