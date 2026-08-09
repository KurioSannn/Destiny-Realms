extends Node

## Block 14: "No one-frame input leak." GameFlowState.set_context(TRANSITION
## or BATTLE) alone must freeze exploration movement/attack/skill/interact
## AND camera orbit/zoom -- ExplorationCharacterController3D and
## ExplorationCamera3D were built before GameFlowState was meaningfully wired
## into them, so this is the regression coverage that keeps that wiring honest.

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const SPAWN_POSITION := Vector3(0.0, 0.63, 13.5)


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var world := ABYSS_SCENE.instantiate() as Node3D
	if world == null:
		_fail("Abyss Forest could not be instantiated for input-gating test")
		return
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var camera := world.get_node_or_null("ExplorationCamera") as Camera3D
	if player == null or camera == null:
		_fail("Input-gating test is missing player or camera")
		return

	GameFlowState.set_context(GameFlowState.InputContext.EXPLORATION)

	# --- Baseline: movement works in EXPLORATION ---
	player.global_position = SPAWN_POSITION
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	for frame_index in range(20):
		await get_tree().physics_frame
	Input.action_release("move_up")
	if player.global_position.distance_to(SPAWN_POSITION) < 0.15:
		_fail("Precondition failed: player did not move under EXPLORATION")
		return
	for frame_index in range(10):
		await get_tree().physics_frame

	# --- TRANSITION freezes movement, attack, skill, and camera orbit/zoom ---
	GameFlowState.set_context(GameFlowState.InputContext.TRANSITION)
	player.global_position = SPAWN_POSITION
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	for frame_index in range(20):
		await get_tree().physics_frame
	Input.action_release("move_up")
	if player.global_position.distance_to(SPAWN_POSITION) > 0.05:
		_fail("TRANSITION must freeze movement, but the player moved")
		return
	if player.call("try_exploration_attack"):
		_fail("TRANSITION must block exploration attack")
		return
	if player.call("try_exploration_skill"):
		_fail("TRANSITION must block exploration skill")
		return

	var distance_before_zoom := float(camera.get("_distance_target"))
	var yaw_before_drag := float(camera.get("_yaw_target_degrees"))
	_send_wheel(true)
	_send_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_send_mouse_motion(Vector2(600.0, 0.0))
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	for frame_index in range(10):
		await get_tree().physics_frame
	if not is_equal_approx(float(camera.get("_distance_target")), distance_before_zoom):
		_fail("TRANSITION must block camera zoom input")
		return
	if not is_equal_approx(float(camera.get("_yaw_target_degrees")), yaw_before_drag):
		_fail("TRANSITION must block camera orbit drag input")
		return

	print("TRANSITION_GATING_OK movement, attack, skill, and camera orbit/zoom all frozen")

	# --- BATTLE also freezes everything (encounter is mid-flight in battle) ---
	GameFlowState.set_context(GameFlowState.InputContext.BATTLE)
	player.global_position = SPAWN_POSITION
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	for frame_index in range(20):
		await get_tree().physics_frame
	Input.action_release("move_up")
	if player.global_position.distance_to(SPAWN_POSITION) > 0.05:
		_fail("BATTLE must freeze movement, but the player moved")
		return
	if player.call("try_exploration_attack"):
		_fail("BATTLE must block exploration attack")
		return

	print("BATTLE_GATING_OK movement and attack frozen while GameFlowState is BATTLE")

	# --- Returning to EXPLORATION immediately restores full input ---
	GameFlowState.set_context(GameFlowState.InputContext.EXPLORATION)
	player.global_position = SPAWN_POSITION
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	for frame_index in range(20):
		await get_tree().physics_frame
	Input.action_release("move_up")
	if player.global_position.distance_to(SPAWN_POSITION) < 0.15:
		_fail("Movement did not resume immediately after returning to EXPLORATION")
		return
	for frame_index in range(10):
		await get_tree().physics_frame

	if not player.call("try_exploration_attack"):
		_fail("Attack did not resume after returning to EXPLORATION")
		return

	_send_wheel(true)
	for frame_index in range(6):
		await get_tree().physics_frame
	if is_equal_approx(float(camera.get("_distance_target")), distance_before_zoom):
		_fail("Camera zoom did not resume after returning to EXPLORATION")
		return

	print("EXPLORATION_RESUME_OK movement, attack, and camera control all resumed after TRANSITION/BATTLE")
	print("INPUT_GATING_ALL_OK")
	get_tree().quit(0)


func _send_wheel(zoom_in: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = Vector2(640.0, 360.0)
	Input.parse_input_event(event)


func _send_mouse_button(button_index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = Vector2(640.0, 360.0)
	Input.parse_input_event(event)


func _send_mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(640.0, 360.0) + relative
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
