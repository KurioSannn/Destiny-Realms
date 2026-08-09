extends Resource
class_name ExplorationEnemyProfile

## Per-species exploration tuning, kept separate from ExplorationEnemy3D so a
## new enemy species (bandit, elite, etc.) is a new .tres, not a new
## controller script. Battle stats (HP/damage formulas) intentionally live in
## whatever resource the battle system already owns -- battle_enemy_id is
## just the bridge Block 14 will use to look those up.

@export_category("Identity")
@export var enemy_id: StringName = &""
@export var display_name: String = ""
## Default battle-side identifier this species maps to when an encounter
## doesn't specify its own group (see ExplorationEnemy3D.encounter_group).
@export var battle_enemy_id: StringName = &""
@export var enemy_tags: Array[StringName] = []
## Block 15: identifies the area/biome this enemy belongs to.
## Propagated into EncounterContext.source_area_id so the battle system
## can select the correct 3D arena. Convention: snake_case ("abyss_forest").
@export var source_area_id: StringName = &""

@export_category("Movement")
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 4.2
@export var acceleration: float = 12.0

@export_category("Perception")
@export var detection_range: float = 10.0
@export var lose_target_range: float = 15.0
@export var detection_angle_degrees: float = 110.0
@export var alert_delay: float = 0.4
@export var use_line_of_sight: bool = false

@export_category("Engagement")
@export var engage_range: float = 1.6
@export var leash_distance: float = 16.0
@export var return_tolerance: float = 0.75

@export_category("Field Interaction")
@export var exploration_attackable: bool = true
@export var player_attack_opening_advantage_allowed: bool = true
@export var enemy_ambush_allowed: bool = false

@export_category("Presentation Hooks")
@export var idle_animation: StringName = &"idle"
@export var move_animation: StringName = &"move"
@export var alert_animation: StringName = &"alert"
@export var alert_vfx_id: StringName = &""
@export var footstep_audio_id: StringName = &""
