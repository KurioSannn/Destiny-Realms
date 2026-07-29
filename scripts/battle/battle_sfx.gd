extends Node
class_name BattleSfx

const ENEMY_IMPACT_WIND_VOLUME_SCALE: float = 0.55
const OCTAGRAM_CHIME_DURATION: float = 0.8
const OCTAGRAM_CHIME_VOLUME: float = 0.46
const SFX_SAMPLE_RATE: float = 22050.0
const BASIC_SFX_START_HZ: float = 520.0
const BASIC_SFX_END_HZ: float = 180.0
const BASIC_SFX_DURATION: float = 0.24
const BASIC_SFX_VOLUME: float = 0.38
const BASIC_SFX_SHIMMER_MIX: float = 0.08
const BASIC_SFX_SUB_MIX: float = 0.2
const BASIC_SFX_NOISE_MIX: float = 0.26
const BASIC_SFX_CRYSTAL_MIX: float = 0.62
const ULTIMATE_ZOOM_WIND_DURATION: float = 0.55
const ULTIMATE_ZOOM_WIND_VOLUME: float = 0.52
const ULTIMATE_ZOOM_OUT_WIND_DURATION: float = 0.42
const ULTIMATE_SHATTER_DURATION: float = 0.78
const ULTIMATE_SHATTER_VOLUME: float = 1.1
const ULTIMATE_HIT_SFX_DURATION: float = 0.74
const ULTIMATE_HIT_SFX_VOLUME: float = 1.08
const ULTIMATE_CHARGE_RUMBLE_DURATION: float = 0.82
const ULTIMATE_CHARGE_RUMBLE_VOLUME: float = 0.78
const ULTIMATE_GLASS_BURST_DURATION: float = 0.56
const ULTIMATE_GLASS_BURST_VOLUME: float = 0.82
const ULTIMATE_DEEP_BOOM_DURATION: float = 0.88
const ULTIMATE_DEEP_BOOM_VOLUME: float = 0.96
const ULTIMATE_CRING_NOISE_DURATION: float = 0.62
const ULTIMATE_CRING_NOISE_VOLUME: float = 0.74
const SKILL_SFX_START_HZ: float = 210.0
const SKILL_SFX_END_HZ: float = 920.0
const IMPACT_SFX_START_HZ: float = 120.0
const IMPACT_SFX_END_HZ: float = 46.0

var basic_sfx_player: AudioStreamPlayer
var skill_sfx_player: AudioStreamPlayer
var impact_sfx_player: AudioStreamPlayer
var cetar_sfx_player: AudioStreamPlayer
var sring_sfx_player: AudioStreamPlayer
var skill_release_sfx_player: AudioStreamPlayer
var rift_crack_sfx_player: AudioStreamPlayer
var ultimate_zoom_sfx_player: AudioStreamPlayer
var ultimate_shatter_sfx_player: AudioStreamPlayer
var octagram_chime_sfx_player: AudioStreamPlayer
var ultimate_charge_sfx_player: AudioStreamPlayer
var ultimate_glass_sfx_player: AudioStreamPlayer
var ultimate_boom_sfx_player: AudioStreamPlayer
var ultimate_cring_sfx_player: AudioStreamPlayer


func setup() -> void:
	basic_sfx_player = _create_generated_sfx_player("RuntimeBasicAttackSfx")
	skill_sfx_player = _create_generated_sfx_player("RuntimeSkillSfx")
	impact_sfx_player = _create_generated_sfx_player("RuntimeImpactSfx")
	cetar_sfx_player = _create_generated_sfx_player("RuntimeCetarSfx")
	sring_sfx_player = _create_generated_sfx_player("RuntimeSringSfx")
	skill_release_sfx_player = _create_generated_sfx_player("RuntimeSkillReleaseSfx")
	rift_crack_sfx_player = _create_generated_sfx_player("RuntimeRiftCrackSfx")
	ultimate_zoom_sfx_player = _create_generated_sfx_player("RuntimeUltimateZoomSfx")
	ultimate_shatter_sfx_player = _create_generated_sfx_player("RuntimeUltimateShatterSfx")
	octagram_chime_sfx_player = _create_generated_sfx_player("RuntimeOctagramChimeSfx")
	ultimate_charge_sfx_player = _create_generated_sfx_player("RuntimeUltimateChargeSfx")
	ultimate_glass_sfx_player = _create_generated_sfx_player("RuntimeUltimateGlassSfx")
	ultimate_boom_sfx_player = _create_generated_sfx_player("RuntimeUltimateBoomSfx")
	ultimate_cring_sfx_player = _create_generated_sfx_player("RuntimeUltimateCringNoiseSfx")


func play_basic() -> void:
	_play_basic_sfx()


func play_skill() -> void:
	_play_skill_sfx()


func play_skill_release() -> void:
	_play_skill_release_sfx()


func play_rift_crack() -> void:
	_play_rift_crack_sfx()


func play_impact() -> void:
	_play_impact_sfx()


func play_ultimate_fvx_step(frame_index: int, keep_visible: bool) -> void:
	_play_ultimate_fvx_step_sfx(frame_index, keep_visible)


func play_ultimate_charge_rumble(intensity: float = 1.0) -> void:
	_play_ultimate_charge_rumble_sfx(intensity)


func play_ultimate_glass_burst(intensity: float = 1.0) -> void:
	_play_ultimate_glass_burst_sfx(intensity)


func play_ultimate_deep_boom(intensity: float = 1.0) -> void:
	_play_ultimate_deep_boom_sfx(intensity)


func play_ultimate_cring_noise(intensity: float = 1.0) -> void:
	_play_ultimate_cring_noise_sfx(intensity)


func play_ultimate_enemy_hit() -> void:
	_play_ultimate_enemy_hit_sfx()


func play_ultimate_zoom() -> void:
	_play_ultimate_zoom_sfx()


func play_ultimate_zoom_out_wind() -> void:
	_play_ultimate_zoom_out_wind_sfx()


func play_enemy_octagram_wind() -> void:
	_play_enemy_octagram_wind_sfx()


func play_octagram_chime() -> void:
	_play_octagram_chime_sfx()


func play_ultimate_shatter() -> void:
	_play_ultimate_shatter_sfx()


func play_sring() -> void:
	_play_sring_sfx()


func play_cetar(hit_index: int) -> void:
	_play_cetar_sfx(hit_index)


func _create_generated_sfx_player(player_name: String) -> AudioStreamPlayer:
	var player_node: AudioStreamPlayer = AudioStreamPlayer.new()
	player_node.name = player_name
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = SFX_SAMPLE_RATE
	stream.buffer_length = 1.25
	player_node.stream = stream
	add_child(player_node)
	return player_node


func _play_basic_sfx() -> void:
	_play_cosmic_basic_sfx()


func _play_skill_sfx() -> void:
	if skill_sfx_player == null:
		return

	skill_sfx_player.stop()
	skill_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = skill_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.36
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var low_phase: float = 0.0
	var rift_phase: float = 0.0
	var shimmer_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var build: float = pow(progress, 0.55)
		var fade: float = minf(progress / 0.04, 1.0) * pow(1.0 - progress * 0.2, 1.2)
		var pulse: float = 0.78 + 0.22 * sin(progress * TAU * 9.0)

		low_phase += TAU * lerpf(58.0, 86.0, build) / SFX_SAMPLE_RATE
		rift_phase += TAU * lerpf(180.0, 520.0, build) / SFX_SAMPLE_RATE
		shimmer_phase += TAU * lerpf(980.0, 2600.0, build) / SFX_SAMPLE_RATE

		var low_rumble: float = sin(low_phase) * 0.42
		var rift_tone: float = (sin(rift_phase) + sin(rift_phase * 1.51) * 0.45) * 0.34
		var cold_shimmer: float = sin(shimmer_phase) * 0.12 * build
		var air: float = randf_range(-1.0, 1.0) * 0.08 * build
		var sample: float = (low_rumble + rift_tone + cold_shimmer + air) * fade * pulse * 0.34
		playback.push_frame(Vector2(sample * 0.95, sample * 1.05))


func _play_skill_release_sfx() -> void:
	if skill_release_sfx_player == null:
		return

	skill_release_sfx_player.stop()
	skill_release_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = skill_release_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.28
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var sweep_phase: float = 0.0
	var blade_phase: float = 0.0
	var sub_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var sweep_progress: float = pow(progress, 0.38)
		var attack: float = minf(progress / 0.018, 1.0)
		var tail: float = pow(1.0 - progress, 1.85)
		var envelope: float = attack * tail
		var transient: float = pow(maxf(1.0 - progress * 9.5, 0.0), 2.0)

		sweep_phase += TAU * lerpf(420.0, 4200.0, sweep_progress) / SFX_SAMPLE_RATE
		blade_phase += TAU * lerpf(1500.0, 5200.0, sweep_progress) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(92.0, 48.0, progress) / SFX_SAMPLE_RATE

		var rift_sweep: float = (sin(sweep_phase) + sin(sweep_phase * 1.33) * 0.35) * envelope * 0.42
		var high_blade: float = sin(blade_phase) * envelope * 0.22
		var sub_drop: float = sin(sub_phase) * pow(1.0 - progress, 2.4) * 0.28
		var burst_air: float = randf_range(-1.0, 1.0) * (0.32 * transient + 0.08 * envelope)
		var sample: float = (rift_sweep + high_blade + sub_drop + burst_air) * 0.44
		var pan: float = lerpf(-0.16, 0.18, progress)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_rift_crack_sfx() -> void:
	if rift_crack_sfx_player == null:
		return

	rift_crack_sfx_player.stop()
	rift_crack_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = rift_crack_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.24
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var crack_phase_a: float = 0.0
	var crack_phase_b: float = 0.0
	var crack_phase_c: float = 0.0
	var sub_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var attack: float = minf(progress / 0.006, 1.0)
		var tail: float = pow(1.0 - progress, 2.45)
		var envelope: float = attack * tail
		var first_crack: float = pow(maxf(1.0 - progress * 15.0, 0.0), 2.0)
		var second_crack: float = pow(maxf(1.0 - absf(progress - 0.32) * 12.0, 0.0), 2.0) * 0.72
		var crack_gate: float = maxf(first_crack, second_crack)

		crack_phase_a += TAU * lerpf(3400.0, 920.0, progress) / SFX_SAMPLE_RATE
		crack_phase_b += TAU * lerpf(4700.0, 1300.0, progress) / SFX_SAMPLE_RATE
		crack_phase_c += TAU * lerpf(1600.0, 520.0, progress) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(68.0, 34.0, progress) / SFX_SAMPLE_RATE

		var rift_crack: float = (
			sin(crack_phase_a) * 0.28 +
			sin(crack_phase_b) * 0.21 +
			sin(crack_phase_c) * 0.26
		) * crack_gate
		var tear_noise: float = randf_range(-1.0, 1.0) * (0.55 * crack_gate + 0.12 * envelope)
		var sub_hit: float = sin(sub_phase) * envelope * 0.45
		var sample: float = (rift_crack + tear_noise + sub_hit) * 0.46
		var pan: float = randf_range(-0.08, 0.08)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_impact_sfx() -> void:
	_play_generated_sfx(impact_sfx_player, IMPACT_SFX_START_HZ, IMPACT_SFX_END_HZ, 0.24, 0.55, 0.28)


func _play_ultimate_fvx_step_sfx(frame_index: int, keep_visible: bool) -> void:
	var intensity: float = 0.42 + float(frame_index) * 0.18
	if keep_visible:
		intensity = 0.95
	_play_ultimate_glass_burst_sfx(intensity)
	_play_ultimate_deep_boom_sfx(intensity * 0.58)


func _play_ultimate_charge_rumble_sfx(intensity: float = 1.0) -> void:
	if ultimate_charge_sfx_player == null:
		return

	ultimate_charge_sfx_player.stop()
	ultimate_charge_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_charge_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_CHARGE_RUMBLE_DURATION)
	var sub_phase: float = 0.0
	var pulse_phase: float = 0.0
	var shimmer_phase: float = 0.0
	var noise_low: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var build: float = pow(progress, 0.62)
		var attack: float = minf(progress / 0.12, 1.0)
		var tail: float = pow(maxf(1.0 - progress * 0.16, 0.0), 0.8)
		var envelope: float = attack * tail

		sub_phase += TAU * lerpf(36.0, 72.0, build) / SFX_SAMPLE_RATE
		pulse_phase += TAU * lerpf(96.0, 164.0, build) / SFX_SAMPLE_RATE
		shimmer_phase += TAU * lerpf(880.0, 3600.0, build) / SFX_SAMPLE_RATE
		noise_low = lerpf(noise_low, randf_range(-1.0, 1.0), 0.09)

		var sub: float = sin(sub_phase) * (0.62 + build * 0.28)
		var pulse: float = sin(pulse_phase) * (0.28 + 0.18 * sin(progress * TAU * 7.0))
		var shimmer: float = sin(shimmer_phase) * build * 0.12
		var air: float = noise_low * (0.18 + build * 0.24)
		var raw_sample: float = (sub + pulse + shimmer + air) * envelope * ULTIMATE_CHARGE_RUMBLE_VOLUME * intensity
		var sample: float = tanh(raw_sample * 1.25) / 1.25
		var pan: float = sin(progress * TAU * 1.1) * 0.12
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_ultimate_glass_burst_sfx(intensity: float = 1.0) -> void:
	if ultimate_glass_sfx_player == null:
		return

	ultimate_glass_sfx_player.stop()
	ultimate_glass_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_glass_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_GLASS_BURST_DURATION)
	var glass_phase_a: float = 0.0
	var glass_phase_b: float = 0.0
	var glass_phase_c: float = 0.0
	var glass_phase_d: float = 0.0
	var noise_smooth: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var snap_gate: float = pow(maxf(1.0 - progress * 48.0, 0.0), 1.7)
		var shard_gate_a: float = pow(maxf(1.0 - absf(progress - 0.12) * 14.0, 0.0), 2.0)
		var shard_gate_b: float = pow(maxf(1.0 - absf(progress - 0.28) * 10.0, 0.0), 2.0) * 0.72
		var shard_gate_c: float = pow(maxf(1.0 - absf(progress - 0.48) * 7.0, 0.0), 2.0) * 0.44
		var tail: float = pow(maxf(1.0 - progress, 0.0), 2.05)
		var shard_gate: float = maxf(snap_gate, maxf(shard_gate_a, maxf(shard_gate_b, shard_gate_c)))

		glass_phase_a += TAU * lerpf(9200.0, 3200.0, progress) / SFX_SAMPLE_RATE
		glass_phase_b += TAU * lerpf(6800.0, 2500.0, progress) / SFX_SAMPLE_RATE
		glass_phase_c += TAU * lerpf(5200.0, 1800.0, progress) / SFX_SAMPLE_RATE
		glass_phase_d += TAU * lerpf(3600.0, 1200.0, progress) / SFX_SAMPLE_RATE
		noise_smooth = lerpf(noise_smooth, randf_range(-1.0, 1.0), 0.36)

		var glass_tone: float = (
			sin(glass_phase_a) * 0.34 +
			sin(glass_phase_b) * 0.27 +
			sin(glass_phase_c) * 0.2 +
			sin(glass_phase_d) * 0.14
		)
		var snap: float = randf_range(-1.0, 1.0) * snap_gate * 1.35
		var shard_click: float = randf_range(-1.0, 1.0) * shard_gate * randf_range(0.2, 1.0)
		var crushed_noise: float = floor(noise_smooth * 14.0) / 14.0
		var shard_noise: float = (crushed_noise * 0.72 + shard_click * 0.46) * (shard_gate * 0.96 + tail * 0.16)
		var sparkle: float = glass_tone * (shard_gate * 0.86 + tail * 0.24)
		var raw_sample: float = (snap + shard_noise + sparkle) * ULTIMATE_GLASS_BURST_VOLUME * intensity
		var sample: float = clampf(tanh(raw_sample * 1.95) / 1.62, -0.82, 0.82)
		var pan: float = sin(progress * TAU * 3.2) * 0.24 + randf_range(-0.08, 0.08) * shard_gate
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_ultimate_deep_boom_sfx(intensity: float = 1.0) -> void:
	if ultimate_boom_sfx_player == null:
		return

	ultimate_boom_sfx_player.stop()
	ultimate_boom_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_boom_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_DEEP_BOOM_DURATION)
	var sub_phase: float = 0.0
	var body_phase: float = 0.0
	var pressure_noise: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var attack: float = minf(progress / 0.018, 1.0)
		var tail: float = pow(maxf(1.0 - progress, 0.0), 1.85)
		var envelope: float = attack * tail
		var punch_gate: float = pow(maxf(1.0 - progress * 9.0, 0.0), 1.45)
		var second_gate: float = pow(maxf(1.0 - absf(progress - 0.19) * 5.4, 0.0), 1.8) * 0.58

		sub_phase += TAU * lerpf(58.0, 24.0, pow(progress, 0.7)) / SFX_SAMPLE_RATE
		body_phase += TAU * lerpf(132.0, 42.0, progress) / SFX_SAMPLE_RATE
		pressure_noise = lerpf(pressure_noise, randf_range(-1.0, 1.0), 0.12)

		var sub: float = sin(sub_phase) * (punch_gate * 1.15 + second_gate * 0.85 + envelope * 0.2)
		var body: float = sin(body_phase) * (punch_gate * 0.55 + second_gate * 0.4)
		var pressure: float = pressure_noise * envelope * 0.24
		var raw_sample: float = (sub + body + pressure) * ULTIMATE_DEEP_BOOM_VOLUME * intensity
		var sample: float = tanh(raw_sample * 1.45) / 1.45
		playback.push_frame(Vector2(sample, sample))


func _play_ultimate_cring_noise_sfx(intensity: float = 1.0) -> void:
	if ultimate_cring_sfx_player == null:
		return

	ultimate_cring_sfx_player.stop()
	ultimate_cring_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_cring_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_CRING_NOISE_DURATION)
	var scrape_phase_a: float = 0.0
	var scrape_phase_b: float = 0.0
	var ring_phase: float = 0.0
	var harsh_noise: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var tail: float = pow(maxf(1.0 - progress, 0.0), 1.7)
		var snap_gate: float = pow(maxf(1.0 - progress * 36.0, 0.0), 1.4)
		var scrape_gate: float = maxf(
			pow(maxf(1.0 - absf(progress - 0.1) * 10.0, 0.0), 2.0),
			pow(maxf(1.0 - absf(progress - 0.31) * 7.5, 0.0), 2.0) * 0.72
		)

		scrape_phase_a += TAU * lerpf(10600.0, 2800.0, progress) / SFX_SAMPLE_RATE
		scrape_phase_b += TAU * lerpf(7900.0, 2100.0, pow(progress, 0.72)) / SFX_SAMPLE_RATE
		ring_phase += TAU * lerpf(4800.0, 900.0, progress) / SFX_SAMPLE_RATE
		harsh_noise = lerpf(harsh_noise, randf_range(-1.0, 1.0), 0.64)

		var bitcrush_rate: float = 18.0
		var crushed_noise: float = floor(harsh_noise * bitcrush_rate) / bitcrush_rate
		var scrape: float = (sin(scrape_phase_a) * 0.42 + sin(scrape_phase_b) * 0.34) * (scrape_gate + tail * 0.18)
		var ring: float = sin(ring_phase) * (scrape_gate * 0.28 + tail * 0.12)
		var crack: float = randf_range(-1.0, 1.0) * snap_gate * 1.18
		var static_spray: float = crushed_noise * (scrape_gate * 0.9 + tail * 0.22)
		var raw_sample: float = (scrape + ring + crack + static_spray) * ULTIMATE_CRING_NOISE_VOLUME * intensity
		var sample: float = clampf(raw_sample, -0.82, 0.82)
		var pan: float = sin(progress * TAU * 5.0) * 0.26 + randf_range(-0.12, 0.12) * (snap_gate + scrape_gate)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_ultimate_enemy_hit_sfx() -> void:
	if impact_sfx_player == null:
		return

	impact_sfx_player.stop()
	impact_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = impact_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_HIT_SFX_DURATION)
	var sub_phase: float = 0.0
	var boom_phase: float = 0.0
	var metal_phase: float = 0.0
	var cring_phase: float = 0.0
	var glass_phase_a: float = 0.0
	var glass_phase_b: float = 0.0
	var glass_phase_c: float = 0.0
	var air_low: float = 0.0
	var air_high: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var attack: float = minf(progress / 0.008, 1.0)
		var tail: float = pow(maxf(1.0 - progress, 0.0), 1.45)
		var envelope: float = attack * tail
		var snap_gate: float = pow(maxf(1.0 - progress * 42.0, 0.0), 2.0)
		var first_boom_gate: float = pow(maxf(1.0 - absf(progress - 0.055) * 8.0, 0.0), 2.0)
		var second_boom_gate: float = pow(maxf(1.0 - absf(progress - 0.18) * 6.5, 0.0), 2.0) * 0.78
		var crunch_gate: float = pow(maxf(1.0 - absf(progress - 0.075) * 13.0, 0.0), 2.0)
		var glass_gate: float = maxf(
			pow(maxf(1.0 - absf(progress - 0.12) * 10.0, 0.0), 2.0),
			pow(maxf(1.0 - absf(progress - 0.34) * 7.0, 0.0), 2.0) * 0.58
		)
		var sparkle_tail: float = pow(maxf(1.0 - progress, 0.0), 2.4)

		sub_phase += TAU * lerpf(62.0, 24.0, pow(progress, 0.55)) / SFX_SAMPLE_RATE
		boom_phase += TAU * lerpf(118.0, 38.0, progress) / SFX_SAMPLE_RATE
		metal_phase += TAU * lerpf(980.0, 210.0, pow(progress, 0.42)) / SFX_SAMPLE_RATE
		cring_phase += TAU * lerpf(6900.0, 1200.0, pow(progress, 0.58)) / SFX_SAMPLE_RATE
		glass_phase_a += TAU * lerpf(7600.0, 3100.0, progress) / SFX_SAMPLE_RATE
		glass_phase_b += TAU * lerpf(5400.0, 2400.0, progress) / SFX_SAMPLE_RATE
		glass_phase_c += TAU * lerpf(3900.0, 1500.0, progress) / SFX_SAMPLE_RATE

		var raw_noise: float = randf_range(-1.0, 1.0)
		air_low = lerpf(air_low, raw_noise, 0.18)
		air_high = lerpf(air_high, raw_noise - air_low, 0.42)

		var snap: float = randf_range(-1.0, 1.0) * snap_gate * 1.25
		var sub_drop: float = sin(sub_phase) * (first_boom_gate * 1.35 + second_boom_gate * 0.86 + envelope * 0.16)
		var boom_body: float = sin(boom_phase) * (first_boom_gate * 0.72 + second_boom_gate * 0.55)
		var metal_slam: float = sin(metal_phase) * envelope * 0.28
		var cring: float = sin(cring_phase) * (crunch_gate * 0.48 + glass_gate * 0.22)
		var glass: float = (
			sin(glass_phase_a) * 0.34 +
			sin(glass_phase_b) * 0.24 +
			sin(glass_phase_c) * 0.18
		) * (glass_gate + sparkle_tail * 0.16)
		var click: float = randf_range(-1.0, 1.0) * crunch_gate * 0.82
		var bitcrush: float = floor((air_high + air_low) * 12.0) / 12.0
		var crackle: float = (bitcrush * 0.92 + air_high * 0.4) * (snap_gate * 0.82 + glass_gate * 0.68 + envelope * 0.16)
		var wind_after: float = air_low * envelope * 0.22

		var raw_sample: float = (snap + sub_drop + boom_body + metal_slam + cring + glass + click + crackle + wind_after) * ULTIMATE_HIT_SFX_VOLUME
		var sample: float = clampf(tanh(raw_sample * 2.15) / 1.72, -0.86, 0.86)
		var pan: float = sin(progress * TAU * 2.15) * 0.18 + randf_range(-0.04, 0.04) * (snap_gate + glass_gate)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_ultimate_zoom_sfx() -> void:
	_play_filtered_wind_sfx(ultimate_zoom_sfx_player, ULTIMATE_ZOOM_WIND_DURATION, 350.0, 2000.0, 0.65, -0.18, 0.18, 1.0)


func _play_ultimate_zoom_out_wind_sfx() -> void:
	_play_filtered_wind_sfx(ultimate_zoom_sfx_player, ULTIMATE_ZOOM_OUT_WIND_DURATION, 2000.0, 350.0, 0.7, 0.18, -0.18, 1.0)


func _play_enemy_octagram_wind_sfx() -> void:
	_play_filtered_wind_sfx(ultimate_zoom_sfx_player, ULTIMATE_ZOOM_WIND_DURATION, 350.0, 2000.0, 0.65, -0.18, 0.18, ENEMY_IMPACT_WIND_VOLUME_SCALE)


func _play_filtered_wind_sfx(player_node: AudioStreamPlayer, duration: float, start_cutoff_hz: float, end_cutoff_hz: float, sweep_curve: float, pan_start: float, pan_end: float, volume_scale: float = 1.0) -> void:
	if player_node == null:
		return

	player_node.stop()
	player_node.play()
	var playback: AudioStreamGeneratorPlayback = player_node.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var low_cutoff_hz: float = 140.0
	var lp_fast: float = 0.0
	var lp_slow: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var attack: float = minf(progress / 0.22, 1.0)
		attack = attack * attack
		var tail: float = pow(1.0 - progress, 1.15)
		var envelope: float = attack * tail

		var fast_cutoff_hz: float = lerpf(start_cutoff_hz, end_cutoff_hz, pow(progress, sweep_curve))
		var fast_alpha: float = 1.0 - exp(-TAU * fast_cutoff_hz / SFX_SAMPLE_RATE)
		var slow_alpha: float = 1.0 - exp(-TAU * low_cutoff_hz / SFX_SAMPLE_RATE)

		var raw_noise: float = randf_range(-1.0, 1.0)
		lp_fast += fast_alpha * (raw_noise - lp_fast)
		lp_slow += slow_alpha * (raw_noise - lp_slow)

		var whoosh: float = (lp_fast - lp_slow) * 1.5
		var flutter: float = 0.88 + 0.12 * sin(progress * TAU * 9.0)
		var sample: float = whoosh * envelope * flutter * ULTIMATE_ZOOM_WIND_VOLUME * volume_scale
		var pan: float = lerpf(pan_start, pan_end, progress)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_octagram_chime_sfx() -> void:
	if octagram_chime_sfx_player == null:
		return

	octagram_chime_sfx_player.stop()
	octagram_chime_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = octagram_chime_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * OCTAGRAM_CHIME_DURATION)
	var phase_a: float = 0.0
	var phase_b: float = 0.0
	var phase_c: float = 0.0
	var phase_d: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var attack: float = minf(progress / 0.012, 1.0)
		var decay: float = pow(1.0 - progress, 1.5)
		var envelope: float = attack * decay

		phase_a += TAU * 2650.0 / SFX_SAMPLE_RATE
		phase_b += TAU * 3480.0 / SFX_SAMPLE_RATE
		phase_c += TAU * 4180.0 / SFX_SAMPLE_RATE
		phase_d += TAU * 5240.0 / SFX_SAMPLE_RATE

		var bell: float = (
			sin(phase_a) * 0.34 +
			sin(phase_b) * 0.26 +
			sin(phase_c) * 0.2 +
			sin(phase_d) * 0.14
		)
		var shimmer: float = 0.86 + 0.14 * sin(progress * TAU * 7.0)
		var sample: float = bell * envelope * shimmer * OCTAGRAM_CHIME_VOLUME
		playback.push_frame(Vector2(sample, sample))


func _play_ultimate_shatter_sfx() -> void:
	if ultimate_shatter_sfx_player == null:
		return

	ultimate_shatter_sfx_player.stop()
	ultimate_shatter_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = ultimate_shatter_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * ULTIMATE_SHATTER_DURATION)
	var glass_phase_a: float = 0.0
	var glass_phase_b: float = 0.0
	var glass_phase_c: float = 0.0
	var glass_phase_d: float = 0.0
	var cring_phase: float = 0.0
	var sub_phase: float = 0.0
	var smoothed_noise: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))

		var initial_crack: float = pow(maxf(1.0 - progress * 18.0, 0.0), 2.4)
		var second_crack: float = pow(maxf(1.0 - absf(progress - 0.16) * 18.0, 0.0), 2.2)
		var third_crack: float = pow(maxf(1.0 - absf(progress - 0.31) * 15.0, 0.0), 2.0)
		var sparkle_tail: float = pow(maxf(1.0 - progress, 0.0), 1.45)
		var crack_gate: float = maxf(initial_crack, maxf(second_crack * 0.82, third_crack * 0.62))

		glass_phase_a += TAU * lerpf(7200.0, 3900.0, progress) / SFX_SAMPLE_RATE
		glass_phase_b += TAU * lerpf(5600.0, 2800.0, progress) / SFX_SAMPLE_RATE
		glass_phase_c += TAU * lerpf(4200.0, 2200.0, progress) / SFX_SAMPLE_RATE
		glass_phase_d += TAU * lerpf(3100.0, 1550.0, progress) / SFX_SAMPLE_RATE
		cring_phase += TAU * lerpf(8800.0, 3600.0, pow(progress, 0.72)) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(78.0, 26.0, progress) / SFX_SAMPLE_RATE

		smoothed_noise = lerpf(smoothed_noise, randf_range(-1.0, 1.0), 0.34)
		var snap_noise: float = randf_range(-1.0, 1.0)

		var glass_tone: float = (
			sin(glass_phase_a) * 0.28 +
			sin(glass_phase_b) * 0.22 +
			sin(glass_phase_c) * 0.18 +
			sin(glass_phase_d) * 0.14
		)
		var cring_gate: float = pow(maxf(1.0 - absf(progress - 0.23) * 7.0, 0.0), 2.0)
		var cring_tail: float = pow(maxf(1.0 - absf(progress - 0.46) * 4.2, 0.0), 2.0) * 0.55
		var cring: float = sin(cring_phase) * (cring_gate + cring_tail) * 0.20
		var crack_noise: float = smoothed_noise * (crack_gate * 0.86 + sparkle_tail * 0.16)
		var sparkle: float = glass_tone * (crack_gate * 0.75 + sparkle_tail * 0.28)
		var snap_gate: float = pow(maxf(1.0 - progress * 55.0, 0.0), 1.6)
		var snap: float = snap_noise * snap_gate * 1.1
		var boom_one_gate: float = pow(maxf(1.0 - progress * 3.4, 0.0), 1.5)
		var boom_two_gate: float = pow(maxf(1.0 - absf(progress - 0.17) * 4.6, 0.0), 1.6)
		var boom: float = sin(sub_phase) * (boom_one_gate * 1.1 + boom_two_gate * 0.85)
		var raw_sample: float = (crack_noise + sparkle + cring + boom + snap) * ULTIMATE_SHATTER_VOLUME
		var sample: float = tanh(raw_sample * 1.9) / 1.9
		var pan: float = sin(progress * TAU * 1.7) * 0.16
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_sring_sfx() -> void:
	if sring_sfx_player == null:
		return

	sring_sfx_player.stop()
	sring_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = sring_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.18
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var phase: float = 0.0
	var edge_phase: float = 0.0
	var glass_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var sweep_progress: float = pow(progress, 0.35)
		var current_hz: float = lerpf(6800.0, 920.0, sweep_progress)
		var attack: float = minf(progress / 0.012, 1.0)
		var tail: float = pow(1.0 - progress, 2.35)
		var envelope: float = attack * tail
		var transient: float = pow(maxf(1.0 - progress * 18.0, 0.0), 2.0)

		phase += TAU * current_hz / SFX_SAMPLE_RATE
		edge_phase += TAU * (current_hz * 1.47) / SFX_SAMPLE_RATE
		glass_phase += TAU * lerpf(5200.0, 2100.0, progress) / SFX_SAMPLE_RATE

		var blade: float = (sin(phase) * 0.65 + sin(edge_phase) * 0.28) * envelope
		var glass_ring: float = sin(glass_phase) * envelope * 0.22
		var air: float = randf_range(-1.0, 1.0) * (0.18 * envelope + 0.34 * transient)
		var sample: float = (blade + glass_ring + air) * 0.28
		var pan: float = lerpf(-0.18, 0.22, progress)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_cetar_sfx(hit_index: int) -> void:
	if cetar_sfx_player == null:
		return

	cetar_sfx_player.stop()
	cetar_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = cetar_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration: float = 0.16
	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var pitch_offset: float = float(hit_index) * 180.0
	var glass_phase_a: float = 0.0
	var glass_phase_b: float = 0.0
	var glass_phase_c: float = 0.0
	var sub_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var attack: float = minf(progress / 0.006, 1.0)
		var tail: float = pow(1.0 - progress, 2.8)
		var envelope: float = attack * tail
		var crack_gate: float = pow(maxf(1.0 - progress * 11.0, 0.0), 2.0)
		var shard_gate_a: float = pow(maxf(1.0 - absf(progress - 0.22) * 12.0, 0.0), 2.0)
		var shard_gate_b: float = pow(maxf(1.0 - absf(progress - 0.43) * 10.0, 0.0), 2.0) * 0.75
		var shard_gate: float = maxf(crack_gate, maxf(shard_gate_a, shard_gate_b))

		glass_phase_a += TAU * (5400.0 + pitch_offset) / SFX_SAMPLE_RATE
		glass_phase_b += TAU * (7200.0 + pitch_offset * 0.7) / SFX_SAMPLE_RATE
		glass_phase_c += TAU * (3900.0 + pitch_offset * 0.45) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(118.0, 54.0, progress) / SFX_SAMPLE_RATE

		var glass_ring: float = (
			sin(glass_phase_a) * 0.34 +
			sin(glass_phase_b) * 0.26 +
			sin(glass_phase_c) * 0.22
		) * shard_gate
		var crack_noise: float = randf_range(-1.0, 1.0) * shard_gate * 0.88
		var low_hit: float = sin(sub_phase) * envelope * 0.34
		var sample: float = (glass_ring + crack_noise + low_hit) * 0.36
		var pan: float = -0.08 + float(hit_index) * 0.08
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_cosmic_basic_sfx() -> void:
	if basic_sfx_player == null:
		return

	basic_sfx_player.stop()
	basic_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = basic_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * BASIC_SFX_DURATION)
	var phase: float = 0.0
	var edge_phase: float = 0.0
	var shimmer_phase: float = 0.0
	var crystal_phase_a: float = 0.0
	var crystal_phase_b: float = 0.0
	var crystal_phase_c: float = 0.0
	var sub_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var drop_progress: float = pow(progress, 0.42)
		var current_hz: float = lerpf(BASIC_SFX_START_HZ, BASIC_SFX_END_HZ, drop_progress)
		var attack: float = minf(progress / 0.01, 1.0)
		var tail: float = pow(1.0 - progress, 2.15)
		var envelope: float = attack * tail
		var transient: float = pow(maxf(1.0 - (progress * 16.0), 0.0), 2.0)

		phase += TAU * current_hz / SFX_SAMPLE_RATE
		edge_phase += TAU * (current_hz * 1.72) / SFX_SAMPLE_RATE
		shimmer_phase += TAU * lerpf(2400.0, 780.0, progress) / SFX_SAMPLE_RATE
		crystal_phase_a += TAU * lerpf(5200.0, 2700.0, progress) / SFX_SAMPLE_RATE
		crystal_phase_b += TAU * lerpf(6400.0, 3400.0, progress) / SFX_SAMPLE_RATE
		crystal_phase_c += TAU * lerpf(3800.0, 2100.0, progress) / SFX_SAMPLE_RATE
		sub_phase += TAU * lerpf(82.0, 38.0, progress) / SFX_SAMPLE_RATE

		var core: float = (sin(phase) * 0.58 + sin(edge_phase) * 0.42) * envelope
		var slash_snap: float = randf_range(-1.0, 1.0) * BASIC_SFX_NOISE_MIX * transient * 1.55
		var slash_air: float = randf_range(-1.0, 1.0) * BASIC_SFX_NOISE_MIX * envelope * 0.34
		var shimmer: float = sin(shimmer_phase) * BASIC_SFX_SHIMMER_MIX * pow(maxf(1.0 - absf(progress - 0.28) * 5.0, 0.0), 2.0)
		var crystal_hit: float = pow(maxf(1.0 - absf(progress - 0.42) * 26.0, 0.0), 2.0)
		var crystal_splinter: float = pow(maxf(1.0 - absf(progress - 0.52) * 20.0, 0.0), 2.0) * 0.78
		var crystal_tail: float = pow(maxf(1.0 - absf(progress - 0.66) * 14.0, 0.0), 2.0) * 0.45
		var crystal_gate: float = maxf(crystal_hit, maxf(crystal_splinter, crystal_tail))
		var crystal_ring: float = (
			sin(crystal_phase_a) * 0.35 +
			sin(crystal_phase_b) * 0.28 +
			sin(crystal_phase_c) * 0.22
		) * crystal_gate
		var crystal_noise: float = randf_range(-1.0, 1.0) * crystal_gate * 0.9
		var crystal: float = (crystal_ring + crystal_noise) * BASIC_SFX_CRYSTAL_MIX
		var sub_envelope: float = pow(maxf(1.0 - (progress * 2.4), 0.0), 1.7)
		var sub: float = sin(sub_phase) * sub_envelope * BASIC_SFX_SUB_MIX

		var sample: float = (core + slash_snap + slash_air + shimmer + crystal + sub) * BASIC_SFX_VOLUME
		var pan: float = lerpf(-0.12, 0.16, progress)
		playback.push_frame(Vector2(sample * (1.0 - pan), sample * (1.0 + pan)))


func _play_generated_sfx(player_node: AudioStreamPlayer, start_hz: float, end_hz: float, duration: float, noise_mix: float, volume: float, shimmer_mix: float = 0.0) -> void:
	if player_node == null:
		return

	player_node.stop()
	player_node.play()
	var playback: AudioStreamGeneratorPlayback = player_node.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var sample_count: int = int(SFX_SAMPLE_RATE * duration)
	var phase: float = 0.0
	var shimmer_phase: float = 0.0
	for sample_index in range(sample_count):
		var progress: float = float(sample_index) / float(maxi(sample_count - 1, 1))
		var current_hz: float = lerpf(start_hz, end_hz, progress)
		var envelope: float = pow(1.0 - progress, 2.0)
		phase += TAU * current_hz / SFX_SAMPLE_RATE
		var tone: float = sin(phase)

		var combined_tone: float = tone
		if shimmer_mix > 0.0:
			shimmer_phase += TAU * (current_hz * 2.01) / SFX_SAMPLE_RATE
			var shimmer_tone: float = sin(shimmer_phase)
			var tremolo: float = 0.65 + 0.35 * sin(progress * TAU * 7.0)
			combined_tone = lerpf(tone, shimmer_tone * tremolo, shimmer_mix)

		var noise: float = randf_range(-1.0, 1.0)
		var sample: float = ((combined_tone * (1.0 - noise_mix)) + (noise * noise_mix)) * envelope * volume
		playback.push_frame(Vector2(sample, sample))


