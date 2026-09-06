extends RefCounted
class_name BattleStageLayout

## BattleStageLayout
## Manages 2D stage layout, background scaling, procedural scenery polygons,
## actor home placements, and ground shadows.

const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const PLAYER_VIEWPORT_POSITION: Vector2 = Vector2(0.34, 0.70)
const ENEMY_VIEWPORT_POSITION: Vector2 = Vector2(0.68, 0.70)
const PLAYER_ACTION_SPRITE_GROUND_Y: float = 46.0


static func get_viewport_size(viewport: Viewport) -> Vector2:
	if viewport == null:
		return BASE_VIEWPORT_SIZE
	var size: Vector2 = viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return BASE_VIEWPORT_SIZE
	return size


static func build_sky_polygon(viewport_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(viewport_size.x, 0.0),
		viewport_size,
		Vector2(0.0, viewport_size.y)
	])


static func build_forest_line_polygon(viewport_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, viewport_size.y * 0.31),
		Vector2(viewport_size.x * 0.08, viewport_size.y * 0.22),
		Vector2(viewport_size.x * 0.16, viewport_size.y * 0.34),
		Vector2(viewport_size.x * 0.28, viewport_size.y * 0.21),
		Vector2(viewport_size.x * 0.43, viewport_size.y * 0.36),
		Vector2(viewport_size.x * 0.57, viewport_size.y * 0.22),
		Vector2(viewport_size.x * 0.72, viewport_size.y * 0.36),
		Vector2(viewport_size.x * 0.86, viewport_size.y * 0.21),
		Vector2(viewport_size.x, viewport_size.y * 0.31),
		viewport_size,
		Vector2(0.0, viewport_size.y)
	])


static func build_ground_polygon(viewport_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, viewport_size.y * 0.72),
		Vector2(viewport_size.x, viewport_size.y * 0.69),
		viewport_size,
		Vector2(0.0, viewport_size.y)
	])


static func build_bottom_vignette_polygon(viewport_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, viewport_size.y * 0.74),
		Vector2(viewport_size.x, viewport_size.y * 0.70),
		viewport_size,
		Vector2(0.0, viewport_size.y)
	])


static func apply_runtime_layout(
	viewport: Viewport,
	camera: Camera2D,
	forest_bg: Sprite2D,
	sky: Polygon2D,
	forest_line: Polygon2D,
	ground: Polygon2D,
	bottom_vignette: Polygon2D,
	player: Combatant,
	enemy: Combatant,
	player_shadow: Node2D,
	enemy_shadow: Node2D,
	animator: TakashiBattleAnimator
) -> void:
	var viewport_size := get_viewport_size(viewport)

	if camera != null:
		camera.enabled = true
		camera.position = viewport_size * 0.5
		camera.offset = Vector2.ZERO

	if forest_bg != null and forest_bg.texture != null:
		var texture_size: Vector2 = forest_bg.texture.get_size()
		var cover_scale: float = maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
		forest_bg.position = Vector2.ZERO
		forest_bg.scale = Vector2(cover_scale, cover_scale)

	if sky != null:
		sky.polygon = build_sky_polygon(viewport_size)
	if forest_line != null:
		forest_line.polygon = build_forest_line_polygon(viewport_size)
	if ground != null:
		ground.polygon = build_ground_polygon(viewport_size)

	if player != null:
		player.z_index = 5
		var player_home := Vector2(viewport_size.x * PLAYER_VIEWPORT_POSITION.x, viewport_size.y * PLAYER_VIEWPORT_POSITION.y)
		player.set_home_position(player_home)
		if player_shadow != null:
			player_shadow.position = player_home + Vector2(0.0, PLAYER_ACTION_SPRITE_GROUND_Y + 4.0)

	if enemy != null:
		enemy.z_index = 5
		var enemy_home := Vector2(viewport_size.x * ENEMY_VIEWPORT_POSITION.x, viewport_size.y * ENEMY_VIEWPORT_POSITION.y)
		enemy.set_home_position(enemy_home)
		if enemy_shadow != null:
			enemy_shadow.position = enemy_home + Vector2(0.0, 48.0)

	if bottom_vignette != null:
		bottom_vignette.polygon = build_bottom_vignette_polygon(viewport_size)

	if animator != null:
		animator.apply_grounding()
