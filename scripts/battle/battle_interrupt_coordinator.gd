class_name BattleInterruptCoordinator
extends RefCounted

## Manages off-turn Ultimate interrupt queue processing, safe window dispatch
## (before_enemy_commit A1, after_enemy_recovery B), and resume token consumption.

const UltimateInterruptQueueScript := preload("res://scripts/battle/command/ultimate_interrupt_queue.gd")

var ultimate_interrupt_queue: UltimateInterruptQueue
var is_processing_interrupt_queue: bool = false
var active_interrupt_request: UltimateInterruptRequest = null
var active_interrupt_window: StringName = &""
var interrupt_resume_token: int = 0
var _consumed_interrupt_resume_tokens: Dictionary = {}
var _processed_interrupt_request_ids: Dictionary = {}


func setup(manager: Node) -> void:
	if ultimate_interrupt_queue != null:
		return
	ultimate_interrupt_queue = UltimateInterruptQueueScript.new()
	ultimate_interrupt_queue.configure(
		func(_actor: Node) -> int: return manager.ultimate_energy,
		func() -> bool: return manager._is_battle_over(),
		func() -> bool: return is_ultimate_active_or_processing(manager)
	)


func reset() -> void:
	if ultimate_interrupt_queue != null:
		ultimate_interrupt_queue.clear()
	is_processing_interrupt_queue = false
	active_interrupt_request = null
	active_interrupt_window = &""
	_processed_interrupt_request_ids.clear()
	_consumed_interrupt_resume_tokens.clear()


func consume_interrupt_resume_token(token: int) -> bool:
	if token == 0 or _consumed_interrupt_resume_tokens.has(token):
		return false
	_consumed_interrupt_resume_tokens[token] = true
	return true


func is_ultimate_active_or_processing(manager: Node) -> bool:
	return manager.active_ultimate_command_token != 0 or is_processing_interrupt_queue


func can_request_off_turn_ultimate_input(manager: Node) -> bool:
	return (
		manager.state == manager.BattleState.ENEMY_TURN
		and manager._uses_new_ultimate_command_flow()
		and not is_processing_interrupt_queue
		and manager.active_ultimate_command_token == 0
		and not manager._has_pending_ultimate_command()
	)


func request_off_turn_ultimate(manager: Node, actor: Node) -> bool:
	if ultimate_interrupt_queue == null or not manager._uses_new_ultimate_command_flow():
		manager.ui.set_battle_log("Cannot use Ultimate now.")
		return false
	if manager.state == manager.BattleState.PLAYER_TURN or manager._is_battle_over():
		manager.ui.set_battle_log("Cannot use Ultimate now.")
		return false
	if is_processing_interrupt_queue or manager.active_ultimate_command_token != 0:
		manager.ui.set_battle_log("Cannot use Ultimate now.")
		return false

	var request := ultimate_interrupt_queue.request_ultimate(
		actor,
		&"octagram_fragment",
		manager.MAX_ULTIMATE_ENERGY,
		manager.state,
		0
	)
	if request.validation_status != UltimateInterruptRequest.ValidationStatus.ACCEPTED:
		manager.ui.set_battle_log(interrupt_request_failure_message(request.reject_reason))
		return false

	var actor_name: String = actor.combatant_name if actor is Combatant else "Ultimate"
	manager.ui.set_battle_log("Ultimate queued: %s" % actor_name)
	return true


func interrupt_request_failure_message(reason: StringName) -> String:
	match reason:
		&"duplicate_request":
			return "Ultimate already queued."
		&"insufficient_energy":
			return "Not enough Energy."
	return "Cannot use Ultimate now."


func process_interrupt_queue_at_safe_window(manager: Node, window_id: StringName) -> bool:
	if window_id != &"after_enemy_recovery" and window_id != &"before_enemy_commit":
		return false
	if not manager.is_inside_tree() or manager._is_battle_over():
		return false
	if ultimate_interrupt_queue == null or ultimate_interrupt_queue.is_empty():
		return false
	if is_processing_interrupt_queue or manager.enemy_action_in_progress:
		return false
	if manager.active_enemy_attack_token != 0:
		return false
	if (
		manager.active_basic_command_token != 0
		or manager.active_skill_command_token != 0
		or manager.active_ultimate_command_token != 0
	):
		return false
	if (
		manager._has_pending_basic_command()
		or manager._has_pending_skill_command()
		or manager._has_pending_ultimate_command()
	):
		return false

	while not ultimate_interrupt_queue.is_empty():
		var request: UltimateInterruptRequest = ultimate_interrupt_queue.dequeue_next()
		if request == null:
			return false
		if _processed_interrupt_request_ids.has(request.unique_request_id):
			continue
		var reason := ultimate_interrupt_queue.revalidate(request)
		if not reason.is_empty():
			_processed_interrupt_request_ids[request.unique_request_id] = true
			continue
		return begin_queued_ultimate(manager, request, window_id)

	return false


func begin_queued_ultimate(manager: Node, request: UltimateInterruptRequest, window_id: StringName) -> bool:
	_processed_interrupt_request_ids[request.unique_request_id] = true
	is_processing_interrupt_queue = true
	active_interrupt_request = request
	active_interrupt_window = window_id
	interrupt_resume_token += 1
	var resume_token := interrupt_resume_token

	manager.state = manager.BattleState.PLAYER_TURN
	manager.ultimate_command_adapter.begin_ultimate(
		&"octagram_fragment",
		PendingBattleCommand.TargetRule.SINGLE_ENEMY,
		request.energy_cost,
		0,
		PendingBattleCommand.RequestSource.INTERRUPT_REQUEST,
		true
	)

	if manager._has_pending_ultimate_command():
		return true

	if is_processing_interrupt_queue and consume_interrupt_resume_token(resume_token):
		is_processing_interrupt_queue = false
		active_interrupt_request = null
		resume_after_interrupt(manager)
	return false


func resume_after_interrupt(manager: Node, log_text: String = "Your turn. Choose an action.") -> void:
	var window := active_interrupt_window
	active_interrupt_window = &""
	if window == &"before_enemy_commit":
		resume_enemy_action_after_a1(manager)
		return
	manager._begin_player_turn(log_text)


func resume_enemy_action_after_a1(manager: Node) -> void:
	if manager._is_battle_over() or not manager.is_inside_tree():
		return
	manager.state = manager.BattleState.ENEMY_TURN
	manager._enemy_attack()


func finish_interrupt_ultimate_action(manager: Node, log_text: String) -> void:
	if not consume_interrupt_resume_token(interrupt_resume_token):
		return
	manager._refresh_energy_ui()
	manager._refresh_skill_points_ui()
	manager._start_player_idle_animation()
	is_processing_interrupt_queue = false
	active_interrupt_request = null
	if manager._all_enemies_defeated():
		active_interrupt_window = &""
		manager._win("Enemy defeated. You win!")
		return
	resume_after_interrupt(manager, log_text)
