extends Area3D
class_name Pickup3D

## Lightweight, reusable world pickup. Auto-collects when an exploration
## character walks into it -- no inventory/economy system required yet, just
## a clean handoff (resource_id + amount) for whatever system consumes it
## later. Not an Interactable3D: pickups are walk-over, interactables are
## button-press, by design.

signal collected(character: Node3D, resource_id: StringName, amount: int)

@export var resource_id: StringName = &""
@export var amount: int = 1

var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func is_collected() -> bool:
	return _collected


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group(&"exploration_character"):
		return
	_collected = true
	collected.emit(body, resource_id, amount)
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
