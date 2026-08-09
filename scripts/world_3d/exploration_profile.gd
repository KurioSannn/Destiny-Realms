extends Resource
class_name ExplorationProfile

## Per-character exploration tuning, kept separate from
## ExplorationCharacterController3D so a new playable character (Yokuni, etc.)
## is a new .tres, not a new controller script or a code change.

@export var character_id: StringName = &""
@export var display_name: String = ""

@export_category("Movement")
@export var move_speed: float = 5.2
@export var sprint_speed: float = 8.5
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var jump_velocity: float = 5.8

@export_category("Exploration Actions")
@export var exploration_attack_cooldown: float = 0.5
@export var exploration_attack_range: float = 2.2
@export var exploration_skill_cooldown: float = 3.0
