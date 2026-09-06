extends Node3D
class_name WerdoniaOutskirts3D

## Scaffold for the open-world Werdonia Outskirts exploration area (the
## Abyss Forest exit). Deliberately minimal -- unlike AbyssForest3D there is
## no procedural asset generation here; ground/props are placed manually in
## the editor (see README_werdonia_outskirts_3d.md). This script only wires
## the same player/camera/HUD/return-trigger plumbing every exploration
## scene needs.

const ABYSS_FOREST_SCENE_PATH := "res://scenes/world_3d/abyss_forest_3d.tscn"
const LOGIN_SCENE_PATH := "res://scenes/login/login_scene.tscn"

@onready var player: CharacterBody3D = $Player
@onready var hud_explor: HudExplorPlaceholder = $HudExplorPlaceholder/HUDRoot
@onready var return_area: Area3D = $ReturnToAbyssArea

var _near_return_point: bool = false


func _ready() -> void:
	return_area.body_entered.connect(_on_return_area_body_entered)
	return_area.body_exited.connect(_on_return_area_body_exited)
	hud_explor.show_player_marker = false
	hud_explor.set_player_status("Takashi", 10, 1897.0, 2000.0)
	hud_explor.set_quest("Jelajahi Werdonia Outskirts", "Area masih dalam pembangunan")
	hud_explor.slot_pressed.connect(_on_hud_slot_pressed)

	GameFlowState.set_active_character(player)
	GameFlowState.set_context(GameFlowState.InputContext.EXPLORATION)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _near_return_point:
		player.call("set_movement_enabled", false)
		SceneTransition.change_to_file(ABYSS_FOREST_SCENE_PATH)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		SceneTransition.change_to_file(LOGIN_SCENE_PATH)
		get_viewport().set_input_as_handled()


func _on_hud_slot_pressed(_slot_id: String) -> void:
	pass


func _on_return_area_body_entered(body: Node3D) -> void:
	if body != player:
		return
	_near_return_point = true
	hud_explor.set_quest("Kembali ke Abyss Forest", "Tekan E untuk kembali")


func _on_return_area_body_exited(body: Node3D) -> void:
	if body != player:
		return
	_near_return_point = false
	hud_explor.set_quest("Jelajahi Werdonia Outskirts", "Area masih dalam pembangunan")
