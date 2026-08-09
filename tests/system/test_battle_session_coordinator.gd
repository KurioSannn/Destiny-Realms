extends Node

## BattleSessionCoordinator: encounter validation/rejection, session capture,
## GameFlowState EXPLORATION->TRANSITION timing, and failure recovery.
## Deliberately stops short of letting the real SceneTransition scene-swap
## fire (it would tear down this test's own scene tree) -- everything
## verifiable up to that point is asserted directly instead, matching how
## the rest of this project tests scene-transition-adjacent code by
## instancing pieces directly rather than driving a real scene change.


func _ready() -> void:
	GameFlowState.set_context(GameFlowState.InputContext.EXPLORATION)

	var player := _make_character(Vector3(0.0, 0.5, 0.0))
	GameFlowState.set_active_character(player)

	var enemy := _make_enemy(Vector3(3.0, 0.5, 0.0), &"session_test_enemy")

	# --- Invalid context: empty roster rejected, no state mutation leaks ---
	var empty_roster_context := EncounterContext.new()
	empty_roster_context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	empty_roster_context.initiating_enemy_id = &"session_test_enemy"
	if EncounterCoordinator.request_encounter(empty_roster_context):
		# EncounterCoordinator accepts anything non-duplicate; BattleSessionCoordinator
		# is responsible for content validation and must clean up after itself.
		await get_tree().physics_frame
		if EncounterCoordinator.has_active_encounter():
			_fail("An empty-roster context must be rejected and cleared, not left active")
			return
		if GameFlowState.current_context != GameFlowState.InputContext.EXPLORATION:
			_fail("Rejecting an invalid context must never have touched GameFlowState")
			return
	else:
		_fail("EncounterCoordinator unexpectedly refused the first request of the test")
		return

	# --- Missing source_world_scene: also rejected ---
	var no_scene_context := EncounterContext.new()
	no_scene_context.battle_enemy_ids = [&"lesser_abyss"]
	EncounterCoordinator.request_encounter(no_scene_context)
	await get_tree().physics_frame
	if EncounterCoordinator.has_active_encounter():
		_fail("A context with no source_world_scene must be rejected and cleared")
		return

	print("HANDOFF_VALIDATION_OK empty roster and missing source scene both rejected cleanly")

	# --- Valid context: accepted, session captured, EXPLORATION -> TRANSITION ---
	var valid_context := EncounterContext.new()
	valid_context.encounter_id = &"session_test_encounter"
	valid_context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	valid_context.battle_enemy_ids = [&"lesser_abyss"]
	valid_context.opening_advantage = EncounterContext.OpeningAdvantage.NEUTRAL
	valid_context.initiating_enemy_id = &"session_test_enemy"

	if not EncounterCoordinator.request_encounter(valid_context):
		_fail("A fully valid context was unexpectedly rejected by EncounterCoordinator")
		return
	await get_tree().physics_frame
	if not BattleSessionCoordinator.has_active_session():
		_fail("A valid, accepted context must produce an active BattleSessionCoordinator session")
		return
	if GameFlowState.current_context != GameFlowState.InputContext.TRANSITION:
		_fail("Accepting an encounter must move GameFlowState from EXPLORATION to TRANSITION immediately")
		return

	print("FLOW_TIMING_OK EXPLORATION -> TRANSITION on accepted encounter verified")

	# --- Duplicate rejection, layer 1: EncounterCoordinator itself ---
	var second_context := EncounterContext.new()
	second_context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	second_context.battle_enemy_ids = [&"lesser_abyss"]
	if EncounterCoordinator.request_encounter(second_context):
		_fail("EncounterCoordinator must reject a second request while one is already in flight")
		return

	# --- Duplicate rejection, layer 2: BattleSessionCoordinator's own guard ---
	# (simulated as if EncounterCoordinator's guard were somehow bypassed)
	BattleSessionCoordinator.call("_on_encounter_requested", second_context)
	await get_tree().physics_frame
	# Still exactly one session's worth of state -- no crash, no second session created.
	if not BattleSessionCoordinator.has_active_session():
		_fail("BattleSessionCoordinator's own duplicate guard must not clear the real session")
		return

	print("DUPLICATE_REJECTION_OK both EncounterCoordinator and BattleSessionCoordinator guards verified")

	# --- Return-position offset: captured away from the enemy, not on top of it ---
	# (accessing the private capture for verification, same convention as other tests in this project)
	var captured_session: Dictionary = BattleSessionCoordinator.get("_active_session")
	if captured_session.is_empty():
		_fail("Expected _active_session to be populated after a valid accepted encounter")
		return
	var return_position: Vector3 = captured_session.get("return_position", Vector3.ZERO)
	if return_position.distance_to(enemy.global_position) < 1.0:
		_fail("Captured return position must be offset away from the enemy, not overlapping it")
		return
	if return_position.distance_to(player.global_position) > 2.0:
		_fail("Captured return position must stay close to where the encounter actually began")
		return

	print("RETURN_POSITION_OK offset-from-enemy capture verified")

	# --- Duplicate world_actor_id: fails loudly (logged), does not crash ---
	var duplicate_enemy := _make_enemy(Vector3(3.0, 0.5, 0.0), &"session_test_enemy")
	var found: Variant = BattleSessionCoordinator.call("_find_world_actor", &"session_test_enemy")
	if found == null:
		_fail("_find_world_actor must still resolve to *a* match even when IDs collide (logs an error, doesn't fail silently)")
		return
	duplicate_enemy.queue_free()

	print("BATTLE_SESSION_COORDINATOR_ALL_OK")
	get_tree().quit(0)


func _make_character(position: Vector3) -> ExplorationCharacterController3D:
	var character := ExplorationCharacterController3D.new()
	character.name = "SessionTestCharacter"
	var capsule_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	capsule_shape.shape = capsule
	character.add_child(capsule_shape)
	var visual := AnimatedSprite3D.new()
	visual.name = "CharacterVisual"
	character.add_child(visual)
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	shadow.mesh = QuadMesh.new()
	character.add_child(shadow)
	character.position = position
	add_child(character)
	character.set_physics_process(false)
	return character


func _make_enemy(position: Vector3, actor_id: StringName) -> ExplorationEnemy3D:
	var enemy := ExplorationEnemy3D.new()
	enemy.world_actor_id = actor_id
	var capsule_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	capsule_shape.shape = capsule
	enemy.add_child(capsule_shape)
	enemy.position = position
	add_child(enemy)
	return enemy


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
