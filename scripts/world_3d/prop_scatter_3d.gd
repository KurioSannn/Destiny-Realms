@tool
extends Node3D
class_name PropScatter3D

## One-shot procedural prop scatter for filling empty ground with variety
## (multiple mesh types) -- unlike GrassField3D, which is a single MultiMesh
## and can only use one mesh. This spawns REAL child Node3D instances (like
## Abyss Forest's procedural dressing), so after scattering you can freely
## hand-edit, move, or delete individual results in the editor. It automates
## the tedious first pass; it doesn't replace manual placement.
##
## Toggle `scatter_now` in the Inspector to (re)roll -- it clears whatever
## this node previously scattered and spawns a fresh batch, so you can
## re-roll the random_seed until you like the result, then leave it alone.

@export var prop_scenes: Array[PackedScene] = []
@export var field_size: Vector2 = Vector2(20.0, 20.0)
@export_range(1, 500, 1) var count: int = 20
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
@export var random_seed: int = 1
## Positions, local to this node, to leave clear (e.g. existing manual
## clusters, paths, water) -- nothing spawns within `avoid_radius` of any of
## these.
@export var avoid_points: Array[Vector3] = []
@export var avoid_radius: float = 4.0
## Toggle (on or off, either way) to clear and re-scatter.
@export var scatter_now: bool = false:
	set(value):
		_scatter()


func _scatter() -> void:
	if prop_scenes.is_empty():
		return
	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 15:
		attempts += 1
		var pos := Vector3(
			rng.randf_range(-field_size.x * 0.5, field_size.x * 0.5),
			0.0,
			rng.randf_range(-field_size.y * 0.5, field_size.y * 0.5)
		)
		var blocked := false
		for avoid in avoid_points:
			if pos.distance_to(avoid) < avoid_radius:
				blocked = true
				break
		if blocked:
			continue

		var scene: PackedScene = prop_scenes[rng.randi_range(0, prop_scenes.size() - 1)]
		var instance := scene.instantiate() as Node3D
		if instance == null:
			continue
		add_child(instance)
		var edited_root := get_tree().edited_scene_root if Engine.is_editor_hint() and get_tree() != null else null
		if edited_root != null:
			instance.owner = edited_root
		instance.position = pos
		instance.rotation.y = rng.randf_range(0.0, TAU)
		var scale_factor := rng.randf_range(min_scale, max_scale)
		instance.scale = Vector3.ONE * scale_factor
		placed += 1
