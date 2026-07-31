extends Node

## Block 10 visual QA: proves multi-enemy targeting looks correct in a
## real production battle -- two enemies alive, target marker switching
## between them, Basic waiting for a target choice, Skill/Ultimate ready
## idle with a target selected, and the battle continuing normally after
## one of two enemies is defeated. See docs/battle_system_spec.md,
## "Block 10 implementation status".

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

var output_dir: String
var capture_index := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_apply_requested_window_size()
	await get_tree().process_frame
	var size := Vector2(get_window().size)
	output_dir = "res://docs/images/battle_command_flow/multi_enemy_targeting/%dx%d" % [
		int(size.x),
		int(size.y)
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await _capture_targeting_sequence()
	await _capture_battle_continues_after_one_enemy_dies()

	print("PASS: captured multi-enemy targeting at %dx%d" % [int(size.x), int(size.y)])
	get_tree().quit(0)


func _capture_targeting_sequence() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	var mock_enemy := _spawn_mock_enemy(battle, manager)
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	await _capture("two_enemies_command_select")

	manager.call("_on_attack_pressed")
	await get_tree().process_frame
	await _capture("basic_waits_for_target_two_enemies")

	manager.call("_select_basic_target_at_position", manager.enemy.global_position)
	await _wait_for_no_pending_basic(manager, 5.0)
	await get_tree().process_frame
	await _capture("basic_target_marker_primary_enemy")

	manager.call("_on_skill_pressed")
	await get_tree().process_frame
	manager.call("_select_skill_target_at_position", mock_enemy.global_position)
	await get_tree().process_frame
	await _capture("skill_ready_target_marker_second_enemy")

	await _wait_for_no_pending_skill(manager, 5.0)
	await _free_scene(battle)


func _capture_battle_continues_after_one_enemy_dies() -> void:
	var battle := await _create_battle()
	var manager := battle.get_node("BattleManager") as BattleManager
	var mock_enemy := _spawn_mock_enemy(battle, manager)
	manager.ultimate_energy = BattleManager.MAX_ULTIMATE_ENERGY
	manager.call("_refresh_energy_ui")
	mock_enemy.current_hp = mini(mock_enemy.current_hp, BattleManager.ULTIMATE_DAMAGE)

	manager.call("_on_ultimate_pressed")
	await get_tree().process_frame
	manager.call("_select_ultimate_target_at_position", mock_enemy.global_position)
	await _capture("ultimate_ready_target_marker_second_enemy")

	await _wait_for_combatant_defeated(mock_enemy, 45.0)
	await get_tree().process_frame
	await _capture("battle_continues_after_one_of_two_enemies_defeated")

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


func _wait_for_no_pending_basic(manager: BattleManager, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or not manager.basic_command_adapter.has_pending_basic():
			return
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _wait_for_no_pending_skill(manager: BattleManager, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(manager) or not manager.skill_command_adapter.has_pending_skill():
			return
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _wait_for_combatant_defeated(combatant: Combatant, timeout_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if not is_instance_valid(combatant) or combatant.is_defeated():
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
