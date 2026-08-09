extends Node

## Deliberately small. Owns exactly two things:
## 1. which high-level context currently owns input
## 2. which exploration character is currently controlled
##
## Does NOT grow into inventory, quests, save data, combat state, or party
## progression -- those belong to their own systems. If a future change wants
## to add unrelated state here, it should get its own autoload instead.

enum InputContext {
	EXPLORATION,
	STORY,
	CUTSCENE,
	MENU,
	TRANSITION,
	BATTLE,
}

signal context_changed(context: InputContext)
signal active_character_changed(character: Node3D)

var current_context: InputContext = InputContext.EXPLORATION
var active_character: Node3D = null


func set_context(context: InputContext) -> void:
	if context == current_context:
		return
	current_context = context
	context_changed.emit(current_context)


func is_exploration_active() -> bool:
	return current_context == InputContext.EXPLORATION


func set_active_character(character: Node3D) -> void:
	if character == active_character:
		return
	active_character = character
	active_character_changed.emit(active_character)


func get_active_character() -> Node3D:
	return active_character
