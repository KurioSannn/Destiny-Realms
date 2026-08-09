extends Resource
class_name CharacterRuntimeState

## Mutable runtime combat state for one party character -- deliberately
## separate from static character configuration (base stats, skills,
## visuals, growth), which stays wherever that already lives. This is the
## ONE authoritative place current_hp/current_energy live across an
## exploration <-> battle transition; nothing else should treat its own
## copy (a Combatant node's current_hp, an exploration HUD field) as
## authoritative -- those are presentation, not truth.
##
## Plain Resource, no scene-node dependencies, so it can be represented as
## saveable data later without rework.

@export var character_id: StringName = &""
@export var max_hp: int = 1
@export var current_hp: int = 1
@export var max_energy: int = 100
@export var current_energy: int = 0
@export var is_defeated: bool = false
