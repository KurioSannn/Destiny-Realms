extends Marker3D
class_name ExplorationSpawnPoint

## Reusable named spawn/checkpoint marker for map transitions, return-from-
## battle, quest travel, and future save/load -- not death/respawn gameplay,
## which isn't implemented yet. Self-contained on purpose: spawn resolution
## is a static helper here rather than another responsibility bolted onto
## GameFlowState.

const SPAWN_POINT_GROUP := &"exploration_spawn_point"
const DEFAULT_SPAWN_ID := &"default"

@export var spawn_id: StringName = DEFAULT_SPAWN_ID


func _ready() -> void:
	add_to_group(SPAWN_POINT_GROUP)


## Finds a spawn point by ID within the given tree. Falls back to a spawn
## explicitly named "default", then to the first spawn point found, so a
## scene entry never fails to resolve just because a requested ID is missing.
static func find_spawn_point(tree: SceneTree, requested_id: StringName) -> ExplorationSpawnPoint:
	var fallback: ExplorationSpawnPoint = null
	var default_spawn: ExplorationSpawnPoint = null
	for spawn_variant in tree.get_nodes_in_group(SPAWN_POINT_GROUP):
		var spawn := spawn_variant as ExplorationSpawnPoint
		if spawn == null:
			continue
		if fallback == null:
			fallback = spawn
		if spawn.spawn_id == requested_id:
			return spawn
		if spawn.spawn_id == DEFAULT_SPAWN_ID:
			default_spawn = spawn
	return default_spawn if default_spawn != null else fallback
