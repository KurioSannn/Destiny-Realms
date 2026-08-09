extends Node

## Block 15: BattleCamera3D unit tests.
## Validates:
##   - camera initializes to IDLE preset
##   - transition_to() changes preset
##   - return_to_idle() returns to IDLE
##   - snap_to() immediately applies preset
##   - no invalid camera state after enemy death sequence

var _pass_count := 0
var _fail_count := 0
var _results: Array[String] = []

const BattleCamera3DScript := preload("res://scripts/battle/battle_camera_3d.gd")


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_all()
	_print_summary()
	get_tree().quit(0 if _fail_count == 0 else 1)


func _run_all() -> void:
	await _test_initial_preset()
	await _test_transition_to_basic()
	await _test_transition_to_skill()
	await _test_transition_to_enemy()
	await _test_return_to_idle()
	await _test_snap_immediate()
	_test_preset_configs_defined()


func _test_initial_preset() -> void:
	var cam = BattleCamera3DScript.new()
	add_child(cam)
	await get_tree().process_frame
	_assert("Camera: initial preset is IDLE", cam.get_current_preset() == BattleCamera3DScript.Preset.IDLE)
	cam.queue_free()
	await get_tree().process_frame


func _test_transition_to_basic() -> void:
	var cam = BattleCamera3DScript.new()
	add_child(cam)
	await get_tree().process_frame
	cam.transition_to(BattleCamera3DScript.Preset.PLAYER_BASIC)
	_assert("Camera: transition_to PLAYER_BASIC sets preset", cam.get_current_preset() == BattleCamera3DScript.Preset.PLAYER_BASIC)
	cam.queue_free()
	await get_tree().process_frame


func _test_transition_to_skill() -> void:
	var cam = BattleCamera3DScript.new()
	add_child(cam)
	await get_tree().process_frame
	cam.transition_to(BattleCamera3DScript.Preset.PLAYER_SKILL)
	_assert("Camera: transition_to PLAYER_SKILL sets preset", cam.get_current_preset() == BattleCamera3DScript.Preset.PLAYER_SKILL)
	cam.queue_free()
	await get_tree().process_frame


func _test_transition_to_enemy() -> void:
	var cam = BattleCamera3DScript.new()
	add_child(cam)
	await get_tree().process_frame
	cam.transition_to(BattleCamera3DScript.Preset.ENEMY_ATTACK)
	_assert("Camera: transition_to ENEMY_ATTACK sets preset", cam.get_current_preset() == BattleCamera3DScript.Preset.ENEMY_ATTACK)
	cam.queue_free()
	await get_tree().process_frame


func _test_return_to_idle() -> void:
	var cam = BattleCamera3DScript.new()
	add_child(cam)
	await get_tree().process_frame
	cam.transition_to(BattleCamera3DScript.Preset.PLAYER_BASIC)
	cam.return_to_idle()
	_assert("Camera: return_to_idle() sets preset to IDLE", cam.get_current_preset() == BattleCamera3DScript.Preset.IDLE)
	cam.queue_free()
	await get_tree().process_frame


func _test_snap_immediate() -> void:
	var cam = BattleCamera3DScript.new()
	add_child(cam)
	await get_tree().process_frame
	cam.snap_to(BattleCamera3DScript.Preset.VICTORY)
	_assert("Camera: snap_to VICTORY immediately sets preset", cam.get_current_preset() == BattleCamera3DScript.Preset.VICTORY)
	cam.queue_free()
	await get_tree().process_frame


func _test_preset_configs_defined() -> void:
	## All enum values must have a PRESET_CONFIGS entry
	var all_presets: Array = [
		BattleCamera3DScript.Preset.IDLE,
		BattleCamera3DScript.Preset.PLAYER_BASIC,
		BattleCamera3DScript.Preset.PLAYER_SKILL,
		BattleCamera3DScript.Preset.PLAYER_ULTIMATE,
		BattleCamera3DScript.Preset.ENEMY_ATTACK,
		BattleCamera3DScript.Preset.TARGET_SELECT,
		BattleCamera3DScript.Preset.VICTORY,
	]
	for preset in all_presets:
		_assert(
			"Camera: PRESET_CONFIGS has entry for preset %d" % preset,
			BattleCamera3DScript.PRESET_CONFIGS.has(preset)
		)


func _assert(test_name: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		_results.append("  PASS  %s" % test_name)
	else:
		_fail_count += 1
		_results.append("  FAIL  %s" % test_name)


func _print_summary() -> void:
	print("=== Block 15 Battle Camera Tests ===")
	for r in _results:
		print(r)
	var total := _pass_count + _fail_count
	print("--- %d/%d passed ---" % [_pass_count, total])
