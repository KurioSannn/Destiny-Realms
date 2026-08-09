extends Node

## Deliberately small: owns exactly one Dictionary of
## StringName -> CharacterRuntimeState, one per party character, for values
## that must survive an exploration <-> battle transition (current HP,
## current Energy, KO state). Does NOT own inventory, quests, save files,
## party progression, or battle logic -- those stay wherever they already
## live (or don't exist yet).
##
## Initialization is idempotent by design: ensure_initialized() only creates
## a state the first time a given character_id is seen in this session, so
## calling it every time a battle starts never re-rolls an in-progress
## character back to full HP.

signal character_state_changed(character_id: StringName)

var _states: Dictionary = {}


## Returns the existing state for character_id, or creates one (HP = max_hp,
## Energy = starting_energy) the first time this ID is seen this session.
func ensure_initialized(
	character_id: StringName, max_hp: int, max_energy: int = 100, starting_energy: int = 0
) -> CharacterRuntimeState:
	if _states.has(character_id):
		return _states[character_id]
	var state := CharacterRuntimeState.new()
	state.character_id = character_id
	state.max_hp = maxi(max_hp, 1)
	state.current_hp = state.max_hp
	state.max_energy = maxi(max_energy, 0)
	state.current_energy = clampi(starting_energy, 0, state.max_energy)
	state.is_defeated = false
	_states[character_id] = state
	return state


func get_state(character_id: StringName) -> CharacterRuntimeState:
	return _states.get(character_id)


func has_state(character_id: StringName) -> bool:
	return _states.has(character_id)


## Writes battle-concluded values back as the new authoritative state.
func apply_battle_result(
	character_id: StringName, current_hp: int, current_energy: int, is_defeated: bool
) -> void:
	var state: CharacterRuntimeState = _states.get(character_id)
	if state == null:
		return
	state.current_hp = clampi(current_hp, 0, state.max_hp)
	state.current_energy = clampi(current_energy, 0, state.max_energy)
	state.is_defeated = is_defeated
	character_state_changed.emit(character_id)


## Explicit checkpoint-recovery rule (Block 14 Part N): restores HP and
## clears KO state without touching Energy. Only ever called by the defeat
## return flow -- never as a side effect of a scene reload.
func restore_after_checkpoint_recovery(character_id: StringName) -> void:
	var state: CharacterRuntimeState = _states.get(character_id)
	if state == null:
		return
	state.current_hp = state.max_hp
	state.is_defeated = false
	character_state_changed.emit(character_id)
