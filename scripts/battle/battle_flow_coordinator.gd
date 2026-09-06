class_name BattleFlowCoordinator
extends RefCounted

## Coordinates encounter setup, runtime state persistence, opening advantage,
## victory/defeat outcome resolution, and battle restarting.


func configure_encounter(manager: Node) -> void:
	if EncounterCoordinator.has_active_encounter():
		configure_from_encounter_context(manager, EncounterCoordinator.get_active_context())
		return

	var progress := manager.get_node_or_null("/root/WorldProgress")
	if progress == null:
		return
	if StringName(progress.get("active_battle_id")) != manager.BANDIT_ENCOUNTER_ID:
		return

	manager.is_bandit_encounter = true
	manager.encounter_enemy_name = "Bandit Captain"
	manager.encounter_enemy_max_hp = 150
	manager.encounter_enemy_damage = 12
	manager.encounter_opening_log = "Makoto and Mitsuki hold off the raiders. Break the captain's guard."
	manager.encounter_victory_log = "The captain falls. The old road to Werdonia is open again."
	manager.encounter_victory_scene_path = manager.GRASSLANDS_SCENE_PATH
	manager.encounter_retry_scene_path = ""
	manager.encounter_intro_text = "THE CLOVER CLASH"
	manager.encounter_bgm_path = manager.BANDIT_BGM_PATH
	manager.encounter_background_path = manager.BANDIT_BACKGROUND_PATH


func configure_from_encounter_context(manager: Node, context: EncounterContext) -> void:
	if context == null or context.battle_enemy_ids.is_empty():
		push_error("BattleManager: active EncounterContext is invalid (null or empty roster); using default encounter")
		return
	var primary_id: StringName = context.battle_enemy_ids[0]
	var primary_data: Dictionary = manager.get_enemy_battle_profile_data(primary_id)
	if primary_data.is_empty():
		push_error("BattleManager: unknown battle_enemy_id '%s'; using default encounter" % primary_id)
		return

	manager.is_bandit_encounter = false
	manager.encounter_enemy_name = primary_data.get("name", manager.encounter_enemy_name)
	manager.encounter_enemy_max_hp = primary_data.get("max_hp", manager.ENEMY_MAX_HP)
	manager.encounter_enemy_damage = primary_data.get("damage", manager.ENEMY_BASE_DAMAGE)
	manager.encounter_opening_log = "A %s blocks the path. Choose Takashi's first action." % manager.encounter_enemy_name
	manager.encounter_victory_log = ""
	manager.encounter_victory_scene_path = (
		context.source_world_scene if not context.source_world_scene.is_empty() else manager.ENDING_SCENE_PATH
	)
	manager.encounter_retry_scene_path = ""
	manager.encounter_intro_text = "ENCOUNTER"
	manager.encounter_bgm_path = ""
	manager.encounter_background_path = ""
	manager._pending_extra_battle_enemy_ids = context.battle_enemy_ids.slice(1)


func stop_exploration_music(manager: Node) -> void:
	var music_director := manager.get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.call("stop_music", 0.0)


func apply_encounter_presentation(manager: Node) -> void:
	if not manager.encounter_background_path.is_empty() and manager.forest_background != null:
		manager.forest_background.texture = load(manager.encounter_background_path) as Texture2D

	if not manager.encounter_bgm_path.is_empty() and manager.battle_bgm != null:
		manager.battle_bgm.stop()
		manager.battle_bgm.stream = load(manager.encounter_bgm_path) as AudioStream

	if manager.enemy_placeholder_visual != null:
		manager.enemy_placeholder_visual.visible = not manager.is_bandit_encounter
	if manager.enemy_action_sprite != null:
		manager.enemy_action_sprite.visible = manager.is_bandit_encounter
	if manager.enemy_title_label != null:
		manager.enemy_title_label.text = manager.encounter_enemy_name
	if manager.encounter_label != null:
		manager.encounter_label.text = manager.encounter_enemy_name
	if manager.battle_intro_label != null:
		manager.battle_intro_label.text = manager.encounter_intro_text


func reset_battle_values(manager: Node) -> void:
	manager.player.reset_hp()
	manager.enemy.reset_hp()
	manager.ultimate_energy = 0
	manager.skill_points = manager.START_SKILL_POINTS
	apply_persisted_player_runtime_state(manager)
	apply_opening_advantage_effects(manager)
	manager._reset_camera()
	manager._hide_takashi_ultimate_glow_effect()
	manager._global_selected_target = null
	manager._reset_basic_command_runtime()
	manager._reset_skill_command_runtime()
	manager._reset_ultimate_command_runtime()
	manager._reset_enemy_attack_runtime()
	manager.timing_bar.cancel_window()
	manager.ui.set_timing_mode(false)
	manager.ui.set_restart_visible(false)
	manager._refresh_player_status_ui()
	manager._refresh_energy_ui()
	manager._refresh_skill_points_ui()


func restart_battle(manager: Node) -> void:
	manager._start_player_idle_animation()
	reset_battle_values(manager)
	manager._begin_player_turn(manager.encounter_opening_log)


func apply_persisted_player_runtime_state(manager: Node) -> void:
	var state: CharacterRuntimeState = PartyRuntimeState.ensure_initialized(
		&"takashi", manager.PLAYER_MAX_HP, manager.MAX_ULTIMATE_ENERGY, 0
	)
	manager.player.current_hp = clampi(state.current_hp, 0, manager.player.max_hp)
	manager.ultimate_energy = clampi(state.current_energy, 0, manager.MAX_ULTIMATE_ENERGY)


func apply_opening_advantage_effects(manager: Node) -> void:
	if not EncounterCoordinator.has_active_encounter():
		return
	var context: EncounterContext = EncounterCoordinator.get_active_context()
	if context == null:
		return
	match context.opening_advantage:
		EncounterContext.OpeningAdvantage.PLAYER_ADVANTAGE:
			manager.enemy.take_damage(roundi(float(manager.enemy.max_hp) * 0.15))
		EncounterContext.OpeningAdvantage.ENEMY_ADVANTAGE:
			manager.player.take_damage(roundi(float(manager.player.max_hp) * 0.10))
		_:
			pass
	manager._refresh_player_status_ui()


func persist_player_runtime_state(manager: Node) -> void:
	PartyRuntimeState.apply_battle_result(
		&"takashi",
		manager.player.current_hp,
		manager.ultimate_energy,
		manager.player.is_defeated()
	)



func all_enemies_defeated(manager: Node) -> bool:
	if manager.battle_scene == null:
		return manager.enemy.is_defeated()
	for child in manager.battle_scene.get_children():
		if (
			child is Combatant
			and child != manager.player
			and is_instance_valid(child)
			and not (child as Combatant).is_defeated()
		):
			return false
	return true


func win(manager: Node, log_text: String) -> void:
	manager.state = manager.BattleState.WIN
	manager.active_basic_command_token = 0
	manager.active_skill_command_token = 0
	manager.active_ultimate_command_token = 0
	manager._reset_ultimate_interrupt_queue()
	manager._reset_enemy_attack_runtime()
	manager._reset_camera()

	if manager.basic_command_adapter != null:
		manager.basic_command_adapter.lock_for_outcome(true)
	if manager.skill_command_adapter != null:
		manager.skill_command_adapter.lock_for_outcome(true)
	if manager.ultimate_command_adapter != null:
		manager.ultimate_command_adapter.lock_for_outcome(true)
	manager._hide_basic_target_highlight()
	manager._hide_skill_target_highlight()
	manager._set_skill_command_panel_visible(false)
	manager._hide_ultimate_target_highlight()
	manager._set_ultimate_command_panel_visible(false)
	manager.timing_bar.cancel_window()
	manager.ui.set_battle_input_enabled(false)
	manager.ui.set_turn_text("Victory")
	manager.ui.set_battle_log(
		manager.encounter_victory_log if not manager.encounter_victory_log.is_empty() else log_text
	)
	manager.ui.set_timing_mode(false)
	manager._update_action_buttons(false)
	manager.ui.set_restart_visible(true)
	persist_player_runtime_state(manager)
	if manager.is_bandit_encounter:
		var progress := manager.get_node_or_null("/root/WorldProgress")
		if progress != null:
			progress.call("complete_active_encounter")
	await manager.get_tree().create_timer(0.8).timeout
	if manager.state != manager.BattleState.WIN:
		return
	if EncounterCoordinator.has_active_encounter():
		BattleSessionCoordinator.report_battle_result(&"victory")
	else:
		SceneTransition.change_to_file(manager.encounter_victory_scene_path)


func lose(manager: Node, log_text: String) -> void:
	manager.state = manager.BattleState.LOSE
	manager.active_basic_command_token = 0
	manager.active_skill_command_token = 0
	manager.active_ultimate_command_token = 0
	manager._reset_ultimate_interrupt_queue()
	manager._reset_enemy_attack_runtime()
	manager._reset_camera()
	if manager.basic_command_adapter != null:
		manager.basic_command_adapter.lock_for_outcome(false)
	if manager.skill_command_adapter != null:
		manager.skill_command_adapter.lock_for_outcome(false)
	if manager.ultimate_command_adapter != null:
		manager.ultimate_command_adapter.lock_for_outcome(false)
	manager._hide_basic_target_highlight()
	manager._hide_skill_target_highlight()
	manager._set_skill_command_panel_visible(false)
	manager._hide_ultimate_target_highlight()
	manager._set_ultimate_command_panel_visible(false)
	manager.timing_bar.cancel_window()
	manager.ui.set_battle_input_enabled(false)
	manager.ui.set_turn_text("Defeat")
	manager.ui.set_battle_log(log_text)
	manager.ui.set_timing_mode(false)
	manager._update_action_buttons(false)
	manager.ui.set_restart_visible(true)
	persist_player_runtime_state(manager)
