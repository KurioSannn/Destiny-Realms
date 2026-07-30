extends Node

## Block 9C: enemy attack token/guard chain. See
## docs/battle_system_spec.md, "Block 9C implementation status". These
## tests exercise the new guard/consume helpers directly (the same way the
## existing suites poke at private state via `.call()`/direct field access)
## plus one full real-attack integration run, to prove a stray double
## callback can never apply damage twice, call _lose() twice, or call
## _resume_after_enemy_action() twice -- without changing normal single
## -invocation behavior.

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_enemy_hit_consumed_once()
	await _test_enemy_recovery_consumed_once_and_requires_prior_hit()
	await _test_enemy_turn_completion_consumed_once_and_requires_prior_recovery()
	await _test_stale_token_fails_all_guards()
	await _test_victory_invalidates_enemy_attack_token()
	await _test_defeat_invalidates_enemy_attack_token()
	await _test_battle_reset_invalidates_enemy_attack_token()
	await _test_real_enemy_attack_applies_damage_once_and_resumes_once()

	if failures.is_empty():
		print("PASS: enemy attack guard chain")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_enemy_hit_consumed_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var token := 1
	manager.active_enemy_attack_token = token

	var first := bool(manager.call("_consume_enemy_hit", token))
	var second := bool(manager.call("_consume_enemy_hit", token))

	_check(first, "first hit consumption for a fresh token succeeds")
	_check(not second, "second hit consumption for the same token is rejected -- damage can never apply twice")
	_check(manager.enemy_hit_tokens.has(token), "consumed hit token is recorded")

	await _free_battle(battle)


func _test_enemy_recovery_consumed_once_and_requires_prior_hit() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var token := 1
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.active_enemy_attack_token = token

	_check(
		not bool(manager.call("_enemy_recovery_guard", token)),
		"recovery guard fails before the hit for this token has been consumed"
	)

	manager.enemy_hit_tokens[token] = true
	_check(
		bool(manager.call("_enemy_recovery_guard", token)),
		"recovery guard passes once the hit has been consumed for this token"
	)

	var first := bool(manager.call("_consume_enemy_recovery", token))
	var second := bool(manager.call("_consume_enemy_recovery", token))

	_check(first, "first recovery consumption succeeds")
	_check(not second, "second recovery consumption for the same token is rejected")

	await _free_battle(battle)


func _test_enemy_turn_completion_consumed_once_and_requires_prior_recovery() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var token := 1
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.active_enemy_attack_token = token
	manager.enemy_hit_tokens[token] = true

	_check(
		not bool(manager.call("_enemy_turn_completion_guard", token)),
		"turn completion guard fails before recovery for this token has been consumed"
	)

	manager.enemy_recovery_tokens[token] = true
	_check(
		bool(manager.call("_enemy_turn_completion_guard", token)),
		"turn completion guard passes once recovery has been consumed for this token"
	)

	var first := bool(manager.call("_consume_enemy_turn_completion", token))
	var second := bool(manager.call("_consume_enemy_turn_completion", token))

	_check(first, "first turn completion consumption succeeds")
	_check(
		not second,
		"second turn completion consumption for the same token is rejected -- this is what stops "
		+ "_resume_after_enemy_action()/_lose() from ever running twice for one enemy attack"
	)

	await _free_battle(battle)


func _test_stale_token_fails_all_guards() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var stale_token := 1
	manager.state = BattleManager.BattleState.ENEMY_TURN
	manager.active_enemy_attack_token = stale_token
	manager.enemy_hit_tokens[stale_token] = true
	manager.enemy_recovery_tokens[stale_token] = true

	# A newer enemy attack begins and takes over the active token, exactly as
	# _enemy_attack() does at the top of every real invocation.
	manager.active_enemy_attack_token = 2

	_check(
		not bool(manager.call("_is_committed_enemy_attack", stale_token)),
		"a stale token is not considered committed once a newer attack has begun"
	)
	_check(
		not bool(manager.call("_enemy_attack_guard", stale_token)),
		"the base attack guard rejects a stale token"
	)
	_check(
		not bool(manager.call("_enemy_recovery_guard", stale_token)),
		"the recovery guard rejects a stale token even though its hit was already consumed"
	)
	_check(
		not bool(manager.call("_enemy_turn_completion_guard", stale_token)),
		"the turn completion guard rejects a stale token even though its recovery was already consumed"
	)

	await _free_battle(battle)


func _test_victory_invalidates_enemy_attack_token() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.active_enemy_attack_token = 7
	manager.enemy_action_in_progress = true
	manager.enemy_hit_tokens[7] = true

	manager.call("_win", "test victory")
	await _idle_frames(1)

	_check(manager.active_enemy_attack_token == 0, "victory clears the active enemy attack token")
	_check(not manager.enemy_action_in_progress, "victory clears enemy_action_in_progress")
	_check(manager.enemy_hit_tokens.is_empty(), "victory clears enemy hit token history")

	await _free_battle(battle)


func _test_defeat_invalidates_enemy_attack_token() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.active_enemy_attack_token = 9
	manager.enemy_action_in_progress = true
	manager.enemy_recovery_tokens[9] = true

	manager.call("_lose", "test defeat")
	await _idle_frames(1)

	_check(manager.active_enemy_attack_token == 0, "defeat clears the active enemy attack token")
	_check(not manager.enemy_action_in_progress, "defeat clears enemy_action_in_progress")
	_check(manager.enemy_recovery_tokens.is_empty(), "defeat clears enemy recovery token history")

	await _free_battle(battle)


func _test_battle_reset_invalidates_enemy_attack_token() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	manager.active_enemy_attack_token = 3
	manager.enemy_action_in_progress = true
	manager.enemy_turn_completion_tokens[3] = true

	manager.restart_battle()
	await _idle_frames(1)

	_check(manager.active_enemy_attack_token == 0, "restart_battle clears the active enemy attack token")
	_check(not manager.enemy_action_in_progress, "restart_battle clears enemy_action_in_progress")
	_check(
		manager.enemy_turn_completion_tokens.is_empty(),
		"restart_battle clears enemy turn completion token history"
	)

	await _free_battle(battle)


## Full real-attack integration run: proves the guard chain wired into
## _enemy_attack() does not change the normal single-invocation outcome --
## exactly one damage application, exactly one arrival at PLAYER_TURN, and
## a fully cleared token afterward.
func _test_real_enemy_attack_applies_damage_once_and_resumes_once() -> void:
	var fixture := await _make_battle()
	var battle := fixture["battle"] as Node
	var manager := fixture["manager"] as BattleManager

	var initial_player_hp := manager.player.current_hp
	var expected_damage := manager.enemy.base_attack_damage

	manager.call("_begin_enemy_turn")

	_check(
		await _wait_for_player_hp_below(manager, initial_player_hp, 5.0),
		"a real enemy attack still deals damage with the guard chain in place"
	)
	_check(
		manager.player.current_hp == initial_player_hp - expected_damage,
		"a real enemy attack deals damage exactly once, for the unchanged damage amount"
	)
	_check(
		await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0),
		"a real enemy attack still resumes to player turn exactly once"
	)
	_check(
		manager.active_enemy_attack_token == 0,
		"the enemy attack token is cleared once the attack fully resolves"
	)
	_check(
		not manager.enemy_action_in_progress,
		"enemy_action_in_progress is cleared once the attack fully resolves"
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
