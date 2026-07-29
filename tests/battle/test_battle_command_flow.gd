extends SceneTree

class FakeCombatant:
	extends Node
	var hp := 100
	func is_defeated() -> bool:
		return hp <= 0

var failures: Array[String] = []
var skill_points := 3
var energy := 100
var commit_count := 0
var flow: BattleCommandFlow
var actor: FakeCombatant
var target_a: FakeCombatant
var target_b: FakeCombatant

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flow = BattleCommandFlow.new()
	root.add_child(flow)
	actor = _combatant("Actor")
	target_a = _combatant("TargetA")
	target_b = _combatant("TargetB")
	flow.configure_resource_callbacks(_validate_resources, _commit_resources)
	_test_cancel_is_side_effect_free()
	_test_target_switch_and_commit_boundary()
	_test_duplicate_execution_is_rejected()
	_test_invalid_target_is_revalidated()
	_test_skill_and_ultimate_costs()
	_test_insufficient_resource_rejects_commit()
	_test_off_turn_ultimate_is_rejected()
	_test_explicit_state_progression()
	_test_outcomes_lock_input()
	if failures.is_empty():
		print("PASS: battle command flow contract")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_cancel_is_side_effect_free() -> void:
	var before_sp := skill_points
	var before_energy := energy
	var before_commits := commit_count
	_check(_begin(PendingBattleCommand.CommandType.SKILL, 1, 0), "skill enters pending")
	_check(flow.cancel_pending_command(), "pending skill can cancel")
	_check(skill_points == before_sp, "cancel does not spend SP")
	_check(energy == before_energy, "cancel does not spend energy")
	_check(commit_count == before_commits, "cancel does not commit")
	_check(flow.battle_state == BattleCommandFlow.BattleFlowState.COMMAND_SELECT, "cancel restores command select")

func _test_target_switch_and_commit_boundary() -> void:
	var before_sp := skill_points
	_check(_begin(PendingBattleCommand.CommandType.SKILL, 1, 0), "skill can begin")
	_check(flow.set_pending_target(target_b), "target can switch while pending")
	_check(flow.get_pending_command().selected_targets[0] == target_b, "switched target is retained")
	_check(skill_points == before_sp, "target selection does not spend SP")
	_check(flow.confirm_pending_command(), "confirm validates and commits")
	_check(skill_points == before_sp - 1, "confirm spends SP exactly once")
	_check(commit_count == 1, "first confirm creates one commit")
	_check(not flow.confirm_pending_command(), "committed command cannot confirm twice")
	_check(skill_points == before_sp - 1, "duplicate confirm does not spend SP")

func _test_duplicate_execution_is_rejected() -> void:
	var command := flow.get_pending_command()
	_check(flow.execute_committed_command(), "committed command executes once")
	_check(not flow.execute_committed_command(), "same command cannot begin execution twice")
	_check(flow.begin_resolution(command), "command enters resolution")
	_check(flow.resolve_committed_command(command), "command resolves once")
	_check(not flow.resolve_committed_command(command), "same token cannot resolve twice")
	_check(flow.is_token_consumed(command.commit_token), "resolved token is consumed")
	_check(flow.begin_recovery(command), "resolved command enters recovery")
	_check(flow.complete_recovery(command), "recovery returns to command select")

func _test_invalid_target_is_revalidated() -> void:
	var before_sp := skill_points
	_check(_begin(PendingBattleCommand.CommandType.SKILL, 1, 0), "second skill can begin")
	target_a.hp = 0
	_check(not flow.confirm_pending_command(), "defeated target fails confirm revalidation")
	_check(skill_points == before_sp, "failed revalidation does not spend SP")
	_check(not flow.has_pending_command(), "failed revalidation clears pending command")
	target_a.hp = 100

func _test_skill_and_ultimate_costs() -> void:
	var before_sp := skill_points
	_check(_begin(PendingBattleCommand.CommandType.SKILL, 1, 0), "skill pending for resource test")
	_check(flow.confirm_pending_command(), "skill resource commit succeeds")
	_check(skill_points == before_sp - 1, "skill cost is committed once")
	_complete_active_command()
	var before_energy := energy
	_check(_begin(PendingBattleCommand.CommandType.ULTIMATE, 0, 100), "ultimate pending on player turn")
	_check(flow.confirm_pending_command(), "ultimate resource commit succeeds")
	_check(energy == before_energy - 100, "ultimate energy is committed once")
	_complete_active_command()

func _test_off_turn_ultimate_is_rejected() -> void:
	var before_energy := energy
	var targets: Array[Node] = [target_a, target_b]
	_check(not flow.begin_command(actor, PendingBattleCommand.CommandType.ULTIMATE, &"ultimate", PendingBattleCommand.TargetRule.SINGLE_ENEMY, targets, 0, 100, 1, BattleCommandFlow.BattleFlowState.COMMAND_SELECT, PendingBattleCommand.RequestSource.INTERRUPT_REQUEST), "off-turn ultimate request is rejected")
	_check(energy == before_energy, "rejected off-turn request does not spend energy")
	_check(not flow.has_pending_command(), "rejected off-turn request creates no pending command")

func _test_insufficient_resource_rejects_commit() -> void:
	var before_energy := energy
	_check(_begin(PendingBattleCommand.CommandType.ULTIMATE, 0, before_energy + 1), "unaffordable ultimate may be previewed")
	_check(not flow.confirm_pending_command(), "insufficient energy rejects commit")
	_check(energy == before_energy, "failed resource commit preserves energy")
	_check(not flow.has_pending_command(), "failed resource commit clears pending command")

func _test_explicit_state_progression() -> void:
	_check(_begin(PendingBattleCommand.CommandType.BASIC_ATTACK, 0, 0), "basic enters ready flow")
	_check(flow.battle_state == BattleCommandFlow.BattleFlowState.TARGET_SELECT, "single target command enters target select")
	_check(flow.animation_state == BattleCommandFlow.CharacterAnimationState.BASIC_READY, "basic uses explicit ready animation state")
	_check(flow.ui_state == BattleCommandFlow.UiInteractionState.TARGET_CURSOR_ACTIVE, "target cursor is explicit")
	_check(flow.confirm_pending_command(), "basic confirms")
	_check(flow.battle_state == BattleCommandFlow.BattleFlowState.ACTION_EXECUTION, "commit locks action execution")
	_check(flow.ui_state == BattleCommandFlow.UiInteractionState.INPUT_LOCKED, "execution locks input")
	_complete_active_command()

func _test_outcomes_lock_input() -> void:
	flow.lock_for_outcome(true)
	_check(flow.battle_state == BattleCommandFlow.BattleFlowState.VICTORY, "victory is explicit")
	_check(flow.ui_state == BattleCommandFlow.UiInteractionState.INPUT_LOCKED, "victory locks input")
	flow.battle_state = BattleCommandFlow.BattleFlowState.COMMAND_SELECT
	flow.lock_for_outcome(false)
	_check(flow.battle_state == BattleCommandFlow.BattleFlowState.DEFEAT, "defeat is explicit")
	_check(flow.ui_state == BattleCommandFlow.UiInteractionState.INPUT_LOCKED, "defeat locks input")

func _begin(command_type: int, sp_cost: int, energy_cost: int) -> bool:
	var targets: Array[Node] = [target_a, target_b]
	return flow.begin_command(actor, command_type, &"test_action", PendingBattleCommand.TargetRule.SINGLE_ENEMY, targets, sp_cost, energy_cost)

func _complete_active_command() -> void:
	var command := flow.get_pending_command()
	_check(flow.execute_committed_command(), "active command starts execution")
	_check(flow.begin_resolution(command), "active command begins resolution")
	_check(flow.resolve_committed_command(command), "active command resolves")
	_check(flow.begin_recovery(command), "active command begins recovery")
	_check(flow.complete_recovery(command), "active command completes recovery")

func _validate_resources(command: PendingBattleCommand) -> String:
	if skill_points < command.skill_point_cost:
		return "insufficient_skill_points"
	if energy < command.energy_cost:
		return "insufficient_energy"
	return ""

func _commit_resources(command: PendingBattleCommand) -> bool:
	if not _validate_resources(command).is_empty():
		return false
	skill_points -= command.skill_point_cost
	energy -= command.energy_cost
	commit_count += 1
	return true

func _combatant(node_name: String) -> FakeCombatant:
	var combatant := FakeCombatant.new()
	combatant.name = node_name
	root.add_child(combatant)
	return combatant

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
