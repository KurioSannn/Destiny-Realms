extends Node2D
class_name Combatant

@export var combatant_name: String = "Combatant"
@export var max_hp: int = 1
@export var base_attack_damage: int = 1

var current_hp: int = 1
var home_position: Vector2 = Vector2.ZERO

@onready var placeholder_visual: CanvasItem = get_node_or_null("PlaceholderVisual") as CanvasItem


func _ready() -> void:
	home_position = position


func setup(new_name: String, new_max_hp: int, new_attack_damage: int) -> void:
	combatant_name = new_name
	max_hp = maxi(new_max_hp, 1)
	base_attack_damage = maxi(new_attack_damage, 0)
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


func play_hit_feedback() -> void:
	var flash_target: CanvasItem = placeholder_visual if placeholder_visual != null else self

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(flash_target, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.06)
	tween.parallel().tween_property(self, "scale", Vector2(1.08, 0.94), 0.06)
	tween.tween_property(flash_target, "modulate", Color.WHITE, 0.12)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.12)
	await tween.finished


func play_guard_feedback() -> void:
	var flash_target: CanvasItem = placeholder_visual if placeholder_visual != null else self

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(flash_target, "modulate", Color(0.55, 0.8, 1.0, 1.0), 0.08)
	tween.parallel().tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	tween.tween_property(flash_target, "modulate", Color.WHITE, 0.16)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.16)
	await tween.finished
