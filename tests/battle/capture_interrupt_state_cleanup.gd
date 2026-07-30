extends Node

## Block 9D visual QA: confirms the interrupt state cleanup/resume-policy
## hardening produces no visible regression -- no duplicate player turn UI,
## no double damage, correct queued indicator, clean target highlight, no
## leaked debug label, and a lethal queued Ultimate reaching victory
## cleanly. See docs/battle_system_spec.md, "Block 9D implementation
## status".

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var output_dir: String
var capture_index := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_apply_requested_window_size()
	await get_tree().process_frame
	var size := Vector2(get_window().size)
	output_dir = "res://docs/images/battle_command_flow/interrupt_state_cleanup/%dx%d" % [
		int(size.x),
		int(size.y)
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await _capture_cancel_sequence()
	await _capture_confirm_sequence()
	await _capture_victory_sequence()

	print("PASS: captured interrupt state cleanup at %dx%d" % [int(size.x), int(size.y)])
	get_tree().quit(0)


func _capture_cancel_sequence() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await get_tree().process_frame
	manager.request_off_turn_ultimate(manager.player)
	await _capture("enemy_turn_queued")

	await _wait_for_pending_ultimate(manager, 10.0)
	await _capture("queued_ultimate_ready")

	manager.call("_cancel_ultimate_command")
	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0)
	await get_tree().process_frame
	await _capture("queued_cancel_player_turn_resumed")

	await _free_scene(battle)


func _capture_confirm_sequence() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_begin_enemy_turn")
	await get_tree().process_frame
	manager.request_off_turn_ultimate(manager.player)
	await _wait_for_pending_ultimate(manager, 10.0)

	var flow: BattleCommandFlow = manager.ultimate_command_adapter.flow
	var cut_in_seen := false
	var recovery_seen := false
	flow.flow_state_changed.connect(func(state: int, _animation: int, _ui: int) -> void:
		if state == BattleCommandFlow.BattleFlowState.ACTION_EXECUTION:
			cut_in_seen = true
		elif state == BattleCommandFlow.BattleFlowState.ACTION_RECOVERY:
			recovery_seen = true
	)

	manager.call("_confirm_ultimate_command")

	var elapsed := 0.0
	while elapsed < 10.0 and not cut_in_seen:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	await _idle_frames(10)
	await _capture("queued_confirm_cut_in")

	elapsed = 0.0
	while elapsed < 30.0 and not recovery_seen:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	await _idle_frames(1)
	await _capture("queued_recovery_in_progress")

	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 10.0)
	await get_tree().process_frame
	await _capture("queued_recovery_player_turn_resumed")

	await _free_scene(battle)


func _capture_victory_sequence() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	manager.enemy.current_hp = mini(manager.enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)

	manager.call("_begin_enemy_turn")
	await get_tree().process_frame
	manager.request_off_turn_ultimate(manager.player)
	await _wait_for_pending_ultimate(manager, 10.0)

	manager.call("_confirm_ultimate_command")
	await _wait_for_state(manager, BattleManager.BattleState.WIN, 30.0)
	await get_tree().process_frame
	await _capture("queued_ultimate_victory")

	await _free_scene(battle)


func _create_battle() -> Node:
	WorldProgress.reset_story()
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


func _wait_for_pending_ultimate(manager: BattleManager, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or manager._has_pending_ultimate_command():
			return
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _wait_for_state(manager: BattleManager, expected_state: int, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or manager.state == expected_state:
			return
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


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
		push_error("Viewport image is unavailable for screenshot %s" % label)
		return
	var path := "%s/%02d_%s.png" % [output_dir, capture_index, label]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save screenshot %s: %s" % [path, error_string(error)])


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
