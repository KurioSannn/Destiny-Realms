extends RefCounted
class_name UltimateInterruptQueue

## Pure FIFO queue for off-turn Ultimate requests. See
## docs/battle_system_spec.md, "Interrupt request queue" for the
## authoritative rules.
##
## Block 9A: this class is not instantiated or wired anywhere in production.
## BattleManager and BattleCommandFlow still reject
## PendingBattleCommand.RequestSource.INTERRUPT_REQUEST unconditionally.
## This queue exists so its rules can be unit tested in isolation ahead of
## Block 9B, which will decide how/when a live BattleManager instantiates
## and drains it.
##
## Enqueue/dequeue never mutates Energy, HP, or turn state directly. Battle
## conditions (current Energy, whether the battle has ended, whether an
## Ultimate is already active) are supplied through the callables passed to
## configure(), mirroring how BattleCommandFlow takes resource callbacks via
## configure_resource_callbacks() instead of reaching into BattleManager
## directly.

signal request_enqueued(request)
signal request_rejected(request, reason)
signal request_dequeued(request)

var _requests: Array = []
var _next_request_id: int = 0
var _energy_lookup: Callable
var _battle_over_lookup: Callable
var _ultimate_active_lookup: Callable


func configure(
	energy_lookup: Callable,
	battle_over_lookup: Callable,
	ultimate_active_lookup: Callable
) -> void:
	_energy_lookup = energy_lookup
	_battle_over_lookup = battle_over_lookup
	_ultimate_active_lookup = ultimate_active_lookup


## Request-time validation happens here, synchronously. Energy is never
## spent by this call regardless of accept/reject outcome.
func request_ultimate(
	actor: Node,
	action_id: StringName,
	energy_cost: int,
	requested_at_state: int,
	requested_at_turn: int
) -> UltimateInterruptRequest:
	var request := UltimateInterruptRequest.new(
		_next_request_id,
		actor,
		action_id,
		energy_cost,
		requested_at_state,
		requested_at_turn,
		_requests.size()
	)
	_next_request_id += 1

	var reason := _validate_at_request_time(request)
	if not reason.is_empty():
		request.validation_status = UltimateInterruptRequest.ValidationStatus.REJECTED
		request.reject_reason = StringName(reason)
		request_rejected.emit(request, request.reject_reason)
		return request

	request.validation_status = UltimateInterruptRequest.ValidationStatus.ACCEPTED
	_requests.append(request)
	request_enqueued.emit(request)
	return request


func has_pending_request_for(actor: Node) -> bool:
	for request in _requests:
		if request.actor == actor:
			return true
	return false


func size() -> int:
	return _requests.size()


func is_empty() -> bool:
	return _requests.is_empty()


func peek_next() -> UltimateInterruptRequest:
	return _requests[0] if not _requests.is_empty() else null


## Process-time removal. Callers (Block 9B+) are expected to call
## revalidate() on the result before acting on it.
func dequeue_next() -> UltimateInterruptRequest:
	if _requests.is_empty():
		return null
	var request: UltimateInterruptRequest = _requests.pop_front()
	request_dequeued.emit(request)
	return request


func cancel_request_for(actor: Node) -> bool:
	for index in range(_requests.size()):
		if _requests[index].actor == actor:
			_requests.remove_at(index)
			return true
	return false


## Process-time validation. Returns an empty string if the request is still
## safe to act on, otherwise a reject reason. Does not mutate the queue or
## the request; the caller decides what to do with a non-empty reason
## (typically: mark expired and drop, matching commit-time validation on the
## production Ultimate adapters).
func revalidate(request: UltimateInterruptRequest) -> String:
	if request == null:
		return "missing_request"
	return _validate_common(request)


func clear() -> void:
	_requests.clear()


func _validate_at_request_time(request: UltimateInterruptRequest) -> String:
	if has_pending_request_for(request.actor):
		return "duplicate_request"
	return _validate_common(request)


func _validate_common(request: UltimateInterruptRequest) -> String:
	if not request.is_actor_valid():
		return "actor_invalid"
	if _battle_over_lookup.is_valid() and bool(_battle_over_lookup.call()):
		return "battle_already_finished"
	if _ultimate_active_lookup.is_valid() and bool(_ultimate_active_lookup.call()):
		return "ultimate_already_active"
	if (
		_energy_lookup.is_valid()
		and int(_energy_lookup.call(request.actor)) < request.energy_cost
	):
		return "insufficient_energy"
	return ""
