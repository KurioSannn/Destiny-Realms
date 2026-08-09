extends Node

## Block 14 world-side return path: AbyssForest3D._ready() must, in order,
## (1) re-apply any previously-persisted world-actor defeats, (2) consume a
## pending BattleSessionCoordinator return (resolving the correct actor by
## world_actor_id and restoring the player to the captured return position),
## and only then (3) hand exploration input back. Instances the real
## abyss_forest_3d.tscn directly (matching the existing project convention
## of testing scene-level behavior against production scenes, not stand-ins).

const ABYSS_FOREST_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const TARGET_ACTOR_ID := &"abyss_lesser_stationary"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_victory_return_resolves_actor_and_restores_position()
	await _test_persisted_defeat_survives_a_fresh_instance()
	await _test_no_pending_return_is_inert()

	print("ABYSS_BATTLE_RETURN_ALL_OK")
	get_tree().quit(0)


func _test_victory_return_resolves_actor_and_restores_position() -> void:
	WorldProgress.reset_story()
	var expected_position := Vector3(4.0, 0.5, -2.0)
	BattleSessionCoordinator.set("_pending_return", {
		"result": &"victory",
		"world_actor_id": TARGET_ACTOR_ID,
		"return_position": expected_position,
		"source_world_scene": "res://scenes/world_3d/abyss_forest_3d.tscn",
	})

	var forest := await _instantiate_forest()
	var actor := forest.get_node("TestEnemyStationary") as ExplorationEnemy3D

	if not actor.is_disabled():
		_fail("A victory return must resolve the source enemy to DISABLED")
		return
	if not WorldProgress.is_world_actor_defeated(TARGET_ACTOR_ID):
		_fail("A victory return must mark the world actor defeated in WorldProgress")
		return
	# Horizontal-only check: Y settles via normal gravity/floor snapping over
	# the idle frames waited below, same as any other CharacterBody3D
	# teleport in this project -- that settling is expected, not a defect.
	var horizontal_actual := Vector2(forest.player.global_position.x, forest.player.global_position.z)
	var horizontal_expected := Vector2(expected_position.x, expected_position.z)
	if horizontal_actual.distance_to(horizontal_expected) > 0.01:
		_fail("Player must be restored to the captured return_position, got %s expected %s" % [forest.player.global_position, expected_position])
		return
	if not forest.player.call("is_exploration_enabled"):
		_fail("Exploration input must be re-enabled on the returning player")
		return
	if GameFlowState.current_context != GameFlowState.InputContext.EXPLORATION:
		_fail("GameFlowState must end in EXPLORATION after a consumed return")
		return
	if not BattleSessionCoordinator.get("_pending_return").is_empty():
		_fail("consume_pending_return() must clear the pending return so it is not reapplied")
		return

	print("VICTORY_RETURN_OK actor resolved to DISABLED, position restored, input re-enabled, context settled")
	forest.queue_free()
	await _idle_frames(2)


func _test_persisted_defeat_survives_a_fresh_instance() -> void:
	# WorldProgress already has TARGET_ACTOR_ID marked defeated from the
	# previous sub-test -- this simulates the full scene reload that
	# SceneTransition performs, where the enemy node itself is destroyed but
	# the defeat must still be re-applied to the brand new instance.
	if not WorldProgress.is_world_actor_defeated(TARGET_ACTOR_ID):
		_fail("Precondition failed: expected the previous sub-test's defeat to still be recorded")
		return

	var forest := await _instantiate_forest()
	var actor := forest.get_node("TestEnemyStationary") as ExplorationEnemy3D
	if not actor.is_disabled():
		_fail("A fresh scene instance must re-apply a persisted defeat on _ready()")
		return

	print("PERSISTED_DEFEAT_OK a brand new scene instance re-applies a prior defeat from WorldProgress")
	forest.queue_free()
	await _idle_frames(2)


func _test_no_pending_return_is_inert() -> void:
	WorldProgress.reset_story()
	# No BattleSessionCoordinator._pending_return set -- an ordinary
	# fresh-load or non-battle-return boot must behave exactly as before.
	var forest := await _instantiate_forest()
	var actor := forest.get_node("TestEnemyStationary") as ExplorationEnemy3D

	if actor.is_disabled():
		_fail("With no persisted defeat and no pending return, the actor must not be disabled")
		return
	if GameFlowState.current_context != GameFlowState.InputContext.EXPLORATION:
		_fail("A normal load with no pending return must still settle into EXPLORATION")
		return

	print("NO_PENDING_RETURN_OK ordinary load is unaffected by the battle-return machinery")
	forest.queue_free()
	await _idle_frames(2)


func _instantiate_forest() -> AbyssForest3D:
	var forest := ABYSS_FOREST_SCENE.instantiate() as AbyssForest3D
	add_child(forest)
	await _idle_frames(4)
	return forest


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
