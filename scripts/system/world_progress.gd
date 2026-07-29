extends Node

const BANDIT_ENCOUNTER_ID: StringName = &"clover_bandit"

var active_battle_id: StringName = &""
var grassland_spawn: StringName = &"clover_start"
var bandit_defeated: bool = false
var bandit_intro_seen: bool = false
var city_spawn: StringName = &"great_gate_start"
var city_arrival_seen: bool = false
var sunstone_reached: bool = false


func reset_story() -> void:
	active_battle_id = &""
	grassland_spawn = &"clover_start"
	bandit_defeated = false
	bandit_intro_seen = false
	city_spawn = &"great_gate_start"
	city_arrival_seen = false
	sunstone_reached = false


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
