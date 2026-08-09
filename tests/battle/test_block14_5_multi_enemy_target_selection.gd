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

	# --- Press Attack with 2 live enemies: must enter target-select, not
	# auto-commit against an arbitrary one ---
	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	if not manager.call("_has_pending_basic_command"):
		_fail("Attack with 2 live enemies did not produce a pending command")
		return
	var command: PendingBattleCommand = manager.basic_command_adapter.get_pending_command()
	if command.is_committed:
		_fail("Attack with 2 live enemies must NOT auto-commit -- it must wait for the player to pick a target")
		return
	if command.candidate_targets.size() != 2:
		_fail("Expected exactly 2 candidate targets, got %d" % command.candidate_targets.size())
		return

	# --- Click precisely on the SECONDARY enemy: only it should take damage ---
	var primary_hp_before := primary.current_hp
	var secondary_hp_before := secondary.current_hp
	var committed := bool(manager.call("_select_basic_target_at_position", secondary.global_position))
	if not committed:
		_fail("Clicking directly on the secondary enemy's position did not select/commit it as the target")
		return
	if not await _wait_for_hp_change(secondary, secondary_hp_before, 5.0):
		_fail("Secondary enemy never took damage after being explicitly selected and attacked")
		return
	if primary.current_hp != primary_hp_before:
		_fail("Primary enemy took damage even though the secondary enemy was the selected target (wrong-target bug)")
		return

	print("MULTI_ENEMY_EXPLICIT_TARGET_OK clicking the secondary enemy committed the attack onto it specifically, primary untouched")

	# --- Second attack, this time select the PRIMARY explicitly ---
	await _wait_for_player_turn(manager, 5.0)
	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	if not manager.call("_has_pending_basic_command"):
		_fail("Second Attack press (2 live enemies still) did not produce a pending command")
		return
	primary_hp_before = primary.current_hp
	secondary_hp_before = secondary.current_hp
	committed = bool(manager.call("_select_basic_target_at_position", primary.global_position))
	if not committed:
		_fail("Clicking directly on the primary enemy's position did not select/commit it as the target")
		return
	if not await _wait_for_hp_change(primary, primary_hp_before, 5.0):
		_fail("Primary enemy never took damage after being explicitly selected and attacked")
		return
	if secondary.current_hp != secondary_hp_before:
		_fail("Secondary enemy took damage even though the primary enemy was the selected target (wrong-target bug)")
		return

	print("MULTI_ENEMY_TARGET_SWITCH_OK re-selecting the other live enemy correctly redirected the attack")

	# --- Now the real question: does an ACTUAL mouse click (not a direct
	# _select_basic_target_at_position call) on the secondary enemy's
	# on-screen position actually reach it? BattleUI's root Control covers
	# the full viewport with the Control default MOUSE_FILTER_STOP -- if
	# that swallows the click before _unhandled_input ever sees it, target
	# selection is unusable from real gameplay input despite the underlying
	# mechanism (just proven above) being correct. ---
	await _wait_for_player_turn(manager, 5.0)
	manager.call("_on_attack_pressed")
	await _idle_frames(3)
	if not manager.call("_has_pending_basic_command"):
		_fail("Third Attack press did not produce a pending command")
		return
	primary_hp_before = primary.current_hp
	secondary_hp_before = secondary.current_hp
	_send_real_click(secondary.global_position)
	await _idle_frames(5)
	command = manager.basic_command_adapter.get_pending_command()
	if command != null and not command.is_committed:
		_fail("REAL_CLICK_BUG_CONFIRMED: an actual mouse click on the secondary enemy's screen position did not select/commit it -- the command is still pending. This matches the 'gak bisa pilih musuh mana yang diserang' report: BattleUI's full-viewport root Control (default MOUSE_FILTER_STOP) is very likely swallowing the click before it reaches BattleManager._unhandled_input().")
		return
	if not await _wait_for_hp_change(secondary, secondary_hp_before, 5.0):
		_fail("REAL_CLICK_BUG_CONFIRMED: secondary enemy never took damage after a real mouse click on its position")
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
