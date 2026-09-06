@tool
extends MultiMeshInstance3D
class_name GrassField3D

## Zelda/Genshin-style dense grass field via GPU instancing (MultiMesh).
## Drop this node onto any ground area and it scatters `blade_count` copies
## of `grass_mesh_scene` across `field_size`, each with randomized position,
## yaw, and scale, then applies a wind-sway shader built from the source
## mesh's own texture. One draw call regardless of blade_count.
##
## Editable live in the editor (@tool) -- change any exported value and the
## field regenerates immediately so you can tune density/size by eye.

const WIND_SHADER := preload("res://resources/shaders/grass_wind.gdshader")
const DEFAULT_GRASS_MESH := "res://Asset 3d/Stylized Nature MegaKit[Standard]/glTF/Grass_Common_Short.gltf"

@export var grass_mesh_scene: PackedScene = load(DEFAULT_GRASS_MESH):
	set(value):
		grass_mesh_scene = value
		_regenerate()
@export var field_size: Vector2 = Vector2(10.0, 10.0):
	set(value):
		field_size = value
		_regenerate()
@export_range(1, 20000, 1) var blade_count: int = 800:
	set(value):
		blade_count = value
		_regenerate()
## Target real-world height of a blade, in meters (measured from the source
## mesh's own bounding box, so this works regardless of which grass mesh is
## plugged in). Realistic short/medium grass is roughly 0.15-0.35m.
@export var target_height: float = 0.28:
	set(value):
		target_height = value
		_regenerate()
## Random height variance around target_height, e.g. 0.2 = +/-20%.
@export_range(0.0, 0.9, 0.01) var height_variance: float = 0.25:
	set(value):
		height_variance = value
		_regenerate()
@export var random_seed: int = 1:
	set(value):
		random_seed = value
		_regenerate()
@export var wind_strength: float = 0.15:
	set(value):
		wind_strength = value
		_apply_shader_params()
@export var wind_speed: float = 1.6:
	set(value):
		wind_speed = value
		_apply_shader_params()
## Toggle (on or off, either way) to force a manual re-scatter in the editor.
@export var regenerate_now: bool = false:
	set(value):
		_regenerate()


func _ready() -> void:
	_regenerate()


func _regenerate() -> void:
	if grass_mesh_scene == null:
		return
	var extracted := _extract_mesh_and_material(grass_mesh_scene)
	var source_mesh: Mesh = extracted.get("mesh")
	if source_mesh == null:
		return

	var source_height: float = maxf(extracted.get("height", 1.0), 0.001)
	var base_scale: float = target_height / source_height

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = source_mesh
	mm.instance_count = max(blade_count, 1)

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for i in range(mm.instance_count):
		var x := rng.randf_range(-field_size.x * 0.5, field_size.x * 0.5)
		var z := rng.randf_range(-field_size.y * 0.5, field_size.y * 0.5)
		var variance := rng.randf_range(1.0 - height_variance, 1.0 + height_variance)
		var scale_factor := base_scale * variance
		var yaw := rng.randf_range(0.0, TAU)
		var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor), Vector3(x, 0.0, z))
		mm.set_instance_transform(i, t)

	multimesh = mm
	_ensure_shader_material(extracted.get("material") as StandardMaterial3D)


func _apply_shader_params() -> void:
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("wind_speed", wind_speed)


## Only builds a fresh shader material the first time (or if something else
## replaced material_override with a non-wind-shader material). If a
## ShaderMaterial using this same wind shader is already assigned -- e.g.
## hand-tuned in the editor with extra params like base_color/tip_color that
## this script doesn't itself expose -- it's left completely alone so those
## customizations survive scene reload/Play instead of being silently reset
## to this script's plain defaults every time _regenerate() runs.
func _ensure_shader_material(source_material: StandardMaterial3D) -> void:
	var existing := material_override as ShaderMaterial
	if existing != null and existing.shader == WIND_SHADER:
		_apply_shader_params()
		return
	_build_shader_material(source_material)


func _build_shader_material(source_material: StandardMaterial3D) -> void:
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = WIND_SHADER
	if source_material != null:
		shader_mat.set_shader_parameter("albedo_texture", source_material.albedo_texture)
		shader_mat.set_shader_parameter("albedo_color", source_material.albedo_color)
	shader_mat.set_shader_parameter("wind_strength", wind_strength)
	shader_mat.set_shader_parameter("wind_speed", wind_speed)
	material_override = shader_mat


func _extract_mesh_and_material(scene: PackedScene) -> Dictionary:
	var instance := scene.instantiate()
	var mesh_instance: MeshInstance3D = null
	if instance is MeshInstance3D:
		mesh_instance = instance
	else:
		for child in instance.get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break

	var result := {"mesh": null, "material": null, "height": 1.0}
	if mesh_instance != null:
		result["mesh"] = mesh_instance.mesh
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			result["material"] = mesh_instance.mesh.surface_get_material(0)
			result["height"] = maxf(mesh_instance.mesh.get_aabb().size.y, 0.001)
	instance.queue_free()
	return result
