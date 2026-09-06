extends Resource
class_name BattleEnvironmentProfile

## Block 15: data-driven descriptor for a single contextual battle arena.
## Adding a new arena for a future area is: new BattleEnvironmentProfile .tres
## + new environment scene -- no BattleManager changes.

@export_category("Identity")
## Stable ID, referenced by BattleEnvironmentRegistry lookup.
## Convention: snake_case, e.g. "abyss_forest", "werdonia_outskirts".
@export var arena_id: StringName = &""
## The area/biome this arena belongs to. Must match EncounterContext.source_area_id.
@export var area_id: StringName = &""

@export_category("Scene")
## Path to the Node3D scene containing the 3D diorama environment.
## Instantiated as a child of the BattlePresentation3D root.
@export var environment_scene: String = ""

@export_category("Lighting and Atmosphere")
## Optional WorldEnvironment resource to apply to the battle scene.
## If empty, the scene's own WorldEnvironment node is used.
@export var environment_resource: Environment = null
## Optional fog color override (applied to Environment.fog_light_color).
@export var fog_color: Color = Color(0.08, 0.25, 0.29, 1.0)
@export var fog_density: float = 0.025
@export var ambient_light_color: Color = Color(0.18, 0.34, 0.38, 1.0)
@export var ambient_light_energy: float = 0.72

@export_category("Audio")
## Optional BGM to play during battles in this arena.
## Leave empty to use the existing battle BGM logic.
@export var ambient_audio_id: StringName = &""

@export_category("Camera")
## Camera default (IDLE) position offset from arena center (Y = height, Z = distance back).
## Defaults match BattleCamera3D's built-in IDLE preset -- a profile that
## doesn't override these renders identically to the shared default.
@export var camera_default_offset: Vector3 = Vector3(-1.4, 4.0, 8.6)
## Default camera look-at offset from arena center.
@export var camera_look_at_offset: Vector3 = Vector3(0.6, 1.05, -0.5)

@export_category("Formation")
## World-space center of the battle formation area.
@export var arena_center: Vector3 = Vector3.ZERO
## Optional floor Y for actor grounding.
@export var arena_floor_y: float = 0.0
