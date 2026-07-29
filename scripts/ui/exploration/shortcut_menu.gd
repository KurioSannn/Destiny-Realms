extends PanelContainer
class_name ShortcutMenu

signal character_requested
signal inventory_requested
signal quest_requested
signal map_requested
signal settings_requested

@onready var character_button: Button = $Shortcuts/Character
@onready var inventory_button: Button = $Shortcuts/Inventory
@onready var quest_button: Button = $Shortcuts/Quest
@onready var map_button: Button = $Shortcuts/Map
@onready var settings_button: Button = $Shortcuts/Settings


func _ready() -> void:
	character_button.pressed.connect(character_requested.emit)
	inventory_button.pressed.connect(inventory_requested.emit)
	quest_button.pressed.connect(quest_requested.emit)
	map_button.pressed.connect(map_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)


func focus_first() -> void:
	character_button.grab_focus()


func get_buttons() -> Array[Button]:
	return [
		character_button,
		inventory_button,
		quest_button,
		map_button,
		settings_button,
	]
