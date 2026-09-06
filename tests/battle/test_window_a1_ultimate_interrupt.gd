extends Node

## Block 9F: safe window A1 (before enemy commit). A queued off-turn
## Ultimate may now resolve *before* the enemy's own attack starts, not
## only after it finishes (window B, Block 9B/9D). See
## docs/battle_system_spec.md, "Block 9F implementation status". This
## suite is specific to A1 timing; the general queued-Ultimate gesture
## tests (second press / target click / locked cancel inputs) already live
## in test_command_ux_no_panel.gd and test_ultimate_off_turn_interrupt.gd.

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_a1_request_enters_queue_without_side_effects()
	await _test_a1_ultimate_resolves_before_enemy_damage()
	await _test_a1_commit_signals_fire_exactly_once()
	await _test_a1_cancel_input_is_locked_until_confirm()
	await _test_a1_survived_confirm_lets_enemy_attack_proceed()
	await _test_a1_lethal_confirm_wins_before_enemy_attacks()
	await _test_a1_processed_request_not_processed_again_at_b()
	await _test_late_request_after_a1_is_held_until_b()
	await _test_late_request_during_enemy_recovery_is_held_until_b()

	if failures.is_empty():
		print("PASS: window A1 ultimate interrupt (before enemy commit)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_a1_request_enters_queue_without_side_effects() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	var accepted := bool(manager.request_off_turn_ultimate(manager.player))

	_check(accepted, "a request made immediately at enemy turn start (well before A1's check) is accepted")
	_check(manager.ultimate_interrupt_queue.size() == 1, "the request enters the queue")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "the request does not spend Energy")
	_check(manager.state == BattleManager.BattleState.ENEMY_TURN, "the request does not change battle state")

	# Let it settle (A1 will pick it up) before freeing the scene.
	await _wait_for_pending_ultimate(manager, 10.0)
	manager.call("_confirm_ultimate_command")
	await _wait_for_interrupt_processing_cleared(manager, 45.0)
	await _free_battle(battle)


## The central Block 9F guarantee: a queued Ultimate confirmed at A1 deals
## its damage to the enemy strictly before the enemy's own attack ever
## touches the player.
func _test_a1_ultimate_resolves_before_enemy_damage() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_player_hp := manager.player.current_hp
	var initial_enemy_hp := manager.enemy.current_hp
	var expected_enemy_hp := initial_enemy_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle at window A1, before the enemy has committed"
	)
	_check(manager.player.current_hp == initial_player_hp, "the enemy has not attacked yet when A1 ready idle opens")

	manager.call("_on_ultimate_pressed")

	_check(
		await _wait_for_enemy_hp(manager, expected_enemy_hp, 45.0),
		"the A1 Ultimate deals its damage to the enemy"
	)
	_check(manager.player.current_hp == initial_player_hp, "the enemy still has not attacked while the A1 Ultimate resolves")
	_check(manager.ultimate_energy == 0, "the A1 Ultimate commit spends Energy exactly once")

	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 10.0),
		"the enemy's own attack proceeds normally afterward, since it survived"
	)
	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 10.0),
		"the battle eventually returns to a normal player turn"
	)

	await _free_battle(battle)


func _test_a1_commit_signals_fire_exactly_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var counts := {"commit": 0, "execution": 0, "resolution": 0}
	var flow: BattleCommandFlow = manager.ultimate_command_adapter.flow
	flow.command_committed.connect(func(_c) -> void: counts["commit"] = int(counts["commit"]) + 1)
	flow.command_execution_started.connect(func(_c) -> void: counts["execution"] = int(counts["execution"]) + 1)
	flow.command_resolved.connect(func(_c) -> void: counts["resolution"] = int(counts["resolution"]) + 1)

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at A1")

	manager.call("_on_ultimate_pressed")
	_check(
		await _wait_for_interrupt_processing_cleared(manager, 45.0),
		"the A1 Ultimate finishes (commit -> cut-in -> execution -> resolution -> recovery)"
	)

	_check(int(counts["commit"]) == 1, "A1 Ultimate commits exactly once")
	_check(int(counts["execution"]) == 1, "A1 Ultimate executes (cut-in) exactly once")
	_check(int(counts["resolution"]) == 1, "A1 Ultimate resolves exactly once")

	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 10.0)
	await _free_battle(battle)


func _test_a1_cancel_input_is_locked_until_confirm() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_player_hp := manager.player.current_hp
	var initial_enemy_hp := manager.enemy.current_hp

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at A1")

	manager.call("_cancel_ultimate_command")
	await _idle_frames(3)

	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "cancel input does not clear locked A1 Ultimate")
	_check(manager.player.current_hp == initial_player_hp, "enemy still waits while locked A1 Ultimate is pending")
	_check(manager.enemy.current_hp == initial_enemy_hp, "locked A1 Ultimate deals no damage before confirm")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "locked A1 Ultimate does not spend Energy before confirm")

	manager.call("_on_ultimate_pressed")
	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 45.0),
		"confirming the locked A1 Ultimate lets the enemy's own attack proceed afterward"
	)
	_check(manager.enemy.current_hp == initial_enemy_hp - BattleManager.ULTIMATE_DAMAGE, "locked A1 Ultimate deals damage on confirm")
	_check(manager.ultimate_energy == 0, "locked A1 Ultimate spends Energy on confirm")
	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 10.0),
		"the battle returns to a normal player turn after the enemy's attack completes"
	)

	await _free_battle(battle)


func _test_a1_survived_confirm_lets_enemy_attack_proceed() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	# Enough HP that ULTIMATE_DAMAGE does not kill the enemy.
	manager.enemy.current_hp = manager.enemy.max_hp
	var initial_player_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at A1")

	manager.call("_on_ultimate_pressed")
	_check(
		await _wait_for_interrupt_processing_cleared(manager, 45.0),
		"the A1 Ultimate finishes resolving"
	)
	_check(not manager.enemy.is_defeated(), "the enemy survives the A1 Ultimate in this scenario")

	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 10.0),
		"the enemy's own attack still proceeds after a non-lethal A1 Ultimate"
	)
	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 10.0),
		"the battle returns to a normal player turn afterward"
	)

	await _free_battle(battle)


func _test_a1_lethal_confirm_wins_before_enemy_attacks() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.enemy.current_hp = mini(manager.enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)
	var initial_player_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at A1")

	manager.call("_on_ultimate_pressed")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.WIN, 45.0),
		"a lethal A1 Ultimate wins the battle"
	)
	_check(
		manager.player.current_hp == initial_player_hp,
		"the enemy never got to attack -- a lethal A1 Ultimate cancels the enemy's own action entirely"
	)
	_check(not manager.is_processing_interrupt_queue, "victory from an A1 Ultimate clears the processing flag")
	_check(manager.active_interrupt_request == null, "victory from an A1 Ultimate clears active_interrupt_request")

	await _free_battle(battle)


## Confirms the same request can never be picked up twice -- once A1
## consumes it (here, via confirm), the queue must be empty and window B's
## later check must find nothing to process.
func _test_a1_processed_request_not_processed_again_at_b() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at A1")

	manager.call("_confirm_ultimate_command")
	await _wait_for_interrupt_processing_cleared(manager, 45.0)

	_check(manager.ultimate_interrupt_queue.is_empty(), "the A1-confirmed request is gone from the queue, not requeued")

	# Let the enemy attack finish and reach window B with an empty queue --
	# no second Ultimate ready idle should ever appear.
	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 10.0),
		"the battle reaches a normal player turn with nothing left queued"
	)
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "no second Ultimate ready idle appears at window B")

	await _free_battle(battle)


## A request made after A1's one-time check has already run (queue was
## empty at that instant) must wait for window B -- it is not reachable
## again until then.
func _test_late_request_after_a1_is_held_until_b() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_enemy_hp := manager.enemy.current_hp

	manager.call("_begin_enemy_turn")
	_check(
		await _wait_past_window_a1(manager, 5.0),
		"A1's one-time check runs and finds nothing (queue was empty), so the enemy attack genuinely starts"
	)

	var accepted := bool(manager.request_off_turn_ultimate(manager.player))
	_check(accepted, "a request made after A1 has already passed is still accepted into the queue")
	_check(manager.ultimate_interrupt_queue.size() == 1, "the late request sits in the queue")
	_check(not manager.is_processing_interrupt_queue, "the late request is not processed immediately -- A1 already ran")
	_check(manager.enemy.current_hp == initial_enemy_hp, "the late request has not dealt any damage yet")

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"the late request is picked up at window B, after the enemy's attack fully resolves"
	)
	manager.call("_confirm_ultimate_command")
	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 45.0)
	await _free_battle(battle)


## A request made while the enemy attack is already mid-flight (movement/
## hit/recovery in progress) must also wait for window B.
func _test_late_request_during_enemy_recovery_is_held_until_b() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_player_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 10.0),
		"the enemy attack actually lands (request will arrive after commit)"
	)

	var accepted := bool(manager.request_off_turn_ultimate(manager.player))
	_check(accepted, "a request made after enemy damage already landed is still accepted into the queue")
	_check(not manager.is_processing_interrupt_queue, "the request is not processed mid-recovery")

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"the request is picked up at window B once recovery completes"
	)
	manager.call("_confirm_ultimate_command")
	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 45.0)
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


func _wait_for_enemy_hp(manager: BattleManager, expected_hp: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.enemy.current_hp == expected_hp:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_player_hp_below(manager: BattleManager, starting_hp: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.player.current_hp < starting_hp:
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


## Waits until enemy_action_in_progress becomes true, meaning window A1's
## one-time check has already run (and found nothing, in these tests) and
## _enemy_attack() has genuinely started.
func _wait_past_window_a1(manager: BattleManager, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.enemy_action_in_progress:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
