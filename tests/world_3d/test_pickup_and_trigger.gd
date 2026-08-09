extends Node

## Standalone tests for Pickup3D and AreaTrigger3D -- no Abyss Forest
## dependency, just a bare Area3D + a fake exploration_character body,
## proving both components work independent of any specific map.


func _ready() -> void:
	var fake_character := CharacterBody3D.new()
	fake_character.add_to_group(&"exploration_character")
	add_child(fake_character)
	var character_shape := CollisionShape3D.new()
	var character_capsule := CapsuleShape3D.new()
	character_capsule.radius = 0.3
	character_capsule.height = 1.0
	character_shape.shape = character_capsule
	fake_character.add_child(character_shape)
	fake_character.global_position = Vector3(20.0, 0.0, 0.0)

	var pickup := Pickup3D.new()
	pickup.resource_id = &"test_shard"
	pickup.amount = 3
	add_child(pickup)
	var pickup_shape := CollisionShape3D.new()
	var pickup_sphere := SphereShape3D.new()
	pickup_sphere.radius = 1.0
	pickup_shape.shape = pickup_sphere
	pickup.add_child(pickup_shape)
	pickup.global_position = Vector3.ZERO

	var collected_events := []
	pickup.collected.connect(
		func(character, resource_id, amount): collected_events.append([character, resource_id, amount])
	)

	for frame_index in range(5):
		await get_tree().physics_frame

	fake_character.global_position = Vector3.ZERO
	for frame_index in range(10):
		await get_tree().physics_frame

	if collected_events.is_empty():
		_fail("Pickup did not fire collected signal on overlap")
		return
	if collected_events[0][1] != &"test_shard" or collected_events[0][2] != 3:
		_fail("Pickup collected signal carried the wrong resource_id/amount")
		return

	fake_character.global_position = Vector3(20.0, 0.0, 0.0)
	for frame_index in range(10):
		await get_tree().physics_frame
	fake_character.global_position = Vector3.ZERO
	for frame_index in range(10):
		await get_tree().physics_frame
	if collected_events.size() != 1:
		_fail("Pickup fired collected more than once")
		return

	print("PICKUP_OK resource id, amount, and fire-once verified")

	var trigger := AreaTrigger3D.new()
	trigger.trigger_id = &"test_trigger"
	trigger.one_shot = true
	add_child(trigger)
	var trigger_shape := CollisionShape3D.new()
	var trigger_box := BoxShape3D.new()
	trigger_box.size = Vector3(2.0, 2.0, 2.0)
	trigger_shape.shape = trigger_box
	trigger.add_child(trigger_shape)
	trigger.global_position = Vector3(0.0, 0.0, 30.0)

	fake_character.global_position = Vector3(0.0, 0.0, 100.0)
	for frame_index in range(5):
		await get_tree().physics_frame

	var entered_events := []
	var exited_events := []
	trigger.trigger_entered.connect(func(body): entered_events.append(body))
	trigger.trigger_exited.connect(func(body): exited_events.append(body))

	fake_character.global_position = Vector3(0.0, 0.0, 30.0)
	for frame_index in range(10):
		await get_tree().physics_frame
	if entered_events.is_empty():
		_fail("Trigger did not fire trigger_entered on overlap")
		return

	fake_character.global_position = Vector3(0.0, 0.0, 100.0)
	for frame_index in range(10):
		await get_tree().physics_frame
	if exited_events.is_empty():
		_fail("Trigger did not fire trigger_exited when leaving")
		return

	fake_character.global_position = Vector3(0.0, 0.0, 30.0)
	for frame_index in range(10):
		await get_tree().physics_frame
	if entered_events.size() != 1:
		_fail("One-shot trigger fired trigger_entered more than once")
		return

	print("TRIGGER_OK enter, exit, and one-shot behavior verified")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
