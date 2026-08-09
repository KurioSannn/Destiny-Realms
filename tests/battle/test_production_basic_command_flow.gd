extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_lesser_basic_single_enemy_auto_target_and_execute()
	await _test_basic_committed_cannot_be_cancelled()
	await _test_basic_no_valid_target_fails_safely()
	await _test_basic_spam_press_and_switch_does_not_duplicate()
	await _test_multi_enemy_target_select_then_auto_commit()
	await _test_multi_enemy_cancel_before_target_selected()
	await _test_legacy_basic_fallback_still_works()
	await _test_legacy_skill_still_works()
	await _test_legacy_ultimate_still_starts()
	await _test_new_ultimate_defers_energy_until_commit()
	await _test_bandit_basic_victory_updates_world_progress()

	if failures.is_empty():
		print("PASS: production basic command flow")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_lesser_basic_single_enemy_auto_target_and_execute() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var counts := {
		"commit": 0,
		"execution": 0,
		"resolution": 0,
		"recovery": 0,
	}
	var flow: BattleCommandFlow = manager.basic_command_adapter.flow
	flow.command_committed.connect(func(_command) -> void:
		counts["commit"] = int(counts["commit"]) + 1
	)
	flow.command_execution_started.connect(func(_command) -> void:
		counts["execution"] = int(counts["execution"]) + 1
	)
	flow.command_resolved.connect(func(_command) -> void:
		counts["resolution"] = int(counts["resolution"]) + 1
	)
	flow.flow_state_changed.connect(func(battle_state, _animation_state, _ui_state) -> void:
		if battle_state == BattleCommandFlow.BattleFlowState.ACTION_RECOVERY:
			counts["recovery"] = int(counts["recovery"]) + 1
	)

	manager.skill_points = BattleManager.START_SKILL_POINTS - 1
	manager.call("_refresh_skill_points_ui")
	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points
	var expected_hp := initial_hp - BattleManager.BASIC_ATTACK_DAMAGE

	manager.call("_on_attack_pressed")

	var command: PendingBattleCommand = manager.basic_command_adapter.get_pending_command()
	_check(
		command != null and command.is_committed,
		"single-enemy basic commits immediately on press, no ready idle or confirm wait"
	)
	_check(
		manager.basic_target_highlight != null and not manager.basic_target_highlight.visible,
		"single-enemy basic does not show a target highlight"
	)

	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "basic deals expected damage")
	_check(await _wait_for_no_pending_basic(manager, 5.0), "basic completes recovery")
	_check(int(counts["commit"]) == 1, "basic commits exactly once")
	_check(int(counts["execution"]) == 1, "basic executes exactly once")
	_check(int(counts["resolution"]) == 1, "basic resolves exactly once")
	_check(int(counts["recovery"]) == 1, "basic enters recovery exactly once")
	_check(manager.enemy.current_hp == expected_hp, "basic damage happens exactly once")
	_check(
		manager.skill_points == initial_sp + BattleManager.SKILL_POINT_GAIN_BASIC,
		"basic SP reward occurs once after hit"
	)
	_check(manager.state != BattleManager.BattleState.ACTION_RESOLUTION, "basic turn leaves execution state")

	await _free_battle(battle)


func _test_basic_committed_cannot_be_cancelled() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp
	var expected_hp := initial_hp - BattleManager.BASIC_ATTACK_DAMAGE

	manager.call("_on_attack_pressed")
	var cancelled := bool(manager.call("_cancel_basic_attack_command"))

	_check(not cancelled, "committed basic cannot be cancelled")
	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "basic still deals damage after a failed cancel attempt")

	await _free_battle(battle)


func _test_basic_no_valid_target_fails_safely() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_sp := manager.skill_points

	manager.enemy.take_damage(manager.enemy.max_hp)
	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	_check(not manager.basic_command_adapter.has_pending_basic(), "no valid target leaves no pending basic command")
	_check(manager.skill_points == initial_sp, "no valid target does not grant SP")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "no valid target keeps player turn")

	await _free_battle(battle)


func _test_basic_spam_press_and_switch_does_not_duplicate() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp
	var expected_hp := initial_hp - BattleManager.BASIC_ATTACK_DAMAGE

	manager.call("_on_attack_pressed")
	manager.call("_on_attack_pressed")
	manager.call("_on_attack_pressed")
	manager.call("_on_skill_pressed")
	manager.call("_on_ultimate_pressed")

	_check(
		await _wait_for_enemy_hp(manager, expected_hp, 5.0),
		"spamming Basic/Skill/Ultimate presses still deals exactly one Basic hit"
	)
	_check(manager.enemy.current_hp == expected_hp, "no duplicate damage from spam input")
	_check(
		not manager.skill_command_adapter.has_pending_skill(),
		"spam does not leave Skill pending once committed Basic blocks it"
	)
	_check(
		not manager.ultimate_command_adapter.has_pending_ultimate(),
		"spam does not leave Ultimate pending once committed Basic blocks it"
	)

	await _free_battle(battle)


func _test_multi_enemy_target_select_then_auto_commit() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var second_enemy := _spawn_mock_enemy(battle, manager, "Mock Enemy B")
	manager.skill_points = BattleManager.START_SKILL_POINTS - 1
	manager.call("_refresh_skill_points_ui")
	var initial_hp_a := manager.enemy.current_hp
	var initial_hp_b := second_enemy.current_hp
	var initial_sp := manager.skill_points

	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	_check(manager.basic_command_adapter.has_pending_basic(), "multi-enemy basic select creates a pending command")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "multi-enemy basic select keeps player turn")
	_check(
		manager.get_current_target_marker_target() == manager.enemy,
		"multi-enemy basic select marks the default target"
	)
	var pending_before: PendingBattleCommand = manager.basic_command_adapter.get_pending_command()
	_check(
		pending_before != null and not pending_before.is_committed,
		"multi-enemy basic select waits for the player to choose a target"
	)
	_check(manager.enemy.current_hp == initial_hp_a, "multi-enemy basic select does not deal damage yet (target A)")
	_check(second_enemy.current_hp == initial_hp_b, "multi-enemy basic select does not deal damage yet (target B)")

	var selected := bool(manager.basic_command_adapter.select_target(second_enemy))
	_check(selected, "player can select target B")
	var pending_after: PendingBattleCommand = manager.basic_command_adapter.get_pending_command()
	_check(
		pending_after != null and pending_after.is_committed,
		"selecting a target commits immediately, no separate confirm step"
	)
	_check(not manager.basic_target_highlight.visible, "target highlight clears immediately after selection")

	var expected_hp_b := initial_hp_b - BattleManager.BASIC_ATTACK_DAMAGE
	_check(
		await _wait_for_combatant_hp(manager, second_enemy, expected_hp_b, 5.0),
		"selecting target B immediately executes on B"
	)
	_check(manager.enemy.current_hp == initial_hp_a, "target A is untouched when target B was selected")
	_check(
		await _wait_for_skill_points(manager, initial_sp + BattleManager.SKILL_POINT_GAIN_BASIC, 5.0),
		"multi-enemy basic still grants SP on hit"
	)

	await _free_battle(battle)


func _test_multi_enemy_cancel_before_target_selected() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var second_enemy := _spawn_mock_enemy(battle, manager, "Mock Enemy B")
	var initial_hp_a := manager.enemy.current_hp
	var initial_hp_b := second_enemy.current_hp
	var initial_sp := manager.skill_points

	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	_check(
		manager.basic_command_adapter.has_pending_basic(),
		"multi-enemy basic select creates a pending command before cancel"
	)

	var cancelled := bool(manager.call("_cancel_basic_attack_command"))
	await _idle_frames(3)

	_check(cancelled, "multi-enemy basic select can be cancelled before a target is chosen")
	_check(not manager.basic_command_adapter.has_pending_basic(), "cancel clears the pending Basic command")
	_check(not manager.basic_target_highlight.visible, "cancel hides the target highlight")
	_check(manager.enemy.current_hp == initial_hp_a, "cancel does not deal damage (target A)")
	_check(second_enemy.current_hp == initial_hp_b, "cancel does not deal damage (target B)")
	_check(manager.skill_points == initial_sp, "cancel does not grant SP")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "cancel keeps player turn")

	await _free_battle(battle)


func _test_legacy_basic_fallback_still_works() -> void:
	var fixture := await _make_battle(false, false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.skill_points = BattleManager.START_SKILL_POINTS - 1
	manager.call("_refresh_skill_points_ui")
	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points
	var expected_hp := initial_hp - BattleManager.BASIC_ATTACK_DAMAGE

	manager.call("_on_attack_pressed")

	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "legacy fallback basic still deals damage")
	_check(not manager.basic_command_adapter.has_pending_basic(), "legacy fallback does not create pending command")
	_check(
		await _wait_for_skill_points(
			manager,
			initial_sp + BattleManager.SKILL_POINT_GAIN_BASIC,
			5.0
		),
		"legacy fallback SP reward unchanged"
	)

	await _free_battle(battle)


func _test_legacy_skill_still_works() -> void:
	var fixture := await _make_battle(false, true, false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp
	var expected_hp := initial_hp - BattleManager.SKILL_DAMAGE

	manager.call("_on_skill_pressed")

	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "legacy skill still deals damage")
	_check(not manager.basic_command_adapter.has_pending_basic(), "legacy skill does not leave basic pending")

	await _free_battle(battle)


func _test_legacy_ultimate_still_starts() -> void:
	var fixture := await _make_battle(false, true, true, false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_on_ultimate_pressed")
	await _idle_frames(5)

	_check(manager.state == BattleManager.BattleState.ACTION_RESOLUTION, "legacy ultimate fallback enters action resolution")
	_check(manager.ultimate_energy == 0, "legacy ultimate fallback energy timing is unchanged")
	_check(not manager.basic_command_adapter.has_pending_basic(), "legacy ultimate does not leave basic pending")
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "legacy ultimate fallback does not create pending command")

	await _free_battle(battle)


func _test_new_ultimate_defers_energy_until_commit() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)

	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "new ultimate flow creates a pending command")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "new ultimate flow does not spend energy before commit")
	_check(manager.state != BattleManager.BattleState.ACTION_RESOLUTION, "new ultimate ready idle does not enter action resolution")

	manager.call("_cancel_ultimate_command")
	await _idle_frames(3)

	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "locked ultimate idle does not spend energy")
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "cancel input does not clear locked ultimate pending command")

	await _free_battle(battle)


func _test_bandit_basic_victory_updates_world_progress() -> void:
	var fixture := await _make_battle(true, true)
	var manager := fixture["manager"] as BattleManager

	_check(manager.is_bandit_encounter, "bandit encounter configuration still loads")
	_check(manager.enemy.combatant_name == "Bandit Captain", "bandit target defaults to captain")
	_check(manager.encounter_victory_scene_path == BattleManager.GRASSLANDS_SCENE_PATH, "bandit victory return scene is unchanged")

	manager.enemy.current_hp = BattleManager.BASIC_ATTACK_DAMAGE
	manager.call("_on_attack_pressed")

	_check(await _wait_for_state(manager, BattleManager.BattleState.WIN, 5.0), "bandit basic can win encounter")
	_check(WorldProgress.bandit_defeated, "bandit basic victory updates WorldProgress")
	_check(WorldProgress.active_battle_id == &"", "bandit basic victory clears active encounter")


func _spawn_mock_enemy(battle: Node, manager: BattleManager, mock_name: String) -> Combatant:
	var mock_enemy := Combatant.new()
	mock_enemy.name = "MockSecondEnemy"
	battle.add_child(mock_enemy)
	mock_enemy.setup(mock_name, 50, 5)
	mock_enemy.global_position = manager.enemy.global_position + Vector2(140.0, 0.0)
	return mock_enemy


func _make_battle(
	bandit: bool,
	use_flow: bool,
	use_skill_flow: bool = true,
	use_ultimate_flow: bool = true
) -> Dictionary:
	WorldProgress.reset_story()
	if bandit:
		WorldProgress.begin_bandit_encounter()
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.use_new_basic_command_flow = use_flow
	manager.use_new_skill_command_flow = use_skill_flow
	manager.use_new_ultimate_command_flow = use_ultimate_flow
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


func _wait_for_enemy_hp(
	manager: BattleManager,
	expected_hp: int,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.enemy.current_hp == expected_hp:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_combatant_hp(
	manager: BattleManager,
	combatant: Combatant,
	expected_hp: int,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or not is_instance_valid(combatant):
			return false
		if combatant.current_hp == expected_hp:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_no_pending_basic(
	manager: BattleManager,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if not manager.basic_command_adapter.has_pending_basic():
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_skill_points(
	manager: BattleManager,
	expected_skill_points: int,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.skill_points == expected_skill_points:
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
