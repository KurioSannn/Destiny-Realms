extends RefCounted
class_name BattleTargetingSystem

## BattleTargetingSystem
## Handles 2D Line2D target reticle generation, 3D-to-2D screen position
## projection, raycasted/screen-distance target selection, and candidate cycling
## across Basic, Skill, Ultimate, and Player Turn neutral states.

const DEFAULT_PICK_DISTANCE: float = 170.0


## Generates a closed elliptical Line2D reticle node with the specified geometry.
static func create_reticle(
	parent: Node,
	reticle_name: String,
	color: Color,
	width: float,
	radius_x: float,
	radius_y: float,
	point_count: int,
	z_index_val: int
) -> Line2D:
	if parent == null:
		return null
	var reticle := Line2D.new()
	reticle.name = reticle_name
	reticle.width = width
	reticle.default_color = color
	reticle.closed = true
	reticle.z_index = z_index_val
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		reticle.add_point(
			Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		)
	parent.add_child(reticle)
	reticle.visible = false
	return reticle


## Computes the 2D screen coordinate of a target Combatant.
## Uses 3D presentation projection if available, falling back to 2D global position.
static func get_target_highlight_position(
	target: Combatant,
	fallback_offset: Vector2,
	vertical_ratio: float,
	presentation_3d: BattlePresentation3D
) -> Vector2:
	if target == null:
		return Vector2.ZERO
	if presentation_3d != null and is_instance_valid(presentation_3d):
		var projected := presentation_3d.get_enemy_screen_position(target, vertical_ratio)
		if not is_inf(projected.x) and not is_inf(projected.y):
			return projected
	return target.global_position + fallback_offset


## Finds the closest candidate Combatant to a screen coordinate.
## Prioritizes 3D presentation picking when active; otherwise measures 2D screen distance.
static func pick_target_at_screen_position(
	screen_position: Vector2,
	candidates: Array[Node],
	presentation_3d: BattlePresentation3D,
	max_distance: float = DEFAULT_PICK_DISTANCE
) -> Combatant:
	if presentation_3d != null and is_instance_valid(presentation_3d):
		var picked_3d := presentation_3d.pick_enemy_combatant_at_screen_position(
			screen_position,
			candidates
		)
		if picked_3d != null:
			return picked_3d

	var closest_target: Combatant = null
	var closest_distance := INF
	for candidate in candidates:
		var combatant := candidate as Combatant
		if combatant == null:
			continue
		var distance := screen_position.distance_to(combatant.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = combatant
	if closest_target == null or closest_distance > max_distance:
		return null
	return closest_target


## Cycles through candidate targets for an active PendingBattleCommand.
static func cycle_command_target(
	command: PendingBattleCommand,
	candidate_list: Array[Node],
	direction: int,
	adapter: Node
) -> bool:
	if command == null or adapter == null:
		return false
	command.candidate_targets.assign(candidate_list)
	command.refresh_candidates()
	if command.candidate_targets.size() < 2:
		return false

	var current_index := 0
	if not command.selected_targets.is_empty():
		current_index = command.candidate_targets.find(command.selected_targets[0])
	if current_index < 0:
		current_index = 0
	var next_index := wrapi(
		current_index + direction,
		0,
		command.candidate_targets.size()
	)
	var next_target := command.candidate_targets[next_index] as Combatant
	if adapter.has_method("select_target"):
		return bool(adapter.call("select_target", next_target))
	return false


## Selects a target at a screen position for an active PendingBattleCommand.
static func select_target_at_position(
	command: PendingBattleCommand,
	candidate_list: Array[Node],
	screen_position: Vector2,
	adapter: Node,
	presentation_3d: BattlePresentation3D
) -> bool:
	if command == null or adapter == null:
		return false
	command.candidate_targets.assign(candidate_list)
	command.refresh_candidates()
	var closest_target := pick_target_at_screen_position(
		screen_position,
		command.candidate_targets,
		presentation_3d
	)
	if closest_target == null:
		return false
	if adapter.has_method("select_target"):
		return bool(adapter.call("select_target", closest_target))
	return false


## Cycles the neutral global target during PLAYER_TURN when no command is pending.
static func cycle_global_target(
	candidate_list: Array[Node],
	current_target: Combatant,
	direction: int
) -> Combatant:
	if candidate_list.size() < 2:
		return current_target
	var current_index := 0
	if current_target != null:
		current_index = candidate_list.find(current_target)
		if current_index < 0:
			current_index = 0
	var next_index := wrapi(current_index + direction, 0, candidate_list.size())
	return candidate_list[next_index] as Combatant


## Synchronizes a Line2D reticle's visibility, position, and rotation toward target.
static func sync_reticle(
	reticle: Line2D,
	target: Combatant,
	fallback_offset: Vector2,
	vertical_ratio: float,
	rotation_delta: float,
	presentation_3d: BattlePresentation3D
) -> void:
	if reticle == null:
		return
	reticle.visible = true
	reticle.global_position = get_target_highlight_position(
		target,
		fallback_offset,
		vertical_ratio,
		presentation_3d
	)
	reticle.rotation += rotation_delta


## Checks whether a candidate node is a valid, living enemy combatant.
static func is_enemy_targetable(target: Node, player: Node) -> bool:
	return (
		target is Combatant
		and target != player
		and is_instance_valid(target)
		and not (target as Combatant).is_defeated()
	)


## Collects all living enemy combatants in the battle scene.
static func get_enemy_candidates(battle_scene: Node, player: Node) -> Array[Node]:
	var targets: Array[Node] = []
	if battle_scene == null:
		return targets
	for child in battle_scene.get_children():
		if is_enemy_targetable(child, player):
			targets.append(child)
	return targets


## Extracts and validates the primary Combatant target of a PendingBattleCommand.
static func get_selected_target(command: PendingBattleCommand, player: Node) -> Combatant:
	if command == null or command.selected_targets.is_empty():
		return null
	var target := command.selected_targets[0] as Combatant
	if target == null or not is_enemy_targetable(target, player):
		return null
	return target


## Refreshes candidate targets for a pending command without switching targets silently.
static func repair_pending_target(
	command: PendingBattleCommand,
	battle_scene: Node,
	player: Node
) -> bool:
	if command == null:
		return false
	command.candidate_targets.assign(get_enemy_candidates(battle_scene, player))
	command.refresh_candidates()
	return get_selected_target(command, player) != null

