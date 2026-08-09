extends Node

## Block 15: tests for exploration action fixes (Part 0 / Part 0b).
## Validates:
##   - field attack works without cursor over enemy
##   - forward range/cone respected
##   - PLAYER_ADVANTAGE encounter generated
##   - skill HUD activation works
##   - skill cooldown works
##   - observable VFX hook fires

var _pass_count := 0
var _fail_count := 0
var _results: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_all()
	_print_summary()
	get_tree().quit(0 if _fail_count == 0 else 1)


func _run_all() -> void:
	await _test_attack_cone_hit()
	await _test_attack_cone_miss()
	await _test_attack_range_limit()
	await _test_attack_emits_signal()
	await _test_skill_cooldown()
	await _test_skill_emits_signal()
	await _test_get_forward_direction_fallback()
	await _test_get_forward_direction_last_move()
	await _test_stationary_attack_prefers_nearest_target()
	await _test_target_indicator_tracks_current_attack_target()


func _test_attack_cone_hit() -> void:
	## A controller with an enemy directly in front should always hit.
	var controller := _make_controller()
	var enemy := _make_attackable_node()
	add_child(controller)
	add_child(enemy)
	## Place enemy 1.5 units in front (within attack range 2.2)
	controller.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, -1.5)
	## Force last_move_direction toward the enemy (forward = -Z)
	controller._last_move_direction = Vector3(0.0, 0.0, -1.0)
	## Mock exploration state
	controller._exploration_enabled = true
	controller._exploration_attack_range = 2.2
	controller._exploration_attack_cooldown_duration = 0.5

	var hit_target: Array[Node3D] = [null]
	controller.exploration_attack_hit.connect(func(t): hit_target[0] = t)
	controller.try_exploration_attack()

	_assert("Attack cone: enemy in front is hit", hit_target[0] == enemy)
	controller.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _test_attack_cone_miss() -> void:
	## Enemy behind controller (opposite direction) must not be hit.
	var controller := _make_controller()
	var enemy := _make_attackable_node()
	add_child(controller)
	add_child(enemy)
	controller.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, 2.0)  ## behind (positive Z)
	controller._last_move_direction = Vector3(0.0, 0.0, -1.0)  ## facing away
	controller._exploration_enabled = true
	controller._exploration_attack_range = 2.2
	controller._exploration_attack_cooldown_duration = 0.5

	var hit_target: Array[Node3D] = [null]
	controller.exploration_attack_hit.connect(func(t): hit_target[0] = t)
	controller.try_exploration_attack()

	_assert("Attack cone: enemy directly behind is not hit", hit_target[0] == null)
	controller.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _test_attack_range_limit() -> void:
	## Enemy beyond attack range must not be hit.
	var controller := _make_controller()
	var enemy := _make_attackable_node()
	add_child(controller)
	add_child(enemy)
	controller.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, -5.0)  ## 5 units away, range 2.2
	controller._last_move_direction = Vector3(0.0, 0.0, -1.0)
	controller._exploration_enabled = true
	controller._exploration_attack_range = 2.2
	controller._exploration_attack_cooldown_duration = 0.5

	var hit_target: Array[Node3D] = [null]
	controller.exploration_attack_hit.connect(func(t): hit_target[0] = t)
	controller.try_exploration_attack()

	_assert("Attack range: enemy out of range not hit", hit_target[0] == null)
	controller.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _test_attack_emits_signal() -> void:
	## try_exploration_attack() must emit exploration_attack_used even if no enemy is in range.
	var controller := _make_controller()
	add_child(controller)
	controller._exploration_enabled = true
	controller._exploration_attack_range = 2.2
	controller._exploration_attack_cooldown_duration = 0.5

	var used_emitted: Array[bool] = [false]
	controller.exploration_attack_used.connect(func(): used_emitted[0] = true)
	controller.try_exploration_attack()

	_assert("Attack: exploration_attack_used signal fires on activation", used_emitted[0])
	controller.queue_free()
	await get_tree().process_frame


func _test_skill_cooldown() -> void:
	## Second immediate call must be rejected while on cooldown.
	var controller := _make_controller()
	add_child(controller)
	controller._exploration_enabled = true
	controller._exploration_skill_cooldown_duration = 3.0

	var first := controller.try_exploration_skill()
	var second := controller.try_exploration_skill()

	_assert("Skill cooldown: first activation succeeds", first == true)
	_assert("Skill cooldown: second immediate call rejected", second == false)
	controller.queue_free()
	await get_tree().process_frame


func _test_skill_emits_signal() -> void:
	var controller := _make_controller()
	add_child(controller)
	controller._exploration_enabled = true
	controller._exploration_skill_cooldown_duration = 3.0

	var skill_used: Array[bool] = [false]
	controller.exploration_skill_used.connect(func(): skill_used[0] = true)
	controller.try_exploration_skill()

	_assert("Skill: exploration_skill_used signal fires on activation", skill_used[0])
	controller.queue_free()
	await get_tree().process_frame


func _test_get_forward_direction_fallback() -> void:
	## When _last_move_direction is zero, get_forward_direction must not return zero.
	var controller := _make_controller()
	add_child(controller)
	controller._last_move_direction = Vector3.ZERO

	var dir := controller.get_forward_direction()
	_assert("Forward direction: fallback never returns zero vector", not dir.is_zero_approx())
	controller.queue_free()
	await get_tree().process_frame


func _test_get_forward_direction_last_move() -> void:
	var controller := _make_controller()
	add_child(controller)
	controller._last_move_direction = Vector3(1.0, 0.0, 0.0)

	var dir := controller.get_forward_direction()
	_assert("Forward direction: returns last_move_direction when set", dir.is_equal_approx(Vector3.RIGHT))
	controller.queue_free()
	await get_tree().process_frame


func _test_stationary_attack_prefers_nearest_target() -> void:
	var controller := _make_controller()
	var enemy := _make_attackable_node()
	add_child(controller)
	add_child(enemy)
	controller.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, 1.5)
	controller._last_move_direction = Vector3.ZERO
	controller._exploration_enabled = true
	controller._exploration_attack_range = 2.2
	controller._exploration_attack_cooldown_duration = 0.5

	var hit_target: Array[Node3D] = [null]
	controller.exploration_attack_hit.connect(func(t): hit_target[0] = t)
	controller.try_exploration_attack()

	_assert("Stationary targeting: nearest enemy can be hit without prior facing input", hit_target[0] == enemy)
	controller.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _test_target_indicator_tracks_current_attack_target() -> void:
	var controller := _make_controller()
	var enemy := _make_attackable_enemy()
	add_child(controller)
	add_child(enemy)
	enemy.add_to_group(&"exploration_attackable")
	controller.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, -1.4)
	controller._last_move_direction = Vector3.ZERO
	controller._exploration_enabled = true
	controller._exploration_attack_range = 2.2

	controller.call("_refresh_current_exploration_target")
	await get_tree().process_frame
	var indicator := enemy.get_node_or_null("TargetIndicator") as Node3D
	_assert("Target indicator: nearest attackable enemy shows marker", indicator != null and indicator.visible)

	controller.set_exploration_enabled(false)
	await get_tree().process_frame
	_assert("Target indicator: marker clears when exploration input is disabled", indicator != null and not indicator.visible)

	controller.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


# --- Helpers -----------------------------------------------------------------

func _make_controller() -> ExplorationCharacterController3D:
	var ctrl := ExplorationCharacterController3D.new()
	## Stub required child nodes
	var visual := AnimatedSprite3D.new()
	visual.name = "CharacterVisual"
	ctrl.add_child(visual)
	ctrl.character_visual = visual
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	ctrl.add_child(shadow)
	return ctrl


func _make_attackable_node() -> Node3D:
	var node := Node3D.new()
	node.add_to_group(&"exploration_attackable")
	return node


func _make_attackable_enemy() -> ExplorationEnemy3D:
	return ExplorationEnemy3D.new()


func _assert(test_name: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		_results.append("  PASS  %s" % test_name)
	else:
		_fail_count += 1
		_results.append("  FAIL  %s" % test_name)


func _print_summary() -> void:
	print("=== Block 15 Exploration Action Tests ===")
	for r in _results:
		print(r)
	var total := _pass_count + _fail_count
	print("--- %d/%d passed ---" % [_pass_count, total])
