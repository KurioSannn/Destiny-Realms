extends Node

## Block 14.5 Part H: verifies each Block 13 Abyss test actor individually.
## Root cause of the "exploration enemies appear static" report: the
## PatrolRoute node in abyss_forest_3d.tscn had no script attached, so
## TestEnemyPatrol's patrol_route_path resolved `as PatrolRoute3D` to null
## and it silently fell back to stationary (a valid, intentional fallback
## for enemies with no route -- just not what TestEnemyPatrol was meant to
## demonstrate). Fixed by attaching patrol_route_3d.gd to that node in the
## scene file; this test locks the fix in with a real position-over-time
## assertion so it cannot silently regress again.

const ABYSS_FOREST_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var forest := ABYSS_FOREST_SCENE.instantiate() as AbyssForest3D
	add_child(forest)
	await _idle_frames(4)

	var stationary := forest.get_node("TestEnemyStationary") as ExplorationEnemy3D
	var patrol := forest.get_node("TestEnemyPatrol") as ExplorationEnemy3D
	var group := forest.get_node("TestEnemyGroup") as ExplorationEnemy3D
	var patrol_route := forest.get_node("PatrolRoute")

	if not (patrol_route is PatrolRoute3D):
		_fail("PatrolRoute node in abyss_forest_3d.tscn has no PatrolRoute3D script attached")
		return
	if (patrol_route as PatrolRoute3D).get_waypoint_count() < 2:
		_fail("PatrolRoute must have at least 2 waypoints for a meaningful patrol")
		return

	# Move the player far away from all three so none of them alert/chase
	# during this test -- this test is about baseline IDLE/PATROL movement,
	# not detection (already covered by test_exploration_enemy_3d.gd).
	forest.player.global_position = Vector3(200.0, 0.63, 200.0)

	var stationary_start := stationary.global_position
	var patrol_start := patrol.global_position
	var group_start := group.global_position

	for frame_index in range(240):
		await get_tree().physics_frame

	# --- TestEnemyStationary: must not move ---
	var stationary_drift := Vector2(stationary.global_position.x, stationary.global_position.z).distance_to(
		Vector2(stationary_start.x, stationary_start.z)
	)
	if stationary_drift > 0.15:
		_fail("TestEnemyStationary drifted %.3f -- it must remain stationary" % stationary_drift)
		return
	if stationary.get_state() != ExplorationEnemy3D.State.IDLE:
		_fail("TestEnemyStationary must stay in IDLE, got %s" % ExplorationEnemy3D.State.keys()[stationary.get_state()])
		return

	# --- TestEnemyPatrol: must physically move through its route ---
	var patrol_drift := Vector2(patrol.global_position.x, patrol.global_position.z).distance_to(
		Vector2(patrol_start.x, patrol_start.z)
	)
	if patrol_drift < 1.0:
		_fail("TestEnemyPatrol did not visibly move (drift=%.3f) -- patrol route is not driving movement" % patrol_drift)
		return
	if patrol.get_state() != ExplorationEnemy3D.State.PATROL:
		_fail("TestEnemyPatrol must remain in PATROL state, got %s" % ExplorationEnemy3D.State.keys()[patrol.get_state()])
		return

	# --- TestEnemyGroup: reports its behavior (stationary by configuration --
	# no patrol_route_path is assigned to it in the scene, matching the
	# "may remain stationary if configured that way" requirement) ---
	var group_drift := Vector2(group.global_position.x, group.global_position.z).distance_to(
		Vector2(group_start.x, group_start.z)
	)
	print(
		"GROUP_ACTOR_REPORT TestEnemyGroup has no patrol_route_path assigned -- intentionally stationary (drift=%.3f, state=%s)"
		% [group_drift, ExplorationEnemy3D.State.keys()[group.get_state()]]
	)

	print("STATIONARY_OK TestEnemyStationary held position and IDLE state")
	print("PATROL_MOVEMENT_OK TestEnemyPatrol physically advanced %.2fm through its route and stayed in PATROL" % patrol_drift)
	print("ABYSS_ENEMY_PATROL_BEHAVIOR_ALL_OK")
	get_tree().quit(0)


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
