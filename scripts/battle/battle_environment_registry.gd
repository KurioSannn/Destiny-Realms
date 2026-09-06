extends Node

## Block 15: maps source_area_id (from EncounterContext) to the correct
## BattleEnvironmentProfile. This is the ONLY place that knows which arena
## belongs to which area -- BattleManager and the encounter system never
## reference arena IDs directly.
##
## Adding a future area is: register a new profile here (or load from a
## resource directory). No other code changes required.
##
## Profiles are registered by area_id. If a lookup misses, resolve_arena()
## returns null safely -- the caller falls back to a generic presentation.

var _profiles: Dictionary = {}

## Pre-loaded profiles keyed by area_id StringName.
## Block 15 ships with Abyss Forest. Future areas extend this list.
const ABYSS_FOREST_PROFILE_PATH: String = "res://resources/battle_arenas/abyss_forest_arena_profile.tres"
## Manually-authored template arena -- see scenes/battle/arenas/README_werdonia_outskirts.md.
## Not yet used by any live encounter (no exploration enemy currently tags
## source_area_id = "werdonia_outskirts"), so registering it here is inert
## until that tagging exists -- safe to ship ahead of time.
const WERDONIA_OUTSKIRTS_PROFILE_PATH: String = "res://resources/battle_arenas/werdonia_outskirts_arena_profile.tres"


func _ready() -> void:
	_load_built_in_profiles()


func _load_built_in_profiles() -> void:
	_try_register(ABYSS_FOREST_PROFILE_PATH)
	_try_register(WERDONIA_OUTSKIRTS_PROFILE_PATH)


func _try_register(path: String) -> void:
	if path.is_empty():
		return
	var profile = load(path)
	if profile == null:
		push_warning("BattleEnvironmentRegistry: could not load profile at '%s'" % path)
		return
	if not ("area_id" in profile) or (profile.area_id as StringName).is_empty():
		push_warning("BattleEnvironmentRegistry: profile at '%s' has empty area_id; skipped" % path)
		return
	_profiles[profile.area_id] = profile


## Registers a BattleEnvironmentProfile at runtime (useful for testing
## or dynamically loaded content). Overwrites a previously registered
## profile for the same area_id.
func register(profile) -> void:
	if profile == null or not ("area_id" in profile):
		push_error("BattleEnvironmentRegistry: register() called with null or id-less profile")
		return
	if (profile.area_id as StringName).is_empty():
		push_error("BattleEnvironmentRegistry: register() called with empty area_id")
		return
	_profiles[profile.area_id] = profile


## Returns the BattleEnvironmentProfile for a given area_id, or null if
## unregistered. A null return must be handled gracefully by the caller.
func resolve_arena(area_id: StringName):
	if area_id.is_empty():
		return null
	var profile = _profiles.get(area_id)
	if profile == null:
		push_warning("BattleEnvironmentRegistry: no arena registered for area_id '%s'" % area_id)
	return profile


## Convenience: resolves directly from an EncounterContext.
func resolve_from_context(context) -> Object:
	if context == null:
		return null
	return resolve_arena(context.source_area_id)


func has_arena(area_id: StringName) -> bool:
	return _profiles.has(area_id)

