extends Node

## Standalone test for ExplorationSpawnPoint's named-spawn resolution --
## no Abyss Forest dependency.


func _ready() -> void:
	var default_spawn := ExplorationSpawnPoint.new()
	default_spawn.spawn_id = &"default"
	add_child(default_spawn)
	default_spawn.global_position = Vector3(0.0, 0.0, 0.0)

	var named_spawn := ExplorationSpawnPoint.new()
	named_spawn.spawn_id = &"from_seal"
	add_child(named_spawn)
	named_spawn.global_position = Vector3(5.0, 0.0, 5.0)

	await get_tree().physics_frame

	var resolved_named := ExplorationSpawnPoint.find_spawn_point(get_tree(), &"from_seal")
	if resolved_named != named_spawn:
		_fail("find_spawn_point did not resolve a matching named spawn")
		return

	var resolved_missing := ExplorationSpawnPoint.find_spawn_point(get_tree(), &"does_not_exist")
	if resolved_missing != default_spawn:
		_fail("find_spawn_point did not fall back to the default spawn for an unknown id")
		return

	default_spawn.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved_after_default_removed := ExplorationSpawnPoint.find_spawn_point(get_tree(), &"does_not_exist")
	if resolved_after_default_removed != named_spawn:
		_fail("find_spawn_point did not fall back to the first available spawn when no default exists")
		return

	print("SPAWN_POINT_OK named resolution, default fallback, and first-found fallback verified")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
