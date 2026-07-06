extends Node2D
class_name Combatant

@export var combatant_name: String = "Combatant"
@export var max_hp: int = 1
@export var base_attack_damage: int = 1

var current_hp: int = 1
var home_position: Vector2 = Vector2.ZERO

@onready var placeholder_visual: CanvasItem = get_node_or_null("PlaceholderVisual") as CanvasItem
@onready var action_sprite: CanvasItem = get_node_or_null("ActionSprite") as CanvasItem
@onready var name_label: Label = get_node_or_null("NameLabel") as Label


func _ready() -> void:
	home_position = position


func set_home_position(new_home_position: Vector2) -> void:
	home_position = new_home_position
	position = home_position
	reset_feedback()


func setup(new_name: String, new_max_hp: int, new_attack_damage: int) -> void:
	combatant_name = new_name
	max_hp = maxi(new_max_hp, 1)
	base_attack_damage = maxi(new_attack_damage, 0)
	if name_label != null:
		name_label.text = combatant_name
		name_label.visible = false
	reset_hp()


func reset_hp() -> void:
	current_hp = max_hp
	reset_feedback()


func take_damage(amount: int) -> int:
	var damage: int = maxi(amount, 0)
	current_hp = maxi(current_hp - damage, 0)
	return damage


func is_defeated() -> bool:
	return current_hp <= 0


func get_hp_text() -> String:
	return "%s HP: %d/%d" % [combatant_name, current_hp, max_hp]


func reset_feedback() -> void:
	position = home_position
	scale = Vector2.ONE
	modulate = Color.WHITE
	if placeholder_visual != null:
		placeholder_visual.modulate = Color.WHITE
	if action_sprite != null:
		action_sprite.modulate = Color.WHITE


func play_attack_movement(target: Node2D) -> void:
	var start_position: Vector2 = position
	var direction: Vector2 = (target.global_position - global_position).normalized()
	var lunge_position: Vector2 = start_position + direction * 54.0

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", lunge_position, 0.14)
	tween.tween_property(self, "position", start_position, 0.16)
	await tween.finished


func play_skill_movement(target: Node2D) -> void:
	var start_position: Vector2 = position
	var direction: Vector2 = (target.global_position - global_position).normalized()
	var lunge_position: Vector2 = start_position + direction * 72.0

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	tween.parallel().tween_property(self, "position", lunge_position, 0.16)
	tween.tween_property(self, "position", start_position, 0.18)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)
	await tween.finished


func play_ultimate_feedback() -> void:
	var flash_target: CanvasItem = _get_feedback_target()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(flash_target, "modulate", Color(1.0, 0.95, 0.45, 1.0), 0.08)
	tween.parallel().tween_property(self, "scale", Vector2(1.22, 1.22), 0.08)
	tween.tween_property(flash_target, "modulate", Color.WHITE, 0.12)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.12)
	await tween.finished


func play_hit_feedback() -> void:
	var flash_target: CanvasItem = _get_feedback_target()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(flash_target, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.06)
	tween.parallel().tween_property(self, "scale", Vector2(1.08, 0.94), 0.06)
	tween.tween_property(flash_target, "modulate", Color.WHITE, 0.12)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.12)
	await tween.finished


func _get_feedback_target() -> CanvasItem:
	if action_sprite != null and action_sprite.visible:
		return action_sprite
	if placeholder_visual != null:
		return placeholder_visual
	return self
