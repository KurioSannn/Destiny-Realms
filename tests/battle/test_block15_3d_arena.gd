extends Node

## Block 15: 3D arena and formation tests.
## Uses a loaded instance of BattlePresentation3D to access slot constants.
## Validates:
##   - Abyss arena scene loads
##   - party slots are on the correct side
##   - enemy slots are on the correct side
##   - no slot overlap
##   - formation Y at floor

var _pass_count := 0
var _fail_count := 0
var _results: Array[String] = []

## Slot constants mirrored from BattlePresentation3D.
## Defined here so tests are self-contained without requiring the autoload.
const PARTY_SLOTS: Array[Vector3] = [
	Vector3(-2.3, 0.0, 1.1),
	Vector3(-3.5, 0.0, 0.0),
	Vector3(-4.5, 0.0, -1.1),
]
const ENEMY_SLOTS: Array[Vector3] = [
	Vector3(2.3, 0.0, 0.5),
	Vector3(4.8, 0.0, -2.0),
	Vector3(6.4, 0.0, -4.4),
]

## Preload the presentation script for class-access validation
const BattlePres3DScript := preload("res://scripts/battle/battle_presentation_3d.gd")


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run_all()
	_print_summary()
	get_tree().quit(0 if _fail_count == 0 else 1)


func _run_all() -> void:
	_test_abyss_arena_scene_loads()
	_test_party_slots_defined()
	_test_enemy_slots_defined()
	_test_no_slot_overlap()
	_test_enemy_slot_count()
	_test_formation_y_at_floor()
	_test_script_constants_match()


func _test_abyss_arena_scene_loads() -> void:
	var packed := load("res://scenes/battle/arenas/battle_arena_abyss.tscn") as PackedScene
	_assert("Abyss arena scene file exists and loads", packed != null)
	if packed != null:
		var instance := packed.instantiate()
		_assert("Abyss arena scene instantiates to Node3D", instance is Node3D)
		instance.queue_free()


func _test_party_slots_defined() -> void:
	_assert("Party slot count >= 3", PARTY_SLOTS.size() >= 3)
	for i in range(PARTY_SLOTS.size()):
		var slot: Vector3 = PARTY_SLOTS[i]
		_assert("PartySlot%d is on the left (X < 0)" % i, slot.x < 0.0)


func _test_enemy_slots_defined() -> void:
	_assert("Enemy slot count >= 3", ENEMY_SLOTS.size() >= 3)
	for i in range(ENEMY_SLOTS.size()):
		var slot: Vector3 = ENEMY_SLOTS[i]
		_assert("EnemySlot%d is on the right (X > 0)" % i, slot.x > 0.0)


func _test_no_slot_overlap() -> void:
	for i in range(PARTY_SLOTS.size()):
		for j in range(i + 1, PARTY_SLOTS.size()):
			_assert(
				"PartySlot%d and PartySlot%d do not overlap" % [i, j],
				not PARTY_SLOTS[i].is_equal_approx(PARTY_SLOTS[j])
			)
	for i in range(ENEMY_SLOTS.size()):
		for j in range(i + 1, ENEMY_SLOTS.size()):
			_assert(
				"EnemySlot%d and EnemySlot%d do not overlap" % [i, j],
				not ENEMY_SLOTS[i].is_equal_approx(ENEMY_SLOTS[j])
			)


func _test_enemy_slot_count() -> void:
	_assert("At least 3 enemy formation slots available", ENEMY_SLOTS.size() >= 3)


func _test_formation_y_at_floor() -> void:
	for i in range(PARTY_SLOTS.size()):
		_assert("PartySlot%d Y = 0 (floor anchor)" % i,
			is_equal_approx(PARTY_SLOTS[i].y, 0.0))
	for i in range(ENEMY_SLOTS.size()):
		_assert("EnemySlot%d Y = 0 (floor anchor)" % i,
			is_equal_approx(ENEMY_SLOTS[i].y, 0.0))


func _test_script_constants_match() -> void:
	## Keep the self-contained values above honest: they must mirror the
	## production formation used by BattlePresentation3D.
	_assert("BattlePresentation3D script preloads without error",
		BattlePres3DScript != null)
	_assert("Production party formation matches the tested slots",
		BattlePres3DScript.PARTY_SLOTS == PARTY_SLOTS)
	_assert("Production enemy formation matches the tested slots",
		BattlePres3DScript.ENEMY_SLOTS == ENEMY_SLOTS)


func _assert(test_name: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		_results.append("  PASS  %s" % test_name)
	else:
		_fail_count += 1
		_results.append("  FAIL  %s" % test_name)


func _print_summary() -> void:
	print("=== Block 15 3D Arena Tests ===")
	for r in _results:
		print(r)
	var total := _pass_count + _fail_count
	print("--- %d/%d passed ---" % [_pass_count, total])
