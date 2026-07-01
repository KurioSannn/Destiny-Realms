extends ProgressBar
class_name TimingBar

signal timing_finished(good_timing: bool, confirmed: bool)

@export var window_seconds: float = 1.5
@export var good_min: float = 45.0
@export var good_max: float = 65.0
@export var bar_speed: float = 140.0

var _active: bool = false
var _elapsed: float = 0.0
var _direction: float = 1.0


func _ready() -> void:
	min_value = 0.0
	max_value = 100.0
	value = 0.0
	visible = false
	set_process(false)


func start_window() -> void:
	_active = true
	_elapsed = 0.0
	_direction = 1.0
	value = 0.0
	modulate = Color.WHITE
	visible = true
	set_process(true)


func confirm() -> void:
	if not _active:
		return

	var good_timing: bool = value >= good_min and value <= good_max
	_finish(good_timing, true)


func cancel_window() -> void:
	_active = false
	_elapsed = 0.0
	value = 0.0
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	value += bar_speed * _direction * delta

	if value >= max_value:
		value = max_value
		_direction = -1.0
	elif value <= min_value:
		value = min_value
		_direction = 1.0

	modulate = Color(0.55, 1.0, 0.55, 1.0) if value >= good_min and value <= good_max else Color.WHITE

	if _elapsed >= window_seconds:
		_finish(false, false)


func _finish(good_timing: bool, confirmed: bool) -> void:
	_active = false
	visible = false
	set_process(false)
	timing_finished.emit(good_timing, confirmed)
