extends Node

## Confirms the Block 13 Abyss testbed content exists correctly and that nothing
## from Block 11/12 regressed alongside it (asset count, camera, pickup,
## interactable, trigger, seal).

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const EXPECTED_ASSET_COUNT := 201  # unchanged from Block 11/12 -- enemies are not _spawn_asset() content


func _ready() -> void:
	var world := ABYSS_SCENE.instantiate() as Node3D
	if world == null:
		_fail("Abyss Forest could not be instantiated for the enemy testbed check")
		return
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame

	var generated_asset_count: int = int(world.get("generated_asset_count"))
	if generated_asset_count != EXPECTED_ASSET_COUNT:
		_fail(
			"generated_asset_count changed unexpectedly: expected %d, got %d (Block 13 must not touch world composition)"
			% [EXPECTED_ASSET_COUNT, generated_asset_count]
		)
		return

	var stationary := world.get_node_or_null("TestEnemyStationary") as ExplorationEnemy3D
	var patrol := world.get_node_or_null("TestEnemyPatrol") as ExplorationEnemy3D
	var group := world.get_node_or_null("TestEnemyGroup") as ExplorationEnemy3D
	if stationary == null or patrol == null or group == null:
		_fail("One or more Block 13 test enemies are missing from the Abyss scene")
		return

	if stationary.profile == null or stationary.profile.enemy_id != &"lesser_abyss":
		_fail("TestEnemyStationary is missing its Lesser Abyss profile")
		return
	if patrol.get_node_or_null(patrol.patrol_route_path) == null:
		_fail("TestEnemyPatrol's patrol_route_path did not resolve")
		return
	if group.encounter_group == null or group.encounter_group.battle_enemy_ids.size() != 2:
		_fail("TestEnemyGroup must represent a 2-enemy encounter group")
		return

	for frame_index in range(10):
		await get_tree().physics_frame
	if stationary.get_state() == ExplorationEnemy3D.State.DISABLED:
		_fail("Stationary test enemy should not start DISABLED")
		return

	# --- Block 11/12 regression spot checks ---
	if world.get_node_or_null("ExplorationCamera") == null:
		_fail("ExplorationCamera missing (Block 11 regression)")
		return
	if world.get_node_or_null("Player") == null:
		_fail("Player missing (Block 12 regression)")
		return
	if world.get_node_or_null("TestPickup") == null:
		_fail("Block 12 TestPickup missing")
		return
	if world.get_node_or_null("TestInteractable") == null:
		_fail("Block 12 TestInteractable missing")
		return
	if world.get_node_or_null("TestTrigger") == null:
		_fail("Block 12 TestTrigger missing")
		return
	if world.get_node_or_null("SealArea") == null:
		_fail("SealArea missing (seal progression regression)")
		return

	print("ABYSS_ENEMY_TESTBED_OK 3 enemies present and configured, asset count unchanged, Block 11/12 content intact")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
