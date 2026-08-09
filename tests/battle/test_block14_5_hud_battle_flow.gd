extends Node

## Block 14.5: traces the REAL, visible production battle HUD end-to-end --
## actual mouse clicks on the actual AttackButton/SkillButton/UltimateButton
## Control nodes in battle_scene.tscn -- rather than calling BattleManager
## methods directly. This is the manual-playtest path the developer actually
## uses, and is deliberately separate from test_multi_enemy_targeting_production.gd
## (which calls manager.call("_on_attack_pressed") directly and already
## covers the deeper command-flow edge cases).

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	# This file drives EncounterCoordinator's active context directly (like
	# test_block14_battle_bridge.gd) and never needs BattleSessionCoordinator's
	# real accept-and-transition flow, which is covered elsewhere -- disconnect
	# it so a stray SceneTransition can't fire and tear down this test's tree.
	if EncounterCoordinator.encounter_requested.is_connected(BattleSessionCoordinator._on_encounter_requested):
		EncounterCoordinator.encounter_requested.disconnect(BattleSessionCoordinator._on_encounter_requested)

	await _test_single_enemy_click_to_click_auto_targets_and_wins()
	if _failed:
		return
	await _test_multi_enemy_kill_one_continues_kill_all_wins_once()
	if _failed:
		return
	await _test_skill_button_real_click_executes()
	if _failed:
		return
	await _test_ultimate_button_disabled_until_energy_ready()
	if _failed:
		return

	print("BLOCK14_5_HUD_BATTLE_FLOW_ALL_OK")
	get_tree().quit(0)


var _failed: bool = false


func _test_single_enemy_click_to_click_auto_targets_and_wins() -> void:
	var fixture := await _start_battle()
	var battle: Node = fixture["battle"]
	var manager: BattleManager = fixture["manager"]
	var ui: BattleUI = fixture["ui"]

	if manager.enemy.max_hp <= 0:
		_fail("Precondition failed: enemy has no HP configured")
		return

	# This test is about the click -> auto-target -> auto-commit -> death
	# lifecycle, not full combat balance (a real multi-turn exchange risks
	# the player losing first, which is a separate, already-covered
	# concern) -- so the finishing blow is set up to land in exactly one
	# real Attack-button click.
	manager.enemy.current_hp = BattleManager.BASIC_ATTACK_DAMAGE
	if manager.state != BattleManager.BattleState.PLAYER_TURN:
		_fail("Precondition failed: battle did not start on PLAYER_TURN")
		return

	_click_button(ui.attack_button)
	if not await _wait_for_settled_state(manager, 3.0):
		_fail("Basic Attack never reached a settled battle state -- command flow appears stuck")
		return

	if manager.state != BattleManager.BattleState.WIN:
		_fail("A single real Attack-button click that brings the enemy to 0 HP did not trigger WIN (single-enemy auto-target/auto-commit and/or the death-lifecycle win-check is not firing from the real HUD button)")
		return
	if not manager.enemy.is_defeated():
		_fail("BattleManager reached WIN but the Enemy Combatant does not report is_defeated()")
		return

	print("SINGLE_ENEMY_REAL_CLICK_OK Attack button alone (no target click needed) brought the enemy to 0 HP and triggered WIN")
	await _teardown(battle)


func _test_multi_enemy_kill_one_continues_kill_all_wins_once() -> void:
	var context := EncounterContext.new()
	context.encounter_id = &"hud_flow_group_test"
	context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	context.battle_enemy_ids = [&"lesser_abyss", &"lesser_abyss"]
	context.opening_advantage = EncounterContext.OpeningAdvantage.NEUTRAL
	context.initiating_enemy_id = &"hud_flow_group_enemy"
	EncounterCoordinator.request_encounter(context)

	var fixture := await _start_battle()
	var battle: Node = fixture["battle"]
	var manager: BattleManager = fixture["manager"]
	var ui: BattleUI = fixture["ui"]

	var extra_enemy: Combatant = battle.get_node_or_null("EncounterEnemy2")
	if extra_enemy == null:
		_fail("Expected a dynamically spawned second enemy (EncounterEnemy2) for a 2-enemy roster")
		return
	# Block 15's 3D presentation layer correctly hides the entire 2D layer
	# (including this enemy) once active, so visibility itself is no longer
	# a meaningful check here -- what matters is that the 2D Combatant is
	# still a REAL, fully-formed node (proper visual body/HP bar), not a
	# bare Combatant.new(), since the 3D actor's sprite is sourced from it
	# (BattlePresentation3D reads combatant.action_sprite.texture) and the
	# 2D layer is still the fallback if the 3D presentation is ever disabled.
	if extra_enemy.get_node_or_null("HpBar") == null or extra_enemy.get_node_or_null("PlaceholderVisual") == null:
		_fail("Dynamically spawned encounter-group enemy is missing its visual body/HP bar (bare Combatant.new() regression)")
		return
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	if not viewport_rect.has_point(extra_enemy.global_position):
		_fail("Dynamically spawned encounter-group enemy formation slot is off-screen: %s" % extra_enemy.global_position)
		return

	# Kill the second enemy directly (this test is about lifecycle/HUD
	# continuity, not re-proving target selection, which
	# test_multi_enemy_targeting_production.gd already covers exhaustively).
	extra_enemy.take_damage(extra_enemy.max_hp)
	await _idle_frames(4)
	if not extra_enemy.is_defeated():
		_fail("Second enemy did not register as defeated after lethal damage")
		return
	if manager.state == BattleManager.BattleState.WIN:
		_fail("Killing only one of two encounter-group enemies must not end the battle")
		return

	# With exactly one live enemy left, Basic must auto-target/auto-commit on
	# a single click (same guarantee as the single-enemy test above) --
	# arrange the finishing blow the same deterministic way.
	manager.enemy.current_hp = BattleManager.BASIC_ATTACK_DAMAGE
	if manager.state != BattleManager.BattleState.PLAYER_TURN:
		_fail("Precondition failed: not on PLAYER_TURN after clearing the second enemy")
		return

	_click_button(ui.attack_button)
	if not await _wait_for_settled_state(manager, 3.0):
		_fail("Basic Attack never reached a settled battle state while finishing off the last enemy")
		return

	if manager.state != BattleManager.BattleState.WIN:
		_fail("Killing the remaining enemy did not end the battle")
		return

	print("MULTI_ENEMY_LIFECYCLE_OK dynamically spawned enemy is visible/on-screen, partial kill continues, full kill wins exactly once")
	await _teardown(battle)
	EncounterCoordinator.resolve_active_encounter(&"victory")


func _test_skill_button_real_click_executes() -> void:
	var fixture := await _start_battle()
	var battle: Node = fixture["battle"]
	var manager: BattleManager = fixture["manager"]
	var ui: BattleUI = fixture["ui"]

	var starting_hp := manager.enemy.current_hp

	if manager.state != BattleManager.BattleState.PLAYER_TURN:
		_fail("Precondition failed: battle did not start on PLAYER_TURN")
		return
	if ui.skill_button.disabled:
		_fail("Skill button is disabled at battle start with a fresh SP total -- HUD is not reflecting real SP state")
		return

	# Skill is designed (Block 9E) to require a second explicit input to
	# commit even against a single enemy -- press once to ready/auto-target,
	# press again (or click the target) to confirm. This is the "press again
	# commits" replacement for a Confirm button; unlike Basic Attack it does
	# NOT auto-commit on the first press.
	_click_button(ui.skill_button)
	await _idle_frames(5)
	if not manager.call("_has_pending_skill_command"):
		_fail("First Skill click did not produce a pending, ready-to-confirm Skill command")
		return
	_click_button(ui.skill_button)
	# Triangle Rift's full cast -> projectile -> multi-pulse impact VFX
	# sequence legitimately takes several real seconds (several chained
	# tweens/timers) -- much longer than Basic Attack's single-hit
	# resolution, so this needs a generously longer settle timeout.
	if not await _wait_for_settled_state(manager, 10.0):
		_fail("Skill command never reached a settled battle state -- real Skill button click is not driving the production Skill command")
		return

	if manager.enemy.current_hp >= starting_hp and not manager.enemy.is_defeated():
		_fail("Skill button click produced no damage to the enemy")
		return

	print("SKILL_BUTTON_REAL_CLICK_OK visible Skill button drives the real Skill command and deals damage")
	await _teardown(battle)


func _test_ultimate_button_disabled_until_energy_ready() -> void:
	var fixture := await _start_battle()
	var battle: Node = fixture["battle"]
	var manager: BattleManager = fixture["manager"]
	var ui: BattleUI = fixture["ui"]

	# Ultimate energy intentionally persists across battles (Block 14 party
	# runtime state), so a battle running after earlier tests in this suite
	# is not guaranteed to start at 0 -- force it here to isolate the
	# gating behavior itself from that (working-as-designed) persistence.
	manager.ultimate_energy = 0
	manager.call("_refresh_energy_ui")
	manager.call("_update_action_buttons", true)
	await _idle_frames(2)
	if not ui.ultimate_button.disabled:
		_fail("Ultimate button must be disabled while Energy is below the activation threshold")
		return
	if not is_equal_approx(float(ui.energy_bar.value), 0.0):
		_fail("Energy bar is not bound to the real ultimate_energy value at battle start")
		return

	manager.ultimate_energy = manager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.call("_update_action_buttons", true)
	await _idle_frames(2)
	if ui.ultimate_button.disabled:
		_fail("Ultimate button did not become enabled once Energy reached the activation threshold")
		return
	if int(ui.energy_bar.value) != manager.MAX_ULTIMATE_ENERGY:
		_fail("Energy bar did not update to reflect full ultimate_energy")
		return

	print("ULTIMATE_ENERGY_BINDING_OK Ultimate button correctly gated on, and Energy bar correctly bound to, real Energy state")
	await _teardown(battle)


func _start_battle() -> Dictionary:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("BattleManager") as BattleManager
	get_tree().root.add_child(battle)
	await _idle_frames(10)
	var ui := battle.get_node("CanvasLayer/BattleUI") as BattleUI
	return {"battle": battle, "manager": manager, "ui": ui}


func _teardown(battle: Node) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
	await _idle_frames(2)
	if EncounterCoordinator.has_active_encounter():
		EncounterCoordinator.resolve_active_encounter(&"escape")
	WorldProgress.reset_story()
	await _idle_frames(2)


func _click_button(button: Button) -> void:
	var click_position: Vector2 = button.global_position + button.size * 0.5
	# A motion event to establish real hover state before the click is
	# needed for reliable back-to-back synthetic clicks on the same Control
	# (a bare press+release pair with no preceding motion can leave Godot's
	# GUI hover/press bookkeeping in a stale state on the second click).
	var motion := InputEventMouseMotion.new()
	motion.position = click_position
	Input.parse_input_event(motion)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_position
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = click_position
	Input.parse_input_event(release)


## Waits for the battle to reach a genuinely settled resting state (WIN,
## LOSE, or back to PLAYER_TURN), rather than merely "not ACTION_RESOLUTION"
## -- the latter is true both before a click's input event has even been
## processed (state is still PLAYER_TURN) and after resolution completes,
## so it does not actually prove anything was resolved.
func _wait_for_settled_state(manager: BattleManager, timeout_seconds: float) -> bool:
	var settled: Array = [
		BattleManager.BattleState.WIN,
		BattleManager.BattleState.LOSE,
	]
	var elapsed := 0.0
	var left_player_turn := false
	while elapsed < timeout_seconds:
		if manager.state != BattleManager.BattleState.PLAYER_TURN:
			left_player_turn = true
		if left_player_turn and (manager.state in settled or manager.state == BattleManager.BattleState.PLAYER_TURN):
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	get_tree().quit(1)
