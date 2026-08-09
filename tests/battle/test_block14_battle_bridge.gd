extends Node

## Block 14 battle-side adapters: EncounterContext -> battle configuration,
## multi-enemy encounter groups, opening-advantage mapping, and HP/Energy
## read-in/write-back via PartyRuntimeState. Instances the real production
## battle_scene.tscn directly, matching the existing convention in
## test_multi_enemy_targeting_production.gd (no BattleManager changes were
## needed for multi-enemy support there; this test confirms the same is
## true for the new Block 14 roster-spawn path).

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := Node3D.new()
	player.name = "BridgeTestPlayer"
	add_child(player)
	GameFlowState.set_active_character(player)

	# This file drives EncounterCoordinator's active context directly and
	# focuses purely on what BattleManager does with it -- the encounter
	# acceptance/session/transition-timing flow itself is already covered by
	# test_battle_session_coordinator.gd. Disconnect BattleSessionCoordinator
	# so its real 0.15s -> SceneTransition.change_to_file() pathway can't
	# fire mid-test and tear down this test's own scene tree.
	if EncounterCoordinator.encounter_requested.is_connected(BattleSessionCoordinator._on_encounter_requested):
		EncounterCoordinator.encounter_requested.disconnect(BattleSessionCoordinator._on_encounter_requested)

	await _test_neutral_configuration()
	await _test_player_advantage_damages_enemy()
	await _test_enemy_advantage_damages_player()
	await _test_multi_enemy_group_spawns()
	await _test_unknown_enemy_id_falls_back_safely()
	await _test_hp_energy_persist_across_two_battles()
	await _test_victory_reports_to_session_coordinator()
	# _test_victory_reports_to_session_coordinator() prints the final success
	# marker and quits itself -- see its own comment for why (avoiding the
	# real SceneTransition fade window that report_battle_result() starts).


func _test_neutral_configuration() -> void:
	var context := _make_context([&"lesser_abyss"], EncounterContext.OpeningAdvantage.NEUTRAL, &"neutral_test_enemy")
	var fixture := await _start_battle_with_context(context)
	var manager: BattleManager = fixture["manager"]

	if manager.is_bandit_encounter:
		_fail("A Block 14 context must never be treated as the bandit encounter")
		return
	if manager.encounter_enemy_name != "Lesser Abyss":
		_fail("Enemy name was not configured from the EncounterContext catalog lookup")
		return
	if manager.encounter_victory_scene_path != context.source_world_scene:
		_fail("Victory scene path must redirect to the EncounterContext's source_world_scene")
		return
	if manager.enemy.current_hp != manager.enemy.max_hp:
		_fail("NEUTRAL opening must not modify enemy HP")
		return
	if manager.player.current_hp != manager.player.max_hp:
		_fail("NEUTRAL opening must not modify player HP")
		return

	print("NEUTRAL_CONFIGURATION_OK enemy identity, victory redirect, and untouched HP verified")
	await _teardown(fixture)


func _test_player_advantage_damages_enemy() -> void:
	var context := _make_context(
		[&"lesser_abyss"], EncounterContext.OpeningAdvantage.PLAYER_ADVANTAGE, &"advantage_test_enemy"
	)
	var fixture := await _start_battle_with_context(context)
	var manager: BattleManager = fixture["manager"]

	var expected_damage := roundi(float(manager.enemy.max_hp) * 0.15)
	var expected_hp := manager.enemy.max_hp - expected_damage
	if manager.enemy.current_hp != expected_hp:
		_fail("PLAYER_ADVANTAGE must apply a 15%% opening hit to the enemy, expected %d got %d" % [expected_hp, manager.enemy.current_hp])
		return
	if manager.player.current_hp != manager.player.max_hp:
		_fail("PLAYER_ADVANTAGE must not damage the player")
		return
	if manager.state != BattleManager.BattleState.PLAYER_TURN:
		_fail("Opening advantage must not skip/alter normal turn start")
		return

	print("PLAYER_ADVANTAGE_OK opening enemy damage verified, player untouched, turn order unaffected")
	await _teardown(fixture)


func _test_enemy_advantage_damages_player() -> void:
	var context := _make_context(
		[&"lesser_abyss"], EncounterContext.OpeningAdvantage.ENEMY_ADVANTAGE, &"enemy_advantage_test_enemy"
	)
	var fixture := await _start_battle_with_context(context)
	var manager: BattleManager = fixture["manager"]

	var expected_damage := roundi(float(manager.player.max_hp) * 0.10)
	var expected_hp := manager.player.max_hp - expected_damage
	if manager.player.current_hp != expected_hp:
		_fail("ENEMY_ADVANTAGE must apply a 10%% opening hit to the player, expected %d got %d" % [expected_hp, manager.player.current_hp])
		return
	if manager.enemy.current_hp != manager.enemy.max_hp:
		_fail("ENEMY_ADVANTAGE must not damage the enemy")
		return

	print("ENEMY_ADVANTAGE_OK opening player damage verified (architecture accepted, minimally used)")
	await _teardown(fixture)


func _test_multi_enemy_group_spawns() -> void:
	var context := _make_context(
		[&"lesser_abyss", &"lesser_abyss"], EncounterContext.OpeningAdvantage.NEUTRAL, &"group_test_enemy"
	)
	var fixture := await _start_battle_with_context(context)
	var manager: BattleManager = fixture["manager"]
	var battle: Node = fixture["battle"]

	var combatant_count := 0
	for child in battle.get_children():
		if child is Combatant:
			combatant_count += 1
	# player + 2 enemies (primary `enemy` node + 1 spawned extra)
	if combatant_count != 3:
		_fail("A 2-enemy encounter group must produce exactly 3 Combatants (1 player + 2 enemies), got %d" % combatant_count)
		return
	if manager._all_enemies_defeated():
		_fail("Freshly spawned multi-enemy group must not already read as defeated")
		return

	# Defeating only one of the two must not end the battle (mirrors the
	# existing multi-enemy production test's exact assertion).
	var extra_enemy: Combatant = battle.get_node("EncounterEnemy2")
	extra_enemy.take_damage(extra_enemy.max_hp)
	if not extra_enemy.is_defeated():
		_fail("Extra enemy did not register as defeated after lethal damage")
		return
	if manager._all_enemies_defeated():
		_fail("Killing only one of two encounter-group enemies must not end the battle")
		return

	print("MULTI_ENEMY_GROUP_OK 1 world actor spawned 2 battle enemies; partial defeat does not end battle")
	await _teardown(fixture)


func _test_unknown_enemy_id_falls_back_safely() -> void:
	var context := _make_context(
		[&"totally_unknown_species"], EncounterContext.OpeningAdvantage.NEUTRAL, &"unknown_id_test_enemy"
	)
	var fixture := await _start_battle_with_context(context)
	var manager: BattleManager = fixture["manager"]

	# Falls back to whatever encounter_enemy_name/max_hp/damage already were
	# (the class-level defaults) rather than crashing or leaving the enemy
	# unconfigured.
	if manager.enemy == null or not is_instance_valid(manager.enemy):
		_fail("Unknown battle_enemy_id must not prevent the enemy Combatant from existing")
		return
	if manager.enemy.max_hp <= 0:
		_fail("Unknown battle_enemy_id must fall back to a sane default max_hp, not 0")
		return

	print("UNKNOWN_ENEMY_ID_OK unknown id handled with a safe, non-crashing fallback")
	await _teardown(fixture)


func _test_hp_energy_persist_across_two_battles() -> void:
	# Uses a dedicated context id but the real "takashi" PartyRuntimeState
	# entry, since BattleManager always persists under &"takashi" -- this is
	# intentional: the whole point is verifying the *shared* runtime state.
	var first_context := _make_context(
		[&"lesser_abyss"], EncounterContext.OpeningAdvantage.NEUTRAL, &"persistence_test_enemy_1"
	)
	var first_fixture := await _start_battle_with_context(first_context)
	var first_manager: BattleManager = first_fixture["manager"]

	first_manager.player.current_hp = 40
	first_manager.ultimate_energy = 65
	await first_manager._win("Test victory for persistence check")
	await _idle_frames(4)

	var persisted := PartyRuntimeState.get_state(&"takashi")
	if persisted == null or persisted.current_hp != 40 or persisted.current_energy != 65:
		_fail("Victory must persist the concluded HP/Energy to PartyRuntimeState")
		return
	await _teardown(first_fixture)

	var second_context := _make_context(
		[&"lesser_abyss"], EncounterContext.OpeningAdvantage.NEUTRAL, &"persistence_test_enemy_2"
	)
	var second_fixture := await _start_battle_with_context(second_context)
	var second_manager: BattleManager = second_fixture["manager"]

	if second_manager.player.current_hp != 40:
		_fail("Next encounter must begin at the persisted damaged HP (40), got %d" % second_manager.player.current_hp)
		return
	if second_manager.ultimate_energy != 65:
		_fail("Next encounter must begin at the persisted Energy (65), got %d" % second_manager.ultimate_energy)
		return

	print("HP_ENERGY_PERSISTENCE_OK damaged HP and gained Energy both carried into the next encounter")
	await _teardown(second_fixture)


func _test_victory_reports_to_session_coordinator() -> void:
	var context := _make_context(
		[&"lesser_abyss"], EncounterContext.OpeningAdvantage.NEUTRAL, &"report_test_enemy"
	)
	EncounterCoordinator.request_encounter(context)
	await _idle_frames(1)

	# BattleSessionCoordinator's own accept flow is fully covered by
	# test_battle_session_coordinator.gd (including its real 0.15s ->
	# SceneTransition pathway, which this file deliberately never lets run,
	# since it would tear down this test's own scene tree). Here we only
	# need an active session to exist so report_battle_result() has
	# somewhere to report to -- populate it directly rather than going
	# through the real signal-driven accept flow a second time.
	BattleSessionCoordinator.set("_active_session", {
		"context": context,
		"source_world_scene": context.source_world_scene,
		"world_actor_id": context.initiating_enemy_id,
		"player_character_id": context.initiating_player_character_id,
		"return_position": Vector3.ZERO,
	})
	if not BattleSessionCoordinator.has_active_session():
		_fail("Precondition failed: expected an active BattleSessionCoordinator session for this test")
		return

	var fixture := await _start_battle_with_context(context)
	var manager: BattleManager = fixture["manager"]

	# report_battle_result() itself calls SceneTransition.change_to_file(),
	# which fades over ~0.34s before actually swapping scenes -- check and
	# quit immediately (no extra idle frames) so this test's own assertion
	# always lands safely inside that window.
	await manager._win("Test victory for bridge report check")
	if BattleSessionCoordinator.has_active_session():
		_fail("Victory with an active Block 14 session must report through BattleSessionCoordinator, not leave the session open")
		return

	print("VICTORY_REPORT_OK win() correctly reported the result through BattleSessionCoordinator")
	print("BLOCK14_BATTLE_BRIDGE_ALL_OK")
	get_tree().quit(0)


func _make_context(
	battle_enemy_ids: Array, opening_advantage: EncounterContext.OpeningAdvantage, initiating_enemy_id: StringName
) -> EncounterContext:
	var context := EncounterContext.new()
	context.encounter_id = StringName("test_%s" % String(initiating_enemy_id))
	context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	var typed_ids: Array[StringName] = []
	for id_variant in battle_enemy_ids:
		typed_ids.append(id_variant as StringName)
	context.battle_enemy_ids = typed_ids
	context.opening_advantage = opening_advantage
	context.initiating_enemy_id = initiating_enemy_id
	context.initiating_player_character_id = &"takashi"
	return context


## Directly drives EncounterCoordinator's active context (bypassing the full
## request/accept signal flow already covered by test_battle_session_coordinator.gd)
## so this file can focus purely on what BattleManager does with it.
func _start_battle_with_context(context: EncounterContext) -> Dictionary:
	if not EncounterCoordinator.has_active_encounter():
		EncounterCoordinator.request_encounter(context)
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	get_tree().root.add_child(battle)
	await _idle_frames(8)
	return {"battle": battle, "manager": manager}


func _teardown(fixture: Dictionary) -> void:
	var battle: Node = fixture["battle"]
	if is_instance_valid(battle):
		battle.queue_free()
	await _idle_frames(2)
	if EncounterCoordinator.has_active_encounter():
		EncounterCoordinator.resolve_active_encounter(&"escape")
	await _idle_frames(2)


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
