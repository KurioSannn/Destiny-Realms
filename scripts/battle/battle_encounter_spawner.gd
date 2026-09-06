extends RefCounted
class_name BattleEncounterSpawner

## BattleEncounterSpawner
## Manages formation slot positioning and runtime replication of enemy Combatants
## for multi-enemy encounters.

const ENCOUNTER_GROUP_SCALE: float = 0.62


static func get_formation_slot_position(
	index: int,
	primary_enemy: Combatant,
	enemy_formation: Node2D
) -> Vector2:
	if enemy_formation != null:
		var slot := enemy_formation.get_node_or_null("EnemySlot%d" % (index + 1))
		if slot is Node2D:
			return (slot as Node2D).position
	if primary_enemy != null:
		return primary_enemy.position + Vector2(140.0 * float(index + 1), 0.0)
	return Vector2.ZERO


static func spawn_additional_enemies(
	pending_ids: Array[StringName],
	primary_enemy: Combatant,
	enemy_formation: Node2D,
	parent_node: Node,
	profile_provider: Callable,
	default_max_hp: int = 120,
	default_damage: int = 14
) -> Array[Combatant]:
	var spawned: Array[Combatant] = []
	if pending_ids.is_empty() or primary_enemy == null or parent_node == null:
		return spawned

	for index in range(pending_ids.size()):
		var extra_id: StringName = pending_ids[index]
		var data: Dictionary = profile_provider.call(extra_id) if profile_provider.is_valid() else {}
		if data.is_empty():
			push_error("BattleEncounterSpawner: unknown extra battle_enemy_id '%s'; skipping roster slot" % extra_id)
			continue
		var extra_enemy := primary_enemy.duplicate() as Combatant
		extra_enemy.name = "EncounterEnemy%d" % (index + 2)
		extra_enemy.position = get_formation_slot_position(index, primary_enemy, enemy_formation)
		extra_enemy.home_scale = Vector2.ONE * ENCOUNTER_GROUP_SCALE
		parent_node.add_child(extra_enemy)
		extra_enemy.set_home_position(extra_enemy.position)
		extra_enemy.setup(
			data.get("name", "Lesser Abyss"),
			data.get("max_hp", default_max_hp),
			data.get("damage", default_damage)
		)
		spawned.append(extra_enemy)

	pending_ids.clear()
	return spawned
