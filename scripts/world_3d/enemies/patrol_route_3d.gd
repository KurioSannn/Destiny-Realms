extends Node3D
class_name PatrolRoute3D

## Reusable patrol path: each direct Node3D child is a waypoint, in child
## order. Keeps patrol coordinates out of enemy scripts entirely -- an enemy
## just references a PatrolRoute3D by NodePath. No route assigned = a
## stationary enemy (ExplorationEnemy3D treats that as valid).

enum LoopMode { NONE, LOOP, PING_PONG }

@export var loop_mode: LoopMode = LoopMode.LOOP
@export var pause_seconds_at_point: float = 1.5


func get_waypoint_count() -> int:
	return get_child_count()


func get_waypoint_position(index: int) -> Vector3:
	var marker := get_child(clampi(index, 0, maxi(get_child_count() - 1, 0))) as Node3D
	return marker.global_position if marker != null else global_position


## Given the current waypoint index and travel direction (+1/-1), returns the
## next {index, direction} pair honoring loop_mode. With NONE, direction
## becomes 0 once the end is reached (the enemy simply stops advancing).
func advance(current_index: int, direction: int) -> Dictionary:
	var count := get_waypoint_count()
	if count <= 1:
		return {"index": 0, "direction": direction}

	var next_index := current_index + direction
	match loop_mode:
		LoopMode.LOOP:
			next_index = wrapi(next_index, 0, count)
		LoopMode.PING_PONG:
			if next_index < 0 or next_index >= count:
				direction = -direction
				next_index = current_index + direction
		LoopMode.NONE:
			if next_index < 0 or next_index >= count:
				next_index = current_index
				direction = 0
	return {"index": next_index, "direction": direction}
