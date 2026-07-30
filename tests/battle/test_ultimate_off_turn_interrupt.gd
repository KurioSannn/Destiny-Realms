extends Node

## Block 9B: off-turn Ultimate interrupt queue integration, safe window B
## only. See docs/battle_system_spec.md, "Block 9B implementation status".

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_off_turn_request_enqueues_without_side_effects()
	await _test_duplicate_off_turn_request_rejected()
	await _test_insufficient_energy_off_turn_request_rejected()
	await _test_dead_actor_off_turn_request_rejected()
	await _test_queue_clears_on_victory()
	await _test_stale_energy_request_discarded_at_safe_window()
	await _test_stale_actor_request_discarded_at_safe_window()
	await _test_safe_window_b_cancel_returns_to_player_turn()
	await _test_safe_window_b_confirm_full_flow()
	await _test_bandit_safe_window_b_cancel_returns_to_player_turn()

	if failures.is_empty():
		print("PASS: ultimate off-turn interrupt (safe window B)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_off_turn_request_enqueues_without_side_effects() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN

	var accepted := bool(manager.request_off_turn_ultimate(manager.player))

	_check(accepted, "valid off-turn request is accepted")
	_check(manager.ultimate_interrupt_queue.size() == 1, "accepted request enters the queue")
	_check(
		manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY,
		"off-turn request does not spend Energy"
	)
	_check(
		manager.state == BattleManager.BattleState.ENEMY_TURN,
		"off-turn request does not change battle state"
	)
	_check(not manager._has_pending_ultimate_command(), "off-turn request does not start ready idle")
	_check(
		manager.active_ultimate_command_token == 0,
		"off-turn request does not start a cut-in/commit"
	)

	await _free_battle(battle)


func _test_duplicate_off_turn_request_rejected() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN

	var first := bool(manager.request_off_turn_ultimate(manager.player))
	var second := bool(manager.request_off_turn_ultimate(manager.player))

	_check(first, "first off-turn request is accepted")
	_check(not second, "duplicate off-turn request for the same actor is rejected")
	_check(manager.ultimate_interrupt_queue.size() == 1, "duplicate request does not enter the queue")

	await _free_battle(battle)


func _test_insufficient_energy_off_turn_request_rejected() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY - 1
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN

	var accepted := bool(manager.request_off_turn_ultimate(manager.player))

	_check(not accepted, "insufficient Energy off-turn request is rejected")
	_check(manager.ultimate_interrupt_queue.is_empty(), "rejected request does not enter the queue")
	_check(
		manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY - 1,
		"rejected request does not mutate Energy"
	)

	await _free_battle(battle)


func _test_dead_actor_off_turn_request_rejected() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.player.current_hp = 0

	var accepted := bool(manager.request_off_turn_ultimate(manager.player))

	_check(not accepted, "dead actor off-turn request is rejected")
	_check(manager.ultimate_interrupt_queue.is_empty(), "dead actor request does not enter the queue")

	await _free_battle(battle)


func _test_queue_clears_on_victory() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	_check(manager.ultimate_interrupt_queue.size() == 1, "request is queued before victory")

	manager.call("_win", "test victory")
	await _idle_frames(1)

	_check(manager.ultimate_interrupt_queue.is_empty(), "victory clears the interrupt queue")
	_check(not manager.is_processing_interrupt_queue, "victory clears the processing flag")

	await _free_battle(battle)


func _test_stale_energy_request_discarded_at_safe_window() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	_check(manager.ultimate_interrupt_queue.size() == 1, "request is queued while Energy is still full")

	manager.ultimate_energy = 0
	manager.call("_refresh_energy_ui")

	var processed := bool(manager.call("_process_interrupt_queue_at_safe_window", &"after_enemy_recovery"))

	_check(not processed, "a request that went stale (Energy dropped) is not processed")
	_check(manager.ultimate_interrupt_queue.is_empty(), "stale request is discarded, not left queued")
	_check(manager.ultimate_energy == 0, "discarding a stale request does not change Energy")
	_check(not manager.is_processing_interrupt_queue, "discarding a stale request leaves processing flag clear")

	await _free_battle(battle)


func _test_stale_actor_request_discarded_at_safe_window() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.request_off_turn_ultimate(manager.player)
	_check(manager.ultimate_interrupt_queue.size() == 1, "request is queued while the actor is alive")

	manager.player.current_hp = 0

	var processed := bool(manager.call("_process_interrupt_queue_at_safe_window", &"after_enemy_recovery"))

	_check(not processed, "a request whose actor died before the safe window is not processed")
	_check(manager.ultimate_interrupt_queue.is_empty(), "stale actor request is discarded, not left queued")

	manager.player.current_hp = manager.player.max_hp
	await _free_battle(battle)


func _test_safe_window_b_cancel_returns_to_player_turn() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_enemy_hp := manager.enemy.current_hp

	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	_check(
		bool(manager.request_off_turn_ultimate(manager.player)),
		"off-turn request is accepted while the enemy turn is in progress"
	)

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)
	_check(manager.is_processing_interrupt_queue, "processing flag is set while the queued Ultimate is pending")
	_check(
		manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY,
		"Energy is still untouched once the queued Ultimate reaches ready idle"
	)

	manager.call("_cancel_ultimate_command")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0),
		"cancelling the queued Ultimate returns to player turn"
	)
	_check(
		manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY,
		"cancelling the queued Ultimate does not spend Energy"
	)
	_check(manager.enemy.current_hp == initial_enemy_hp, "cancelling the queued Ultimate deals no damage")
	_check(not manager.is_processing_interrupt_queue, "cancel clears the processing flag")
	_check(manager.ultimate_interrupt_queue.is_empty(), "cancel leaves no request behind in the queue")

	await _free_battle(battle)


func _test_safe_window_b_confirm_full_flow() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var counts := {
		"commit": 0,
		"execution": 0,
		"resolution": 0,
	}
	var flow: BattleCommandFlow = manager.ultimate_command_adapter.flow
	flow.command_committed.connect(func(_command) -> void:
		counts["commit"] = int(counts["commit"]) + 1
	)
	flow.command_execution_started.connect(func(_command) -> void:
		counts["execution"] = int(counts["execution"]) + 1
	)
	flow.command_resolved.connect(func(_command) -> void:
		counts["resolution"] = int(counts["resolution"]) + 1
	)

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_player_hp := manager.player.current_hp
	var initial_enemy_hp := manager.enemy.current_hp
	var expected_enemy_hp := initial_enemy_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	_check(
		bool(manager.request_off_turn_ultimate(manager.player)),
		"off-turn request is accepted while the enemy turn is in progress"
	)

	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 5.0),
		"enemy attack still completes normally while an off-turn request is queued"
	)
	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle only after enemy recovery"
	)
	_check(
		manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY,
		"Energy is still untouched once the queued Ultimate reaches ready idle"
	)
	_check(
		manager.state == BattleManager.BattleState.PLAYER_TURN,
		"safe window B sets state to PLAYER_TURN before the queued Ultimate begins"
	)

	manager.call("_confirm_ultimate_command")

	_check(
		await _wait_for_interrupt_processing_cleared(manager, 40.0),
		"queued Ultimate finishes (confirm -> commit -> cut-in -> damage -> recovery)"
	)
	_check(int(counts["commit"]) == 1, "queued Ultimate commits exactly once")
	_check(int(counts["execution"]) == 1, "queued Ultimate executes exactly once")
	_check(int(counts["resolution"]) == 1, "queued Ultimate resolves exactly once")
	_check(manager.enemy.current_hp == expected_enemy_hp, "queued Ultimate deals damage exactly once")
	_check(manager.ultimate_energy == 0, "queued Ultimate spends Energy exactly once, at commit")
	_check(
		manager.state == BattleManager.BattleState.PLAYER_TURN,
		"battle returns to a normal player turn after the queued Ultimate finishes"
	)
	_check(manager.active_ultimate_command_token == 0, "no Ultimate token remains active after finishing")
	_check(manager.ultimate_interrupt_queue.is_empty(), "queue is empty after the request is consumed")

	await _free_battle(battle)


func _test_bandit_safe_window_b_cancel_returns_to_player_turn() -> void:
	var fixture := await _make_battle(true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	_check(manager.is_bandit_encounter, "bandit encounter configuration still loads")
	_check(manager.enemy.combatant_name == "Bandit Captain", "bandit target defaults to captain")

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_enemy_hp := manager.enemy.current_hp

	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	_check(
		bool(manager.request_off_turn_ultimate(manager.player)),
		"off-turn request is accepted during a Bandit Captain enemy turn"
	)
	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after Bandit Captain's recovery"
	)

	manager.call("_cancel_ultimate_command")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0),
		"cancelling the queued Ultimate returns to player turn against Bandit Captain"
	)
	_check(manager.enemy.current_hp == initial_enemy_hp, "cancelling deals no damage to Bandit Captain")
	_check(
		manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY,
		"cancelling does not spend Energy against Bandit Captain"
	)

	await _free_battle(battle)


func _make_battle(bandit: bool) -> Dictionary:
	WorldProgress.reset_story()
	if bandit:
		WorldProgress.begin_bandit_encounter()
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
## would be processed there instead of at window B. This suite is
## specifically about window B (see test_window_a1_ultimate_interrupt.gd
## for A1-specific timing), so requests here deliberately wait until
## enemy_action_in_progress is true (meaning A1 already ran, found
## nothing, and _enemy_attack() has now genuinely started) before
## requesting, guaranteeing the request is only picked up later at
## window B -- exactly this suite's original, still-valid intent.
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


func _wait_for_player_hp_below(
	manager: BattleManager,
	starting_hp: int,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.player.current_hp < starting_hp:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_interrupt_processing_cleared(
	manager: BattleManager,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if not manager.is_processing_interrupt_queue:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_state(
	manager: BattleManager,
	expected_state: int,
	timeout_seconds: float
) -> bool:
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
