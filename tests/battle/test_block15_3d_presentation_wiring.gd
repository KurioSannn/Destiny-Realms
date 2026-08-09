extends Node

## Block 15 stabilization: BattlePresentation3D.battle_manager was never
## assigned anywhere, so every battle_manager-gated step silently no-op'd --
## no enemy 3D actors were ever spawned, and the 2D layer (background,
## Player/Enemy sprites) was never hidden, leaving both presentations
## rendered on top of each other. This verifies the fix: battle_manager is
## set, enemy actors are spawned to match the real roster (including
## dynamically spawned encounter-group enemies), the party actor exists,
## and the 2D layer is correctly hidden once the 3D presentation takes over.

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_single_enemy_wiring()
	await _test_multi_enemy_wiring_matches_real_roster()
	await _test_3d_target_click_commits_skill_without_first_press_animation()
	await _test_3d_second_enemy_skill_targeting_hits_selected_actor()
	await _test_3d_ultimate_ready_focus_and_cutscene_bridge()

	print("BLOCK15_3D_PRESENTATION_WIRING_ALL_OK")
	get_tree().quit(0)


func _test_single_enemy_wiring() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	get_tree().root.add_child(battle)
	await _idle_frames(10)

	var presentation := battle.get_node_or_null("BattlePresentation3D") as BattlePresentation3D
	if presentation == null:
		_fail("BattlePresentation3D node not found on the battle scene")
		return
	if presentation.battle_manager != manager:
		_fail("BattlePresentation3D.battle_manager was not assigned to the real BattleManager instance")
		return
	if presentation.get_party_actor(0) == null:
		_fail("Party actor (Takashi) was not spawned")
		return
	var enemy_actor := presentation.get_enemy_actor(0)
	if enemy_actor == null:
		_fail("Enemy actor was not spawned for a single-enemy legacy/default battle")
		return
	if enemy_actor.actor_id != &"lesser_abyss":
		_fail("Default enemy actor did not resolve the lesser_abyss visual identity")
		return
	if not enemy_actor.uses_model():
		_fail("Lesser Abyss did not resolve to its registered 3D GLTF model")
		return
	var model_root := enemy_actor.get_node_or_null("ModelRoot") as Node3D
	if model_root == null or model_root.get_child_count() != 1:
		_fail("Lesser Abyss model was not instantiated under ModelRoot")
		return

	# --- The 2D layer must now be hidden, since battle_manager is wired ---
	var bg_node := manager.get_node_or_null("../Background") as Node2D
	if bg_node == null or bg_node.visible:
		_fail("2D Background must be hidden once the 3D presentation is active")
		return
	if manager.player.visible:
		_fail("2D Player sprite must be hidden once the 3D presentation is active")
		return
	if manager.enemy.visible:
		_fail("2D Enemy sprite must be hidden once the 3D presentation is active")
		return

	print("SINGLE_ENEMY_3D_WIRING_OK battle_manager assigned, Lesser Abyss GLTF spawned, 2D layer hidden")
	battle.queue_free()
	await _idle_frames(2)


func _test_multi_enemy_wiring_matches_real_roster() -> void:
	if EncounterCoordinator.encounter_requested.is_connected(BattleSessionCoordinator._on_encounter_requested):
		EncounterCoordinator.encounter_requested.disconnect(BattleSessionCoordinator._on_encounter_requested)

	var context := EncounterContext.new()
	context.encounter_id = &"presentation_wiring_test"
	context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	context.battle_enemy_ids = [&"lesser_abyss", &"lesser_abyss"]
	context.opening_advantage = EncounterContext.OpeningAdvantage.NEUTRAL
	context.initiating_enemy_id = &"presentation_wiring_test_enemy"
	EncounterCoordinator.request_encounter(context)

	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	get_tree().root.add_child(battle)
	await _idle_frames(12)

	var presentation := battle.get_node_or_null("BattlePresentation3D") as BattlePresentation3D
	if presentation == null:
		_fail("BattlePresentation3D node not found")
		return
	var enemy_actor_0 := presentation.get_enemy_actor(0)
	var enemy_actor_1 := presentation.get_enemy_actor(1)
	if enemy_actor_0 == null or enemy_actor_1 == null:
		_fail("Expected 2 enemy actors to be spawned for a 2-enemy encounter-group roster, matching the real dynamically-spawned Combatant count")
		return
	if presentation.get_enemy_actor(2) != null:
		_fail("A 2-enemy roster must not produce a 3rd enemy actor")
		return
	if not enemy_actor_0.uses_model() or not enemy_actor_1.uses_model():
		_fail("Every Lesser Abyss in the encounter group must use the registered 3D model")
		return
	if enemy_actor_0.position.distance_to(enemy_actor_1.position) < 3.4:
		_fail("Enemy formation slots are still too close and can visually overlap")
		return

	print("MULTI_ENEMY_3D_WIRING_OK two GLTF actors spawned in separated formation slots")
	battle.queue_free()
	await _idle_frames(2)
	if EncounterCoordinator.has_active_encounter():
		EncounterCoordinator.resolve_active_encounter(&"escape")
	WorldProgress.reset_story()


func _test_3d_target_click_commits_skill_without_first_press_animation() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	get_tree().root.add_child(battle)
	await _idle_frames(12)

	var presentation := battle.get_node_or_null("BattlePresentation3D") as BattlePresentation3D
	if presentation == null:
		_fail("BattlePresentation3D node not found for 3D click targeting test")
		return
	var party_actor := presentation.get_party_actor(0)
	var enemy_actor := presentation.get_enemy_actor(0)
	if party_actor == null or enemy_actor == null:
		_fail("3D click targeting test needs both party and enemy actors")
		return

	var initial_hp := manager.enemy.current_hp
	manager.call("_on_skill_pressed")
	await _idle_frames(2)

	if party_actor.current_state != BattleActor3D.ActorState.IDLE:
		_fail("First Skill press must not play the 3D skill action before commit")
		return
	if presentation.battle_camera_3d.get_current_preset() != BattleCamera3D.Preset.PLAYER_SKILL:
		_fail("First Skill press must move the 3D camera into Skill ready focus")
		return
	if manager.skill_target_highlight.visible or manager.basic_target_highlight.visible:
		_fail("3D Skill ready must not show legacy 2D target highlights")
		return
	if not enemy_actor.is_target_selected():
		_fail("Skill ready idle must show the 3D target marker on the selected enemy")
		return

	var target_screen_position := presentation.get_enemy_screen_position(manager.enemy, 0.52)
	if is_inf(target_screen_position.x) or is_inf(target_screen_position.y):
		_fail("Enemy 3D actor did not project to a valid screen position")
		return
	var committed := bool(manager.call("_select_skill_target_at_position", target_screen_position))
	if not committed:
		_fail("Clicking the projected 3D enemy position must commit Skill")
		return
	await _idle_frames(2)

	if party_actor.current_state != BattleActor3D.ActorState.SKILL:
		_fail("3D Skill animation must begin only after target-click commit")
		return
	if not await _wait_for_enemy_hp(manager, initial_hp - BattleManager.SKILL_DAMAGE, 6.0):
		_fail("3D target-click Skill did not damage the selected enemy")
		return

	print("TARGET_CLICK_3D_WIRING_OK ready idle marker shown, projected enemy click commits Skill")
	battle.queue_free()
	await _idle_frames(2)
	WorldProgress.reset_story()


func _test_3d_second_enemy_skill_targeting_hits_selected_actor() -> void:
	if EncounterCoordinator.encounter_requested.is_connected(BattleSessionCoordinator._on_encounter_requested):
		EncounterCoordinator.encounter_requested.disconnect(BattleSessionCoordinator._on_encounter_requested)

	var context := EncounterContext.new()
	context.encounter_id = &"presentation_targeting_test"
	context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	context.battle_enemy_ids = [&"lesser_abyss", &"lesser_abyss"]
	context.opening_advantage = EncounterContext.OpeningAdvantage.NEUTRAL
	context.initiating_enemy_id = &"presentation_targeting_test_enemy"
	EncounterCoordinator.request_encounter(context)

	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	get_tree().root.add_child(battle)
	await _idle_frames(12)

	var presentation := battle.get_node_or_null("BattlePresentation3D") as BattlePresentation3D
	if presentation == null:
		_fail("BattlePresentation3D node not found for second-enemy targeting test")
		return
	var party_actor := presentation.get_party_actor(0)
	var enemy_actor_0 := presentation.get_enemy_actor(0)
	var enemy_actor_1 := presentation.get_enemy_actor(1)
	if party_actor == null or enemy_actor_0 == null or enemy_actor_1 == null:
		_fail("Second-enemy targeting test needs one party actor and two enemy actors")
		return

	var enemies := _battle_enemies(battle)
	if enemies.size() != 2:
		_fail("Second-enemy targeting test expected exactly two live Combatant enemies")
		return
	var primary_enemy := enemies[0]
	var second_enemy := enemies[1]
	var initial_primary_hp := primary_enemy.current_hp
	var initial_second_hp := second_enemy.current_hp

	manager.call("_on_skill_pressed")
	await _idle_frames(2)
	if party_actor.current_state != BattleActor3D.ActorState.IDLE:
		_fail("Skill ready against two enemies must hold 3D actor idle before target commit")
		return
	if presentation.battle_camera_3d.get_current_preset() != BattleCamera3D.Preset.PLAYER_SKILL:
		_fail("Skill ready against two enemies must focus the 3D camera on Takashi")
		return
	if manager.skill_target_highlight.visible or manager.basic_target_highlight.visible:
		_fail("Second-enemy targeting must not show legacy yellow/cyan 2D rings in 3D mode")
		return

	var second_screen_position := presentation.get_enemy_screen_position(second_enemy, 0.52)
	if is_inf(second_screen_position.x) or is_inf(second_screen_position.y):
		_fail("Second enemy 3D actor did not project to a valid screen position")
		return
	var committed := bool(manager.call("_select_skill_target_at_position", second_screen_position))
	if not committed:
		_fail("Clicking the projected second 3D enemy position must commit Skill")
		return
	await _idle_frames(2)

	if party_actor.current_state != BattleActor3D.ActorState.SKILL:
		_fail("3D Skill animation must begin only after selecting the second enemy")
		return
	if not await _wait_for_combatant_hp(second_enemy, initial_second_hp - BattleManager.SKILL_DAMAGE, 6.0):
		_fail("3D Skill click on the second enemy did not damage the selected second enemy")
		return
	if primary_enemy.current_hp != initial_primary_hp:
		_fail("3D Skill click on the second enemy incorrectly damaged the primary enemy")
		return

	print("SECOND_ENEMY_3D_TARGETING_OK skill ready holds idle, click damages selected enemy only")
	battle.queue_free()
	await _idle_frames(2)
	if EncounterCoordinator.has_active_encounter():
		EncounterCoordinator.resolve_active_encounter(&"escape")
	WorldProgress.reset_story()


func _test_3d_ultimate_ready_focus_and_cutscene_bridge() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	get_tree().root.add_child(battle)
	await _idle_frames(12)

	var presentation := battle.get_node_or_null("BattlePresentation3D") as BattlePresentation3D
	if presentation == null or presentation.battle_camera_3d == null:
		_fail("Ultimate 3D bridge test needs BattlePresentation3D and camera")
		return
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_on_ultimate_pressed")
	await _idle_frames(3)
	if presentation.battle_camera_3d.get_current_preset() != BattleCamera3D.Preset.PLAYER_ULTIMATE:
		_fail("Ultimate ready idle must move the 3D camera into Ultimate focus")
		return
	if not presentation.visible:
		_fail("Ultimate ready idle must keep the 3D presentation visible until commit")
		return
	if manager.ultimate_frame_player.visible:
		_fail("Ultimate ready idle must not start the full-screen cutscene before confirm")
		return

	manager.call("_on_ultimate_pressed")
	if not await _wait_for_ultimate_cutscene_frame(manager, 12.0):
		_fail("Committed Ultimate in 3D mode never showed the full-screen Ultimate frame effect")
		return
	if presentation.visible:
		_fail("Committed Ultimate cutscene should temporarily hide the 3D presentation so 2D Ultimate effects are visible")
		return

	battle.queue_free()
	await _idle_frames(2)
	WorldProgress.reset_story()


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _battle_enemies(battle: Node) -> Array[Combatant]:
	var enemies: Array[Combatant] = []
	for child in battle.get_children():
		var combatant := child as Combatant
		if combatant != null and combatant.name != "Player":
			enemies.append(combatant)
	return enemies


func _wait_for_enemy_hp(
	manager: BattleManager,
	expected_hp: int,
	timeout_seconds: float
) -> bool:
	return await _wait_for_combatant_hp(manager.enemy, expected_hp, timeout_seconds)


func _wait_for_combatant_hp(
	combatant: Combatant,
	expected_hp: int,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(combatant):
			return false
		if combatant.current_hp == expected_hp:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_ultimate_cutscene_frame(
	manager: BattleManager,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.ultimate_frame_player != null and manager.ultimate_frame_player.visible:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
