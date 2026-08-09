extends Area3D
class_name AreaTrigger3D

## Reusable Area3D trigger: location discovery, story/quest triggers,
## encounter boundaries, music transitions, tutorials, map transitions.
## Avoids one-off Area3D scripts per use case -- attach this and connect to
## trigger_entered/trigger_exited instead.

signal trigger_entered(body: Node3D)
signal trigger_exited(body: Node3D)

@export var trigger_id: StringName = &""
@export var one_shot: bool = false
@export var enabled: bool = true

var _has_fired: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not enabled or (one_shot and _has_fired):
		return
	if not body.is_in_group(&"exploration_character"):
		return
	_has_fired = true
	trigger_entered.emit(body)
	if one_shot:
		enabled = false


func _on_body_exited(body: Node3D) -> void:
	# Exit reports a physical fact (the body left the area) independent of
	# `enabled`/one_shot, which only gate whether re-entry can fire again.
	if not body.is_in_group(&"exploration_character"):
		return
	trigger_exited.emit(body)
