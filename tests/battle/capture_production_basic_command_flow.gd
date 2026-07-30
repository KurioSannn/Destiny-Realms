extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var output_dir: String
var capture_index := 0
var execution_capture_requested := false
var damage_capture_requested := false
var recovery_capture_requested := false
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
	output_dir = "res://docs/images/battle_command_flow/production_basic_fast/%dx%d" % [
		int(size.x),
		int(size.y)
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	var lesser := await _create_battle(false)
	var lesser_manager := lesser.get_node("BattleManager") as BattleManager
	lesser_manager.basic_command_adapter.flow.flow_state_changed.connect(
		_capture_lesser_flow_state
	)
	await _capture("lesser_command_select")
	lesser_manager.call("_on_attack_pressed")
	await _capture("lesser_basic_pressed_immediate")

	var elapsed := 0.0
	while elapsed < 6.0 and not recovery_capture_complete:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	if not execution_capture_complete:
		push_error("Timed out before Lesser Abyss Basic execution capture")
		get_tree().quit(1)
		return
	if not damage_capture_complete:
		push_error("Timed out before Lesser Abyss Basic damage resolution capture")
		get_tree().quit(1)
		return
	if not recovery_capture_complete:
		push_error("Timed out before Lesser Abyss Basic recovery capture")
		get_tree().quit(1)
		return
	if capture_failed:
		get_tree().quit(1)
		return
	await _free_scene(lesser)

	var bandit := await _create_battle(true)
	var bandit_manager := bandit.get_node("BattleManager") as BattleManager
	await _capture("bandit_command_select")
	bandit_manager.call("_on_attack_pressed")
	await _idle_frames(10)
	await _capture("bandit_basic_execution")
	if capture_failed:
		get_tree().quit(1)
		return
	await _free_scene(bandit)

	var victory := await _create_battle(true)
	var victory_manager := victory.get_node("BattleManager") as BattleManager
	victory_manager.enemy.current_hp = BattleManager.BASIC_ATTACK_DAMAGE
	victory_manager.call("_on_attack_pressed")
	if not await _wait_for_state(victory_manager, BattleManager.BattleState.WIN, 6.0):
		push_error("Timed out before production Basic victory capture")
		get_tree().quit(1)
		return
	await _capture("bandit_victory")
	if capture_failed:
		get_tree().quit(1)
		return
	await _free_scene(victory)

	var multi := await _create_battle(false)
	var multi_manager := multi.get_node("BattleManager") as BattleManager
	var second_enemy := _spawn_mock_enemy(multi, multi_manager)
	await _capture("mock_multi_command_select")
	multi_manager.call("_on_attack_pressed")
	await _capture("mock_multi_target_select")
	multi_manager.basic_command_adapter.select_target(second_enemy)
	await _idle_frames(6)
	await _capture("mock_multi_target_selected_immediate_execution")
	if capture_failed:
		get_tree().quit(1)
		return
	await _free_scene(multi)

	print("PASS: captured production basic command flow at %dx%d" % [int(size.x), int(size.y)])
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


func _spawn_mock_enemy(battle: Node, manager: BattleManager) -> Combatant:
	var mock_enemy := Combatant.new()
	mock_enemy.name = "MockSecondEnemy"
	var placeholder := Polygon2D.new()
	placeholder.name = "PlaceholderVisual"
	placeholder.color = Color(0.55, 0.32, 0.85, 1.0)
	placeholder.polygon = PackedVector2Array([
		Vector2(0.0, -60.0),
		Vector2(34.0, 0.0),
		Vector2(0.0, 60.0),
		Vector2(-34.0, 0.0),
	])
	mock_enemy.add_child(placeholder)
	battle.add_child(mock_enemy)
	mock_enemy.setup("Mock Enemy B", 50, 5)
	mock_enemy.global_position = manager.enemy.global_position + Vector2(190.0, -160.0)
	mock_enemy.z_index = 5
	return mock_enemy


func _free_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await _idle_frames(3)


func _capture_lesser_flow_state(state: int, _animation: int, _ui: int) -> void:
	if state == BattleCommandFlow.BattleFlowState.ACTION_EXECUTION and not execution_capture_requested:
		execution_capture_requested = true
		_capture_action_execution_after_delay.call_deferred()
	elif state == BattleCommandFlow.BattleFlowState.DAMAGE_AND_EFFECT_RESOLUTION and not damage_capture_requested:
		damage_capture_requested = true
		_capture_damage_resolution_after_delay.call_deferred()
	elif state == BattleCommandFlow.BattleFlowState.ACTION_RECOVERY and not recovery_capture_requested:
		recovery_capture_requested = true
		_capture_recovery_after_delay.call_deferred()


func _capture_action_execution_after_delay() -> void:
	await _idle_frames(6)
	await _capture("lesser_basic_execution")
	execution_capture_complete = true


func _capture_damage_resolution_after_delay() -> void:
	await _idle_frames(3)
	await _capture("lesser_damage_resolution")
	damage_capture_complete = true


func _capture_recovery_after_delay() -> void:
	await _idle_frames(1)
	await _capture("lesser_recovery")
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


func _wait_for_state(
	manager: BattleManager,
	expected_state: int,
	timeout_seconds: float
) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager):
			return false
		if manager.state == expected_state:
			return true
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	return false


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
