extends Node

const SILENT_VOLUME_DB: float = -50.0

var current_track_path: String = ""
var _active_player_index: int = 0
var _players: Array[AudioStreamPlayer] = []
var _fade_tween: Tween


func _ready() -> void:
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicChannel%d" % (index + 1)
		player.finished.connect(_on_music_channel_finished.bind(player))
		add_child(player)
		_players.append(player)


func play_track(
	track_path: String,
	target_volume_db: float = -12.0,
	fade_duration: float = 1.1
) -> void:
	if track_path.is_empty() or not ResourceLoader.exists(track_path):
		push_warning("MusicDirector could not load track: %s" % track_path)
		return

	var active_player := _players[_active_player_index]
	if current_track_path == track_path and active_player.playing:
		if not is_equal_approx(active_player.volume_db, target_volume_db):
			active_player.volume_db = target_volume_db
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	var next_player_index := 1 - _active_player_index
	var next_player := _players[next_player_index]
	next_player.stop()
	next_player.stream = load(track_path) as AudioStream
	next_player.volume_db = SILENT_VOLUME_DB
	next_player.play()

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(next_player, "volume_db", target_volume_db, fade_duration)
	if active_player.playing:
		_fade_tween.tween_property(active_player, "volume_db", SILENT_VOLUME_DB, fade_duration)
		_fade_tween.chain().tween_callback(active_player.stop)

	_active_player_index = next_player_index
	current_track_path = track_path


func stop_music(fade_duration: float = 0.45) -> void:
	current_track_path = ""
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	var playing_channels: Array[AudioStreamPlayer] = []
	for player in _players:
		if player.playing:
			playing_channels.append(player)

	if playing_channels.is_empty():
		return

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for player in playing_channels:
		_fade_tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_duration)
	_fade_tween.chain().tween_callback(_stop_all_channels)


func _stop_all_channels() -> void:
	for player in _players:
		player.stop()


func _on_music_channel_finished(player: AudioStreamPlayer) -> void:
	if (
		not current_track_path.is_empty()
		and player == _players[_active_player_index]
		and player.stream != null
	):
		player.play()
