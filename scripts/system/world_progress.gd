extends Node

const BANDIT_ENCOUNTER_ID: StringName = &"clover_bandit"

var active_battle_id: StringName = &""
var grassland_spawn: StringName = &"clover_start"
var bandit_defeated: bool = false
var bandit_intro_seen: bool = false
var city_spawn: StringName = &"great_gate_start"
var city_arrival_seen: bool = false
var sunstone_reached: bool = false

## Generic equivalent of bandit_defeated, for Block 13/14 world encounters:
## a world scene reload (the existing full-scene-reload transition pattern)
## destroys and recreates ExplorationEnemy3D instances from scratch, so a
## victory needs to survive that reload as plain data, keyed by the
## defeated actor's stable world_actor_id. Not a general save system --
## just the minimum needed for "stays defeated for the rest of this session."
var defeated_world_actor_ids: Dictionary = {}


func reset_story() -> void:
	active_battle_id = &""
	grassland_spawn = &"clover_start"
	bandit_defeated = false
	bandit_intro_seen = false
	city_spawn = &"great_gate_start"
	city_arrival_seen = false
	sunstone_reached = false
	defeated_world_actor_ids.clear()


func mark_world_actor_defeated(world_actor_id: StringName) -> void:
	if world_actor_id.is_empty():
		return
	defeated_world_actor_ids[world_actor_id] = true


func is_world_actor_defeated(world_actor_id: StringName) -> bool:
	return defeated_world_actor_ids.get(world_actor_id, false)


func begin_bandit_encounter() -> void:
	active_battle_id = BANDIT_ENCOUNTER_ID
	grassland_spawn = &"old_stone_after_battle"
	bandit_intro_seen = true


func complete_active_encounter() -> void:
	if active_battle_id == BANDIT_ENCOUNTER_ID:
		bandit_defeated = true
		grassland_spawn = &"old_stone_after_battle"
	active_battle_id = &""


func enter_werdonia_city() -> void:
	city_spawn = &"great_gate_start"


func reach_sunstone_quarter() -> void:
	city_spawn = &"sunstone_entry"
	sunstone_reached = true
