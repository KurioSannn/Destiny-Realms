extends Node

## Block 9G: multi-enemy targeting production hardening. Proves the
## production Basic/Skill/Ultimate command flow (Block 8.5/9E UX,
## Block 9B/9F off-turn queue) behaves correctly when more than one live
## enemy exists in the battle -- target selection, target validity,
## dead/stale target handling, no auto-retarget after commit, no
## duplicate resource/damage/turn-completion, and correct victory
## semantics (killing one of several enemies must not end the battle).
##
## The production battle scene only ever spawns one `Enemy` node
## (`@onready var enemy: Combatant = $"../Enemy"` in battle_manager.gd);
## a second Combatant is added here as a direct child of the battle root,
## exactly mirroring the pattern already used by
## test_production_skill_command_flow.gd/test_production_ultimate_command_flow.gd
## since Block 8.5/9B (`_spawn_mock_enemy`) -- this is not a new
## architecture, just this suite's dedicated, comprehensive use of an
## existing, already-tested harness technique. Target *enumeration*
## (`_get_basic_attack_candidate_targets()` and its Skill/Ultimate
## equivalents) already scans the battle scene tree for every non-player
## Combatant, so no BattleManager changes were needed to make two enemies
## selectable -- see docs/battle_system_spec.md, "Block 9G implementation
## status" for the full audit. The one real bug this block fixed:
## `_finish_player_action()`/`_finish_interrupt_ultimate_action()` used to
## check `enemy.is_defeated()` (the single scene-node reference) for
## victory, which would have incorrectly ended a multi-enemy battle the
## moment that one node died -- replaced with `_all_enemies_defeated()`.

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Basic
	await _test_basic_with_two_enemies_waits_for_target()
	await _test_basic_selected_target_is_only_enemy_damaged()
	await _test_basic_one_remaining_enemy_auto_targets_and_commits()
	await _test_basic_invalid_target_does_not_commit()
	await _test_basic_sp_gain_occurs_once_after_selected_target_hit()
	# Skill
	await _test_skill_with_two_enemies_enters_ready_target_selection()
	await _test_skill_selected_target_receives_damage_only()
	await _test_skill_cancel_preserves_sp_and_clears_target()
	await _test_skill_target_dies_before_commit_does_not_spend_sp()
	await _test_skill_commit_spends_sp_once()
	# Ultimate
	await _test_ultimate_selected_target_receives_damage_only()
	await _test_ultimate_locked_idle_preserves_energy()
	await _test_ultimate_target_dies_before_commit_does_not_spend_energy()
	await _test_ultimate_commit_spends_energy_once()
	# Target stability
	await _test_committed_command_does_not_retarget_after_selection_changes()
	await _test_dead_target_is_not_auto_replaced_by_another_enemy()
	await _test_target_cleanup_on_victory()
	await _test_turn_completion_occurs_once_after_multi_enemy_command()
	# Victory semantics
	await _test_killing_one_of_two_enemies_does_not_end_battle()
	await _test_killing_last_enemy_ends_battle_once()
	# Off-turn interrupt compatibility
	await _test_a1_ultimate_killing_one_enemy_does_not_end_multi_enemy_battle()
	await _test_a1_ultimate_target_is_stable_before_enemy_commit()
	await _test_window_b_ultimate_target_is_stable_after_enemy_recovery()

	if failures.is_empty():
		print("PASS: multi-enemy targeting production")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


# --- Basic ------------------------------------------------------------


func _test_basic_with_two_enemies_waits_for_target() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var primary_hp := manager.enemy.current_hp
	var mock_hp := mock_enemy.current_hp
	var initial_sp := manager.skill_points

	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	var command: PendingBattleCommand = manager.basic_command_adapter.get_pending_command()
	_check(command != null and command.is_committed, "Basic with two live enemies auto-commits on 1x press to active target")
	_check(await _wait_for_combatant_hp(manager.enemy, primary_hp - BattleManager.BASIC_ATTACK_DAMAGE, 5.0), "Basic damages default target")
	_check(mock_enemy.current_hp == mock_hp, "second enemy untouched")

	await _free_battle(battle)


func _test_basic_selected_target_is_only_enemy_damaged() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var primary_hp := manager.enemy.current_hp
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.BASIC_ATTACK_DAMAGE

	manager._global_selected_target = mock_enemy
	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	_check(await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 5.0), "Basic deals damage to the targeted enemy on 1x press")
	_check(manager.enemy.current_hp == primary_hp, "Basic does not also damage the primary enemy")

	await _free_battle(battle)


func _test_basic_one_remaining_enemy_auto_targets_and_commits() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	mock_enemy.current_hp = 0
	var primary_hp := manager.enemy.current_hp
	var expected_primary_hp := primary_hp - BattleManager.BASIC_ATTACK_DAMAGE

	manager.call("_on_attack_pressed")

	_check(
		await _wait_for_combatant_hp(manager.enemy, expected_primary_hp, 5.0),
		"with only one live enemy remaining, Basic auto-targets and auto-commits without a target click"
	)

	await _free_battle(battle)


func _test_basic_invalid_target_does_not_commit() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var primary_hp := manager.enemy.current_hp
	var initial_sp := manager.skill_points

	var selected := bool(manager.call("_select_basic_target_at_position", Vector2(-9999.0, -9999.0)))
	_check(not selected, "clicking empty space does not select any target")
	_check(manager.enemy.current_hp == primary_hp, "an invalid click deals no damage")
	_check(manager.skill_points == initial_sp, "an invalid click does not gain SP")

	await _free_battle(battle)


func _test_basic_sp_gain_occurs_once_after_selected_target_hit() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var initial_sp := manager.skill_points
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.BASIC_ATTACK_DAMAGE

	manager._global_selected_target = mock_enemy
	manager.call("_on_attack_pressed")
	await _idle_frames(3)

	_check(await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 5.0), "Basic hit resolves")
	await _idle_frames(3)
	_check(
		manager.skill_points == mini(initial_sp + BattleManager.SKILL_POINT_GAIN_BASIC, BattleManager.MAX_SKILL_POINTS),
		"SP gain happens exactly once after the selected target is hit"
	)

	await _free_battle(battle)


# --- Skill --------------------------------------------------------------


func _test_skill_with_two_enemies_enters_ready_target_selection() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_sp := manager.skill_points

	manager.call("_on_skill_pressed")
	await _idle_frames(3)

	_check(manager.skill_command_adapter.has_pending_skill(), "Skill with two live enemies opens ready idle")
	_check(manager.skill_points == initial_sp, "ready idle does not spend SP")
	_check(not manager.skill_command_panel.visible, "no confirm/cancel panel (Block 9E UX unchanged)")

	await _free_battle(battle)


func _test_skill_selected_target_receives_damage_only() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var primary_hp := manager.enemy.current_hp
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.SKILL_DAMAGE

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	var committed := bool(manager.call("_select_skill_target_at_position", mock_enemy.global_position))

	_check(committed, "clicking the second enemy commits Skill to it")
	_check(await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 5.0), "Skill deals damage to the clicked enemy")
	_check(manager.enemy.current_hp == primary_hp, "Skill does not also damage the primary enemy")

	await _free_battle(battle)


func _test_skill_cancel_preserves_sp_and_clears_target() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_sp := manager.skill_points

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_cancel_skill_command")
	await _idle_frames(3)

	_check(not manager.skill_command_adapter.has_pending_skill(), "cancel clears the pending Skill")
	_check(manager.skill_points == initial_sp, "cancel does not spend SP")
	_check(not manager.skill_target_highlight.visible, "cancel hides the target highlight")

	await _free_battle(battle)


func _test_skill_target_dies_before_commit_does_not_spend_sp() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var initial_sp := manager.skill_points

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	var command: PendingBattleCommand = manager.skill_command_adapter.get_pending_command()
	var auto_selected := command.selected_targets[0] as Combatant
	auto_selected.current_hp = 0

	var confirmed := bool(manager.call("_confirm_skill_command"))
	await _idle_frames(3)

	_check(not confirmed, "Skill cannot commit once its selected target has died")
	_check(manager.skill_points == initial_sp, "a dead-target commit attempt does not spend SP")
	_check(not manager.skill_command_adapter.has_pending_skill(), "a dead-target commit attempt clears the pending command rather than leaving it corrupted")

	await _free_battle(battle)


func _test_skill_commit_spends_sp_once() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var initial_sp := manager.skill_points
	var expected_sp := initial_sp - BattleManager.SKILL_POINT_COST_SKILL
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.SKILL_DAMAGE

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_select_skill_target_at_position", mock_enemy.global_position)
	# Spam commit through every entry point -- must not double-spend.
	manager.call("_confirm_skill_command")
	manager.call("_on_skill_pressed")

	_check(await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 5.0), "Skill resolves")
	_check(manager.skill_points == expected_sp, "spam commit spends SP exactly once")

	await _free_battle(battle)


# --- Ultimate ------------------------------------------------------------


func _test_ultimate_selected_target_receives_damage_only() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var primary_hp := manager.enemy.current_hp
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	var committed := bool(manager.call("_select_ultimate_target_at_position", mock_enemy.global_position))

	_check(committed, "clicking the second enemy commits Ultimate to it")
	_check(await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 45.0), "Ultimate deals damage to the clicked enemy")
	_check(manager.enemy.current_hp == primary_hp, "Ultimate does not also damage the primary enemy")

	await _free_battle(battle)


func _test_ultimate_locked_idle_preserves_energy() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_cancel_ultimate_command")
	await _idle_frames(3)

	_check(manager.ultimate_command_adapter.has_pending_ultimate(), "cancel input does not clear locked Ultimate")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "locked Ultimate idle does not spend Energy")

	await _free_battle(battle)


func _test_ultimate_target_dies_before_commit_does_not_spend_energy() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	var command: PendingBattleCommand = manager.ultimate_command_adapter.get_pending_command()
	var auto_selected := command.selected_targets[0] as Combatant
	auto_selected.current_hp = 0

	var confirmed := bool(manager.call("_confirm_ultimate_command"))
	await _idle_frames(3)

	_check(not confirmed, "Ultimate cannot commit once its selected target has died")
	_check(manager.ultimate_energy == BattleManager.MAX_ULTIMATE_ENERGY, "a dead-target commit attempt does not spend Energy")
	_check(not manager.ultimate_command_adapter.has_pending_ultimate(), "a dead-target commit attempt clears the pending command")

	await _free_battle(battle)


func _test_ultimate_commit_spends_energy_once() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_select_ultimate_target_at_position", mock_enemy.global_position)
	manager.call("_confirm_ultimate_command")
	manager.call("_on_ultimate_pressed")

	_check(await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 45.0), "Ultimate resolves")
	_check(manager.ultimate_energy == 0, "spam commit spends Energy exactly once")

	await _free_battle(battle)


# --- Target stability ------------------------------------------------


func _test_committed_command_does_not_retarget_after_selection_changes() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var primary_hp := manager.enemy.current_hp
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.SKILL_DAMAGE

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	var committed := bool(manager.call("_select_skill_target_at_position", mock_enemy.global_position))
	_check(committed, "clicking the second enemy commits Skill to it")

	# Execution is now in flight. A click on a different enemy afterward
	# must not retarget the already-committed command.
	var retarget_attempt := bool(manager.call("_select_skill_target_at_position", manager.enemy.global_position))
	_check(not retarget_attempt, "clicking a different enemy after commit is rejected, not applied")

	_check(
		await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 5.0),
		"damage still lands on the originally committed target"
	)
	_check(manager.enemy.current_hp == primary_hp, "the primary enemy -- clicked after commit -- takes no damage")

	await _free_battle(battle)


func _test_dead_target_is_not_auto_replaced_by_another_enemy() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var initial_sp := manager.skill_points

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	var command: PendingBattleCommand = manager.skill_command_adapter.get_pending_command()
	var auto_selected := command.selected_targets[0] as Combatant
	auto_selected.current_hp = 0
	var other_enemy := manager.enemy if auto_selected != manager.enemy else mock_enemy
	var other_enemy_hp := other_enemy.current_hp

	var confirmed := bool(manager.call("_confirm_skill_command"))
	await _idle_frames(3)

	_check(not confirmed, "commit fails rather than silently retargeting to the other live enemy")
	_check(other_enemy.current_hp == other_enemy_hp, "the still-alive other enemy is never auto-targeted as a replacement")
	_check(manager.skill_points == initial_sp, "no SP spent when auto-retargeting did not happen")

	await _free_battle(battle)


func _test_target_cleanup_on_victory() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	mock_enemy.current_hp = 0
	manager.enemy.current_hp = mini(manager.enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_select_ultimate_target_at_position", manager.enemy.global_position)

	_check(
		await _wait_for_state(manager, BattleManager.BattleState.WIN, 45.0),
		"killing the last live enemy wins the battle"
	)
	_check(not manager.ultimate_target_highlight.visible, "victory hides the Ultimate target highlight")
	_check(not manager.skill_target_highlight.visible, "victory hides the Skill target highlight")
	_check(not manager.basic_target_highlight.visible, "victory hides the Basic target highlight")

	await _free_battle(battle)


func _test_turn_completion_occurs_once_after_multi_enemy_command() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var counts := {"resolution": 0}
	var flow: BattleCommandFlow = manager.skill_command_adapter.flow
	flow.command_resolved.connect(func(_c) -> void: counts["resolution"] = int(counts["resolution"]) + 1)

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_select_skill_target_at_position", mock_enemy.global_position)

	_check(
		await _wait_for_no_pending_skill(manager, 5.0),
		"multi-enemy Skill command completes its turn"
	)
	_check(int(counts["resolution"]) == 1, "turn completion (resolution) occurs exactly once")

	await _free_battle(battle)


# --- Victory semantics ------------------------------------------------


func _test_killing_one_of_two_enemies_does_not_end_battle() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	mock_enemy.current_hp = mini(mock_enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_select_ultimate_target_at_position", mock_enemy.global_position)

	_check(
		await _wait_for_combatant_defeated(mock_enemy, 45.0),
		"the targeted second enemy is defeated"
	)
	await _idle_frames(5)
	_check(manager.state != BattleManager.BattleState.WIN, "killing only one of two enemies does not end the battle")
	_check(not manager.enemy.is_defeated(), "the primary enemy is unaffected and still alive")

	await _free_battle(battle)


func _test_killing_last_enemy_ends_battle_once() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	var win_count := {"count": 0}
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	# Kill the second enemy outright first.
	mock_enemy.current_hp = 0
	manager.enemy.current_hp = mini(manager.enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	manager.call("_select_ultimate_target_at_position", manager.enemy.global_position)

	var elapsed := 0.0
	while elapsed < 45.0:
		if manager.state == BattleManager.BattleState.WIN:
			win_count["count"] = int(win_count["count"]) + 1
			break
		await get_tree().process_frame
		elapsed += 1.0 / 60.0

	_check(int(win_count["count"]) == 1, "killing the last live enemy ends the battle exactly once")

	await _free_battle(battle)


# --- Off-turn interrupt compatibility ------------------------------------


func _test_a1_ultimate_killing_one_enemy_does_not_end_multi_enemy_battle() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	mock_enemy.current_hp = mini(mock_enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)
	var initial_player_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	await get_tree().process_frame
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at A1")

	manager.call("_select_ultimate_target_at_position", mock_enemy.global_position)

	_check(
		await _wait_for_combatant_defeated(mock_enemy, 45.0),
		"the A1 Ultimate defeats the targeted second enemy"
	)
	_check(manager.state != BattleManager.BattleState.WIN, "killing one of two enemies at A1 does not end the battle")
	_check(not manager.enemy.is_defeated(), "the primary enemy is unaffected")

	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 15.0),
		"the primary enemy's own attack proceeds normally afterward, since the battle continues"
	)
	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 10.0),
		"battle returns to a normal player turn"
	)

	await _free_battle(battle)


func _test_a1_ultimate_target_is_stable_before_enemy_commit() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var primary_hp := manager.enemy.current_hp
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_begin_enemy_turn")
	await get_tree().process_frame
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at A1")

	manager.call("_select_ultimate_target_at_position", mock_enemy.global_position)

	_check(
		await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 45.0),
		"the A1 Ultimate deals damage to the specifically selected second enemy"
	)
	_check(manager.enemy.current_hp == primary_hp, "the primary enemy is untouched by an A1 Ultimate aimed at the second enemy")

	await _free_battle(battle)


func _test_window_b_ultimate_target_is_stable_after_enemy_recovery() -> void:
	var fixture := await _make_multi_enemy_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager
	var mock_enemy := fixture["mock_enemy"] as Combatant
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var primary_hp := manager.enemy.current_hp
	var expected_mock_hp := mock_enemy.current_hp - BattleManager.ULTIMATE_DAMAGE

	manager.call("_begin_enemy_turn")
	await _wait_past_window_a1(manager, 5.0)
	manager.request_off_turn_ultimate(manager.player)
	_check(await _wait_for_pending_ultimate(manager, 10.0), "queued Ultimate reaches ready idle at window B")

	manager.call("_select_ultimate_target_at_position", mock_enemy.global_position)

	_check(
		await _wait_for_combatant_hp(mock_enemy, expected_mock_hp, 45.0),
		"the window B Ultimate deals damage to the specifically selected second enemy"
	)
	_check(manager.enemy.current_hp == primary_hp, "the primary enemy is untouched by a window B Ultimate aimed at the second enemy")

	await _free_battle(battle)


# --- Fixtures and helpers ------------------------------------------------


func _make_multi_enemy_battle() -> Dictionary:
	WorldProgress.reset_story()
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.use_new_basic_command_flow = true
	manager.use_new_skill_command_flow = true
	manager.use_new_ultimate_command_flow = true
	get_tree().root.add_child(battle)
	await _idle_frames(8)
	var mock_enemy := _spawn_mock_enemy(battle, manager)
	return {
		"battle": battle,
		"manager": manager,
		"mock_enemy": mock_enemy,
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


func _wait_for_combatant_defeated(combatant: Combatant, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(combatant):
			return false
		if combatant.is_defeated():
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


func _wait_for_no_pending_skill(manager: BattleManager, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if not manager.skill_command_adapter.has_pending_skill():
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
