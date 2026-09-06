extends Node
class_name TakashiBasicAction

## Handles execution, visual impacts, animations, and damage resolution for Takashi's Basic Attack (Void Strike).


func start_legacy_basic_attack(manager: Node) -> void:
	if manager.state != manager.BattleState.PLAYER_TURN or manager._is_battle_over():
		return
	manager.state = manager.BattleState.ACTION_RESOLUTION
	manager._set_player_action_texture(manager.TAKASHI_BASIC_TEXTURE)
	manager._update_action_buttons(false)
	manager.ui.set_battle_input_enabled(false)
	manager.ui.set_turn_text("Void Strike")
	manager.ui.set_battle_log("Void Strike!")
	await resolve_basic_attack(manager, manager.enemy)


func execute_committed_basic_attack(manager: Node, command: PendingBattleCommand) -> void:
	if not manager._uses_new_basic_command_flow():
		return
	if not manager._is_committed_basic_command(command):
		return
	if not manager.basic_command_adapter.execute_committed_command():
		return

	var target: Combatant = manager._selected_basic_target(command)
	if target == null:
		manager._abort_committed_basic_command(command, &"target_missing_during_execution")
		return

	manager.active_basic_command_token = command.commit_token
	manager.state = manager.BattleState.ACTION_RESOLUTION
	manager._set_player_action_texture(manager.TAKASHI_BASIC_TEXTURE)
	if manager.battle_presentation_3d != null:
		manager.battle_presentation_3d.play_party_attack()
	manager.ui.set_turn_text("Void Strike")
	manager.ui.set_battle_log("Void Strike!")
	await resolve_basic_attack(manager, target, command)


func resolve_basic_attack(
	manager: Node,
	target: Combatant = null,
	command: PendingBattleCommand = null
) -> void:
	if manager.state != manager.BattleState.ACTION_RESOLUTION:
		return
	if target == null:
		target = manager.enemy
	if not manager._basic_execution_guard(command, target):
		return

	var damage: int = manager.BASIC_ATTACK_DAMAGE
	var energy_gain: int = manager.BASIC_ATTACK_ENERGY

	manager._play_basic_sfx()
	await manager.player.play_attack_movement(target)
	if not is_instance_valid(manager) or manager.state != manager.BattleState.ACTION_RESOLUTION:
		return
	if not manager._basic_execution_guard(command, target):
		return

	spawn_basic_slash_effect(manager, target)
	await manager.get_tree().create_timer(0.08).timeout
	if not is_instance_valid(manager) or manager.state != manager.BattleState.ACTION_RESOLUTION:
		return
	if not manager._basic_execution_guard(command, target):
		return
	if command != null and not manager.basic_command_adapter.begin_resolution(command):
		return

	target.take_damage(damage)
	manager._show_floating_damage(target, damage)
	if manager.BASIC_IMPACT_HOLD_SECONDS > 0.0:
		await manager.get_tree().create_timer(manager.BASIC_IMPACT_HOLD_SECONDS).timeout
		if not is_instance_valid(manager) or manager.state != manager.BattleState.ACTION_RESOLUTION or not manager._basic_execution_guard(command, target, false):
			return
	await play_basic_cetar_impact(manager, target, command)
	if not is_instance_valid(manager) or manager.state != manager.BattleState.ACTION_RESOLUTION:
		return
	if not manager._basic_execution_guard(command, target, false):
		return

	await target.play_hit_feedback()
	if not is_instance_valid(manager) or not manager._basic_execution_guard(command, target, false):
		return
	manager._shake_camera()
	manager._add_ultimate_energy(energy_gain)
	manager._add_skill_points(manager.SKILL_POINT_GAIN_BASIC)
	var log_text := "Void Strike deals %d damage, gains %d energy, and restores %d Skill Point." % [damage, energy_gain, manager.SKILL_POINT_GAIN_BASIC]
	if command != null:
		manager._finish_basic_command_resolution(command, log_text)
	else:
		manager._finish_player_action(log_text)


func play_basic_cetar_impact(
	manager: Node,
	target: Node2D,
	command: PendingBattleCommand = null
) -> void:
	if not is_instance_valid(manager):
		return
	manager._play_sring_sfx()
	if manager.battle_vfx != null:
		manager.battle_vfx.play_sriing_burst(target.global_position, manager.BASIC_CETAR_TEXT_RISE)
	manager._shake_target_once(target, manager.BASIC_CETAR_TARGET_SHAKE * 0.65, manager.BASIC_CETAR_INTERVAL * 0.75)
	manager._shake_camera_with_strength(manager.BASIC_CETAR_CAMERA_SHAKE * 0.65)
	await manager.get_tree().create_timer(0.045).timeout

	if not is_instance_valid(manager):
		return

	for hit_index in range(manager.BASIC_CETAR_HIT_COUNT):
		if not is_instance_valid(manager) or not manager._basic_impact_guard(command, target):
			return

		manager._play_cetar_sfx(hit_index)
		if manager.battle_vfx != null:
			manager.battle_vfx.play_cetar_hit_burst(target.global_position, hit_index, manager.BASIC_CETAR_TEXT_RISE)
		manager._shake_target_once(target, manager.BASIC_CETAR_TARGET_SHAKE + float(hit_index) * 1.5, manager.BASIC_CETAR_INTERVAL * 0.75)
		manager._shake_camera_with_strength(manager.BASIC_CETAR_CAMERA_SHAKE + float(hit_index) * 0.8)
		await manager.get_tree().create_timer(manager.BASIC_CETAR_INTERVAL).timeout


func spawn_basic_slash_effect(manager: Node, target: Node2D) -> void:
	if manager.effect_layer == null or manager.battle_vfx == null or target == null:
		return
	var start_position: Vector2 = manager.player.global_position + Vector2(0.0, -118.0)
	var end_position: Vector2 = target.global_position + Vector2(-10.0, -118.0)
	manager.battle_vfx.spawn_slash_projectile(start_position, end_position, Color(1.0, 0.97, 0.86, 0.92), 1.0)
