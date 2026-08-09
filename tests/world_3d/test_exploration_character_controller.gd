extends Node

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const SPAWN_POSITION := Vector3(0.0, 0.63, 13.5)


func _ready() -> void:
	var world := ABYSS_SCENE.instantiate() as Node3D
	if world == null:
		_fail("Abyss Forest could not be instantiated for controller test")
		return
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		_fail("Controller test is missing player")
		return

	# --- Camera-relative movement (regression from Block 11) ---
	var start_position := player.global_position
	Input.action_press("move_up")
	for frame_index in range(12):
		await get_tree().physics_frame
	Input.action_release("move_up")
	if player.global_position.distance_to(start_position) < 0.15:
		_fail("Player did not move with camera-relative input")
		return
	for frame_index in range(20):
		await get_tree().physics_frame

	# --- Sprint increases speed ---
	player.global_position = SPAWN_POSITION
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	for frame_index in range(30):
		await get_tree().physics_frame
	var walk_speed := Vector2(player.velocity.x, player.velocity.z).length()

	Input.action_press("sprint")
	for frame_index in range(30):
		await get_tree().physics_frame
	var sprint_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("sprint")
	Input.action_release("move_up")
	if sprint_speed <= walk_speed + 0.5:
		_fail("Sprint did not meaningfully increase speed: walk=%.3f sprint=%.3f" % [walk_speed, sprint_speed])
		return
	for frame_index in range(30):
		await get_tree().physics_frame

	# --- Input disabled state blocks movement ---
	player.global_position = SPAWN_POSITION
	player.velocity = Vector3.ZERO
	player.call("set_exploration_enabled", false)
	Input.action_press("move_up")
	for frame_index in range(20):
		await get_tree().physics_frame
	Input.action_release("move_up")
	if Vector2(player.velocity.x, player.velocity.z).length() > 0.05:
		_fail("Movement did not respect set_exploration_enabled(false)")
		return
	player.call("set_exploration_enabled", true)
	for frame_index in range(10):
		await get_tree().physics_frame

	# --- Grounded jump ---
	player.global_position = SPAWN_POSITION
	player.velocity = Vector3.ZERO
	for frame_index in range(10):
		await get_tree().physics_frame
	if not player.is_on_floor():
		_fail("Player unexpectedly not grounded before jump test")
		return
	_send_key(KEY_SPACE, true)
	# is_action_just_pressed becomes visible one physics frame after the
	# synthetic event, and the controller reacts to it the frame after that.
	for frame_index in range(2):
		await get_tree().physics_frame
	_send_key(KEY_SPACE, false)
	if player.velocity.y <= 0.5:
		_fail("Jump did not apply upward velocity, got %.3f" % player.velocity.y)
		return

	# --- No mid-air double jump ---
	var velocity_after_first_jump := player.velocity.y
	for frame_index in range(3):
		await get_tree().physics_frame
	_send_key(KEY_SPACE, true)
	for frame_index in range(2):
		await get_tree().physics_frame
	_send_key(KEY_SPACE, false)
	if player.velocity.y > velocity_after_first_jump:
		_fail("Mid-air jump incorrectly added extra upward velocity")
		return

	var landed_within_window := false
	for frame_index in range(120):
		await get_tree().physics_frame
		if player.is_on_floor():
			landed_within_window = true
			break
	if not landed_within_window:
		_fail("Player did not land within the expected window")
		return

	print("EXPLORATION_CONTROLLER_MOVEMENT_OK camera-relative, sprint, gating, jump, no double-jump verified")

	# --- Exploration attack: fires, cooldown, hit detection, blocked state ---
	player.global_position = SPAWN_POSITION
	player.velocity = Vector3.ZERO
	for frame_index in range(10):
		await get_tree().physics_frame

	var dummy_target := Node3D.new()
	dummy_target.name = "DummyAttackTarget"
	world.add_child(dummy_target)
	dummy_target.add_to_group(&"exploration_attackable")
	dummy_target.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)

	var attack_fired := []
	player.exploration_attack_used.connect(func(): attack_fired.append(true))
	var hit_targets := []
	player.exploration_attack_hit.connect(func(target): hit_targets.append(target))

	Input.action_press("move_up")
	for frame_index in range(6):
		await get_tree().physics_frame
	Input.action_release("move_up")
	for frame_index in range(10):
		await get_tree().physics_frame
	dummy_target.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)

	if not player.call("try_exploration_attack"):
		_fail("Exploration attack did not fire when off cooldown")
		return
	if attack_fired.is_empty():
		_fail("exploration_attack_used signal did not fire")
		return
	if hit_targets.is_empty() or hit_targets[0] != dummy_target:
		_fail("Exploration attack did not detect the dummy target in front")
		return
	if player.call("try_exploration_attack"):
		_fail("Exploration attack fired again while on cooldown")
		return

	player.call("set_exploration_enabled", false)
	if player.call("try_exploration_attack"):
		_fail("Exploration attack fired while exploration was disabled")
		return
	player.call("set_exploration_enabled", true)

	print("EXPLORATION_ATTACK_OK fires, cooldown, hit detection, and blocked-state verified")

	# --- Exploration skill: fires, cooldown, blocked state, field hit ---
	var skill_fired := []
	player.exploration_skill_used.connect(func(): skill_fired.append(true))
	var skill_hits := []
	if player.has_signal("exploration_skill_hit"):
		player.connect("exploration_skill_hit", func(t): skill_hits.append(t))

	dummy_target.global_position = player.global_position + Vector3(0.0, 0.0, -2.0)
	if not player.call("try_exploration_skill"):
		_fail("Exploration skill did not fire when off cooldown")
		return
	if skill_fired.is_empty():
		_fail("exploration_skill_used signal did not fire")
		return
	if skill_hits.is_empty() or skill_hits[0] != dummy_target:
		_fail("Exploration skill did not hit target in field skill volume")
		return
	if player.call("try_exploration_skill"):
		_fail("Exploration skill fired again while on cooldown")
		return
	player.call("set_exploration_enabled", false)
	if player.call("try_exploration_skill"):
		_fail("Exploration skill fired while exploration was disabled")
		return
	player.call("set_exploration_enabled", true)

	print("EXPLORATION_SKILL_OK fires, cooldown, field hit, and blocked-state verified")

	# --- Interaction: nearest target, range enter/exit, prompt callback, disabled target ---
	var interactable_a := Interactable3D.new()
	interactable_a.name = "InteractableA"
	world.add_child(interactable_a)
	interactable_a.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)

	var interactable_b := Interactable3D.new()
	interactable_b.name = "InteractableB"
	world.add_child(interactable_b)
	interactable_b.global_position = player.global_position + Vector3(0.5, 0.0, 0.0)

	player.call("register_nearby_interactable", interactable_a)
	player.call("register_nearby_interactable", interactable_b)
	if player.call("get_current_interactable") != interactable_b:
		_fail("Nearest interactable selection did not pick the closer target")
		return

	player.call("unregister_nearby_interactable", interactable_b)
	if player.call("get_current_interactable") != interactable_a:
		_fail("Interactable selection did not fall back correctly after range exit")
		return

	var interacted_with := []
	interactable_a.interacted.connect(func(character): interacted_with.append(character))
	_send_key(KEY_E, true)
	for frame_index in range(2):
		await get_tree().physics_frame
	_send_key(KEY_E, false)
	if interacted_with.is_empty():
		_fail("Interact input did not trigger the current interactable")
		return

	interactable_a.enabled = false
	player.call("unregister_nearby_interactable", interactable_a)
	player.call("register_nearby_interactable", interactable_a)
	if player.call("get_current_interactable") != null:
		_fail("A disabled interactable must not become the current target")
		return

	print("INTERACTION_OK nearest selection, range exit fallback, interact callback, and disabled target verified")

	get_tree().quit(0)


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
