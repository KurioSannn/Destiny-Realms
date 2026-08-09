extends Resource
class_name EncounterGroupProfile

## What battle-side enemies a single world actor represents. A world encounter
## is not assumed to be 1 world enemy = 1 battle enemy: one visible Lesser
## Abyss can represent a 2-enemy battle group, one visible elite can
## represent itself plus escorts, etc. Assigned per world placement (on the
## ExplorationEnemy3D instance), not per species profile, since the same
## species can anchor different group compositions in different spots.

@export var encounter_group_id: StringName = &""
@export var battle_enemy_ids: Array[StringName] = []
