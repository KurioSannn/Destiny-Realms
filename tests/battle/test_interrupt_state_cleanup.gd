extends Node

## Block 9D: interrupt state cleanup, resume-token single-use guarantee,
## resume policy stabilization, bridge/state hardening, safe window B
## hardening, and window-A-stub inertness. See docs/battle_system_spec.md,
## "Block 9D implementation status". This suite deliberately does not
## re-prove what tests/battle/test_ultimate_off_turn_interrupt.gd (Block
## 9B) and tests/battle/test_enemy_attack_guard_chain.gd (Block 9C) already
## cover -- it targets the specific gaps Block 9D closed.

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_confirm_clears_active_interrupt_request()
	await _test_cancel_clears_active_interrupt_request()
	await _test_stale_discard_never_sets_active_interrupt_request()
	await _test_interrupt_resume_token_cannot_be_reused()
	await _test_queue_clears_on_win_including_resume_token_history()
	await _test_queue_clears_on_lose()
	await _test_queue_clears_on_exit_tree()
	await _test_victory_from_queued_ultimate_does_not_also_resume_player_turn()
	await _test_direct_begin_command_interrupt_request_rejected_without_authorization()
	await _test_external_request_during_interrupt_processing_rejected()
	await _test_queue_not_processed_while_enemy_action_in_progress()
	await _test_queue_not_processed_while_active_enemy_attack_token_valid()
	await _test_interrupt_stubs_remain_inert()

	if failures.is_empty():
		print("PASS: interrupt state cleanup")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_confirm_clears_active_interrupt_request() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	manager.request_off_turn_ultimate(manager.player)

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)
	_check(manager.active_interrupt_request != null, "active_interrupt_request is set while ready idle is showing")

	manager.call("_confirm_ultimate_command")

	_check(
		await _wait_for_interrupt_processing_cleared(manager, 40.0),
		"queued Ultimate finishes"
	)
	_check(manager.active_interrupt_request == null, "confirm clears active_interrupt_request")
	_check(not manager.is_processing_interrupt_queue, "confirm clears is_processing_interrupt_queue")

	await _free_battle(battle)


func _test_cancel_clears_active_interrupt_request() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	manager.request_off_turn_ultimate(manager.player)

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)

	manager.call("_cancel_ultimate_command")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0),
		"cancel returns to player turn"
	)
	_check(manager.active_interrupt_request == null, "cancel clears active_interrupt_request")
	_check(not manager.is_processing_interrupt_queue, "cancel clears is_processing_interrupt_queue")

	await _free_battle(battle)


func _test_stale_discard_never_sets_active_interrupt_request() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	manager.ultimate_energy = 0
	manager.call("_refresh_energy_ui")

	var processed := bool(manager.call("_process_interrupt_queue_at_safe_window", &"after_enemy_recovery"))

	_check(not processed, "a stale (Energy dropped) request is not processed")
	_check(manager.active_interrupt_request == null, "a discarded stale request never becomes the active interrupt request")
	_check(not manager.is_processing_interrupt_queue, "discarding a stale request leaves processing flag clear")

	await _free_battle(battle)


func _test_interrupt_resume_token_cannot_be_reused() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var token := 5
	var first := bool(manager.call("_consume_interrupt_resume_token", token))
	var second := bool(manager.call("_consume_interrupt_resume_token", token))
	var zero_token := bool(manager.call("_consume_interrupt_resume_token", 0))

	_check(first, "an unconsumed resume token is consumed successfully the first time")
	_check(not second, "the same resume token cannot be consumed a second time")
	_check(not zero_token, "token 0 (never issued) is never treated as consumable")

	await _free_battle(battle)


func _test_queue_clears_on_win_including_resume_token_history() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	manager.call("_consume_interrupt_resume_token", 42)
	_check(manager.ultimate_interrupt_queue.size() == 1, "request is queued before victory")

	manager.call("_win", "test victory")
	await _idle_frames(1)

	_check(manager.ultimate_interrupt_queue.is_empty(), "victory clears the interrupt queue")
	_check(not manager.is_processing_interrupt_queue, "victory clears the processing flag")
	_check(manager.active_interrupt_request == null, "victory clears active_interrupt_request")
	_check(
		bool(manager.call("_consume_interrupt_resume_token", 42)),
		"victory clears resume-token consumption history, so a fresh token 42 can be consumed again after reset"
	)

	await _free_battle(battle)


func _test_queue_clears_on_lose() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	_check(manager.ultimate_interrupt_queue.size() == 1, "request is queued before defeat")

	manager.call("_lose", "test defeat")
	await _idle_frames(1)

	_check(manager.ultimate_interrupt_queue.is_empty(), "defeat clears the interrupt queue")
	_check(not manager.is_processing_interrupt_queue, "defeat clears the processing flag")
	_check(manager.active_interrupt_request == null, "defeat clears active_interrupt_request")

	await _free_battle(battle)


func _test_queue_clears_on_exit_tree() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	_check(manager.ultimate_interrupt_queue.size() == 1, "request is queued before scene exit")

	manager.call("_exit_tree")

	_check(manager.ultimate_interrupt_queue.is_empty(), "_exit_tree clears the interrupt queue")
	_check(not manager.is_processing_interrupt_queue, "_exit_tree clears the processing flag")
	_check(manager.active_interrupt_request == null, "_exit_tree clears active_interrupt_request")

	await _free_battle(battle)


## A queued Ultimate that defeats the enemy must win the battle exactly
## once and must never also resume a normal player turn afterward.
func _test_victory_from_queued_ultimate_does_not_also_resume_player_turn() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.enemy.current_hp = mini(manager.enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)

	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	manager.request_off_turn_ultimate(manager.player)

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)

	manager.call("_confirm_ultimate_command")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.WIN, 40.0),
		"a lethal queued Ultimate reaches the WIN state"
	)
	_check(not manager.is_processing_interrupt_queue, "victory from a queued Ultimate clears the processing flag")
	_check(manager.active_interrupt_request == null, "victory from a queued Ultimate clears active_interrupt_request")
	_check(
		manager.state == BattleManager.BattleState.WIN,
		"state remains WIN and is not overwritten back to PLAYER_TURN by a stray resume"
	)

	await _free_battle(battle)


func _test_direct_begin_command_interrupt_request_rejected_without_authorization() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var flow: BattleCommandFlow = manager.ultimate_command_adapter.flow

	var targets: Array[Node] = [manager.enemy]
	var accepted := flow.begin_command(
		manager.player,
		PendingBattleCommand.CommandType.ULTIMATE,
		&"octagram_fragment",
		PendingBattleCommand.TargetRule.SINGLE_ENEMY,
		targets,
		0,
		BattleManager.MAX_ULTIMATE_ENERGY,
		0,
		BattleCommandFlow.BattleFlowState.COMMAND_SELECT,
		PendingBattleCommand.RequestSource.INTERRUPT_REQUEST
	)

	_check(
		not accepted,
		"begin_command(INTERRUPT_REQUEST) without interrupt_authorized=true is rejected, even called directly"
	)
	_check(not flow.has_pending_command(), "a rejected direct interrupt call leaves no pending command behind")

	await _free_battle(battle)


func _test_external_request_during_interrupt_processing_rejected() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	manager.request_off_turn_ultimate(manager.player)

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)
	_check(manager.is_processing_interrupt_queue, "processing flag is set while the queued Ultimate is pending")

	var second_request := bool(manager.request_off_turn_ultimate(manager.enemy))

	_check(
		not second_request,
		"a new off-turn request made while interrupt processing is already active is rejected"
	)
	_check(manager.ultimate_interrupt_queue.is_empty(), "the rejected concurrent request never enters the queue")

	manager.call("_cancel_ultimate_command")
	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0)
	await _free_battle(battle)


func _test_queue_not_processed_while_enemy_action_in_progress() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	manager.enemy_action_in_progress = true

	var processed := bool(manager.call("_process_interrupt_queue_at_safe_window", &"after_enemy_recovery"))

	_check(not processed, "the queue is not processed while enemy_action_in_progress is true")
	_check(manager.ultimate_interrupt_queue.size() == 1, "the request stays queued, untouched, while blocked")

	manager.enemy_action_in_progress = false
	await _free_battle(battle)


func _test_queue_not_processed_while_active_enemy_attack_token_valid() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	manager.active_enemy_attack_token = 1

	var processed := bool(manager.call("_process_interrupt_queue_at_safe_window", &"after_enemy_recovery"))

	_check(not processed, "the queue is not processed while active_enemy_attack_token is still valid")
	_check(manager.ultimate_interrupt_queue.size() == 1, "the request stays queued, untouched, while blocked")

	manager.active_enemy_attack_token = 0
	await _free_battle(battle)


## Confirms Block 9A's window-A stub surface is still fully inert as of
## Block 9D -- a false-by-default guard against any future block quietly
## depending on one of these without a deliberate window A decision.
func _test_interrupt_stubs_remain_inert() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var flow: BattleCommandFlow = manager.ultimate_command_adapter.flow

	_check(not flow.can_process_interrupt_now(), "can_process_interrupt_now() is still always false")
	_check(
		not flow.queue_ultimate_interrupt(null),
		"queue_ultimate_interrupt() is still always false"
	)
	var empty_targets: Array[Node] = []
	_check(
		not flow.begin_interrupt_request(manager.player, &"octagram_fragment", PendingBattleCommand.TargetRule.SINGLE_ENEMY, empty_targets, 0),
		"begin_interrupt_request() is still always false"
	)

	await _free_battle(battle)


func _make_battle() -> Dictionary:
	WorldProgress.reset_story()
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.use_new_basic_command_flow = true
	manager.use_new_skill_command_flow = true
	manager.use_new_ultimate_command_flow = true
	get_tree().root.add_child(battle)
	await _idle_frames(8)
	return {
		"battle": battle,
		"manager": manager,
	}


func _free_battle(battle: Node) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
	await _idle_frames(2)
	WorldProgress.reset_story()


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


## Block 9F: requesting immediately after _begin_enemy_turn() (1 frame
## later) now lands before safe window A1's check (see
## docs/battle_system_spec.md, "Block 9F implementation status"), so it
## would be processed there instead of at window B. This suite's requests
## are deliberately about window B specifically (see
## test_window_a1_ultimate_interrupt.gd for A1-specific timing), so they
## wait until enemy_action_in_progress is true (meaning A1 already ran,
## found nothing, and _enemy_attack() has now genuinely started) before
## requesting, guaranteeing the request is only picked up later at
## window B.
func _wait_past_window_a1(manager: BattleManager, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or manager.enemy_action_in_progress:
			return
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _wait_for_pending_ultimate(manager: BattleManager, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager._has_pending_ultimate_command():
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_interrupt_processing_cleared(manager: BattleManager, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if not manager.is_processing_interrupt_queue:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_state(manager: BattleManager, expected_state: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.state == expected_state:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
