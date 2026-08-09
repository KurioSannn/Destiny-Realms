extends Resource
class_name EncounterContext

## Clean, serializable handoff from exploration to Block 14's battle
## transition. Deliberately holds only IDs/data, never direct scene-node
## references, so it survives a scene change intact.

enum OpeningAdvantage { NEUTRAL, PLAYER_ADVANTAGE, ENEMY_ADVANTAGE }

@export var encounter_id: StringName = &""
@export var source_world_scene: String = ""
@export var encounter_group_id: StringName = &""
@export var battle_enemy_ids: Array[StringName] = []
@export var opening_advantage: OpeningAdvantage = OpeningAdvantage.NEUTRAL
@export var initiating_enemy_id: StringName = &""
@export var initiating_player_character_id: StringName = &""
## Block 15: identifies the area/biome of the encounter so the
## BattleEnvironmentRegistry can select the correct 3D arena.
## Convention: use snake_case area IDs ("abyss_forest", "werdonia_outskirts").
@export var source_area_id: StringName = &""
## Optional, only for data that doesn't yet warrant its own typed field.
@export var metadata: Dictionary = {}
