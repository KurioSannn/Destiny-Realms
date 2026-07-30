extends RefCounted
class_name UltimateInterruptRequest

## Off-turn Ultimate request data, as it will exist once Block 9B+ wires
## queue processing to production. See docs/battle_system_spec.md,
## "Interrupt request queue" for the authoritative rules.
##
## Block 9A: constructing this class has no side effects on Energy, battle
## state, or turn order. It is a pure data holder used by
## UltimateInterruptQueue and its tests; nothing in production creates one
## yet.

enum ValidationStatus {
	PENDING,
	ACCEPTED,
	REJECTED,
	EXPIRED,
}

var unique_request_id: int = 0
var actor: Node = null
var actor_id: int = 0
var action_id: StringName = &""
var request_source: int = PendingBattleCommand.RequestSource.INTERRUPT_REQUEST
var energy_cost: int = 0
var requested_at_state: int = -1
var requested_at_turn: int = 0
var request_order: int = 0
var preferred_target: Node = null
var validation_status: int = ValidationStatus.PENDING
var reject_reason: StringName = &""
var created_at_msec: int = 0


func _init(
	new_unique_request_id: int,
	new_actor: Node,
	new_action_id: StringName,
	new_energy_cost: int,
	new_requested_at_state: int,
	new_requested_at_turn: int,
	new_request_order: int
) -> void:
	unique_request_id = new_unique_request_id
	actor = new_actor
	actor_id = new_actor.get_instance_id() if is_instance_valid(new_actor) else 0
	action_id = new_action_id
	energy_cost = maxi(new_energy_cost, 0)
	requested_at_state = new_requested_at_state
	requested_at_turn = new_requested_at_turn
	request_order = new_request_order
	created_at_msec = Time.get_ticks_msec()


func is_actor_valid() -> bool:
	return is_instance_valid(actor) and not _node_is_defeated(actor)


func _node_is_defeated(node: Node) -> bool:
	return node.has_method("is_defeated") and bool(node.call("is_defeated"))
