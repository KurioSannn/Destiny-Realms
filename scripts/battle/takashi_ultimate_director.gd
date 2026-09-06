class_name TakashiUltimateDirector
extends RefCounted

## Orchestrates Takashi's Ultimate cutscene presentation, camera zooms,
## audio playback, frame player animation, and damage resolution.

const ULTIMATE_FRAME_PATH_FORMAT: String = "res://public/ultimate_frames/takashi_ultimate_%03d.jpg"

var ultimate_frames: Array[Texture2D] = []
var battle_ui_visible_before_ultimate: bool = true
var ultimate_cutscene_snapshot: Dictionary = {}


func load_ultimate_frames(frame_count: int = 14) -> void:
	ultimate_frames.clear()
	for frame_index in range(1, frame_count + 1):
		var frame_path: String = ULTIMATE_FRAME_PATH_FORMAT % frame_index
		var frame_texture: Texture2D = load(frame_path) as Texture2D
		if frame_texture != null:
			ultimate_frames.append(frame_texture)


func enter_cutscene_presentation(manager: Node, target: Combatant) -> void:
	if not manager._uses_3d_target_markers() or not ultimate_cutscene_snapshot.is_empty():
		return
	ultimate_cutscene_snapshot = {
		"presentation_visible": manager.battle_presentation_3d.visible,
		"battle_camera_enabled": manager.battle_camera.enabled if manager.battle_camera != null else false,
		"player_visible": manager.player.visible if manager.player != null else false,
		"player_modulate": manager.player.modulate if manager.player != null else Color.WHITE,
		"target": target,
		"target_visible": target.visible if target != null else false,
		"target_modulate": target.modulate if target != null else Color.WHITE,
	}
	manager.battle_presentation_3d.visible = false
	if manager.battle_camera != null:
		manager.battle_camera.enabled = true
	show_combatant_for_cutscene(manager.player)
	show_combatant_for_cutscene(target)


func exit_cutscene_presentation(manager: Node) -> void:
	if ultimate_cutscene_snapshot.is_empty():
		return
	if manager.battle_presentation_3d != null and is_instance_valid(manager.battle_presentation_3d):
		manager.battle_presentation_3d.visible = bool(ultimate_cutscene_snapshot.get("presentation_visible", true))
		manager.battle_presentation_3d.camera_return_to_idle()
	if manager.battle_camera != null:
		manager.battle_camera.enabled = bool(ultimate_cutscene_snapshot.get("battle_camera_enabled", false))
	if manager.player != null and is_instance_valid(manager.player):
		manager.player.visible = bool(ultimate_cutscene_snapshot.get("player_visible", manager.player.visible))
		manager.player.modulate = ultimate_cutscene_snapshot.get("player_modulate", manager.player.modulate)
	var target := ultimate_cutscene_snapshot.get("target") as Combatant
	if target != null and is_instance_valid(target):
		target.visible = bool(ultimate_cutscene_snapshot.get("target_visible", target.visible))
		target.modulate = ultimate_cutscene_snapshot.get("target_modulate", target.modulate)
	ultimate_cutscene_snapshot.clear()


func show_combatant_for_cutscene(combatant: Combatant) -> void:
	if combatant == null or not is_instance_valid(combatant):
		return
	combatant.visible = true
	combatant.modulate.a = 1.0


func set_battle_ui_for_ultimate(manager: Node, visible: bool) -> void:
	if manager.ui == null:
		return
	if visible:
		manager.ui.visible = battle_ui_visible_before_ultimate
		return
	battle_ui_visible_before_ultimate = manager.ui.visible
	manager.ui.visible = false


func abort_cutscene_visuals(manager: Node) -> void:
	manager._hide_takashi_ultimate_glow_effect()
	manager._hide_enemy_impact_fvx()
	if manager.ultimate_frame_player != null:
		manager.ultimate_frame_player.texture = null
		manager.ultimate_frame_player.visible = false
	if manager.ultimate_audio_player != null:
		manager.ultimate_audio_player.stop()
	set_battle_ui_for_ultimate(manager, true)
	exit_cutscene_presentation(manager)


func start_ultimate_camera_zoom_in(manager: Node) -> void:
	if manager.battle_camera == null:
		return
	manager._play_ultimate_zoom_sfx()
	var target_position: Vector2 = manager.player.global_position + manager.ULTIMATE_CAMERA_FOCUS_OFFSET
	var tween: Tween = manager.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(manager.battle_camera, "position", target_position, manager.ULTIMATE_ZOOM_DURATION)
	tween.parallel().tween_property(manager.battle_camera, "zoom", manager.ULTIMATE_CAMERA_ZOOM, manager.ULTIMATE_ZOOM_DURATION)
	tween.parallel().tween_property(manager.battle_camera, "offset", Vector2.ZERO, manager.ULTIMATE_ZOOM_DURATION)


func wait_for_remaining_ultimate_zoom_in(manager: Node) -> void:
	var pre_animation_duration: float = 0.0
	if manager.TAKASHI_ULTI_PRE_FRAME_RATE > 0.0:
		pre_animation_duration = float(manager.takashi_ulti_pre_frames.size()) / manager.TAKASHI_ULTI_PRE_FRAME_RATE

	var remaining_duration: float = manager.ULTIMATE_ZOOM_DURATION - pre_animation_duration
	if remaining_duration <= 0.0:
		return

	await manager.get_tree().create_timer(remaining_duration).timeout


func play_ultimate_camera_zoom_out(manager: Node) -> void:
	if manager.battle_camera == null:
		return

	manager._play_ultimate_zoom_out_wind_sfx()
	var viewport_size: Vector2 = manager.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = manager.BASE_VIEWPORT_SIZE

	var tween: Tween = manager.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(manager.battle_camera, "position", viewport_size * 0.5, manager.ULTIMATE_ZOOM_OUT_DURATION)
	tween.parallel().tween_property(manager.battle_camera, "zoom", Vector2.ONE, manager.ULTIMATE_ZOOM_OUT_DURATION)
	tween.parallel().tween_property(manager.battle_camera, "offset", Vector2.ZERO, manager.ULTIMATE_ZOOM_OUT_DURATION)
	await tween.finished


func play_ultimate_sequence(manager: Node) -> void:
	if manager.ultimate_frame_player == null or ultimate_frames.is_empty():
		return

	if manager.ultimate_audio_player != null:
		manager.ultimate_audio_player.stop()
		manager.ultimate_audio_player.volume_db = manager.ULTIMATE_AUDIO_VOLUME_DB
		manager.ultimate_audio_player.play()

	manager.ultimate_frame_player.visible = true
	manager.ultimate_frame_player.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var frame_duration: float = 1.0 / manager.ULTIMATE_FRAME_RATE
	for frame_texture in ultimate_frames:
		if manager.state != manager.BattleState.ACTION_RESOLUTION:
			break
		manager.ultimate_frame_player.texture = frame_texture
		await manager.get_tree().create_timer(frame_duration).timeout

	manager.ultimate_frame_player.texture = null
	manager.ultimate_frame_player.visible = false


func run_ultimate_sequence(
	manager: Node,
	target: Combatant,
	command: PendingBattleCommand = null
) -> void:
	if not manager._ultimate_execution_guard(command, target):
		return

	enter_cutscene_presentation(manager, target)
	set_battle_ui_for_ultimate(manager, false)
	start_ultimate_camera_zoom_in(manager)
	await manager._play_takashi_ultimate_fvx_intro()
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return
	await manager._play_takashi_ulti_pre_animation()
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return
	await wait_for_remaining_ultimate_zoom_in(manager)
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return

	await play_ultimate_sequence(manager)
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return

	manager._play_ultimate_shatter_sfx()
	manager._play_ultimate_glass_burst_sfx(0.9)
	manager._play_ultimate_cring_noise_sfx(0.65)
	manager._play_ultimate_deep_boom_sfx(0.65)
	manager._play_screen_flash(Color(0.72, 0.95, 1.0, 0.24), 0.12)
	manager._shake_camera_with_strength(7.0)
	await manager._play_takashi_ulti_post_animation()
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return

	await play_ultimate_camera_zoom_out(manager)
	set_battle_ui_for_ultimate(manager, true)
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return

	await manager.player.play_ultimate_feedback()
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return

	await manager.player.play_skill_movement(target)
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return

	await manager._play_enemy_octagram_impact(target)
	if not manager._ultimate_execution_guard(command, target):
		abort_cutscene_visuals(manager)
		return

	if command != null and not manager.ultimate_command_adapter.begin_resolution(command):
		return
	if not manager._consume_ultimate_hit(command, 0):
		return
	target.take_damage(manager.ULTIMATE_DAMAGE)
	manager._show_floating_damage(target, manager.ULTIMATE_DAMAGE)
	if manager.ULTIMATE_IMPACT_HOLD_SECONDS > 0.0:
		await manager.get_tree().create_timer(manager.ULTIMATE_IMPACT_HOLD_SECONDS).timeout
		if not manager._ultimate_execution_guard(command, target, false):
			return
	await target.play_hit_feedback()
	if not manager._ultimate_execution_guard(command, target, false):
		return
	await manager._fade_out_takashi_ultimate_glow_effect(0.26)
	if not manager._ultimate_execution_guard(command, target, false):
		return
	await manager._play_enemy_impact_camera_zoom_out()
	if not manager._ultimate_execution_guard(command, target, false):
		abort_cutscene_visuals(manager)
		return
	exit_cutscene_presentation(manager)
	manager._shake_camera()
	var log_text := "Octagram Fragment deals %d damage and consumes all energy." % manager.ULTIMATE_DAMAGE
	if command != null:
		manager._finish_ultimate_command_resolution(command, log_text, manager._is_interrupt_sourced(command))
	else:
		manager._finish_player_action(log_text)
