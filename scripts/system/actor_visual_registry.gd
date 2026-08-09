extends Node

## Game-wide registry of ActorVisualProfile resources, auto-discovered from
## res://resources/actor_visuals/. Adding a creature or character to the
## whole game's visual vocabulary is: drop one .tres in that folder.
## No registration call, no code change, no scene edit.
##
## Mirrors the deliberately-narrow shape of BattleEnvironmentRegistry: it
## only answers "what does actor X look like", and never owns stats,
## behaviour, or battle state.

const PROFILE_DIRECTORY: String = "res://resources/actor_visuals/"

var _profiles: Dictionary = {}
var _scanned: bool = false


func _ready() -> void:
	_scan_directory()


## Returns the ActorVisualProfile for an actor id, or null. A null return
## must be handled gracefully by the caller (fall back to a placeholder).
func resolve(actor_id: StringName) -> ActorVisualProfile:
	if actor_id.is_empty():
		return null
	if not _scanned:
		_scan_directory()
	return _profiles.get(actor_id)


func has_profile(actor_id: StringName) -> bool:
	if not _scanned:
		_scan_directory()
	return _profiles.has(actor_id)


## Runtime registration, for tests or dynamically generated content.
func register(profile: ActorVisualProfile) -> void:
	if profile == null or profile.actor_id.is_empty():
		push_error("ActorVisualRegistry: register() needs a profile with a non-empty actor_id")
		return
	_profiles[profile.actor_id] = profile


func get_registered_ids() -> Array:
	if not _scanned:
		_scan_directory()
	return _profiles.keys()


func _scan_directory() -> void:
	_scanned = true
	var dir := DirAccess.open(PROFILE_DIRECTORY)
	if dir == null:
		push_warning("ActorVisualRegistry: no profile directory at '%s'" % PROFILE_DIRECTORY)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			# Exported builds rename .tres to .res; accept both.
			var is_resource := file_name.ends_with(".tres") or file_name.ends_with(".res")
			if is_resource:
				_try_register(PROFILE_DIRECTORY + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _try_register(path: String) -> void:
	var profile := load(path) as ActorVisualProfile
	if profile == null:
		push_warning("ActorVisualRegistry: '%s' is not an ActorVisualProfile" % path)
		return
	if profile.actor_id.is_empty():
		push_warning("ActorVisualRegistry: profile at '%s' has an empty actor_id; skipped" % path)
		return
	_profiles[profile.actor_id] = profile
