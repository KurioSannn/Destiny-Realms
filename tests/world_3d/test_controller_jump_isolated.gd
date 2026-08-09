extends Node

## Minimal, Abyss-Forest-independent jump test to isolate controller behavior
## from unrelated map/HUD content -- just a controller and a floor.


func _ready() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(20.0, 1.0, 20.0)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	ground.global_position = Vector3(0.0, -0.5, 0.0)

	var controller := ExplorationCharacterController3D.new()
	controller.name = "TestController"
	var capsule_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	capsule_shape.shape = capsule
	controller.add_child(capsule_shape)
	var visual := AnimatedSprite3D.new()
	visual.name = "CharacterVisual"
	controller.add_child(visual)
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	shadow.mesh = QuadMesh.new()
	controller.add_child(shadow)
	# Children must exist before the controller enters the tree, since its
	# @onready vars resolve $CharacterVisual/$Shadow at _ready() time.
	add_child(controller)
	controller.global_position = Vector3(0.0, 0.5, 0.0)

	for frame_index in range(15):
		await get_tree().physics_frame

	if not controller.is_on_floor():
		_fail("Controller did not settle onto the ground before jump test")
		return

	_send_key(KEY_SPACE, true)
	# is_action_just_pressed becomes visible one physics frame after the
	# synthetic event, and the controller's own _physics_process reacts to it
	# the frame after that -- two frames of settle, not one.
	for frame_index in range(2):
		await get_tree().physics_frame
	_send_key(KEY_SPACE, false)

	if controller.velocity.y <= 0.5:
		_fail("Jump did not apply upward velocity in isolation, got %.4f" % controller.velocity.y)
		return

	print("ISOLATED_JUMP_OK velocity.y=%.4f" % controller.velocity.y)
	get_tree().quit(0)


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
