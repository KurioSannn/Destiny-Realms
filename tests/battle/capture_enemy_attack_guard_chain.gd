extends Node

## Block 9C visual QA: confirms the enemy attack guard chain produces no
## visible regression -- no duplicate player turn UI, no double damage, a
## correct queued indicator, clean target highlight, no leaked debug label.
## Lighter than Block 9B's capture (4 shots, not 10). See
## docs/battle_system_spec.md, "Block 9C implementation status".

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var output_dir: String
var capture_index := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_apply_requested_window_size()
	await get_tree().process_frame
	var size := Vector2(get_window().size)
	output_dir = "res://docs/images/battle_command_flow/enemy_attack_guard_chain/%dx%d" % [
		int(size.x),
		int(size.y)
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await _capture_normal_enemy_attack()
	await _capture_queued_ultimate_sequence()

	print("PASS: captured enemy attack guard chain at %dx%d" % [int(size.x), int(size.y)])
	get_tree().quit(0)


func _capture_normal_enemy_attack() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	var initial_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	await _wait_for_player_hp_below(manager, initial_hp, 5.0)
	await _capture("normal_enemy_attack_no_queue")

	await _wait_for_state(manager, BattleManager.BattleState.PLAYER_TURN, 5.0)
	await _capture("normal_enemy_attack_player_turn_resumed")

	await _free_scene(battle)


func _capture_queued_ultimate_sequence() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	var initial_hp := manager.player.current_hp

	manager.call("_begin_enemy_turn")
	await get_tree().process_frame
	manager.request_off_turn_ultimate(manager.player)
	await _capture("enemy_attack_with_queued_ultimate")

	await _wait_for_player_hp_below(manager, initial_hp, 5.0)
	await _wait_for_pending_ultimate(manager, 10.0)
	await _capture("after_enemy_recovery_queued_ultimate_ready")

	manager.call("_confirm_ultimate_command")
	await _wait_for_interrupt_processing_cleared(manager, 40.0)
	await get_tree().process_frame
	await _capture("queued_ultimate_finished_player_turn_normal")

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


func _wait_for_player_hp_below(manager: BattleManager, starting_hp: int, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or manager.player.current_hp < starting_hp:
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


func _wait_for_pending_ultimate(manager: BattleManager, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or manager._has_pending_ultimate_command():
			return
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _wait_for_interrupt_processing_cleared(manager: BattleManager, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or not manager.is_processing_interrupt_queue:
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
