extends Resource
class_name ActorVisualProfile

## Game-wide "what does this actor look like" descriptor.
##
## Deliberately NOT battle-specific and NOT exploration-specific: the same
## creature should read as the same creature everywhere it appears. A new
## species/character is a new .tres in res://resources/actor_visuals/ --
## no code change anywhere (ActorVisualRegistry auto-discovers the folder).
##
## Resolution order when applied to a 3D actor:
##   1. model_scene   -- a real 3D model (preferred; matches exploration)
##   2. billboard_texture -- a flat sprite fallback
##   3. caller's own fallback (procedural placeholder)

@export_category("Identity")
## Stable lookup key. For enemies this matches EncounterContext's
## battle_enemy_id (e.g. &"lesser_abyss"); for party members, the character
## id (e.g. &"takashi").
@export var actor_id: StringName = &""
@export var display_name: String = ""

@export_category("3D Visual")
## Path to a 3D scene/GLTF. This is the SAME asset the exploration world
## uses for the species, so field and battle show one creature.
@export_file("*.tscn", "*.gltf", "*.glb") var model_scene: String = ""
## Feet-to-head height in metres. Every visual is normalised to this,
## whatever the asset's authored scale happens to be.
@export var world_height: float = 1.7
## Extra yaw applied after the model is turned to face its opponent, for
## assets whose "forward" axis is not -Z.
@export var model_yaw_offset_degrees: float = 0.0

@export_category("2D Fallback")
## Used only when model_scene is empty or fails to load.
@export var billboard_texture: Texture2D = null


## Applies this profile to a BattleActor3D. Returns true if a real visual
## was installed (so the caller knows not to build a placeholder).
func apply_to(actor: Node) -> bool:
	if actor == null:
		return false
	if not model_scene.is_empty() and actor.has_method("setup_model_visual"):
		if bool(actor.call("setup_model_visual", model_scene, world_height, model_yaw_offset_degrees)):
			return true
	if billboard_texture != null and actor.has_method("setup_static_texture"):
		actor.call("setup_static_texture", billboard_texture, world_height)
		return true
	return false
