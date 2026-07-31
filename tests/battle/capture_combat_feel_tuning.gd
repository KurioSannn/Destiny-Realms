extends Node

## Block 9H visual QA: proves the combat feel tuning (impact-hold pauses,
## camera-shake-tween cleanup) looks correct in a real production battle
## -- Basic anticipation/impact, Skill buildup/impact, Ultimate cut-in
## toward impact, enemy anticipation before damage, multi-enemy hit
## feedback landing on the right target, and recovery with no leftover
## camera offset. See docs/battle_system_spec.md, "Block 9H
## implementation status".

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var output_dir: String
var capture_index := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_apply_requested_window_size()
	await get_tree().process_frame
	var size := Vector2(get_window().size)
	output_dir = "res://docs/images/battle_command_flow/combat_feel_tuning/%dx%d" % [
		int(size.x),
		int(size.y)
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await _capture_basic()
	await _capture_skill()
	await _capture_ultimate()
	await _capture_enemy()
	await _capture_multi_enemy_and_recovery()

	print("PASS: captured combat feel tuning at %dx%d" % [int(size.x), int(size.y)])
	get_tree().quit(0)


func _capture_basic() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager

	manager.call("_on_attack_pressed")
	await _idle_frames(10)
	await _capture("basic_anticipation_movement")

	await _idle_frames(6)
	await _capture("basic_impact")

	await _free_scene(battle)


func _capture_skill() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager

	manager.call("_on_skill_pressed")
	await _idle_frames(8)
	await _capture("skill_ready_buildup")

	manager.call("_on_skill_pressed")
	await _idle_frames(20)
	await _capture("skill_impact")

	await _free_scene(battle)


func _capture_ultimate() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")

	manager.call("_on_ultimate_pressed")
	await _idle_frames(8)
	manager.call("_on_ultimate_pressed")
	await _idle_frames(40)
	await _capture("ultimate_cut_in")

	await _idle_frames(60)
	await _capture("ultimate_impact")

	await _free_scene(battle)


func _capture_enemy() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager

	manager.call("_begin_enemy_turn")
	await _idle_frames(20)
	await _capture("enemy_anticipation")

	await _idle_frames(20)
	await _capture("enemy_impact")

	await _free_scene(battle)


func _capture_multi_enemy_and_recovery() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	var mock_enemy := _spawn_mock_enemy(battle, manager)

	manager.call("_on_skill_pressed")
	await _idle_frames(3)
	manager.call("_select_skill_target_at_position", mock_enemy.global_position)
	await _wait_for_no_pending_skill(manager, 5.0)
	await get_tree().process_frame
	await _capture("multi_enemy_hit_feedback_correct_target")
	await _capture("recovery_no_camera_offset")

	await _free_scene(battle)


func _spawn_mock_enemy(battle: Node, manager: BattleManager) -> Combatant:
	var mock_enemy := Combatant.new()
	mock_enemy.name = "MockSecondEnemy"
	battle.add_child(mock_enemy)
	mock_enemy.setup("Mock Enemy B", 150, 5)
	mock_enemy.global_position = manager.enemy.global_position + Vector2(140.0, 0.0)
	return mock_enemy


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


func _wait_for_no_pending_skill(manager: BattleManager, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or not manager.skill_command_adapter.has_pending_skill():
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
