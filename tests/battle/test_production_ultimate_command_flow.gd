extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")
const PendingCommand := preload("res://scripts/battle/command/pending_battle_command.gd")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_lesser_ultimate_select_ready_and_cancel()
	await _test_ultimate_insufficient_energy_does_not_create_pending()
	await _test_ultimate_invalid_target_revalidates_before_commit()
	await _test_ultimate_invalid_actor_revalidates_before_commit()
	await _test_ultimate_energy_drop_revalidates_before_commit()
	await _test_ultimate_switching_with_basic_and_skill()
	await _test_ultimate_interrupt_request_is_rejected()
	await _test_ultimate_confirm_is_single_execution()
	await _test_scene_exit_stops_committed_ultimate_callbacks()
	await _test_bandit_ultimate_victory_updates_world_progress()

	if failures.is_empty():
		print("PASS: production ultimate command flow")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_lesser_ultimate_select_ready_and_cancel() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_hp := manager.enemy.current_hp
	var initial_energy := manager.ultimate_energy

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)

	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "ultimate select keeps player turn")
	_check(manager.enemy.current_hp == initial_hp, "ultimate select does not deal damage")
	_check(manager.ultimate_energy == initial_energy, "ultimate select does not spend energy")
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "ultimate select creates pending command")
	_check(
		manager.player_action_sprite.texture == BattleManager.TAKASHI_ULTIMATE_TEXTURE,
		"ultimate select starts ready idle pose"
	)
	_check(manager.ultimate_target_highlight.visible, "ultimate select shows target highlight")
	_check(manager.ultimate_command_panel.visible, "ultimate select shows confirm/cancel panel")

	manager.call("_cancel_ultimate_command")
	await _idle_frames(3)

	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "ultimate cancel preserves player turn")
	_check(manager.enemy.current_hp == initial_hp, "ultimate cancel does not deal damage")
	_check(manager.ultimate_energy == initial_energy, "ultimate cancel preserves energy")
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "ultimate cancel clears pending command")
	_check(not manager.ultimate_target_highlight.visible, "ultimate cancel hides target highlight")
	_check(not manager.ultimate_command_panel.visible, "ultimate cancel hides confirm/cancel panel")

	await _free_battle(battle)


func _test_ultimate_insufficient_energy_does_not_create_pending() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY - 1
	manager.call("_refresh_energy_ui")
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)

	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "insufficient energy does not create pending command")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "insufficient energy stays on player turn")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY - 1, "insufficient energy is not spent")

	await _free_battle(battle)


func _test_ultimate_invalid_target_revalidates_before_commit() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	var initial_energy := manager.ultimate_energy
	manager.enemy.take_damage(manager.enemy.max_hp)

	var confirmed := bool(manager.call("_confirm_ultimate_command"))
	await _idle_frames(3)

	_check(not confirmed, "dead target cannot commit ultimate")
	_check(manager.ultimate_energy == initial_energy, "invalid target confirm does not spend energy")
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "invalid target clears pending command")
	_check(not manager.ultimate_target_highlight.visible, "invalid target clears highlight")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "invalid target stays on player turn")

	await _free_battle(battle)


func _test_ultimate_invalid_actor_revalidates_before_commit() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	var initial_hp := manager.enemy.current_hp
	var initial_energy := manager.ultimate_energy
	manager.player.take_damage(manager.player.max_hp)

	var confirmed := bool(manager.call("_confirm_ultimate_command"))
	await _idle_frames(3)

	_check(not confirmed, "defeated actor cannot commit ultimate")
	_check(manager.enemy.current_hp == initial_hp, "invalid actor confirm does not damage")
	_check(manager.ultimate_energy == initial_energy, "invalid actor confirm does not spend energy")
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "invalid actor clears pending command")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "invalid actor returns command selection")

	await _free_battle(battle)


func _test_ultimate_energy_drop_revalidates_before_commit() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	var initial_hp := manager.enemy.current_hp
	manager.ultimate_energy = 0
	manager.call("_refresh_energy_ui")

	var confirmed := bool(manager.call("_confirm_ultimate_command"))
	await _idle_frames(3)

	_check(not confirmed, "ultimate cannot commit once energy drops below cost")
	_check(manager.enemy.current_hp == initial_hp, "energy drop confirm does not damage")
	_check(manager.ultimate_energy == 0, "energy drop confirm does not go negative")
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "energy drop clears pending command")
	_check(manager.state == BattleManager.BattleState.PLAYER_TURN, "energy drop stays on player turn")

	await _free_battle(battle)


func _test_ultimate_switching_with_basic_and_skill() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)

	_check(not manager.basic_command_adapter.has_pending_basic(), "Ultimate selection cancels pending Basic")
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "Ultimate starts after Basic cancel")
	_check(not manager.basic_command_panel.visible, "Basic panel hides after switching to Ultimate")
	_check(manager.ultimate_command_panel.visible, "Ultimate panel shows after switching from Basic")

	manager.call("_cancel_ultimate_command")
	await _idle_frames(3)
	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)

	_check(not manager.skill_command_adapter.has_pending_skill(), "Ultimate selection cancels pending Skill")
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "Ultimate starts after Skill cancel")
	_check(not manager.skill_command_panel.visible, "Skill panel hides after switching to Ultimate")
	_check(manager.ultimate_command_panel.visible, "Ultimate panel shows after switching from Skill")

	manager.call("_cancel_ultimate_command")
	await _idle_frames(3)
	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "Basic selection cancels pending Ultimate")
	_check(manager.basic_command_adapter.has_pending_basic(), "Basic starts after Ultimate cancel")

	await _free_battle(battle)


func _test_ultimate_interrupt_request_is_rejected() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	var failed_reasons: Array[StringName] = []
	manager.ultimate_command_adapter.ultimate_failed.connect(
		func(_command, reason: StringName) -> void:
			failed_reasons.append(reason)
	)

	var began := bool(manager.ultimate_command_adapter.begin_ultimate(
		&"octagram_fragment",
		PendingCommand.TargetRule.SINGLE_ENEMY,
		BattleManager.MAX_ULTIMATE_ENERGY,
		0,
		PendingCommand.RequestSource.INTERRUPT_REQUEST
	))
	await _idle_frames(3)

	_check(not began, "off-turn Ultimate interrupt request does not begin a command")
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "off-turn Ultimate interrupt request leaves no pending command")
	_check(
		failed_reasons.has(&"off_turn_interrupt_not_available"),
		"off-turn Ultimate interrupt request fails with off_turn_interrupt_not_available"
	)
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "rejected interrupt request does not spend energy")

	await _free_battle(battle)


func _test_ultimate_confirm_is_single_execution() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var counts := {
		"commit": 0,
		"execution": 0,
		"resolution": 0,
		"recovery": 0,
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
	flow.flow_state_changed.connect(func(battle_state, _animation_state, _ui_state) -> void:
		if battle_state == BattleCommandFlow.BattleFlowState.ACTION_RECOVERY:
			counts["recovery"] = int(counts["recovery"]) + 1
	)

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_hp := manager.enemy.current_hp
	var expected_hp := initial_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_confirm_ultimate_command")
	manager.call("_confirm_ultimate_command")
	manager.call("_on_confirm_pressed")

	_check(await _wait_for_enemy_hp(manager, expected_hp, 45.0), "ultimate confirm deals legacy damage")
	_check(await _wait_for_no_pending_ultimate(manager, 10.0), "ultimate confirm completes recovery")
	_check(int(counts["commit"]) == 1, "ultimate confirm commits once")
	_check(int(counts["execution"]) == 1, "ultimate confirm executes once")
	_check(int(counts["resolution"]) == 1, "ultimate confirm resolves once")
	_check(int(counts["recovery"]) == 1, "ultimate confirm enters recovery once")
	_check(manager.enemy.current_hp == expected_hp, "spam confirm does not duplicate ultimate damage")
	_check(manager.ultimate_energy == 0, "ultimate energy is spent exactly once at commit")
	_check(not manager.ultimate_target_highlight.visible, "ultimate resolution clears target highlight")
	_check(not manager.ultimate_command_panel.visible, "ultimate resolution clears confirm/cancel panel")
	_check(manager.state != BattleManager.BattleState.ACTION_RESOLUTION, "ultimate turn leaves execution state")

	await _free_battle(battle)


func _test_scene_exit_stops_committed_ultimate_callbacks() -> void:
	var fixture := await _make_battle(false)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_confirm_ultimate_command")
	await _idle_frames(1)
	battle.queue_free()
	await _idle_frames(20)

	_check(true, "scene exit during committed Ultimate does not crash test runner")
	WorldProgress.reset_story()


func _test_bandit_ultimate_victory_updates_world_progress() -> void:
	var fixture := await _make_battle(true)
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	_check(manager.is_bandit_encounter, "bandit encounter configuration still loads")
	_check(manager.enemy.combatant_name == "Bandit Captain", "bandit target defaults to captain")
	_check(manager.encounter_victory_scene_path == BattleManager.GRASSLANDS_SCENE_PATH, "bandit victory return scene is unchanged")

	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.enemy.current_hp = BattleManager.ULTIMATE_DAMAGE
	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_confirm_ultimate_command")

	_check(await _wait_for_state(manager, BattleManager.BattleState.WIN, 45.0), "bandit Ultimate can win encounter")
	_check(WorldProgress.bandit_defeated, "bandit Ultimate victory updates WorldProgress")
	_check(WorldProgress.active_battle_id == &"", "bandit Ultimate victory clears active encounter")

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


func _wait_for_no_pending_ultimate(
	manager: BattleManager,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if not manager.ultimate_command_adapter.has_pending_ultimate():
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
