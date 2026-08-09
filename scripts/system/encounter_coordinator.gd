extends Node

## Narrow signal/service boundary between world enemies and whatever
## eventually starts battle (Block 14). Enemies never call BattleManager (or
## anything battle-related) directly -- they call request_encounter() here.
##
## Deliberately does NOT become a general encounter/battle manager: no
## inventory, no battle state, no GameFlowState duplication. Its only job is
## "is a request already in flight, and here it is if not."

signal encounter_requested(context: EncounterContext)
signal encounter_resolved(context: EncounterContext, result: StringName)

var _active_context: EncounterContext = null


## Returns true if the request was accepted (no other encounter already
## in flight). Enemies should treat a false return as "someone else already
## started one this frame" and not retry.
func request_encounter(context: EncounterContext) -> bool:
	if _active_context != null:
		return false
	_active_context = context
	encounter_requested.emit(context)
	return true


func get_active_context() -> EncounterContext:
	return _active_context


func has_active_encounter() -> bool:
	return _active_context != null


## Block 14 seam: call once the encounter is fully resolved (victory/escape/
## defeat) so a new one can be requested. Block 13's debug verification path
## also uses this to unfreeze the test scene without a real battle.
func resolve_active_encounter(result: StringName) -> void:
	if _active_context == null:
		return
	var context := _active_context
	_active_context = null
	encounter_resolved.emit(context, result)
