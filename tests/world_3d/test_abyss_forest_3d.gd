extends Node

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")


func _ready() -> void:
	var world := ABYSS_SCENE.instantiate() as Node3D
	if world == null:
		_fail("Abyss Forest 3D could not be instantiated")
		return

	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var camera := world.get_node_or_null("ExplorationCamera") as Camera3D
	var generated := world.get_node_or_null("GeneratedWorld") as Node3D
	if player == null:
		_fail("Hybrid 2D/3D player is missing")
		return
	if camera == null or not camera.current:
		_fail("Isometric camera is missing or not current")
		return
	var generated_asset_count: int = int(world.get("generated_asset_count"))
	if generated == null or generated_asset_count < 90:
		_fail("Abyss Forest dressing did not generate enough 3D assets")
		return

	var start_position := player.global_position
	Input.action_press("move_up")
	for frame_index in range(12):
		await get_tree().physics_frame
	Input.action_release("move_up")
	if player.global_position.distance_to(start_position) < 0.15:
		_fail("Hybrid player did not move across the 3D world")
		return

	print("ABYSS_FOREST_3D_OK assets=%d player=%s camera=%s" % [
		generated_asset_count,
		str(player.global_position),
		str(camera.global_position)
	])
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
