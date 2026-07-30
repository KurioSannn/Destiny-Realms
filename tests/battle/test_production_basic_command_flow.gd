extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_lesser_basic_select_and_cancel()
	await _test_lesser_basic_confirm_is_single_execution()
	await _test_invalid_target_revalidates_before_confirm()
	await _test_legacy_basic_fallback_still_works()
	await _test_legacy_skill_still_works()
	await _test_legacy_ultimate_still_starts()
	await _test_bandit_basic_victory_updates_world_progress()

	if failures.is_empty():
		print("PASS: production basic command flow")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_lesser_basic_select_and_cancel() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.skill_points = BattleManager.START_SKILL_POINTS - 1
	manager.call("_refresh_skill_points_ui")
	var initial_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points

	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "basic select keeps player turn")
	_check(manager.enemy.current_hp == initial_hp, "basic select does not deal damage")
	_check(manager.skill_points == initial_sp, "basic select does not grant SP")
	_check(manager.basic_command_adapter.has_pending_basic(), "basic select creates pending command")
	_check(manager.basic_animation_playing, "basic select starts ready idle")
	_check(manager.basic_target_highlight.visible, "basic select shows target highlight")
	_check(manager.basic_command_panel.visible, "basic select shows confirm/cancel panel")

	manager.call("_cancel_basic_attack_command")
	await _idle_frames(3)

	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "basic cancel preserves player turn")
	_check(manager.enemy.current_hp == initial_hp, "basic cancel does not deal damage")
	_check(manager.skill_points == initial_sp, "basic cancel does not grant SP")
	_check(not manager.basic_command_adapter.has_pending_basic(), "basic cancel clears pending command")
	_check(not manager.basic_target_highlight.visible, "basic cancel hides target highlight")
	_check(not manager.basic_command_panel.visible, "basic cancel hides confirm/cancel panel")
	_check(not manager.basic_animation_playing, "basic cancel exits ready idle")

	await _free_battle(battle)


func _test_lesser_basic_confirm_is_single_execution() -> void:
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
	await _idle_frames(3)
	manager.call("_confirm_basic_attack_command")
	manager.call("_confirm_basic_attack_command")
	manager.call("_on_confirm_pressed")

	_check(await _wait_for_enemy_hp(manager, expected_hp, 5.0), "basic confirm deals expected damage")
	_check(await _wait_for_no_pending_basic(manager, 5.0), "basic confirm completes recovery")
	_check(int(counts["commit"]) == 1, "basic confirm commits once")
	_check(int(counts["execution"]) == 1, "basic confirm executes once")
	_check(int(counts["resolution"]) == 1, "basic confirm resolves once")
	_check(int(counts["recovery"]) == 1, "basic confirm enters recovery once")
	_check(manager.enemy.current_hp == expected_hp, "spam confirm does not duplicate damage")
	_check(manager.skill_points == initial_sp + BattleManager.SKILL_POINT_GAIN_BASIC, "basic SP reward occurs once after hit")
	_check(not manager.basic_target_highlight.visible, "basic resolution clears target highlight")
	_check(not manager.basic_command_panel.visible, "basic resolution clears confirm/cancel panel")
	_check(manager.state != BattleManager.BattleState.ACTION_RESOLUTION, "basic turn leaves execution state")

	await _free_battle(battle)


func _test_invalid_target_revalidates_before_confirm() -> void:
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.skill_points = BattleManager.START_SKILL_POINTS - 1
	manager.call("_refresh_skill_points_ui")
	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	var initial_sp := manager.skill_points
	manager.enemy.take_damage(manager.enemy.max_hp)
	var confirmed := bool(manager.call("_confirm_basic_attack_command"))
	await _idle_frames(3)

	_check(not confirmed, "dead target cannot commit basic")
	_check(manager.skill_points == initial_sp, "invalid target confirm does not grant SP")
	_check(not manager.basic_command_adapter.has_pending_basic(), "invalid target clears pending command")
	_check(not manager.basic_target_highlight.visible, "invalid target clears highlight")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "invalid target stays on player turn")

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
	var fixture := await _make_battle(false, true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_on_ultimate_pressed")
	await _idle_frames(5)

	_check(manager.state == BattleManager.BattleState.ACTION_RESOLUTION, "legacy ultimate enters action resolution")
	_check(manager.ultimate_energy == 0, "legacy ultimate energy timing is unchanged")
	_check(not manager.basic_command_adapter.has_pending_basic(), "legacy ultimate does not leave basic pending")

	await _free_battle(battle)


func _test_bandit_basic_victory_updates_world_progress() -> void:
	var fixture := await _make_battle(true, true)
	var manager := fixture["manager"] as BattleManager

	_check(manager.is_bandit_encounter, "bandit encounter configuration still loads")
	_check(manager.enemy.combatant_name == "Bandit Captain", "bandit target defaults to captain")
	_check(manager.encounter_victory_scene_path == BattleManager.GRASSLANDS_SCENE_PATH, "bandit victory return scene is unchanged")

	manager.enemy.current_hp = BattleManager.BASIC_ATTACK_DAMAGE
	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	manager.call("_confirm_basic_attack_command")

	_check(await _wait_for_state(manager, BattleManager.BattleState.WIN, 5.0), "bandit basic can win encounter")
	_check(WorldProgress.bandit_defeated, "bandit basic victory updates WorldProgress")
	_check(WorldProgress.active_battle_id == &"", "bandit basic victory clears active encounter")


func _make_battle(
	bandit: bool,
	use_flow: bool,
	use_skill_flow: bool = true
) -> Dictionary:
	WorldProgress.reset_story()
	if bandit:
		WorldProgress.begin_bandit_encounter()
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.use_new_basic_command_flow = use_flow
	manager.use_new_skill_command_flow = use_skill_flow
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
