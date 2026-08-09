extends Node

## Visual QA for the shared actor registry and the Block 15.1 battle staging.
## Captures a real two-enemy Lesser Abyss encounter at the production size.

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")
const OUTPUT_PATH := "res://docs/images/battle_3d_visual_overhaul_1280x720.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("BLOCK15_VISUAL_CAPTURE_START")
	get_window().size = Vector2i(1280, 720)
	if EncounterCoordinator.encounter_requested.is_connected(BattleSessionCoordinator._on_encounter_requested):
		EncounterCoordinator.encounter_requested.disconnect(BattleSessionCoordinator._on_encounter_requested)

	var context := EncounterContext.new()
	context.encounter_id = &"block15_visual_capture"
	context.source_area_id = &"abyss_forest"
	context.source_world_scene = "res://scenes/world_3d/abyss_forest_3d.tscn"
	context.battle_enemy_ids = [&"lesser_abyss", &"lesser_abyss"]
	context.initiating_enemy_id = &"block15_visual_capture_enemy"
	EncounterCoordinator.request_encounter(context)

	var battle := BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	for _frame in range(100):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("BLOCK15_VISUAL_CAPTURE_FRAME_READY")

	var presentation := battle.get_node("BattlePresentation3D") as BattlePresentation3D
	var first_enemy := presentation.get_enemy_actor(0)
	var second_enemy := presentation.get_enemy_actor(1)
	if first_enemy == null or second_enemy == null:
		push_error("Visual capture requires two enemy actors")
		get_tree().quit(1)
		return
	if not first_enemy.uses_model() or not second_enemy.uses_model():
		push_error("Visual capture requires both Lesser Abyss GLTF models")
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/images"))
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("Viewport image is unavailable; run this capture with a rendering display driver")
		get_tree().quit(1)
		return
	var save_error := image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save Block 15 visual capture: %s" % error_string(save_error))
		get_tree().quit(1)
		return

	print("BLOCK15_VISUAL_CAPTURE_OK %s" % OUTPUT_PATH)
	get_tree().quit(0)
