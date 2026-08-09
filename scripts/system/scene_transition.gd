extends Node

const DEFAULT_FADE_OUT_SECONDS: float = 0.34
const DEFAULT_FADE_IN_SECONDS: float = 0.34

var _layer: CanvasLayer
var _fade_rect: ColorRect
var _is_transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


func change_to_file(scene_path: String, fade_out_seconds: float = DEFAULT_FADE_OUT_SECONDS, fade_in_seconds: float = DEFAULT_FADE_IN_SECONDS) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	get_tree().paused = false
	_stop_active_scene_audio()
	_stop_global_music()
	await _fade_to_black(fade_out_seconds)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_from_black(fade_in_seconds)
	_is_transitioning = false


func reload_current(fade_out_seconds: float = DEFAULT_FADE_OUT_SECONDS, fade_in_seconds: float = DEFAULT_FADE_IN_SECONDS) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	get_tree().paused = false
	_stop_active_scene_audio()
	_stop_global_music()
	await _fade_to_black(fade_out_seconds)
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_from_black(fade_in_seconds)
	_is_transitioning = false


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "SceneTransitionLayer"
	_layer.layer = 128
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_layer.add_child(_fade_rect)


func _fade_to_black(duration: float) -> void:
	_fade_rect.visible = true
	await _tween_fade_alpha(1.0, duration)


func _fade_from_black(duration: float) -> void:
	await _tween_fade_alpha(0.0, duration)
	_fade_rect.visible = false


func _tween_fade_alpha(target_alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade_rect, "modulate:a", target_alpha, duration)
	await tween.finished


func _stop_active_scene_audio() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	for node in current_scene.find_children("*", "AudioStreamPlayer", true, false):
		var audio_player := node as AudioStreamPlayer
		if audio_player != null and audio_player.playing:
			audio_player.stop()


func _stop_global_music() -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null and music_director.has_method("stop_music"):
		music_director.call("stop_music", 0.0)
