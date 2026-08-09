extends Node

const TEST_TRACK_PATH: String = "res://public/Under_the_Iron_Bough.mp3"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_music_director_immediate_stop()
	await _test_scene_transition_stops_scene_and_global_music()
	print("MUSIC_OVERLAP_GUARD_ALL_OK")
	get_tree().quit(0)


func _test_music_director_immediate_stop() -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director == null:
		_fail("MusicDirector autoload is missing")
		return

	music_director.call("play_track", TEST_TRACK_PATH, -12.0, 0.0)
	await _idle_frames(2)
	if _playing_music_director_channels(music_director) != 1:
		_fail("MusicDirector should have exactly one playing channel after play_track")
		return

	music_director.call("stop_music", 0.0)
	await _idle_frames(1)
	if _playing_music_director_channels(music_director) != 0:
		_fail("MusicDirector stop_music(0.0) must stop all channels immediately")
		return

	print("MUSIC_DIRECTOR_IMMEDIATE_STOP_OK")


func _test_scene_transition_stops_scene_and_global_music() -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	var scene_transition := get_node_or_null("/root/SceneTransition")
	if music_director == null or scene_transition == null:
		_fail("MusicDirector/SceneTransition autoloads are required for overlap guard")
		return

	var previous_scene := get_tree().current_scene
	var fake_scene := Node.new()
	fake_scene.name = "MusicOverlapFakeScene"
	var scene_bgm := AudioStreamPlayer.new()
	scene_bgm.name = "FakeSceneBgm"
	scene_bgm.stream = load(TEST_TRACK_PATH) as AudioStream
	fake_scene.add_child(scene_bgm)
	get_tree().root.add_child(fake_scene)
	get_tree().current_scene = fake_scene

	scene_bgm.play()
	music_director.call("play_track", TEST_TRACK_PATH, -12.0, 0.0)
	await _idle_frames(2)
	if not scene_bgm.playing:
		_fail("Fixture scene BGM did not start")
		return
	if _playing_music_director_channels(music_director) != 1:
		_fail("Fixture global MusicDirector channel did not start")
		return

	scene_transition.call("_stop_active_scene_audio")
	scene_transition.call("_stop_global_music")
	await _idle_frames(1)
	if scene_bgm.playing:
		_fail("SceneTransition must stop active scene BGM before changing scenes")
		return
	if _playing_music_director_channels(music_director) != 0:
		_fail("SceneTransition must stop MusicDirector before changing scenes")
		return

	fake_scene.queue_free()
	get_tree().current_scene = previous_scene
	await _idle_frames(1)
	print("SCENE_TRANSITION_MUSIC_GUARD_OK")


func _playing_music_director_channels(music_director: Node) -> int:
	var count := 0
	for child in music_director.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing:
			count += 1
	return count


func _idle_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
