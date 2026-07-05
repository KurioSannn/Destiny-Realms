extends Node2D
class_name PrologueScene

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)

@onready var dialogue_manager: DialogueManager = get_node_or_null("CanvasLayer/DialogueUI") as DialogueManager
@onready var forest_background: Sprite2D = get_node_or_null("Background/ForestBackground") as Sprite2D
@onready var sky: Polygon2D = get_node_or_null("Background/Sky") as Polygon2D
@onready var forest_line: Polygon2D = get_node_or_null("Background/ForestLine") as Polygon2D
@onready var ground: Polygon2D = get_node_or_null("Background/Ground") as Polygon2D
@onready var takashi_visual: Node2D = get_node_or_null("CharacterLayer/TakashiVisual") as Node2D
@onready var mitsuki_visual: Node2D = get_node_or_null("CharacterLayer/MitsukiVisual") as Node2D
@onready var makoto_visual: Node2D = get_node_or_null("CharacterLayer/MakotoVisual") as Node2D
@onready var world_portraits: Dictionary = {
	"Takashi": get_node_or_null("CharacterLayer/WorldTakashiPortrait") as Sprite2D,
	"Mitsuki": get_node_or_null("CharacterLayer/WorldMitsukiPortrait") as Sprite2D,
	"Makoto": get_node_or_null("CharacterLayer/WorldMakotoPortrait") as Sprite2D
}
@onready var world_name_labels: Array[Label] = [
	get_node_or_null("CharacterLayer/TakashiVisual/TakashiLabel") as Label,
	get_node_or_null("CharacterLayer/MitsukiVisual/MitsukiLabel") as Label,
	get_node_or_null("CharacterLayer/MakotoVisual/MakotoLabel") as Label
]


func _ready() -> void:
	if dialogue_manager != null:
		dialogue_manager.dialogue_finished.connect(_on_dialogue_finished)
		dialogue_manager.speaker_changed.connect(_on_dialogue_speaker_changed)
	_hide_world_name_labels()

	await get_tree().process_frame
	_apply_runtime_layout()
	if dialogue_manager != null:
		dialogue_manager.start_dialogue()


func _apply_runtime_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	if forest_background != null and forest_background.texture != null:
		var texture_size: Vector2 = forest_background.texture.get_size()
		var cover_scale: float = maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
		forest_background.position = Vector2.ZERO
		forest_background.scale = Vector2(cover_scale, cover_scale)

	if sky != null:
		sky.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(viewport_size.x, 0.0),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if forest_line != null:
		forest_line.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.32),
			Vector2(viewport_size.x * 0.1, viewport_size.y * 0.22),
			Vector2(viewport_size.x * 0.22, viewport_size.y * 0.38),
			Vector2(viewport_size.x * 0.35, viewport_size.y * 0.2),
			Vector2(viewport_size.x * 0.52, viewport_size.y * 0.36),
			Vector2(viewport_size.x * 0.68, viewport_size.y * 0.21),
			Vector2(viewport_size.x * 0.84, viewport_size.y * 0.35),
			Vector2(viewport_size.x, viewport_size.y * 0.24),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if ground != null:
		ground.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.68),
			Vector2(viewport_size.x, viewport_size.y * 0.65),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])

	if takashi_visual != null:
		takashi_visual.position = Vector2(viewport_size.x * 0.28, viewport_size.y * 0.67)
	if mitsuki_visual != null:
		mitsuki_visual.position = Vector2(viewport_size.x * 0.52, viewport_size.y * 0.66)
	if makoto_visual != null:
		makoto_visual.position = Vector2(viewport_size.x * 0.68, viewport_size.y * 0.66)
	_layout_world_portraits(viewport_size)


func _on_dialogue_finished() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_dialogue_speaker_changed(speaker_name: String) -> void:
	for character_name in world_portraits.keys():
		var portrait: Sprite2D = world_portraits[character_name] as Sprite2D
		if portrait == null:
			continue

		if character_name == speaker_name:
			portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
			portrait.z_index = 4
		else:
			portrait.modulate = Color(0.52, 0.56, 0.64, 0.72)
			portrait.z_index = 2


func _layout_world_portraits(viewport_size: Vector2) -> void:
	var positions: Dictionary = {
		"Takashi": Vector2(viewport_size.x * 0.2, viewport_size.y * 0.52),
		"Makoto": Vector2(viewport_size.x * 0.65, viewport_size.y * 0.515),
		"Mitsuki": Vector2(viewport_size.x * 0.8, viewport_size.y * 0.51)
	}

	for character_name in world_portraits.keys():
		var portrait: Sprite2D = world_portraits[character_name] as Sprite2D
		if portrait == null:
			continue

		portrait.position = positions[character_name]
		portrait.scale = Vector2(0.24, 0.24)


func _hide_world_name_labels() -> void:
	for label in world_name_labels:
		if label != null:
			label.visible = false
