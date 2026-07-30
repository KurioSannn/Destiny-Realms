extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var output_dir: String
var capture_index := 0
var cut_in_capture_requested := false
var execution_capture_requested := false
var damage_capture_requested := false
var recovery_capture_requested := false
var cut_in_capture_complete := false
var execution_capture_complete := false
var damage_capture_complete := false
var recovery_capture_complete := false
var capture_failed := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_apply_requested_window_size()
	await get_tree().process_frame
	var size := Vector2(get_window().size)
	output_dir = "res://docs/images/battle_command_flow/ultimate_off_turn_interrupt/%dx%d" % [
		int(size.x),
		int(size.y)
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	var lesser := await _create_battle(false)
	var lesser_manager := lesser.get_node("BattleManager") as BattleManager
	lesser_manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	lesser_manager.call("_refresh_energy_ui")
	lesser_manager.ultimate_command_adapter.flow.flow_state_changed.connect(
		_capture_lesser_flow_state
	)
	await _capture("lesser_command_select")

	lesser_manager.call("_begin_enemy_turn")
	await get_tree().process_frame
	lesser_manager.request_off_turn_ultimate(lesser_manager.player)
	await _capture("lesser_enemy_turn_ultimate_queued")

	var ready_elapsed := 0.0
	while ready_elapsed < 10.0 and not lesser_manager.call("_has_pending_ultimate_command"):
		await get_tree().process_frame
		ready_elapsed += 1.0 / 60.0
	if not lesser_manager.call("_has_pending_ultimate_command"):
		push_error("Timed out before queued Ultimate reached ready idle after enemy recovery")
		get_tree().quit(1)
		return
	await _capture("lesser_after_enemy_recovery_ultimate_ready")
	await _capture("lesser_queued_target_select")
	await _capture("lesser_queued_confirm_cancel")

	lesser_manager.call("_confirm_ultimate_command")
	var elapsed := 0.0
	while elapsed < 40.0 and not recovery_capture_complete:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	if not cut_in_capture_complete:
		push_error("Timed out before queued Ultimate cut-in capture")
		get_tree().quit(1)
		return
	if not damage_capture_complete:
		push_error("Timed out before queued Ultimate damage resolution capture")
		get_tree().quit(1)
		return
	if not recovery_capture_complete:
		push_error("Timed out before queued Ultimate recovery capture")
		get_tree().quit(1)
		return
	if capture_failed:
		get_tree().quit(1)
		return

	var resume_elapsed := 0.0
	while resume_elapsed < 5.0 and lesser_manager.is_processing_interrupt_queue:
		await get_tree().process_frame
		resume_elapsed += 1.0 / 60.0
	await _capture("lesser_player_turn_resumed")
	if capture_failed:
		get_tree().quit(1)
		return
	await _free_scene(lesser)

	print("PASS: captured ultimate off-turn interrupt at %dx%d" % [int(size.x), int(size.y)])
	get_tree().quit(0)


func _create_battle(bandit: bool) -> Node:
	WorldProgress.reset_story()
	if bandit:
		WorldProgress.begin_bandit_encounter()
	var scene := BATTLE_SCENE.instantiate()
	var manager := scene.get_node("BattleManager") as BattleManager
	manager.use_new_basic_command_flow = true
	manager.use_new_skill_command_flow = true
	manager.use_new_ultimate_command_flow = true
	get_tree().root.add_child(scene)
	await _idle_frames(75)
	return scene


func _free_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await _idle_frames(3)


func _capture_lesser_flow_state(state: int, _animation: int, _ui: int) -> void:
	if state == BattleCommandFlow.BattleFlowState.ACTION_EXECUTION and not cut_in_capture_requested:
		cut_in_capture_requested = true
		_capture_cut_in_after_delay.call_deferred()
	elif state == BattleCommandFlow.BattleFlowState.DAMAGE_AND_EFFECT_RESOLUTION and not damage_capture_requested:
		damage_capture_requested = true
		_capture_damage_resolution_after_delay.call_deferred()
	elif state == BattleCommandFlow.BattleFlowState.ACTION_RECOVERY and not recovery_capture_requested:
		recovery_capture_requested = true
		_capture_recovery_after_delay.call_deferred()


func _capture_cut_in_after_delay() -> void:
	await _idle_frames(10)
	await _capture("lesser_queued_cut_in")
	cut_in_capture_complete = true
	_capture_execution_after_delay.call_deferred()


func _capture_execution_after_delay() -> void:
	if execution_capture_requested:
		return
	execution_capture_requested = true
	await _idle_frames(90)
	await _capture("lesser_queued_ultimate_execution")
	execution_capture_complete = true


func _capture_damage_resolution_after_delay() -> void:
	await _idle_frames(3)
	await _capture("lesser_queued_damage_resolution")
	damage_capture_complete = true


func _capture_recovery_after_delay() -> void:
	await _idle_frames(1)
	await _capture("lesser_queued_recovery")
	recovery_capture_complete = true


func _apply_requested_window_size() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-size="):
			continue
		var dimensions := argument.trim_prefix("--capture-size=").split("x")
		if dimensions.size() == 2:
			get_window().size = Vector2i(int(dimensions[0]), int(dimensions[1]))


func _capture(label: String) -> void:
	await get_tree().process_frame
	capture_index += 1
	var image := get_viewport().get_texture().get_image()
	if image == null:
		capture_failed = true
		push_error("Viewport image is unavailable for screenshot %s" % label)
		return
	var path := "%s/%02d_%s.png" % [output_dir, capture_index, label]
	var error := image.save_png(path)
	if error != OK:
		capture_failed = true
		push_error("Could not save screenshot %s: %s" % [path, error_string(error)])


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
