class_name TakashiSkillAction
extends RefCounted

## Executes Takashi's Triangle Rift skill action sequence, projectile timing,
## multi-pulse impact, and damage resolution.


func start_legacy_skill(manager: Node) -> void:
	if manager.state != manager.BattleState.PLAYER_TURN or manager._is_battle_over():
		return
	manager.state = manager.BattleState.ACTION_RESOLUTION
	manager._set_player_action_texture(manager.TAKASHI_SKILL_TEXTURE)
	manager._play_skill_sfx()
	manager._update_action_buttons(false)
	manager.ui.set_turn_text("Triangle Rift")
	manager.ui.set_battle_log("Triangle Rift charging...")
	await execute_triangle_rift(manager, manager.enemy, null, true)


func execute_committed_skill(manager: Node, command: PendingBattleCommand) -> void:
	if not manager._uses_new_skill_command_flow():
		return
	if not manager._is_committed_skill_command(command):
		return
	if not manager.skill_command_adapter.execute_committed_command():
		return

	var target: Combatant = manager._selected_skill_target(command)
	if target == null:
		manager._abort_committed_skill_command(command, &"target_missing_during_execution")
		return

	manager.active_skill_command_token = command.commit_token
	manager.state = manager.BattleState.ACTION_RESOLUTION
	manager._set_player_action_texture(manager.TAKASHI_SKILL_TEXTURE)
	if manager.battle_presentation_3d != null:
		manager.battle_presentation_3d.play_party_skill()
	manager._play_skill_sfx()
	manager._update_action_buttons(false)
	manager.ui.set_turn_text("Triangle Rift")
	manager.ui.set_battle_log("Triangle Rift charging...")
	await execute_triangle_rift(manager, target, command)


func execute_triangle_rift(
	manager: Node,
	target: Combatant = null,
	command: PendingBattleCommand = null,
	spend_cost_before_cast: bool = false
) -> void:
	if target == null:
		target = manager.enemy
	if not manager._skill_execution_guard(command, target):
		return

	if spend_cost_before_cast:
		manager._spend_skill_points(manager.SKILL_POINT_COST_SKILL)
	manager._spawn_skill_charge_effect(manager.player)
	await manager.ui.play_skill_cast_feedback()
	if not manager._skill_execution_guard(command, target):
		return

	manager.ui.set_battle_log(
		"Triangle Rift spends %d Skill Point and generates %d energy." % [manager.SKILL_POINT_COST_SKILL, manager.SKILL_ENERGY]
	)
	await manager.player.play_skill_movement(target)
	if not manager._skill_execution_guard(command, target):
		return

	await resolve_triangle_rift_damage(manager, target, command)
	if not manager._skill_execution_guard(command, target, false):
		return

	manager._add_ultimate_energy(manager.SKILL_ENERGY)
	var log_text := "Triangle Rift deals %d damage." % manager.SKILL_DAMAGE
	if command != null:
		manager._finish_skill_command_resolution(command, log_text)
	else:
		manager._finish_player_action(log_text)


func resolve_triangle_rift_damage(
	manager: Node,
	target: Combatant = null,
	command: PendingBattleCommand = null
) -> void:
	if target == null:
		target = manager.enemy
	if not manager._skill_execution_guard(command, target):
		return

	manager._play_skill_release_sfx()
	spawn_triangle_rift_projectile(manager, manager.player, target)

	await manager.get_tree().create_timer(manager.SKILL_RIFT_PROJECTILE_DURATION).timeout
	if not manager._skill_execution_guard(command, target):
		return
	if command != null and not manager.skill_command_adapter.begin_resolution(command):
		return

	if not manager._consume_skill_hit(command, 0):
		return
	target.take_damage(manager.SKILL_DAMAGE)
	manager._show_floating_damage(target, manager.SKILL_DAMAGE)

	if manager.SKILL_IMPACT_HOLD_SECONDS > 0.0:
		await manager.get_tree().create_timer(manager.SKILL_IMPACT_HOLD_SECONDS).timeout
		if not manager._skill_execution_guard(command, target, false):
			return

	await play_triangle_rift_impact(manager, target, command)
	if not manager._skill_execution_guard(command, target, false):
		return

	await target.play_hit_feedback()


func spawn_triangle_rift_projectile(manager: Node, origin: Node2D, target: Node2D) -> void:
	if manager.effect_layer == null or manager.battle_vfx == null or origin == null or target == null:
		return
	var start_position: Vector2 = origin.global_position + Vector2(28.0, -128.0)
	var end_position: Vector2 = target.global_position + Vector2(-8.0, -118.0)
	manager.battle_vfx.spawn_triangle_rift_projectile(start_position, end_position, manager.SKILL_RIFT_PROJECTILE_DURATION)


func spawn_triangle_rift_effect(manager: Node, target: Node2D, large: bool) -> void:
	if manager.effect_layer == null or manager.battle_vfx == null or target == null:
		return
	manager.battle_vfx.spawn_triangle_rift_effect(target.global_position + Vector2(0.0, -118.0), large)


func play_triangle_rift_impact(
	manager: Node,
	target: Node2D,
	command: PendingBattleCommand = null
) -> void:
	if manager.effect_layer == null or target == null:
		return

	manager._play_rift_crack_sfx()
	manager._play_screen_flash(Color(0.55, 0.92, 1.0, 0.22), 0.09)
	spawn_triangle_rift_effect(manager, target, false)
	manager._spawn_hit_spark(target, Color(0.45, 0.92, 1.0, 1.0))
	manager._spawn_triangle_rift_break(target, 0)
	manager._shake_camera_with_strength(manager.SKILL_RIFT_CAMERA_SHAKE)

	await manager._shake_target_once(target, manager.SKILL_RIFT_TARGET_SHAKE, 0.055)

	for pulse_index in range(manager.SKILL_RIFT_IMPACT_PULSE_COUNT):
		if not manager._skill_impact_guard(command, target):
			return

		manager._play_rift_crack_sfx()
		if manager.battle_vfx != null:
			manager.battle_vfx.play_triangle_rift_pulse_burst(target.global_position, pulse_index)
		manager._shake_camera_with_strength(manager.SKILL_RIFT_CAMERA_SHAKE + float(pulse_index) * 1.5)

		await manager._shake_target_once(target, manager.SKILL_RIFT_TARGET_SHAKE + float(pulse_index) * 2.0, 0.045)
		await manager.get_tree().create_timer(manager.SKILL_RIFT_IMPACT_INTERVAL).timeout
