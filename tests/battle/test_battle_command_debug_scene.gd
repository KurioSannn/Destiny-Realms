extends Node

const DEBUG_SCENE := preload("res://scenes/battle/debug/battle_command_flow_debug.tscn")

var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := DEBUG_SCENE.instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var manager := scene.get_node("BattleManager") as BattleCommandFlowDebug
	manager.enemy_turn_enabled = false
	manager.recovery_hold_seconds = 0.01
	var flow := scene.get_node("CommandFlow") as BattleCommandFlow

	var initial_sp: int = manager.skill_points
	_check(manager.call("_begin_debug_command", PendingBattleCommand.CommandType.SKILL), "debug skill enters pending")
	_check(manager.skill_points == initial_sp, "debug pending does not spend SP")
	_check(manager.call("_cancel_pending_command"), "debug pending can cancel")
	_check(manager.skill_points == initial_sp, "debug cancel preserves SP")

	var initial_hp: int = manager.enemy.current_hp
	_check(manager.call("_begin_debug_command", PendingBattleCommand.CommandType.SKILL), "debug skill can be selected again")
	_check(manager.call("_confirm_pending_command"), "debug skill confirms")
	_check(manager.skill_points == initial_sp - 1, "debug confirm spends one SP")
	var completed := await _wait_for_state(flow, BattleCommandFlow.BattleFlowState.COMMAND_SELECT, 8.0)
	_check(completed, "debug skill returns through resolution and recovery")
	_check(manager.enemy.current_hp < initial_hp, "debug skill applies damage")
	_check(manager.skill_points == initial_sp - 1, "debug execution does not spend SP twice")

	manager.call("_fill_energy")
	var initial_energy: int = manager.ultimate_energy
	_check(manager.call("_begin_debug_command", PendingBattleCommand.CommandType.ULTIMATE), "debug ultimate enters pending on player turn")
	_check(manager.ultimate_energy == initial_energy, "pending ultimate preserves energy")
	_check(manager.call("_cancel_pending_command"), "pending ultimate can cancel")
	_check(manager.ultimate_energy == initial_energy, "cancelled ultimate preserves energy")

	if failures.is_empty():
		print("PASS: battle command debug scene integration")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _wait_for_state(flow: BattleCommandFlow, expected: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if flow.battle_state == expected and not flow.has_pending_command():
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
