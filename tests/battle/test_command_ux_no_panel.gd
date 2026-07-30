extends Node

## Block 9E: Skill/Ultimate command UX revision -- no confirm/cancel panel.
## Ready idle and target selection are kept; commit now happens by
## pressing the same command again or clicking a valid target, and
## pressing a *different* command only cancels the pending one (never
## also begins the new one in the same click). See
## docs/battle_system_spec.md, "Block 9E implementation status". This
## suite covers the specific new gestures (second-press commit,
## target-click commit, Escape cancel, and the queued/off-turn Ultimate
## equivalents) that the updated production suites don't already exercise
## directly through _on_skill_pressed()/_on_ultimate_pressed()/Escape.

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_skill_second_press_commits()
	await _test_skill_target_click_commits()
	await _test_skill_escape_cancels()
	await _test_ultimate_second_press_commits()
	await _test_ultimate_target_click_commits()
	await _test_ultimate_escape_cancels()
	await _test_queued_ultimate_ready_shows_no_panel()
	await _test_queued_ultimate_second_press_commits()
	await _test_queued_ultimate_target_click_commits()
	await _test_queued_ultimate_basic_press_cancels_and_resumes_player_turn()
	await _test_queued_ultimate_skill_press_cancels_and_resumes_player_turn()
	await _test_queued_ultimate_escape_cancels_and_resumes_player_turn()

	if failures.is_empty():
		print("PASS: command UX no confirm/cancel panel")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_skill_second_press_commits() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points
	var expected_hp := initial_hp - BattleManager.SKILL_DAMAGE

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	_check(manager.skill_command_adapter.has_pending_skill(), "first Skill press opens ready idle")
	_check(manager.skill_points == initial_sp, "ready idle does not spend SP")
	_check(not manager.skill_command_panel.visible, "ready idle shows no confirm/cancel panel")

	manager.call("_on_skill_pressed")

	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "second Skill press commits and deals damage")
	_check(manager.skill_points == initial_sp - BattleManager.SKILL_POINT_COST_SKILL, "second Skill press spends SP exactly once")

	await _free_battle(battle)


func _test_skill_target_click_commits() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp
	var expected_hp := initial_hp - BattleManager.SKILL_DAMAGE

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	_check(manager.skill_command_adapter.has_pending_skill(), "Skill press opens ready idle")

	var committed := bool(manager.call("_select_skill_target_at_position", manager.enemy.global_position))

	_check(committed, "clicking the enemy while Skill is pending commits")
	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "target click commit deals damage")

	await _free_battle(battle)


func _test_skill_escape_cancels() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	_check(manager.skill_command_adapter.has_pending_skill(), "Skill press opens ready idle")

	_simulate_ui_cancel(manager)
	await _idle_frames(3)

	_check(not manager.skill_command_adapter.has_pending_skill(), "Escape cancels pending Skill")
	_check(manager.skill_points == initial_sp, "Escape cancel does not spend SP")
	_check(manager.enemy.current_hp == initial_hp, "Escape cancel deals no damage")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "Escape cancel returns to default select")

	await _free_battle(battle)


func _test_ultimate_second_press_commits() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_hp := manager.enemy.current_hp
	var expected_hp := initial_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "first Ultimate press opens ready idle")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "ready idle does not spend Energy")
	_check(not manager.ultimate_command_panel.visible, "ready idle shows no confirm/cancel panel")

	manager.call("_on_ultimate_pressed")

	_check(await _wait_for_enemy_hp(manager, expected_hp, 45.0), "second Ultimate press commits and deals damage")
	_check(manager.ultimate_energy == 0, "second Ultimate press spends Energy exactly once")

	await _free_battle(battle)


func _test_ultimate_target_click_commits() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_hp := manager.enemy.current_hp
	var expected_hp := initial_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "Ultimate press opens ready idle")

	var committed := bool(manager.call("_select_ultimate_target_at_position", manager.enemy.global_position))

	_check(committed, "clicking the enemy while Ultimate is pending commits")
	_check(await _wait_for_enemy_hp(manager, expected_hp, 45.0), "target click commit deals damage")

	await _free_battle(battle)


func _test_ultimate_escape_cancels() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_hp := manager.enemy.current_hp

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "Ultimate press opens ready idle")

	_simulate_ui_cancel(manager)
	await _idle_frames(3)

	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "Escape cancels pending Ultimate")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "Escape cancel does not spend Energy")
	_check(manager.enemy.current_hp == initial_hp, "Escape cancel deals no damage/no cut-in")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "Escape cancel returns to default select")

	await _free_battle(battle)


func _test_queued_ultimate_ready_shows_no_panel() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)
	_check(not manager.ultimate_command_panel.visible, "queued Ultimate ready idle shows no confirm/cancel panel")

	manager.call("_cancel_ultimate_command")
	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0)
	await _free_battle(battle)


func _test_queued_ultimate_second_press_commits() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)

	manager.call("_on_ultimate_pressed")

	_check(
		await _wait_for_interrupt_processing_cleared(manager, 40.0),
		"a second Ultimate press commits the queued Ultimate through to resolution"
	)
	_check(manager.ultimate_energy == 0, "queued Ultimate commit spends Energy exactly once")
	_check(
		manager.state == BattleManager.BattleState.PLAYER_TURN,
		"queued Ultimate confirm resumes a normal player turn afterward"
	)

	await _free_battle(battle)


func _test_queued_ultimate_target_click_commits() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)

	var committed := bool(manager.call("_select_ultimate_target_at_position", manager.enemy.global_position))

	_check(committed, "clicking the enemy while a queued Ultimate is pending commits")
	_check(
		await _wait_for_interrupt_processing_cleared(manager, 40.0),
		"target click commits the queued Ultimate through to resolution"
	)
	_check(manager.ultimate_energy == 0, "queued Ultimate target-click commit spends Energy exactly once")

	await _free_battle(battle)


func _test_queued_ultimate_basic_press_cancels_and_resumes_player_turn() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)

	manager.call("_on_attack_pressed")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0),
		"pressing Basic while a queued Ultimate is pending cancels it and resumes player turn"
	)
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "Basic press clears the queued Ultimate")
	_check(not manager.basic_command_adapter.has_pending_basic(), "Basic does not start in the same click that cancelled the queued Ultimate")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "cancelling the queued Ultimate does not spend Energy")

	await _free_battle(battle)


func _test_queued_ultimate_skill_press_cancels_and_resumes_player_turn() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)

	manager.call("_on_skill_pressed")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0),
		"pressing Skill while a queued Ultimate is pending cancels it and resumes player turn"
	)
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "Skill press clears the queued Ultimate")
	_check(not manager.skill_command_adapter.has_pending_skill(), "Skill does not start in the same click that cancelled the queued Ultimate")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "cancelling the queued Ultimate does not spend Energy")

	await _free_battle(battle)


func _test_queued_ultimate_escape_cancels_and_resumes_player_turn() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"queued Ultimate reaches ready idle after enemy recovery"
	)

	_simulate_ui_cancel(manager)

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0),
		"Escape while a queued Ultimate is pending cancels it and resumes player turn"
	)
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "Escape clears the queued Ultimate")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "Escape cancel of a queued Ultimate does not spend Energy")

	await _free_battle(battle)


func _simulate_ui_cancel(manager: BattleManager) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	manager.call("_unhandled_input", event)


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
