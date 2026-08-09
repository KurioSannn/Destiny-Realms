extends Node

## Block 14.5 Part I: the exploration HUD's action_two (Basic) / action_one
## (Skill) icons previously only printed a debug line when clicked -- this
## verifies AbyssForest3D._on_hud_slot_pressed() now actually drives
## ExplorationCharacterController3D.try_exploration_attack()/
## try_exploration_skill(), and that the HUD's ready-state mirrors real
## controller cooldown/enabled state each frame.

const ABYSS_FOREST_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var forest := ABYSS_FOREST_SCENE.instantiate() as AbyssForest3D
	add_child(forest)
	await _idle_frames(4)

	var player := forest.player
	var hud: HudExplorPlaceholder = forest.hud_explor

	var attack_fired := []
	player.exploration_attack_used.connect(func(): attack_fired.append(true))
	var skill_fired := []
	player.exploration_skill_used.connect(func(): skill_fired.append(true))

	# --- Basic: action_two drives try_exploration_attack() ---
	forest.call("_on_hud_slot_pressed", &"action_two")
	if attack_fired.is_empty():
		_fail("Clicking the exploration HUD's action_two slot did not fire exploration_attack_used")
		return
	print("EXPLORATION_HUD_BASIC_OK action_two drives try_exploration_attack()")

	# --- Skill: action_one drives try_exploration_skill() ---
	forest.call("_on_hud_slot_pressed", &"action_one")
	if skill_fired.is_empty():
		_fail("Clicking the exploration HUD's action_one slot did not fire exploration_skill_used")
		return
	print("EXPLORATION_HUD_SKILL_OK action_one drives try_exploration_skill()")

	# --- Ready-state mirrors real cooldown: both just fired, so both must
	# now read as not-ready until their cooldowns elapse ---
	await _idle_frames(2)
	if hud.basic_action_ready:
		_fail("HUD must reflect Basic Attack being on cooldown right after use")
		return
	if hud.skill_action_ready:
		_fail("HUD must reflect Skill being on cooldown right after use")
		return
	print("EXPLORATION_HUD_COOLDOWN_REFLECTED_OK basic_action_ready/skill_action_ready mirror real cooldown state")

	# --- Unrelated slots are untouched (still just the debug fallback path,
	# not routed into exploration actions) ---
	var attack_count_before := attack_fired.size()
	var skill_count_before := skill_fired.size()
	forest.call("_on_hud_slot_pressed", &"inventory")
	if attack_fired.size() != attack_count_before or skill_fired.size() != skill_count_before:
		_fail("An unrelated HUD slot (inventory) must not trigger exploration actions")
		return

	print("EXPLORATION_HUD_ACTIONS_ALL_OK")
	get_tree().quit(0)


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
