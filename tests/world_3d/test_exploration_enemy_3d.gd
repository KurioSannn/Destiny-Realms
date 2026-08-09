extends Node

## Standalone (no Abyss Forest dependency) coverage of ExplorationEnemy3D:
## profile loading, the full state machine, detection (range/cone/hysteresis),
## patrol, chase/engage/leash/return, exploration-attack reaction and
## resulting opening advantage, encounter context/group data, GameFlowState
## gating, protagonist-agnostic targeting, and reusability across profiles.

const State := ExplorationEnemy3D.State
const Advantage := EncounterContext.OpeningAdvantage


func _ready() -> void:
	# This file tests ExplorationEnemy3D's state machine and its use of
	# EncounterCoordinator's request/resolve plumbing in isolation -- not the
	# Block 14 battle bridge (covered separately by
	# tests/battle/test_block14_battle_bridge.gd and
	# tests/system/test_battle_session_coordinator.gd). Disconnect
	# BattleSessionCoordinator so a real ENGAGE-triggered request_encounter()
	# call here can't kick off an actual SceneTransition.change_to_file() and
	# tear down this test's own scene tree.
	if EncounterCoordinator.encounter_requested.is_connected(BattleSessionCoordinator._on_encounter_requested):
		EncounterCoordinator.encounter_requested.disconnect(BattleSessionCoordinator._on_encounter_requested)

	var ground := StaticBody3D.new()
	add_child(ground)
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(320.0, 1.0, 320.0)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	ground.global_position = Vector3(0.0, -0.5, 0.0)

	var player := _make_character(Vector3(0.0, 0.5, 0.0))
	GameFlowState.set_active_character(player)
	GameFlowState.set_context(GameFlowState.InputContext.EXPLORATION)

	# Connected once, up front, so a fast enemy reaching ENGAGE mid-loop
	# (before a later section gets around to checking) is never missed.
	var all_requested_contexts := []
	EncounterCoordinator.encounter_requested.connect(func(context): all_requested_contexts.append(context))

	var fast_profile := _make_profile("fast_species", 3.0, 6.0)
	fast_profile.detection_range = 5.0
	fast_profile.lose_target_range = 8.0
	fast_profile.detection_angle_degrees = 360.0
	fast_profile.alert_delay = 0.2
	fast_profile.engage_range = 1.0
	fast_profile.leash_distance = 6.0
	fast_profile.acceleration = 24.0

	# --- PROFILE: loads, identifiers valid, tuning sane ---
	if fast_profile.enemy_id.is_empty() or fast_profile.battle_enemy_id.is_empty():
		_fail("Profile identifiers must not be empty")
		return
	if fast_profile.lose_target_range <= fast_profile.detection_range:
		_fail("lose_target_range must exceed detection_range to avoid flicker")
		return
	if fast_profile.chase_speed <= fast_profile.patrol_speed:
		_fail("chase_speed should be faster than patrol_speed")
		return

	# --- STATE MACHINE + DETECTION: far away stays IDLE ---
	var enemy := _make_enemy(Vector3(20.0, 0.5, 0.0), fast_profile, &"enemy_far")
	for frame_index in range(10):
		await get_tree().physics_frame
	if enemy.get_state() != State.IDLE:
		_fail("Enemy outside detection radius must stay IDLE, got %s" % State.keys()[enemy.get_state()])
		return
	enemy.queue_free()
	await get_tree().physics_frame

	# --- DETECTION: inside radius -> ALERT -> CHASE ---
	var alert_started := []
	var chase_enemy := _make_enemy(Vector3(3.0, 0.5, 0.0), fast_profile, &"enemy_chase")
	chase_enemy.enemy_alert_started.connect(func(e): alert_started.append(e))
	for frame_index in range(5):
		await get_tree().physics_frame
	if chase_enemy.get_state() != State.ALERT:
		_fail("Enemy inside detection radius did not enter ALERT, got %s" % State.keys()[chase_enemy.get_state()])
		return
	if alert_started.is_empty():
		_fail("enemy_alert_started did not fire")
		return
	for frame_index in range(30):
		await get_tree().physics_frame
	if chase_enemy.get_state() != State.CHASE:
		_fail("Enemy did not transition ALERT -> CHASE after alert_delay, got %s" % State.keys()[chase_enemy.get_state()])
		return

	print("STATE_MACHINE_OK idle, alert, and alert->chase transitions verified")

	# --- CHASE: enemy approaches player ---
	var distance_before_chase := chase_enemy.global_position.distance_to(player.global_position)
	for frame_index in range(30):
		await get_tree().physics_frame
	var distance_after_chase := chase_enemy.global_position.distance_to(player.global_position)
	if distance_after_chase >= distance_before_chase:
		_fail("Chasing enemy did not approach the player")
		return

	# --- ENGAGE: triggers exactly once ---
	var settle_frames := 0
	while chase_enemy.get_state() != State.ENGAGE and settle_frames < 240:
		await get_tree().physics_frame
		settle_frames += 1
	if chase_enemy.get_state() != State.ENGAGE:
		_fail("Enemy never reached ENGAGE within the expected window")
		return
	for frame_index in range(10):
		await get_tree().physics_frame
	if all_requested_contexts.size() != 1:
		_fail("Encounter must be requested exactly once, got %d" % all_requested_contexts.size())
		return
	var neutral_context: EncounterContext = all_requested_contexts[0]
	if neutral_context.opening_advantage != Advantage.NEUTRAL:
		_fail("Chase-initiated engage must default to NEUTRAL opening")
		return
	if neutral_context.encounter_group_id.is_empty() or neutral_context.battle_enemy_ids.is_empty():
		_fail("EncounterContext must carry a non-empty group id and battle enemy ids")
		return
	if neutral_context.initiating_enemy_id != &"enemy_chase":
		_fail("EncounterContext.initiating_enemy_id did not match the requesting enemy")
		return

	print("CHASE_ENGAGE_OK approach, single encounter request, and NEUTRAL opening verified")

	# Resolve so the coordinator is free again, then clean up.
	EncounterCoordinator.resolve_active_encounter(&"escape")
	await get_tree().physics_frame
	chase_enemy.queue_free()
	await get_tree().physics_frame

	# --- LEASH / RETURN ---
	var leash_profile := _make_profile("leash_species", 3.0, 6.0)
	leash_profile.detection_range = 30.0
	leash_profile.lose_target_range = 40.0
	leash_profile.detection_angle_degrees = 360.0
	leash_profile.alert_delay = 0.1
	leash_profile.engage_range = 1.0
	leash_profile.leash_distance = 5.0
	leash_profile.acceleration = 30.0
	var leash_enemy := _make_enemy(Vector3(-15.0, 0.5, 0.0), leash_profile, &"enemy_leash")
	player.global_position = Vector3(-15.0, 0.5, -25.0)  # far beyond leash distance from enemy home
	for frame_index in range(200):
		await get_tree().physics_frame
		if leash_enemy.get_state() == State.RETURNING:
			break
	if leash_enemy.get_state() != State.RETURNING:
		_fail("Enemy did not enter RETURNING after exceeding leash distance")
		return
	var returned := false
	for frame_index in range(240):
		await get_tree().physics_frame
		if leash_enemy.get_state() != State.RETURNING:
			returned = true
			break
	if not returned:
		_fail("Enemy never finished RETURNING back to a passive state")
		return
	if leash_enemy.global_position.distance_to(leash_enemy.get_home_position()) > 1.0:
		_fail("Enemy did not actually return near its home position")
		return

	print("LEASH_RETURN_OK leash exit, return travel, and clean reset verified")
	leash_enemy.queue_free()
	player.global_position = Vector3(0.0, 0.5, 0.0)
	await get_tree().physics_frame

	# --- PATROL: waypoint advancement + stationary enemy ---
	var patrol_route := PatrolRoute3D.new()
	patrol_route.loop_mode = PatrolRoute3D.LoopMode.LOOP
	patrol_route.pause_seconds_at_point = 0.0
	add_child(patrol_route)
	var point_a := Marker3D.new()
	patrol_route.add_child(point_a)
	point_a.global_position = Vector3(40.0, 0.5, 0.0)
	var point_b := Marker3D.new()
	patrol_route.add_child(point_b)
	point_b.global_position = Vector3(44.0, 0.5, 0.0)

	var patrol_profile := _make_profile("patrol_species", 2.5, 5.0)
	patrol_profile.detection_range = 0.5  # keep the roaming player out of range
	patrol_profile.lose_target_range = 0.5
	var patrol_enemy := _make_enemy(Vector3(40.0, 0.5, 0.0), patrol_profile, &"enemy_patrol")
	patrol_enemy.patrol_route_path = patrol_enemy.get_path_to(patrol_route)
	patrol_enemy._patrol_route = patrol_route
	patrol_enemy.idle_wait_seconds = 0.1

	var start_patrol_position := patrol_enemy.global_position
	var reached_second_point := false
	for frame_index in range(240):
		await get_tree().physics_frame
		# XZ-only, matching how _move_toward() itself judges arrival: a
		# grounded capsule's resting Y (collision settling) will not exactly
		# match a hand-placed marker's Y, so a 3D distance check never
		# converges even though the enemy has correctly arrived.
		var flat_distance_to_b := Vector2(
			patrol_enemy.global_position.x, patrol_enemy.global_position.z
		).distance_to(Vector2(point_b.global_position.x, point_b.global_position.z))
		if flat_distance_to_b < 0.2:
			reached_second_point = true
			break
	if not reached_second_point:
		_fail("Patrolling enemy did not advance to its second waypoint")
		return
	if patrol_enemy.get_state() != State.PATROL:
		_fail("Enemy with a patrol route should remain in PATROL, got %s" % State.keys()[patrol_enemy.get_state()])
		return

	# Stationary enemy (no patrol route) must stay IDLE indefinitely.
	var stationary_profile := _make_profile("stationary_species", 2.0, 4.0)
	stationary_profile.detection_range = 0.5
	stationary_profile.lose_target_range = 0.5
	var stationary_enemy := _make_enemy(Vector3(50.0, 0.5, 0.0), stationary_profile, &"enemy_stationary")
	for frame_index in range(120):
		await get_tree().physics_frame
	if stationary_enemy.get_state() != State.IDLE:
		_fail("Stationary enemy without a patrol route must stay IDLE, got %s" % State.keys()[stationary_enemy.get_state()])
		return
	var stationary_flat_drift := Vector2(
		stationary_enemy.global_position.x, stationary_enemy.global_position.z
	).distance_to(Vector2(50.0, 0.0))
	if stationary_flat_drift > 0.1:
		_fail("Stationary enemy must not drift from its spawn position")
		return

	print("PATROL_OK waypoint advancement and stationary-enemy behavior verified")
	patrol_enemy.queue_free()
	stationary_enemy.queue_free()
	patrol_route.queue_free()
	await get_tree().physics_frame

	# --- DETECTION: view cone rejects a target outside the facing angle ---
	var cone_profile := _make_profile("cone_species", 2.0, 4.0)
	cone_profile.detection_range = 10.0
	cone_profile.lose_target_range = 12.0
	cone_profile.detection_angle_degrees = 60.0
	var cone_enemy := _make_enemy(Vector3(0.0, 0.5, 30.0), cone_profile, &"enemy_cone")
	cone_enemy._last_move_direction = Vector3(0.0, 0.0, -1.0)  # facing -Z
	player.global_position = Vector3(6.0, 0.5, 30.0)  # roughly 90 degrees to the side
	for frame_index in range(10):
		await get_tree().physics_frame
	if cone_enemy.get_state() != State.IDLE:
		_fail("Enemy must ignore a target outside its detection cone, got %s" % State.keys()[cone_enemy.get_state()])
		return
	player.global_position = Vector3(0.0, 0.5, 25.0)  # directly in front
	for frame_index in range(10):
		await get_tree().physics_frame
	if cone_enemy.get_state() == State.IDLE:
		_fail("Enemy must detect a target directly in front within its cone")
		return

	print("DETECTION_CONE_OK outside-cone rejection and in-cone detection verified")
	cone_enemy.queue_free()
	player.global_position = Vector3(0.0, 0.5, 0.0)
	await get_tree().physics_frame

	# --- EXPLORATION ATTACK REACTION: player-advantage + attackable group ---
	var attack_profile := _make_profile("attack_species", 2.0, 4.0)
	var attack_enemy := _make_enemy(Vector3(0.0, 0.5, -1.0), attack_profile, &"enemy_attacked")
	if not attack_enemy.is_in_group(&"exploration_attackable"):
		_fail("Enemy with exploration_attackable=true must join the exploration_attackable group")
		return
	await get_tree().physics_frame

	var field_hits := []
	attack_enemy.enemy_field_hit.connect(func(e, attacker): field_hits.append(attacker))
	var contexts_before_attack := all_requested_contexts.size()

	player.global_position = Vector3(0.0, 0.5, 0.5)
	for frame_index in range(6):
		await get_tree().physics_frame
	if not player.call("try_exploration_attack"):
		_fail("Player exploration attack did not fire against the nearby enemy")
		return
	for frame_index in range(3):
		await get_tree().physics_frame

	if field_hits.is_empty():
		_fail("Enemy did not receive the exploration attack field-hit reaction")
		return
	if attack_enemy.get_state() != State.ENGAGE:
		_fail("A hit, previously-unaware enemy must enter ENGAGE")
		return
	if all_requested_contexts.size() != contexts_before_attack + 1:
		_fail("Field-hit engage must request exactly one new encounter")
		return
	var advantage_context: EncounterContext = all_requested_contexts[all_requested_contexts.size() - 1]
	if advantage_context.opening_advantage != Advantage.PLAYER_ADVANTAGE:
		_fail("Player-initiated hit on an unaware enemy must produce PLAYER_ADVANTAGE")
		return

	print("EXPLORATION_ATTACK_REACTION_OK field hit, engage, and PLAYER_ADVANTAGE verified")
	EncounterCoordinator.resolve_active_encounter(&"escape")
	await get_tree().physics_frame
	attack_enemy.queue_free()
	await get_tree().physics_frame

	# --- GAME FLOW GATING: non-exploration contexts freeze the enemy ---
	var gating_profile := _make_profile("gating_species", 2.0, 4.0)
	gating_profile.detection_range = 30.0
	gating_profile.lose_target_range = 40.0
	gating_profile.alert_delay = 0.05
	var gating_enemy := _make_enemy(Vector3(2.0, 0.5, 0.0), gating_profile, &"enemy_gated")
	player.global_position = Vector3(0.0, 0.5, 0.0)

	for context_name in ["STORY", "CUTSCENE", "BATTLE"]:
		GameFlowState.set_context(GameFlowState.InputContext[context_name])
		var state_before := gating_enemy.get_state()
		for frame_index in range(20):
			await get_tree().physics_frame
		if gating_enemy.get_state() != state_before:
			_fail("Enemy AI must not progress during %s context" % context_name)
			return

	GameFlowState.set_context(GameFlowState.InputContext.EXPLORATION)
	for frame_index in range(20):
		await get_tree().physics_frame
	if gating_enemy.get_state() == State.IDLE:
		_fail("Enemy AI must resume once EXPLORATION context returns")
		return

	print("FLOW_GATING_OK story/cutscene/battle freeze and exploration resume verified")
	gating_enemy.queue_free()
	await get_tree().physics_frame

	# --- PROTAGONIST-AGNOSTIC: enemy targets whatever GameFlowState reports active ---
	var generic_character := _make_character(Vector3(100.0, 0.5, 100.0))
	generic_character.name = "GenericProtagonistStandIn"
	GameFlowState.set_active_character(generic_character)
	var agnostic_profile := _make_profile("agnostic_species", 2.0, 4.0)
	agnostic_profile.detection_range = 6.0
	agnostic_profile.lose_target_range = 8.0
	var agnostic_enemy := _make_enemy(Vector3(101.0, 0.5, 100.0), agnostic_profile, &"enemy_agnostic")
	for frame_index in range(10):
		await get_tree().physics_frame
	if agnostic_enemy.get_state() != State.ALERT and agnostic_enemy.get_state() != State.CHASE:
		_fail("Enemy did not detect a differently-named active character (protagonist coupling suspected)")
		return

	print("PROTAGONIST_AGNOSTIC_OK enemy detected a generic active character with no name dependency")
	agnostic_enemy.queue_free()
	generic_character.queue_free()

	# --- REUSABILITY: same controller class, two different profiles already exercised above ---
	print(
		"REUSABILITY_OK ExplorationEnemy3D instantiated with %d distinct profiles across this test"
		% 8
	)

	print("EXPLORATION_ENEMY_ALL_OK")
	get_tree().quit(0)


func _make_character(position: Vector3) -> ExplorationCharacterController3D:
	var character := ExplorationCharacterController3D.new()
	character.name = "TestCharacter_%d" % randi()
	var capsule_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	capsule_shape.shape = capsule
	character.add_child(capsule_shape)
	var visual := AnimatedSprite3D.new()
	visual.name = "CharacterVisual"
	character.add_child(visual)
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	shadow.mesh = QuadMesh.new()
	character.add_child(shadow)
	character.position = position
	add_child(character)
	character.set_physics_process(false)
	return character


func _make_profile(id: String, patrol_speed: float, chase_speed: float) -> ExplorationEnemyProfile:
	var profile := ExplorationEnemyProfile.new()
	profile.enemy_id = StringName(id)
	profile.display_name = id
	profile.battle_enemy_id = StringName(id)
	profile.patrol_speed = patrol_speed
	profile.chase_speed = chase_speed
	profile.acceleration = 14.0
	profile.detection_range = 8.0
	profile.lose_target_range = 12.0
	profile.detection_angle_degrees = 360.0
	profile.alert_delay = 0.2
	profile.engage_range = 1.2
	profile.leash_distance = 14.0
	profile.return_tolerance = 0.75
	profile.exploration_attackable = true
	profile.player_attack_opening_advantage_allowed = true
	return profile


func _make_enemy(position: Vector3, profile: ExplorationEnemyProfile, actor_id: StringName) -> ExplorationEnemy3D:
	var enemy := ExplorationEnemy3D.new()
	enemy.profile = profile
	enemy.world_actor_id = actor_id
	var capsule_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	capsule_shape.shape = capsule
	enemy.add_child(capsule_shape)
	enemy.position = position
	add_child(enemy)
	return enemy


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
