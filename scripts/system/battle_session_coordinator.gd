extends Node

## Narrow bridge between an accepted EncounterContext (from
## EncounterCoordinator) and the existing production battle scene. Owns
## exactly: receiving the accepted context, capturing minimal return data,
## driving GameFlowState through TRANSITION/BATTLE/TRANSITION/EXPLORATION,
## invoking the existing SceneTransition fade, loading the battle scene, and
## handing the result back to whichever world scene reloads.
##
## Does NOT own inventory, rewards, quests, save files, party progression,
## battle logic, or enemy AI. Never loads a scene directly except via the
## existing SceneTransition autoload -- no duplicate transition system.
##
## BattleManager calls report_battle_result() the same way it already calls
## out to WorldProgress on win/lose (see battle_manager.gd _win()/_lose()/
## _on_restart_pressed()) -- this is an additive sibling call, not a new
## calling convention.

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
## Brief freeze/focus beat before the fade starts, so the moment of
## engagement reads as a distinct beat rather than an instant cut. Combined
## with SceneTransition's own ~0.34s fade out + ~0.34s fade in, total
## transition time lands around 0.7-0.9s, within the requested 0.4-1.0s.
const PRE_TRANSITION_FOCUS_SECONDS: float = 0.15

signal encounter_transition_started(context: EncounterContext)
signal world_return_ready(pending_return: Dictionary)

var debug_logging: bool = false

var _active_session: Dictionary = {}
var _pending_return: Dictionary = {}


func _ready() -> void:
	EncounterCoordinator.encounter_requested.connect(_on_encounter_requested)


func has_active_session() -> bool:
	return not _active_session.is_empty()


func _on_encounter_requested(context: EncounterContext) -> void:
	if not _validate_context(context):
		EncounterCoordinator.resolve_active_encounter(&"invalid")
		return
	if has_active_session():
		push_error("BattleSessionCoordinator: encounter requested while a session is already in flight; ignoring")
		return

	var player := GameFlowState.get_active_character()
	if player == null or not is_instance_valid(player):
		push_error("BattleSessionCoordinator: no active exploration character to send into battle")
		EncounterCoordinator.resolve_active_encounter(&"invalid")
		return

	var return_position: Vector3 = player.global_position
	var source_enemy := _find_world_actor(context.initiating_enemy_id)
	if source_enemy != null:
		var away_from_enemy := (player.global_position - source_enemy.global_position)
		away_from_enemy.y = 0.0
		if away_from_enemy.length_squared() > 0.0001:
			return_position = player.global_position + away_from_enemy.normalized() * 1.5

	_active_session = {
		"context": context,
		"source_world_scene": context.source_world_scene,
		"world_actor_id": context.initiating_enemy_id,
		"player_character_id": context.initiating_player_character_id,
		"return_position": return_position,
	}

	if debug_logging:
		print(
			"BattleSessionCoordinator: encounter accepted id=%s group=%s enemies=%s opening=%s actor=%s"
			% [
				context.encounter_id,
				context.encounter_group_id,
				str(context.battle_enemy_ids),
				EncounterContext.OpeningAdvantage.keys()[context.opening_advantage],
				context.initiating_enemy_id,
			]
		)

	encounter_transition_started.emit(context)
	GameFlowState.set_context(GameFlowState.InputContext.TRANSITION)
	await get_tree().create_timer(PRE_TRANSITION_FOCUS_SECONDS).timeout
	SceneTransition.change_to_file(BATTLE_SCENE_PATH)


## Called by BattleManager once battle concludes. result is one of
## &"victory" / &"defeat" / &"escape".
func report_battle_result(result: StringName) -> void:
	if not has_active_session():
		push_error("BattleSessionCoordinator: report_battle_result() called with no active session")
		return

	var session := _active_session
	_active_session = {}

	if result == &"defeat":
		var player_id: StringName = session.get("player_character_id", &"")
		if not player_id.is_empty():
			PartyRuntimeState.restore_after_checkpoint_recovery(player_id)

	if debug_logging:
		print(
			"BattleSessionCoordinator: battle result=%s returning to %s actor=%s"
			% [result, session.get("source_world_scene", ""), session.get("world_actor_id", "")]
		)

	_pending_return = {
		"result": result,
		"world_actor_id": session.get("world_actor_id", &""),
		"return_position": session.get("return_position", Vector3.ZERO),
		"source_world_scene": session.get("source_world_scene", ""),
	}

	GameFlowState.set_context(GameFlowState.InputContext.TRANSITION)
	var source_scene: String = session.get("source_world_scene", "")
	if source_scene.is_empty():
		push_error("BattleSessionCoordinator: session has no source_world_scene to return to; clearing session safely")
		EncounterCoordinator.resolve_active_encounter(result)
		GameFlowState.set_context(GameFlowState.InputContext.EXPLORATION)
		_pending_return = {}
		return
	SceneTransition.change_to_file(source_scene)


## Called by the reloaded world scene's _ready(). Returns an empty
## Dictionary if this load wasn't a return from battle. One-shot: clears
## itself and resolves the encounter so a new one can be requested.
func consume_pending_return() -> Dictionary:
	if _pending_return.is_empty():
		return {}
	var pending := _pending_return
	_pending_return = {}
	EncounterCoordinator.resolve_active_encounter(pending.get("result", &"unknown"))
	world_return_ready.emit(pending)
	return pending


func _validate_context(context: EncounterContext) -> bool:
	if context == null:
		push_error("BattleSessionCoordinator: null EncounterContext rejected")
		return false
	if context.battle_enemy_ids.is_empty():
		push_error("BattleSessionCoordinator: EncounterContext with an empty battle_enemy_ids roster rejected")
		return false
	if context.source_world_scene.is_empty():
		push_error("BattleSessionCoordinator: EncounterContext with no source_world_scene rejected")
		return false
	return true


func _find_world_actor(world_actor_id: StringName) -> Node3D:
	if world_actor_id.is_empty():
		return null
	var matches: Array[Node3D] = []
	for candidate_variant in get_tree().get_nodes_in_group(&"exploration_enemy"):
		var candidate := candidate_variant as Node3D
		if candidate == null:
			continue
		if "world_actor_id" in candidate and candidate.world_actor_id == world_actor_id:
			matches.append(candidate)
	if matches.size() > 1:
		push_error(
			"BattleSessionCoordinator: multiple world actors share id '%s' -- IDs must be unique per scene"
			% world_actor_id
		)
	return matches[0] if not matches.is_empty() else null
