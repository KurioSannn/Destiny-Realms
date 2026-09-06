extends Node
class_name BattleVfx

## Handles runtime visual particle effects, slash projectiles, and screen flash for the battle system.

const EFFECT_SLASH_TEXTURE: Texture2D = preload("res://public/effects/slash.png")
const EFFECT_SPLASH_TEXTURE: Texture2D = preload("res://public/effects/Splash.png")
const EFFECT_PARTICLE_TEXTURE: Texture2D = preload("res://public/effects/Particle Efect.png")

var effect_layer: Node2D
var screen_flash: ColorRect
var battle_scene: Node


func setup(target_effect_layer: Node2D, target_screen_flash: ColorRect, target_battle_scene: Node) -> void:
	effect_layer = target_effect_layer
	screen_flash = target_screen_flash
	battle_scene = target_battle_scene


func spawn_slash_projectile(start_position: Vector2, end_position: Vector2, color: Color, scale_multiplier: float) -> void:
	if effect_layer == null:
		return

	var slash: Sprite2D = Sprite2D.new()
	slash.texture = EFFECT_SLASH_TEXTURE
	slash.flip_h = true
	slash.position = start_position
	slash.rotation = (end_position - start_position).angle()
	slash.modulate = color
	var start_scale: float = 0.07 * scale_multiplier
	slash.scale = Vector2(start_scale, start_scale)
	effect_layer.add_child(slash)

	var end_scale: float = 0.14 * scale_multiplier
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(slash, "position", end_position, 0.16)
	tween.parallel().tween_property(slash, "scale", Vector2(end_scale, end_scale), 0.16)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(slash.queue_free)


func spawn_skill_charge_effect(charge_position: Vector2) -> void:
	if effect_layer == null:
		return

	for index in range(2):
		var particle: Sprite2D = Sprite2D.new()
		particle.texture = EFFECT_PARTICLE_TEXTURE
		particle.position = charge_position
		particle.rotation = float(index) * 0.55
		particle.modulate = Color(0.6, 0.9, 1.0, 0.62 - (float(index) * 0.18))
		particle.scale = Vector2(0.08, 0.08)
		effect_layer.add_child(particle)

		var end_scale: float = 0.16 + (float(index) * 0.04)
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector2(end_scale, end_scale), 0.24)
		tween.parallel().tween_property(particle, "rotation", particle.rotation + 1.1, 0.24)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.24)
		tween.tween_callback(particle.queue_free)


func spawn_triangle_rift_effect(rift_position: Vector2, large: bool) -> void:
	if effect_layer == null:
		return

	var ring_count: int = 3 if large else 2
	for index in range(ring_count):
		var particle: Sprite2D = Sprite2D.new()
		particle.texture = EFFECT_PARTICLE_TEXTURE
		particle.position = rift_position
		particle.rotation = -0.65 + (float(index) * 0.42)
		particle.modulate = Color(0.55, 0.95, 1.0, 0.82 - (float(index) * 0.16))
		particle.scale = Vector2(0.09, 0.09)
		effect_layer.add_child(particle)

		var end_scale: float = 0.2 + (float(index) * 0.05)
		if large:
			end_scale += 0.08
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector2(end_scale, end_scale), 0.22)
		tween.parallel().tween_property(particle, "rotation", particle.rotation + 1.25, 0.22)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.22)
		tween.tween_callback(particle.queue_free)


func spawn_triangle_rift_projectile(start_position: Vector2, end_position: Vector2, duration: float) -> void:
	if effect_layer == null:
		return

	var projectile: Sprite2D = Sprite2D.new()
	projectile.texture = EFFECT_PARTICLE_TEXTURE
	projectile.position = start_position
	projectile.rotation = (end_position - start_position).angle()
	projectile.modulate = Color(0.45, 0.95, 1.0, 0.95)
	projectile.scale = Vector2(0.08, 0.08)
	projectile.z_index = 18
	effect_layer.add_child(projectile)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(projectile, "position", end_position, duration)
	tween.parallel().tween_property(projectile, "scale", Vector2(0.18, 0.18), duration)
	tween.parallel().tween_property(projectile, "rotation", projectile.rotation + 0.8, duration)
	tween.parallel().tween_property(projectile, "modulate:a", 0.0, duration + 0.04)
	tween.tween_callback(projectile.queue_free)


func spawn_triangle_rift_break(impact_position: Vector2, pulse_index: int) -> void:
	if effect_layer == null:
		return

	var burst: Sprite2D = Sprite2D.new()
	burst.texture = EFFECT_PARTICLE_TEXTURE
	burst.position = impact_position
	burst.rotation = randf_range(-0.45, 0.45)
	burst.modulate = Color(0.42, 0.95, 1.0, 0.92)
	burst.scale = Vector2(0.08, 0.08)
	burst.z_index = 19
	effect_layer.add_child(burst)

	var end_scale: float = 0.26 + float(pulse_index) * 0.05
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "scale", Vector2(end_scale, end_scale), 0.10)
	tween.parallel().tween_property(burst, "rotation", burst.rotation + randf_range(-1.4, 1.4), 0.16)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.18)
	tween.tween_callback(burst.queue_free)


func spawn_rift_crack_slashes(impact_position: Vector2, pulse_index: int) -> void:
	if effect_layer == null:
		return

	var slash_count: int = 3
	for index in range(slash_count):
		var slash: Sprite2D = Sprite2D.new()
		slash.texture = EFFECT_SLASH_TEXTURE
		slash.position = impact_position + Vector2(randf_range(-18.0, 18.0), randf_range(-16.0, 12.0))
		slash.rotation = deg_to_rad(randf_range(-58.0, 58.0))
		slash.modulate = Color(0.68, 0.96, 1.0, 0.78)
		slash.scale = Vector2(0.04, 0.04)
		slash.z_index = 20
		effect_layer.add_child(slash)

		var end_scale: float = 0.12 + float(pulse_index) * 0.025
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "scale", Vector2(end_scale, end_scale), 0.08)
		tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.14)
		tween.parallel().tween_property(slash, "rotation", slash.rotation + deg_to_rad(randf_range(-16.0, 16.0)), 0.14)
		tween.tween_callback(slash.queue_free)


func spawn_rift_after_particles(impact_position: Vector2, pulse_index: int) -> void:
	if effect_layer == null:
		return

	var particle_count: int = 9 + pulse_index * 2
	for index in range(particle_count):
		var particle: Sprite2D = Sprite2D.new()
		particle.texture = EFFECT_PARTICLE_TEXTURE
		particle.position = impact_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		particle.rotation = randf_range(-PI, PI)
		particle.modulate = Color(
			randf_range(0.35, 0.7),
			randf_range(0.86, 1.0),
			1.0,
			randf_range(0.58, 0.9)
		)
		var start_scale: float = randf_range(0.03, 0.065)
		particle.scale = Vector2(start_scale, start_scale)
		particle.z_index = 21
		effect_layer.add_child(particle)

		var angle: float = randf_range(-PI, PI)
		var distance: float = randf_range(24.0, 66.0) + float(pulse_index) * 8.0
		var end_position: Vector2 = impact_position + Vector2(cos(angle), sin(angle)) * distance

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", end_position, 0.24)
		tween.parallel().tween_property(particle, "rotation", particle.rotation + randf_range(-2.0, 2.0), 0.24)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.24)
		tween.tween_callback(particle.queue_free)


func spawn_hit_spark(spark_position: Vector2, color: Color) -> void:
	if effect_layer == null:
		return

	var spark: Sprite2D = Sprite2D.new()
	spark.texture = EFFECT_SPLASH_TEXTURE
	spark.position = spark_position
	spark.modulate = color
	spark.scale = Vector2(0.05, 0.05)
	effect_layer.add_child(spark)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.11)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.16)
	tween.tween_callback(spark.queue_free)


func spawn_cetar_slash_cross(center_position: Vector2, burst_index: int) -> void:
	if effect_layer == null:
		return

	var angles: Array[float] = [-0.72, 0.68, -0.08]
	var colors: Array[Color] = [
		Color(1.0, 0.96, 0.68, 0.9),
		Color(0.68, 0.96, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.78)
	]

	for slash_index in range(angles.size()):
		var slash: Sprite2D = Sprite2D.new()
		slash.texture = EFFECT_SLASH_TEXTURE
		slash.flip_h = slash_index % 2 == 0
		slash.position = center_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		slash.rotation = angles[slash_index] + float(burst_index) * 0.14
		slash.modulate = colors[slash_index]
		var start_scale: float = 0.09 + float(burst_index) * 0.012 + float(slash_index) * 0.01
		slash.scale = Vector2(start_scale, start_scale)
		effect_layer.add_child(slash)

		var end_scale: float = start_scale + 0.13
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "scale", Vector2(end_scale, end_scale), 0.11)
		tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.13)
		tween.parallel().tween_property(slash, "position", slash.position + Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)), 0.13)
		tween.tween_callback(slash.queue_free)


func spawn_cetar_triangle_shards(shard_origin: Vector2, burst_index: int) -> void:
	if effect_layer == null:
		return

	var shard_count: int = 7 + burst_index
	for shard_index in range(shard_count):
		var particle: Sprite2D = Sprite2D.new()
		particle.texture = EFFECT_PARTICLE_TEXTURE
		particle.position = shard_origin + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
		particle.rotation = randf_range(-PI, PI)
		particle.modulate = Color(0.78, 0.96, 1.0, 0.78)
		var start_scale: float = randf_range(0.035, 0.055)
		particle.scale = Vector2(start_scale, start_scale)
		effect_layer.add_child(particle)

		var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(-PI, PI))
		var distance: float = randf_range(28.0, 62.0) + float(burst_index) * 6.0
		var end_position: Vector2 = particle.position + direction * distance
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", end_position, 0.18)
		tween.parallel().tween_property(particle, "rotation", particle.rotation + randf_range(-2.4, 2.4), 0.18)
		tween.parallel().tween_property(particle, "scale", Vector2(start_scale * 1.65, start_scale * 1.65), 0.12)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.2)
		tween.tween_callback(particle.queue_free)


func spawn_cetar_text(start_position: Vector2, text_value: String, color: Color, rise_distance: float) -> void:
	if battle_scene == null:
		return

	var label: Label = Label.new()
	label.text = text_value
	label.z_index = 22
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	battle_scene.add_child(label)

	label.position = start_position
	label.rotation = randf_range(-0.12, 0.12)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", start_position + Vector2(randf_range(-8.0, 8.0), -rise_distance), 0.28)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.28)
	tween.tween_callback(label.queue_free)


func play_screen_flash(color: Color, duration: float) -> void:
	if screen_flash == null:
		return

	screen_flash.visible = true
	screen_flash.color = color
	screen_flash.modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(screen_flash, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(self, "hide_screen_flash"))


func hide_screen_flash() -> void:
	if screen_flash != null:
		screen_flash.visible = false
		screen_flash.modulate = Color.WHITE
