extends PanelContainer
class_name CharacterStatus

const UiTokens := preload("res://scripts/ui/ui_tokens.gd")

@export var portrait_texture: Texture2D

@onready var portrait: TextureRect = $Content/PortraitFrame/Portrait
@onready var character_name_label: Label = $Content/Stats/IdentityRow/CharacterName
@onready var level_label: Label = $Content/Stats/IdentityRow/Level
@onready var hp_bar: ProgressBar = $Content/Stats/HpBlock/HpBar
@onready var hp_value_label: Label = $Content/Stats/HpBlock/HpRow/HpValue
@onready var low_health_label: Label = $Content/Stats/HpBlock/HpRow/LowHealth
@onready var energy_bar: ProgressBar = $Content/Stats/EnergyBlock/EnergyBar
@onready var energy_value_label: Label = $Content/Stats/EnergyBlock/EnergyRow/EnergyValue

var _health_tween: Tween
var _energy_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	low_health_label.add_theme_color_override("font_color", UiTokens.DANGER)
	if portrait_texture != null:
		portrait.texture = portrait_texture


func set_character_name(value: String) -> void:
	character_name_label.text = value


func set_level(value: int) -> void:
	level_label.text = "LV. %d" % maxi(value, 0)


func set_portrait(texture: Texture2D) -> void:
	portrait_texture = texture
	if is_node_ready():
		portrait.texture = texture


func set_health(
	current_value: float,
	maximum_value: float,
	animated: bool = true
) -> void:
	var safe_maximum := maxf(maximum_value, 0.0)
	var safe_current := clampf(current_value, 0.0, safe_maximum)
	var target_percent := 0.0
	if safe_maximum > 0.0:
		target_percent = (safe_current / safe_maximum) * 100.0

	hp_value_label.text = "%s / %s" % [
		_format_stat(safe_current),
		_format_stat(safe_maximum),
	]
	var is_low := safe_maximum > 0.0 and target_percent <= 25.0
	low_health_label.visible = is_low
	hp_bar.modulate = UiTokens.DANGER if is_low else UiTokens.WHITE
	_set_bar_value(hp_bar, target_percent, animated, true)


func set_energy(
	current_value: float,
	maximum_value: float,
	animated: bool = true
) -> void:
	var safe_maximum := maxf(maximum_value, 0.0)
	var safe_current := clampf(current_value, 0.0, safe_maximum)
	var target_percent := 0.0
	if safe_maximum > 0.0:
		target_percent = (safe_current / safe_maximum) * 100.0

	energy_value_label.text = "%s / %s" % [
		_format_stat(safe_current),
		_format_stat(safe_maximum),
	]
	_set_bar_value(energy_bar, target_percent, animated, false)


func _set_bar_value(
	bar: ProgressBar,
	target_value: float,
	animated: bool,
	is_health: bool
) -> void:
	var active_tween := _health_tween if is_health else _energy_tween
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	if not animated:
		bar.value = target_value
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		bar,
		"value",
		target_value,
		UiTokens.MOTION_SLOW
	)
	if is_health:
		_health_tween = tween
	else:
		_energy_tween = tween


func _format_stat(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value

