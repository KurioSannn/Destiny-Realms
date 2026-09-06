class_name BattleEnemyTurnController
extends RefCounted

## Manages enemy turn execution, commit tokens, and duplicate action guards
## for the battle system (Block 9C).

var active_enemy_attack_token: int = 0
var token_sequence: int = 0
var enemy_action_in_progress: bool = false

var enemy_hit_tokens: Dictionary = {}
var enemy_recovery_tokens: Dictionary = {}
var enemy_turn_completion_tokens: Dictionary = {}


func generate_next_token() -> int:
	token_sequence += 1
	active_enemy_attack_token = token_sequence
	enemy_action_in_progress = true
	return token_sequence


func is_committed_enemy_attack(token: int) -> bool:
	return token != 0 and active_enemy_attack_token == token


func enemy_attack_guard(
	token: int,
	is_inside_tree: bool,
	state: int,
	is_battle_over: bool,
	enemy: Node,
	player: Node,
	enemy_turn_state_value: int = 1
) -> bool:
	return (
		is_inside_tree
		and state == enemy_turn_state_value
		and not is_battle_over
		and is_instance_valid(enemy)
		and is_instance_valid(player)
		and is_committed_enemy_attack(token)
	)


func enemy_recovery_guard(
	token: int,
	is_inside_tree: bool,
	state: int,
	is_battle_over: bool,
	enemy: Node,
	player: Node,
	enemy_turn_state_value: int = 1
) -> bool:
	return (
		enemy_attack_guard(token, is_inside_tree, state, is_battle_over, enemy, player, enemy_turn_state_value)
		and enemy_hit_tokens.has(token)
	)


func enemy_turn_completion_guard(
	token: int,
	is_inside_tree: bool,
	state: int,
	is_battle_over: bool,
	enemy: Node,
	player: Node,
	enemy_turn_state_value: int = 1
) -> bool:
	return (
		enemy_attack_guard(token, is_inside_tree, state, is_battle_over, enemy, player, enemy_turn_state_value)
		and enemy_recovery_tokens.has(token)
	)


func consume_enemy_hit(token: int) -> bool:
	if enemy_hit_tokens.has(token):
		return false
	enemy_hit_tokens[token] = true
	return true


func consume_enemy_recovery(token: int) -> bool:
	if enemy_recovery_tokens.has(token):
		return false
	enemy_recovery_tokens[token] = true
	return true


func consume_enemy_turn_completion(token: int) -> bool:
	if enemy_turn_completion_tokens.has(token):
		return false
	enemy_turn_completion_tokens[token] = true
	return true


func clear_enemy_attack_token(token: int) -> void:
	if active_enemy_attack_token == token:
		active_enemy_attack_token = 0
	enemy_action_in_progress = false


func reset_enemy_attack_runtime() -> void:
	active_enemy_attack_token = 0
	enemy_hit_tokens.clear()
	enemy_recovery_tokens.clear()
	enemy_turn_completion_tokens.clear()
	enemy_action_in_progress = false


func execute_attack(manager: Node) -> void:
	var token: int = generate_next_token()
	var enemy = manager.enemy
	var player = manager.player

	var damage: int = enemy.base_attack_damage
	var log_text: String = "Enemy attacks for %d damage." % damage

	await enemy.play_attack_movement(player)
	if not manager._enemy_attack_guard(token):
		clear_enemy_attack_token(token)
		return

	if not consume_enemy_hit(token):
		clear_enemy_attack_token(token)
		return

	manager._play_impact_sfx()
	manager._spawn_enemy_claw_effect(player)
	manager._spawn_hit_spark(player, Color(1.0, 0.4, 0.42, 1.0))
	player.take_damage(damage)
	manager._refresh_player_status_ui()
	manager._show_floating_damage(player, damage)

	if manager.ENEMY_IMPACT_HOLD_SECONDS > 0.0:
		await manager.get_tree().create_timer(manager.ENEMY_IMPACT_HOLD_SECONDS).timeout
		if not manager._enemy_attack_guard(token):
			clear_enemy_attack_token(token)
			return

	await player.play_hit_feedback()
	if not manager._enemy_recovery_guard(token) or not consume_enemy_recovery(token):
		clear_enemy_attack_token(token)
		return
	manager._shake_camera()

	if player.is_defeated():
		if not manager._enemy_turn_completion_guard(token) or not consume_enemy_turn_completion(token):
			clear_enemy_attack_token(token)
			return
		clear_enemy_attack_token(token)
		manager._lose("You were defeated.")
		return

	if not manager._enemy_turn_completion_guard(token) or not consume_enemy_turn_completion(token):
		clear_enemy_attack_token(token)
		return
	clear_enemy_attack_token(token)
	await manager._resume_after_enemy_action(log_text)
