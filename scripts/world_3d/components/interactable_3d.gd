extends Area3D
class_name Interactable3D

## Reusable interaction target: NPC, chest, resource node, lever, door, quest
## object, seal, or any other world object a character can interact with.
## Attach (or extend) this on an Area3D with its own CollisionShape3D sized
## as the interaction range -- never hardcode a specific interactable by node
## name elsewhere in the codebase.
##
## Override interact() (call super first) or connect to `interacted` for
## interactable-specific behavior (chests, doors, NPCs, etc.).

signal player_entered_range(character: Node3D)
signal player_exited_range(character: Node3D)
signal interacted(character: Node3D)

@export var interaction_id: StringName = &""
@export var prompt_text: String = "[E] Interact"
@export var enabled: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_interaction_prompt() -> String:
	return prompt_text


func can_interact(_character: Node3D) -> bool:
	return enabled


func interact(character: Node3D) -> void:
	if not can_interact(character):
		return
	interacted.emit(character)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"exploration_character"):
		return
	if body.has_method("register_nearby_interactable"):
		body.call("register_nearby_interactable", self)
	player_entered_range.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group(&"exploration_character"):
		return
	if body.has_method("unregister_nearby_interactable"):
		body.call("unregister_nearby_interactable", self)
	player_exited_range.emit(body)
