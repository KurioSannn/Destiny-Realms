extends Resource
class_name BattleEnemyProfile

## Per-species battle profile. Defines combat stats and display information
## for enemies encountered in the turn-based battle system.

@export_category("Identity")
@export var enemy_id: StringName = &""
@export var display_name: String = ""

@export_category("Combat Stats")
@export var max_hp: int = 120
@export var base_damage: int = 14


func to_dict() -> Dictionary:
	return {
		"name": display_name,
		"max_hp": max_hp,
		"damage": base_damage,
	}
