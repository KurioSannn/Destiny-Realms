extends Node

## Block 14.5 follow-up: the earlier multi-enemy lifecycle test always killed
## the second (duplicated) enemy directly via take_damage() before ever
## exercising real target selection between two LIVE, duplicated enemies.
## User report: "basic attack arahnya random", "gak bisa pilih musuh mana
## yang diserang" -- this reproduces that exact scenario against the real
## production battle scene and the real _spawn_additional_encounter_enemies()
## formation-duplicate path (not test_multi_enemy_targeting_production.gd's
## bare Combatant.new() mock, which is structurally different).

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	if EncounterCoordinator.encounter_requested.is_connected(BattleSessionCoordinator._on_encounter_requested):
		EncounterCoordinator.encounter_requested.disconnect(BattleSessionCoordinator._on_encounter_requested)

	var context := EncounterContext.new()
	context.encounter_id = &"target_select_test"
	context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	context.battle_enemy_ids = [&"lesser_abyss", &"lesser_abyss"]
	context.opening_advantage = EncounterContext.OpeningAdvantage.NEUTRAL
	context.initiating_enemy_id = &"target_select_test_enemy"
	EncounterCoordinator.request_encounter(context)

	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	get_tree().root.add_child(battle)
	await _idle_frames(10)

	var primary := manager.enemy
	var secondary: Combatant = battle.get_node_or_null("EncounterEnemy2")
	if secondary == null:
		_fail("Expected a second dynamically spawned enemy for this 2-enemy roster")
		return
	if primary.global_position.distance_to(secondary.global_position) < 10.0:
		_fail("Primary and secondary enemy are not meaningfully separated on the battle stage")
		return

	# --- 1-Click Basic Attack on Secondary Enemy: pre-select secondary, then press attack ---
	manager._global_selected_target = secondary
	var primary_hp_before := primary.current_hp
	var secondary_hp_before := secondary.current_hp

	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	if not manager.call("_has_pending_basic_command"):
		_fail("Attack with 2 live enemies did not produce a pending command")
		return
	var command: PendingBattleCommand = manager.basic_command_adapter.get_pending_command()
	if not command.is_committed:
		_fail("1-Click Basic Attack with pre-selected secondary must auto-commit immediately on press")
		return
	if command.selected_targets.is_empty() or command.selected_targets[0] != secondary:
		_fail("1-Click Basic Attack committed against the wrong enemy instead of secondary")
		return

	if not await _wait_for_hp_change(secondary, secondary_hp_before, 5.0):
		_fail("Secondary enemy never took damage after being attacked")
		return
	if primary.current_hp != primary_hp_before:
		_fail("Primary enemy took damage even though secondary was selected")
		return

	print("MULTI_ENEMY_EXPLICIT_TARGET_OK attack committed onto secondary specifically, primary untouched")

	# --- Second attack, this time select PRIMARY and press attack ---
	await _wait_for_player_turn(manager, 5.0)
	manager._global_selected_target = primary
	primary_hp_before = primary.current_hp
	secondary_hp_before = secondary.current_hp

	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	if not manager.call("_has_pending_basic_command"):
		_fail("Second Attack press did not produce a pending command")
		return
	command = manager.basic_command_adapter.get_pending_command()
	if not command.is_committed:
		_fail("1-Click Basic Attack with pre-selected primary must auto-commit immediately on press")
		return
	if command.selected_targets.is_empty() or command.selected_targets[0] != primary:
		_fail("1-Click Basic Attack committed against the wrong enemy instead of primary")
		return

	if not await _wait_for_hp_change(primary, primary_hp_before, 5.0):
		_fail("Primary enemy never took damage after being explicitly selected and attacked")
		return
	if secondary.current_hp != secondary_hp_before:
		_fail("Secondary enemy took damage even though primary was selected")
		return

	print("MULTI_ENEMY_TARGET_SWITCH_OK re-selecting the other live enemy correctly redirected the attack")

	# --- Third attack: test real mouse click selection on secondary, then attack press ---
	await _wait_for_player_turn(manager, 5.0)
	primary_hp_before = primary.current_hp
	secondary_hp_before = secondary.current_hp

	_send_real_click(secondary.global_position)
	await _idle_frames(5)
	if manager._global_selected_target != secondary:
		_fail("Real mouse click on secondary enemy screen position did not select it as _global_selected_target")
		return

	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	command = manager.basic_command_adapter.get_pending_command()
	if not command or not command.is_committed:
		_fail("Pressing attack after mouse selecting secondary did not commit command")
		return

	if not await _wait_for_hp_change(secondary, secondary_hp_before, 5.0):
		_fail("Secondary enemy never took damage after mouse click selection + attack")
		return

	print("REAL_MOUSE_CLICK_TARGETING_OK an actual synthetic mouse click on the enemy's screen position selected and committed it")

	print("BLOCK14_5_MULTI_ENEMY_TARGET_SELECTION_ALL_OK")
	get_tree().quit(0)


func _send_real_click(screen_position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_position
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_position
	Input.parse_input_event(release)


func _wait_for_hp_change(combatant: Combatant, previous_hp: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(combatant):
			return false
		if combatant.current_hp != previous_hp:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _wait_for_player_turn(manager: BattleManager, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if manager.state == BattleManager.BattleState.PLAYER_TURN:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
