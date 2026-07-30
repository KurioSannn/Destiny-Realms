extends Node

## Block 9A contract test for UltimateInterruptQueue in isolation. This does
## not exercise BattleManager, BattleCommandFlow, or any production Ultimate
## path — the queue is not wired to any of those yet. See
## docs/battle_system_spec.md, "Interrupt request queue".

class FakeCombatant:
	extends Node
	var hp := 100
	func is_defeated() -> bool:
		return hp <= 0

var failures: Array[String] = []
var queue: UltimateInterruptQueue
var energy_by_actor: Dictionary = {}
var battle_over: bool = false
var ultimate_active: bool = false
var actor_a: FakeCombatant
var actor_b: FakeCombatant


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	queue = UltimateInterruptQueue.new()
	queue.configure(_energy_lookup, _battle_over_lookup, _ultimate_active_lookup)
	actor_a = _combatant("ActorA")
	actor_b = _combatant("ActorB")
	energy_by_actor[actor_a] = 100
	energy_by_actor[actor_b] = 100

	_test_valid_request_enqueues()
	_test_duplicate_actor_rejected()
	_test_insufficient_energy_rejected()
	_test_dead_actor_rejected()
	_test_fifo_order()
	_test_battle_over_rejected()
	_test_ultimate_active_rejected()
	_test_energy_not_spent_by_queue()
	_test_cancel_clears_queue()
	_test_revalidate_catches_stale_request()

	if failures.is_empty():
		print("PASS: ultimate interrupt queue contract")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_valid_request_enqueues() -> void:
	queue.clear()
	var request := queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	_check(
		request.validation_status == UltimateInterruptRequest.ValidationStatus.ACCEPTED,
		"valid request is accepted"
	)
	_check(queue.size() == 1, "valid request enters the queue")
	_check(queue.has_pending_request_for(actor_a), "queue tracks pending request per actor")
	queue.clear()


func _test_duplicate_actor_rejected() -> void:
	queue.clear()
	queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	var second := queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	_check(
		second.validation_status == UltimateInterruptRequest.ValidationStatus.REJECTED,
		"duplicate actor request is rejected"
	)
	_check(second.reject_reason == &"duplicate_request", "duplicate rejection reason is explicit")
	_check(queue.size() == 1, "duplicate request does not enter the queue")
	queue.clear()


func _test_insufficient_energy_rejected() -> void:
	queue.clear()
	energy_by_actor[actor_a] = 50
	var request := queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	_check(
		request.validation_status == UltimateInterruptRequest.ValidationStatus.REJECTED,
		"insufficient energy is rejected"
	)
	_check(request.reject_reason == &"insufficient_energy", "insufficient energy reason is explicit")
	_check(queue.is_empty(), "insufficient energy request does not enter the queue")
	energy_by_actor[actor_a] = 100
	queue.clear()


func _test_dead_actor_rejected() -> void:
	queue.clear()
	actor_a.hp = 0
	var request := queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	_check(
		request.validation_status == UltimateInterruptRequest.ValidationStatus.REJECTED,
		"dead actor request is rejected"
	)
	_check(request.reject_reason == &"actor_invalid", "dead actor rejection reason is explicit")
	actor_a.hp = 100
	queue.clear()


func _test_fifo_order() -> void:
	queue.clear()
	queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	queue.request_ultimate(actor_b, &"octagram_fragment", 100, 0, 2)
	_check(queue.peek_next().actor == actor_a, "FIFO order keeps the first request in front")
	var first := queue.dequeue_next()
	_check(first.actor == actor_a, "dequeue returns actor A first")
	var second := queue.dequeue_next()
	_check(second.actor == actor_b, "dequeue returns actor B second")
	_check(queue.is_empty(), "queue is empty after dequeuing both requests")


func _test_battle_over_rejected() -> void:
	queue.clear()
	battle_over = true
	var request := queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	_check(
		request.validation_status == UltimateInterruptRequest.ValidationStatus.REJECTED,
		"request during a finished battle is rejected"
	)
	_check(request.reject_reason == &"battle_already_finished", "battle finished reason is explicit")
	battle_over = false
	queue.clear()


func _test_ultimate_active_rejected() -> void:
	queue.clear()
	ultimate_active = true
	var request := queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	_check(
		request.validation_status == UltimateInterruptRequest.ValidationStatus.REJECTED,
		"request while an Ultimate is active is rejected"
	)
	_check(request.reject_reason == &"ultimate_already_active", "ultimate active reason is explicit")
	ultimate_active = false
	queue.clear()


func _test_energy_not_spent_by_queue() -> void:
	queue.clear()
	var before_energy: int = energy_by_actor[actor_a]
	queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	_check(energy_by_actor[actor_a] == before_energy, "enqueuing a request never spends Energy")
	queue.clear()


func _test_cancel_clears_queue() -> void:
	queue.clear()
	queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	var cancelled := queue.cancel_request_for(actor_a)
	_check(cancelled, "cancel_request_for reports success")
	_check(queue.is_empty(), "cancel removes the request from the queue")
	_check(not queue.has_pending_request_for(actor_a), "cancel clears the per-actor pending flag")


func _test_revalidate_catches_stale_request() -> void:
	queue.clear()
	var request := queue.request_ultimate(actor_a, &"octagram_fragment", 100, 0, 1)
	actor_a.hp = 0
	var reason := queue.revalidate(request)
	_check(reason == "actor_invalid", "revalidate rejects a request whose actor died after enqueue")
	actor_a.hp = 100
	queue.clear()


func _energy_lookup(actor: Node) -> int:
	return int(energy_by_actor.get(actor, 0))


func _battle_over_lookup() -> bool:
	return battle_over


func _ultimate_active_lookup() -> bool:
	return ultimate_active


func _combatant(node_name: String) -> FakeCombatant:
	var combatant := FakeCombatant.new()
	combatant.name = node_name
	add_child(combatant)
	return combatant


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
