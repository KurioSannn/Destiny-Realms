extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_lesser_skill_select_ready_and_cancel()
	await _test_lesser_skill_confirm_is_single_execution()
	await _test_skill_insufficient_sp_revalidates_before_commit()
	await _test_skill_invalid_target_revalidates_before_commit()
	await _test_skill_invalid_actor_revalidates_before_commit()
	await _test_skill_switching_with_basic()
	await _test_legacy_skill_fallback_keeps_old_timing()
	await _test_ultimate_cancels_skill_pending_and_stays_legacy()
	await _test_new_ultimate_cancels_skill_pending()
	await _test_scene_exit_stops_committed_skill_callbacks()
	await _test_bandit_skill_victory_updates_world_progress()

	if failures.is_empty():
		print("PASS: production skill command flow")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_lesser_skill_select_ready_and_cancel() -> void:
	var fixture := await _make_battle(false, true, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points

	manager.call("_on_skill_pressed")
	await _idle_frames(3)

	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "skill select keeps player turn")
	_check(manager.enemy.current_hp == initial_hp, "skill select does not deal damage")
	_check(manager.skill_points == initial_sp, "skill select does not spend SP")
	_check(manager.skill_command_adapter.has_pending_skill(), "skill select creates pending command")
	_check(manager.skill_animation_playing, "skill select starts ready idle")
	_check(manager.skill_animation_looping, "skill ready idle loops")
	_check(manager.skill_target_highlight.visible, "skill select shows target highlight")
	_check(manager.skill_command_panel.visible, "skill select shows confirm/cancel panel")

	manager.call("_cancel_skill_command")
	await _idle_frames(3)

	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "skill cancel preserves player turn")
	_check(manager.enemy.current_hp == initial_hp, "skill cancel does not deal damage")
	_check(manager.skill_points == initial_sp, "skill cancel preserves SP")
	_check(not manager.skill_command_adapter.has_pending_skill(), "skill cancel clears pending command")
	_check(not manager.skill_target_highlight.visible, "skill cancel hides target highlight")
	_check(not manager.skill_command_panel.visible, "skill cancel hides confirm/cancel panel")
	_check(not manager.skill_animation_looping, "skill cancel exits ready idle")

	await _free_battle(battle)


func _test_lesser_skill_confirm_is_single_execution() -> void:
	var fixture := await _make_battle(false, true, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var counts := {
		"commit": 0,
		"execution": 0,
		"resolution": 0,
		"recovery": 0,
	}
	var flow: BattleCommandFlow = manager.skill_command_adapter.flow
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

	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points
	var expected_hp := initial_hp - BattleManager.SKILL_DAMAGE
	var expected_sp := initial_sp - BattleManager.SKILL_POINT_COST_SKILL

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_confirm_skill_command")
	manager.call("_confirm_skill_command")
	manager.call("_on_confirm_pressed")

	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "skill confirm deals legacy damage")
	_check(await _wait_for_no_pending_skill(manager, 5.0), "skill confirm completes recovery")
	_check(int(counts["commit"]) == 1, "skill confirm commits once")
	_check(int(counts["execution"]) == 1, "skill confirm executes once")
	_check(int(counts["resolution"]) == 1, "skill confirm resolves once")
	_check(int(counts["recovery"]) == 1, "skill confirm enters recovery once")
	_check(manager.enemy.current_hp == expected_hp, "spam confirm does not duplicate skill damage")
	_check(manager.skill_points == expected_sp, "skill SP spend occurs once at commit")
	_check(manager.ultimate_energy == BattleManager.SKILL_ENERGY, "skill energy gain is unchanged")
	_check(not manager.skill_target_highlight.visible, "skill resolution clears target highlight")
	_check(not manager.skill_command_panel.visible, "skill resolution clears confirm/cancel panel")
	_check(manager.state != BattleManager.BattleState.ACTION_RESOLUTION, "skill turn leaves execution state")

	await _free_battle(battle)


func _test_skill_insufficient_sp_revalidates_before_commit() -> void:
	var fixture := await _make_battle(false, true, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	var initial_hp := manager.enemy.current_hp
	manager.skill_points = 0
	manager.call("_refresh_skill_points_ui")

	var confirmed := bool(manager.call("_confirm_skill_command"))
	await _idle_frames(3)

	_check(not confirmed, "skill cannot commit without SP")
	_check(manager.enemy.current_hp == initial_hp, "insufficient SP confirm does not damage")
	_check(manager.skill_points == 0, "insufficient SP confirm does not mutate SP")
	_check(not manager.skill_command_adapter.has_pending_skill(), "insufficient SP clears pending command")
	_check(not manager.skill_target_highlight.visible, "insufficient SP clears highlight")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "insufficient SP stays on player turn")

	await _free_battle(battle)


func _test_skill_invalid_target_revalidates_before_commit() -> void:
	var fixture := await _make_battle(false, true, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	var initial_sp := manager.skill_points
	manager.enemy.take_damage(manager.enemy.max_hp)

	var confirmed := bool(manager.call("_confirm_skill_command"))
	await _idle_frames(3)

	_check(not confirmed, "dead target cannot commit skill")
	_check(manager.skill_points == initial_sp, "invalid target confirm does not spend SP")
	_check(not manager.skill_command_adapter.has_pending_skill(), "invalid target clears pending command")
	_check(not manager.skill_target_highlight.visible, "invalid target clears highlight")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "invalid target stays on player turn")

	await _free_battle(battle)


func _test_skill_invalid_actor_revalidates_before_commit() -> void:
	var fixture := await _make_battle(false, true, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points
	manager.player.take_damage(manager.player.max_hp)

	var confirmed := bool(manager.call("_confirm_skill_command"))
	await _idle_frames(3)

	_check(not confirmed, "defeated actor cannot commit skill")
	_check(manager.enemy.current_hp == initial_hp, "invalid actor confirm does not damage")
	_check(manager.skill_points == initial_sp, "invalid actor confirm does not spend SP")
	_check(not manager.skill_command_adapter.has_pending_skill(), "invalid actor clears pending command")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "invalid actor returns command selection")

	await _free_battle(battle)


func _test_skill_switching_with_basic() -> void:
	# Basic Attack is fast-flow as of Block 8.5 (no ready idle/confirm panel);
	# a second live enemy is mocked here so Basic has a genuine pre-commit
	# pending state (target selection) to switch away from/into.
	var fixture := await _make_battle(false, true, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var second_enemy := _spawn_mock_enemy(battle, manager)

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	_check(not manager.skill_command_adapter.has_pending_skill(), "Basic selection cancels pending Skill")
	_check(manager.basic_command_adapter.has_pending_basic(), "Basic starts after Skill cancel")
	_check(not manager.skill_command_panel.visible, "Skill panel hides after switching to Basic")
	var basic_pending: PendingBattleCommand = manager.basic_command_adapter.get_pending_command()
	_check(
		basic_pending != null and not basic_pending.is_committed,
		"Basic waits for a target choice (multiple live enemies) instead of a confirm panel"
	)
	_check(manager.basic_target_highlight.visible, "Basic shows target selection after switching from Skill")

	manager.call("_cancel_basic_attack_command")
	await _idle_frames(3)
	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	manager.call("_on_skill_pressed")
	await _idle_frames(3)

	_check(not manager.basic_command_adapter.has_pending_basic(), "Skill selection cancels pending Basic target selection")
	_check(manager.skill_command_adapter.has_pending_skill(), "Skill starts after Basic cancel")
	_check(not manager.basic_target_highlight.visible, "Basic target highlight hides after switching to Skill")
	_check(manager.skill_command_panel.visible, "Skill panel shows after switching from Basic")

	await _free_battle(battle)


func _test_legacy_skill_fallback_keeps_old_timing() -> void:
	var fixture := await _make_battle(false, true, false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points
	var expected_hp := initial_hp - BattleManager.SKILL_DAMAGE

	manager.call("_on_skill_pressed")
	await _idle_frames(1)

	_check(manager.skill_points == initial_sp - BattleManager.SKILL_POINT_COST_SKILL, "legacy fallback spends SP before hit")
	_check(manager.enemy.current_hp == initial_hp, "legacy fallback keeps damage delayed until hit")
	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "legacy fallback skill still deals damage")
	_check(not manager.skill_command_adapter.has_pending_skill(), "legacy fallback does not leave Skill pending")

	await _free_battle(battle)


func _test_ultimate_cancels_skill_pending_and_stays_legacy() -> void:
	var fixture := await _make_battle(false, true, true, false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_ultimate_pressed")
	await _idle_frames(5)

	_check(not manager.skill_command_adapter.has_pending_skill(), "Ultimate clears pending Skill")
	_check(not manager.skill_command_panel.visible, "Ultimate hides Skill panel")
	_check(manager.state == BattleManager.BattleState.ACTION_RESOLUTION, "Ultimate legacy fallback remains action resolution")
	_check(manager.ultimate_energy == 0, "Ultimate legacy fallback energy timing is unchanged")

	await _free_battle(battle)


func _test_new_ultimate_cancels_skill_pending() -> void:
	var fixture := await _make_battle(false, true, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.enemy.current_hp = BattleManager.ULTIMATE_DAMAGE
	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)

	_check(not manager.skill_command_adapter.has_pending_skill(), "new Ultimate clears pending Skill")
	_check(not manager.skill_command_panel.visible, "new Ultimate hides Skill panel")
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "new Ultimate flow creates a pending command")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "new Ultimate flow does not spend energy before commit")

	manager.call("_confirm_ultimate_command")

	_check(await _wait_for_state(manager, BattleManager.BattleState.WIN, 40.0), "new Ultimate can win Lesser Abyss")
	_check(manager.ultimate_energy == 0, "new Ultimate flow spends energy exactly once on commit")

	await _free_battle(battle)


func _test_scene_exit_stops_committed_skill_callbacks() -> void:
	var fixture := await _make_battle(false, true, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_confirm_skill_command")
	await _idle_frames(1)
	battle.queue_free()
	await _idle_frames(20)

	_check(true, "scene exit during committed Skill does not crash test runner")
	WorldProgress.reset_story()


func _test_bandit_skill_victory_updates_world_progress() -> void:
	var fixture := await _make_battle(true, true, true)
	var manager := fixture["manager"] as BattleManager

	_check(manager.is_bandit_encounter, "bandit encounter configuration still loads")
	_check(manager.enemy.combatant_name == "Bandit Captain", "bandit target defaults to captain")
	_check(manager.encounter_victory_scene_path == BattleManager.GRASSLANDS_SCENE_PATH, "bandit victory return scene is unchanged")

	manager.enemy.current_hp = BattleManager.SKILL_DAMAGE
	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_confirm_skill_command")

	_check(await _wait_for_state(manager, BattleManager.BattleState.WIN, 6.0), "bandit Skill can win encounter")
	_check(WorldProgress.bandit_defeated, "bandit Skill victory updates WorldProgress")
	_check(WorldProgress.active_battle_id == &"", "bandit Skill victory clears active encounter")


func _spawn_mock_enemy(battle: Node, manager: BattleManager) -> Combatant:
	var mock_enemy := Combatant.new()
	mock_enemy.name = "MockSecondEnemy"
	battle.add_child(mock_enemy)
	mock_enemy.setup("Mock Enemy B", 50, 5)
	mock_enemy.global_position = manager.enemy.global_position + Vector2(140.0, 0.0)
	return mock_enemy


func _make_battle(
	bandit: bool,
	use_basic_flow: bool,
	use_skill_flow: bool,
	use_ultimate_flow: bool = true
) -> Dictionary:
	WorldProgress.reset_story()
	if bandit:
		WorldProgress.begin_bandit_encounter()
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.use_new_basic_command_flow = use_basic_flow
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


func _wait_for_no_pending_skill(
	manager: BattleManager,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if not manager.skill_command_adapter.has_pending_skill():
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
