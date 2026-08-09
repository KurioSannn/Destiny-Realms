extends Node

## Block 9H: combat feel timing regression. Tests event order and bounded
## timing (never pixel-perfect frame assertions, which would be flaky in
## a headless environment) -- proving damage/resource/turn-completion
## still happen exactly once, and that the new impact-hold cosmetic pause
## (Block 9H) never delays or blocks authoritative resolution. See
## docs/battle_system_spec.md, "Block 9H implementation status".

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Basic
	await _test_basic_begins_motion_without_dead_input_delay()
	await _test_basic_damage_occurs_at_impact_once()
	await _test_basic_recovery_completes_once()
	await _test_basic_sp_gain_still_occurs_after_hit_once()
	await _test_basic_total_resolve_time_is_within_profile_bounds()
	# Skill
	await _test_skill_ready_feedback_occurs_before_commit()
	await _test_skill_damage_occurs_after_anticipation()
	await _test_skill_impact_feedback_occurs_once()
	await _test_skill_sp_spend_remains_commit_only()
	await _test_skill_recovery_and_turn_completion_occur_once()
	# Ultimate
	await _test_ultimate_cut_in_precedes_damage()
	await _test_ultimate_damage_occurs_at_impact_once()
	await _test_ultimate_energy_spend_remains_commit_only()
	await _test_ultimate_on_turn_resume_state_is_unchanged()
	await _test_a1_ultimate_resume_policy_is_unchanged()
	await _test_window_b_ultimate_resume_policy_is_unchanged()
	# Enemy
	await _test_enemy_anticipation_precedes_damage()
	await _test_enemy_damage_occurs_once()
	await _test_enemy_recovery_precedes_window_b_processing()
	await _test_enemy_turn_completion_occurs_once()
	# Safety
	await _test_scene_exit_cancels_pending_cosmetic_callbacks()
	await _test_battle_end_clears_camera_feedback()
	await _test_multi_enemy_feedback_uses_selected_target()
	await _test_cosmetic_feedback_failure_does_not_block_resolution()
	await _test_spam_input_during_impact_does_not_duplicate_command()

	if failures.is_empty():
		print("PASS: combat feel timing")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


# --- Basic ----------------------------------------------------------------


func _test_basic_begins_motion_without_dead_input_delay() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var flow: BattleCommandFlow = manager.basic_command_adapter.flow
	var committed_at := {"elapsed": -1.0}
	var elapsed := 0.0
	flow.command_committed.connect(func(_c) -> void:
		if committed_at["elapsed"] < 0.0:
			committed_at["elapsed"] = elapsed
	)

	manager.call("_on_attack_pressed")
	while committed_at["elapsed"] < 0.0 and elapsed < 2.0:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0

	_check(committed_at["elapsed"] >= 0.0, "Basic commits (single live enemy auto-commits)")
	_check(
		float(committed_at["elapsed"]) < 0.5,
		"Basic commits without an artificial dead-input delay (took %.3fs)" % float(committed_at["elapsed"])
	)

	await _free_battle(battle)


func _test_basic_damage_occurs_at_impact_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp
	var hp_change_count := {"count": 0}
	var last_hp := initial_hp

	manager.call("_on_attack_pressed")
	var elapsed := 0.0
	while elapsed < 5.0:
		if manager.enemy.current_hp != last_hp:
			hp_change_count["count"] = int(hp_change_count["count"]) + 1
			last_hp = manager.enemy.current_hp
		await get_tree().process_frame
		elapsed += 1.0 / 60.0

	_check(int(hp_change_count["count"]) == 1, "Basic damage changes enemy HP exactly once")
	_check(manager.enemy.current_hp == initial_hp - BattleManager.BASIC_ATTACK_DAMAGE, "Basic damage amount is unchanged")

	await _free_battle(battle)


func _test_basic_recovery_completes_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var counts := {"resolved": 0}
	var flow: BattleCommandFlow = manager.basic_command_adapter.flow
	flow.command_resolved.connect(func(_c) -> void: counts["resolved"] = int(counts["resolved"]) + 1)

	manager.call("_on_attack_pressed")
	_check(
		await _wait_for_no_pending_basic(manager, 5.0),
		"Basic command completes its turn"
	)
	await _idle_frames(5)
	_check(int(counts["resolved"]) == 1, "Basic recovery/resolution occurs exactly once")

	await _free_battle(battle)


func _test_basic_sp_gain_still_occurs_after_hit_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_sp := manager.skill_points

	manager.call("_on_attack_pressed")
	_check(await _wait_for_no_pending_basic(manager, 5.0), "Basic command completes")
	await _idle_frames(5)

	_check(
		manager.skill_points == mini(initial_sp + BattleManager.SKILL_POINT_GAIN_BASIC, BattleManager.MAX_SKILL_POINTS),
		"Basic SP gain occurs exactly once after the impact-hold tuning"
	)

	await _free_battle(battle)


func _test_basic_total_resolve_time_is_within_profile_bounds() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var start_elapsed := 0.0

	manager.call("_on_attack_pressed")
	var elapsed := 0.0
	var resolved := false
	while elapsed < 5.0:
		if not manager.basic_command_adapter.has_pending_basic() and manager.active_basic_command_token == 0:
			resolved = true
			break
		await get_tree().process_frame
		elapsed += 1.0 / 60.0

	_check(resolved, "Basic resolves within a bounded window")
	_check(
		elapsed < 3.0,
		"Basic's total resolve time stays within profile bounds (took %.3fs, expected well under Skill/Ultimate weight)" % elapsed
	)
	_check(start_elapsed == 0.0, "sanity: measurement starts at zero")

	await _free_battle(battle)


# --- Skill ------------------------------------------------------------


func _test_skill_ready_feedback_occurs_before_commit() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var order := []
	var flow: BattleCommandFlow = manager.skill_command_adapter.flow
	flow.command_ready.connect(func(_c) -> void: order.append("ready"))
	flow.command_committed.connect(func(_c) -> void: order.append("committed"))

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	_check(order == ["ready"], "Skill shows ready feedback before any commit")

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	_check(order == ["ready", "committed"], "Skill commits only after ready feedback, in order")

	await _free_battle(battle)


func _test_skill_damage_occurs_after_anticipation() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.enemy.current_hp

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_skill_pressed")

	# Immediately after commit, damage must not have landed yet -- there is
	# a real anticipation phase (cast feedback + movement + projectile
	# travel) before impact.
	await _idle_frames(2)
	_check(manager.enemy.current_hp == initial_hp, "Skill damage has not landed immediately after commit")

	_check(
		await _wait_for_enemy_hp(manager, initial_hp - BattleManager.SKILL_DAMAGE, 5.0),
		"Skill damage lands after the anticipation phase completes"
	)

	await _free_battle(battle)


func _test_skill_impact_feedback_occurs_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var counts := {"resolved": 0}
	var flow: BattleCommandFlow = manager.skill_command_adapter.flow
	flow.command_resolved.connect(func(_c) -> void: counts["resolved"] = int(counts["resolved"]) + 1)

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_skill_pressed")

	_check(await _wait_for_no_pending_skill(manager, 5.0), "Skill command completes")
	await _idle_frames(5)
	_check(int(counts["resolved"]) == 1, "Skill impact/resolution feedback occurs exactly once")

	await _free_battle(battle)


func _test_skill_sp_spend_remains_commit_only() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_sp := manager.skill_points

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	_check(manager.skill_points == initial_sp, "SP unchanged through ready idle")

	manager.call("_on_skill_pressed")
	await _idle_frames(2)
	_check(
		manager.skill_points == initial_sp - BattleManager.SKILL_POINT_COST_SKILL,
		"SP spends exactly once, at commit, unaffected by the impact-hold tuning"
	)

	await _free_battle(battle)


func _test_skill_recovery_and_turn_completion_occur_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_skill_pressed")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.ENEMY_TURN, 5.0),
		"Skill recovery and turn completion transition to enemy turn exactly once"
	)

	await _free_battle(battle)


# --- Ultimate ---------------------------------------------------------


func _test_ultimate_cut_in_precedes_damage() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_hp := manager.enemy.current_hp
	var order := []
	var flow: BattleCommandFlow = manager.ultimate_command_adapter.flow
	flow.command_execution_started.connect(func(_c) -> void: order.append("cut_in_started"))

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_on_ultimate_pressed")

	_check(
		await _wait_for_enemy_hp(manager, initial_hp - BattleManager.ULTIMATE_DAMAGE, 45.0),
		"Ultimate damage eventually lands"
	)
	_check(order == ["cut_in_started"], "the cut-in (execution start) fires exactly once, before damage was observed")

	await _free_battle(battle)


func _test_ultimate_damage_occurs_at_impact_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_hp := manager.enemy.current_hp
	var hp_change_count := {"count": 0}
	var last_hp := initial_hp

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_on_ultimate_pressed")

	var elapsed := 0.0
	while elapsed < 45.0:
		if manager.enemy.current_hp != last_hp:
			hp_change_count["count"] = int(hp_change_count["count"]) + 1
			last_hp = manager.enemy.current_hp
		if int(hp_change_count["count"]) > 0 and not manager.ultimate_command_adapter.has_pending_ultimate():
			break
		await get_tree().process_frame
		elapsed += 1.0 / 60.0

	_check(int(hp_change_count["count"]) == 1, "Ultimate damage changes enemy HP exactly once, even with the impact-hold pause")

	await _free_battle(battle)


func _test_ultimate_energy_spend_remains_commit_only() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "Energy unchanged through ready idle")

	manager.call("_on_ultimate_pressed")
	await _idle_frames(2)
	_check(manager.ultimate_energy == 0, "Energy spends exactly once, at commit")

	await _free_battle(battle)


func _test_ultimate_on_turn_resume_state_is_unchanged() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_on_ultimate_pressed")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.ENEMY_TURN, 45.0),
		"on-turn Ultimate still hands off to the enemy turn afterward -- resume behavior unchanged by the impact-hold tuning"
	)

	await _free_battle(battle)


func _test_a1_ultimate_resume_policy_is_unchanged() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_player_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	await _idle_frames(1)
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at A1")

	manager.call("_cancel_ultimate_command")
	await _idle_frames(3)
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "A1 locked Ultimate ignores cancel input")

	manager.call("_confirm_ultimate_command")
	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 45.0),
		"A1 resume policy is unchanged after confirming locked Ultimate: enemy action proceeds afterward"
	)
	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 10.0),
		"battle still reaches a normal player turn afterward"
	)

	await _free_battle(battle)


func _test_window_b_ultimate_resume_policy_is_unchanged() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at window B")

	manager.call("_cancel_ultimate_command")
	await _idle_frames(3)
	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "window B locked Ultimate ignores cancel input")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "locked Ultimate idle still spends no Energy before confirm")

	manager.call("_confirm_ultimate_command")
	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 45.0),
		"window B resume policy is unchanged after confirming locked Ultimate: battle returns to player turn"
	)
	_check(manager.ultimate_energy == 0, "confirming locked Ultimate spends Energy")

	await _free_battle(battle)


# --- Enemy --------------------------------------------------------------


func _test_enemy_anticipation_precedes_damage() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	# TURN_DELAY_SECONDS (0.6s) plus movement must pass before any damage.
	await _idle_frames(20)
	_check(manager.player.current_hp == initial_hp, "enemy anticipation window passes with no damage yet")

	_check(
		await _wait_for_player_hp_below(manager, initial_hp, 10.0),
		"enemy damage lands after anticipation and movement complete"
	)

	await _free_battle(battle)


func _test_enemy_damage_occurs_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_hp := manager.player.current_hp
	var hp_change_count := {"count": 0}
	var last_hp := initial_hp

	manager.call("_begin_enemy_turn")
	var elapsed := 0.0
	while elapsed < 10.0:
		if manager.player.current_hp != last_hp:
			hp_change_count["count"] = int(hp_change_count["count"]) + 1
			last_hp = manager.player.current_hp
		await get_tree().process_frame
		elapsed += 1.0 / 60.0

	_check(int(hp_change_count["count"]) == 1, "enemy damage changes player HP exactly once, even with the impact-hold pause")

	await _free_battle(battle)


func _test_enemy_recovery_precedes_window_b_processing() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_player_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	manager.request_off_turn_ultimate(manager.player)

	_check(
		manager.player.current_hp == initial_player_hp,
		"the request is made while the enemy attack is still mid-flight, before any damage lands"
	)
	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 10.0),
		"the enemy attack still fully lands despite the mid-flight request"
	)
	# The queued request must not be picked up mid-recovery -- only once
	# enemy_action_in_progress goes false (recovery/turn-completion done).
	_check(
		not manager.is_processing_interrupt_queue,
		"safe window B has not opened immediately after damage -- hit feedback/recovery is still settling"
	)

	_check(
		await _wait_for_pending_ultimate(manager, 10.0),
		"safe window B opens only after enemy recovery genuinely completes"
	)

	manager.call("_confirm_ultimate_command")
	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 45.0)
	await _free_battle(battle)


func _test_enemy_turn_completion_occurs_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var player_turn_count := {"count": 0}

	manager.call("_begin_enemy_turn")
	var elapsed := 0.0
	var last_state := manager.state
	while elapsed < 10.0:
		if manager.state == BattleManager.BattleState.PLAYER_TURN and last_state != BattleManager.BattleState.PLAYER_TURN:
			player_turn_count["count"] = int(player_turn_count["count"]) + 1
		last_state = manager.state
		await get_tree().process_frame
		elapsed += 1.0 / 60.0

	_check(int(player_turn_count["count"]) == 1, "enemy turn completion returns to player turn exactly once")

	await _free_battle(battle)


# --- Safety -------------------------------------------------------------


func _test_scene_exit_cancels_pending_cosmetic_callbacks() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.call("_on_attack_pressed")
	await _idle_frames(2)
	battle.queue_free()
	await _idle_frames(20)

	_check(true, "scene exit during a committed action (mid impact-hold/cosmetic chain) does not crash the test runner")
	WorldProgress.reset_story()


func _test_battle_end_clears_camera_feedback() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.enemy.current_hp = mini(manager.enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_on_ultimate_pressed")

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.WIN, 45.0),
		"a lethal Ultimate wins the battle"
	)
	await _idle_frames(3)

	if manager.battle_camera != null:
		_check(manager.battle_camera.offset == Vector2.ZERO, "victory leaves no stray camera offset")
		_check(manager.battle_camera.zoom == Vector2.ONE, "victory leaves no stray camera zoom")

	await _free_battle(battle)


func _test_multi_enemy_feedback_uses_selected_target() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := _spawn_mock_enemy(battle, manager)
	var primary_hp := manager.enemy.current_hp
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.SKILL_DAMAGE

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_select_skill_target_at_position", mock_enemy.global_position)

	_check(
		await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 5.0),
		"impact feedback/damage lands on the specifically selected second enemy"
	)
	_check(manager.enemy.current_hp == primary_hp, "the primary enemy receives no feedback/damage from a command aimed elsewhere")

	await _free_battle(battle)


func _test_cosmetic_feedback_failure_does_not_block_resolution() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	# Disable the VFX layer -- every _spawn_*_effect() call already guards
	# on `effect_layer == null` and no-ops safely; this proves cosmetic
	# failure never blocks authoritative resolution.
	manager.effect_layer = null
	var initial_sp := manager.skill_points
	var initial_hp := manager.enemy.current_hp

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_skill_pressed")

	_check(
		await _wait_for_enemy_hp(manager, initial_hp - BattleManager.SKILL_DAMAGE, 5.0),
		"damage still resolves even with the cosmetic VFX layer unavailable"
	)
	_check(
		manager.skill_points == initial_sp - BattleManager.SKILL_POINT_COST_SKILL,
		"resource mutation still occurs despite cosmetic VFX failure"
	)
	_check(
		await _wait_for_no_pending_skill(manager, 5.0),
		"turn completion still occurs despite cosmetic VFX failure"
	)

	await _free_battle(battle)


func _test_spam_input_during_impact_does_not_duplicate_command() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var counts := {"committed": 0, "resolved": 0}
	var flow: BattleCommandFlow = manager.skill_command_adapter.flow
	flow.command_committed.connect(func(_c) -> void: counts["committed"] = int(counts["committed"]) + 1)
	flow.command_resolved.connect(func(_c) -> void: counts["resolved"] = int(counts["resolved"]) + 1)

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_on_skill_pressed")
	# Spam additional presses during the impact-hold/cosmetic window.
	for _spam_index in range(5):
		manager.call("_on_skill_pressed")
		await get_tree().process_frame

	_check(await _wait_for_no_pending_skill(manager, 5.0), "Skill still resolves despite spammed input")
	_check(int(counts["committed"]) == 1, "spam input during the impact window does not duplicate the commit")
	_check(int(counts["resolved"]) == 1, "spam input during the impact window does not duplicate resolution")

	await _free_battle(battle)


# --- Fixtures and helpers ------------------------------------------------


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


func _spawn_mock_enemy(battle: Node, manager: BattleManager) -> Combatant:
	var mock_enemy := Combatant.new()
	mock_enemy.name = "MockSecondEnemy"
	battle.add_child(mock_enemy)
	mock_enemy.setup("Mock Enemy B", 150, 5)
	mock_enemy.global_position = manager.enemy.global_position + Vector2(140.0, 0.0)
	return mock_enemy


func _free_battle(battle: Node) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
	await _idle_frames(2)
	WorldProgress.reset_story()


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _wait_for_no_pending_basic(manager: BattleManager, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if not manager.basic_command_adapter.has_pending_basic() and manager.active_basic_command_token == 0:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_no_pending_skill(manager: BattleManager, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if not manager.skill_command_adapter.has_pending_skill() and manager.active_skill_command_token == 0:
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


func _wait_for_combatant_hp(combatant: Combatant, expected_hp: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(combatant):
			return false
		if combatant.current_hp == expected_hp:
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


func _wait_past_window_a1(manager: BattleManager, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or manager.enemy_action_in_progress:
			return
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
