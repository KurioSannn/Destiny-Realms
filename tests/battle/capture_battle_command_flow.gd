extends Node

const DEBUG_SCENE := preload("res://scenes/battle/debug/battle_command_flow_debug.tscn")

var scene: Node
var manager: BattleCommandFlowDebug
var flow: BattleCommandFlow
var output_dir: String
var capture_index := 0
var captured_execution := false
var captured_recovery := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_apply_requested_window_size()
	await get_tree().process_frame
	scene = DEBUG_SCENE.instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	manager = scene.get_node("BattleManager") as BattleCommandFlowDebug
	flow = scene.get_node("CommandFlow") as BattleCommandFlow
	manager.enemy_turn_enabled = false
	manager.recovery_hold_seconds = 0.8
	flow.flow_state_changed.connect(_capture_transient_state)
	var size := Vector2(get_window().size)
	output_dir = "res://docs/images/battle_command_flow/%dx%d" % [int(size.x), int(size.y)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await _capture("command_select")
	manager.call("_begin_debug_command", PendingBattleCommand.CommandType.BASIC_ATTACK)
	await _capture("basic_ready")
	manager.call("_cycle_target", 1)
	await _capture("target_select")
	await _capture("confirm_cancel")
	manager.call("_cancel_pending_command")
	await _capture("cancelled")

	manager.call("_begin_debug_command", PendingBattleCommand.CommandType.SKILL)
	await _capture("skill_ready")
	manager.call("_cancel_pending_command")
	manager.call("_fill_energy")
	manager.call("_begin_debug_command", PendingBattleCommand.CommandType.ULTIMATE)
	await _capture("ultimate_ready")
	manager.call("_cancel_pending_command")

	manager.call("_begin_debug_command", PendingBattleCommand.CommandType.BASIC_ATTACK)
	manager.call("_confirm_pending_command")
	var elapsed := 0.0
	while elapsed < 10.0 and (not captured_execution or not captured_recovery):
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	if not captured_execution or not captured_recovery:
		push_error("Transient execution/recovery screenshot timed out")
		get_tree().quit(1)
		return
	print("PASS: captured battle command flow at %dx%d" % [int(size.x), int(size.y)])
	get_tree().quit(0)

func _apply_requested_window_size() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-size="):
			continue
		var dimensions := argument.trim_prefix("--capture-size=").split("x")
		if dimensions.size() == 2:
			get_window().size = Vector2i(int(dimensions[0]), int(dimensions[1]))

func _capture_transient_state(state: int, _animation: int, _ui: int) -> void:
	if state == BattleCommandFlow.BattleFlowState.ACTION_EXECUTION and not captured_execution:
		captured_execution = true
		_capture.call_deferred("execution")
	elif state == BattleCommandFlow.BattleFlowState.ACTION_RECOVERY and not captured_recovery:
		captured_recovery = true
		_capture.call_deferred("recovery")

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	capture_index += 1
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [output_dir, capture_index, label]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save screenshot %s: %s" % [path, error_string(error)])
