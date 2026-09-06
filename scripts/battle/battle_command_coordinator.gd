class_name BattleCommandCoordinator
extends RefCounted

## Coordinates runtime lifecycle, adapter setup, targeting, and resource commits
## for Basic Attack, Skill, and Ultimate command flows.

const BasicAttackAdapter := preload("res://scripts/battle/command/basic_attack_command_adapter.gd")
const SkillCommandAdapterScript := preload("res://scripts/battle/command/skill_command_adapter.gd")
const UltimateCommandAdapterScript := preload("res://scripts/battle/command/ultimate_command_adapter.gd")
const PendingBattleCommand := preload("res://scripts/battle/command/pending_battle_command.gd")
const BattleTargetingSystemScript := preload("res://scripts/battle/battle_targeting_system.gd")
const BattleLegacyCommandPanelsScript := preload("res://scripts/battle/battle_legacy_command_panels.gd")

var global_selected_target: Combatant = null

# Basic Attack Command state
var basic_command_adapter = null
var basic_target_highlight: Line2D = null
var active_basic_command_token: int = 0
var basic_recovery_tokens: Dictionary = {}
var basic_turn_completion_tokens: Dictionary = {}

# Skill Command state
var skill_command_adapter = null
var skill_target_highlight: Line2D = null
var skill_command_panel: Panel = null
var skill_ready_label: Label = null
var skill_target_label: Label = null
var skill_cost_label: Label = null
var skill_confirm_button: Button = null
var skill_cancel_button: Button = null
var active_skill_command_token: int = 0
var skill_recovery_tokens: Dictionary = {}
var skill_turn_completion_tokens: Dictionary = {}
var skill_hit_tokens: Dictionary = {}

# Ultimate Command state
var ultimate_command_adapter = null
var ultimate_target_highlight: Line2D = null
var ultimate_command_panel: Panel = null
var ultimate_ready_label: Label = null
var ultimate_target_label: Label = null
var ultimate_cost_label: Label = null
var ultimate_confirm_button: Button = null
var ultimate_cancel_button: Button = null
var active_ultimate_command_token: int = 0
var ultimate_recovery_tokens: Dictionary = {}
var ultimate_turn_completion_tokens: Dictionary = {}
var ultimate_hit_tokens: Dictionary = {}


# =========================================================================
# Common Helpers
# =========================================================================

func preselect_pending_target_without_commit(
	command: PendingBattleCommand,
	target: Combatant
) -> bool:
	if command == null or command.is_committed or command.is_cancelled:
		return false
	if target == null or not is_instance_valid(target) or target.is_defeated():
		return false
	return command.select_target(target)


func get_current_target_marker_target(manager: Node) -> Combatant:
	if has_pending_basic_command():
		return selected_basic_target(manager, basic_command_adapter.get_pending_command())
	if has_pending_skill_command():
		return selected_skill_target(manager, skill_command_adapter.get_pending_command())
	if has_pending_ultimate_command():
		return selected_ultimate_target(manager, ultimate_command_adapter.get_pending_command())
	if manager.state == manager.BattleState.PLAYER_TURN:
		return global_selected_target
	return null


func reset_all(manager: Node) -> void:
	reset_basic_command_runtime(manager)
	reset_skill_command_runtime(manager)
	reset_ultimate_command_runtime(manager)


func handle_unhandled_input(manager: Node, event: InputEvent) -> bool:
	if uses_new_basic_command_flow(manager) and has_pending_basic_command():
		if event.is_action_pressed("ui_cancel"):
			if cancel_basic_attack_command(manager):
				return true
		elif event.is_action_pressed("ui_left"):
			if cycle_basic_target(manager, -1):
				return true
		elif event.is_action_pressed("ui_right"):
			if cycle_basic_target(manager, 1):
				return true
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if (
				mouse_event.button_index == MOUSE_BUTTON_LEFT
				and mouse_event.pressed
				and select_basic_target_at_position(manager, mouse_event.position)
			):
				return true
		return false

	if uses_new_skill_command_flow(manager) and has_pending_skill_command():
		if event.is_action_pressed("ui_cancel"):
			if cancel_skill_command(manager):
				return true
		elif event.is_action_pressed("ui_left"):
			if cycle_skill_target(manager, -1):
				return true
		elif event.is_action_pressed("ui_right"):
			if cycle_skill_target(manager, 1):
				return true
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if (
				mouse_event.button_index == MOUSE_BUTTON_LEFT
				and mouse_event.pressed
				and select_skill_target_at_position(manager, mouse_event.position)
			):
				return true
		return false

	if uses_new_ultimate_command_flow(manager) and has_pending_ultimate_command():
		if event.is_action_pressed("ui_cancel"):
			manager._show_ultimate_locked_message()
			return true
		elif event.is_action_pressed("ui_left"):
			if cycle_ultimate_target(manager, -1):
				return true
		elif event.is_action_pressed("ui_right"):
			if cycle_ultimate_target(manager, 1):
				return true
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if (
				mouse_event.button_index == MOUSE_BUTTON_LEFT
				and mouse_event.pressed
				and select_ultimate_target_at_position(manager, mouse_event.position)
			):
				return true
		return false

	return false


# =========================================================================
# Basic Attack Command Flow
# =========================================================================

func setup_basic_command_runtime(manager: Node) -> void:
	setup_basic_command_adapter(manager)
	create_basic_target_highlight(manager)


func setup_basic_command_adapter(manager: Node) -> void:
	if basic_command_adapter != null:
		return
	basic_command_adapter = BasicAttackAdapter.new()
	basic_command_adapter.name = "BasicAttackCommandAdapter"
	manager.add_child(basic_command_adapter)
	basic_command_adapter.configure(
		manager.player,
		Callable(manager, "_get_basic_attack_candidate_targets"),
		Callable(manager, "_validate_basic_attack_command"),
		Callable(manager, "_commit_basic_attack_command_resources")
	)
	basic_command_adapter.target_changed.connect(Callable(manager, "_on_basic_command_target_changed"))
	basic_command_adapter.basic_cancelled.connect(Callable(manager, "_on_basic_command_cancelled"))
	basic_command_adapter.basic_committed.connect(Callable(manager, "_on_basic_command_committed"))
	basic_command_adapter.basic_failed.connect(Callable(manager, "_on_basic_command_failed"))


func reset_basic_command_runtime(manager: Node) -> void:
	active_basic_command_token = 0
	basic_recovery_tokens.clear()
	basic_turn_completion_tokens.clear()
	if basic_command_adapter != null:
		basic_command_adapter.reset()
	hide_basic_target_highlight(manager)


func uses_new_basic_command_flow(manager: Node) -> bool:
	return manager.use_new_basic_command_flow and basic_command_adapter != null


func begin_basic_attack_command(manager: Node) -> bool:
	if not uses_new_basic_command_flow(manager):
		return false
	if manager.state != manager.BattleState.PLAYER_TURN or manager._is_battle_over():
		return false
	if has_pending_basic_command() or has_pending_skill_command():
		return false
	var preferred_target: Combatant = global_selected_target
	var started: bool = basic_command_adapter.begin_basic()
	if started:
		var command: PendingBattleCommand = basic_command_adapter.get_pending_command()
		if (
			not command.is_committed
			and not command.is_cancelled
			and preferred_target != null
			and is_instance_valid(preferred_target)
			and not preferred_target.is_defeated()
		):
			if preselect_pending_target_without_commit(command, preferred_target):
				on_basic_command_target_changed(manager, command, command.selected_targets.duplicate())
		if command != null and not command.is_committed and not command.is_cancelled:
			confirm_basic_attack_command(manager)
	return started


func confirm_basic_attack_command(manager: Node) -> bool:
	if not has_pending_basic_command():
		return false
	repair_basic_pending_target(manager)
	return basic_command_adapter.confirm_basic()


func cancel_basic_attack_command(_manager: Node) -> bool:
	if not has_pending_basic_command():
		return false
	return basic_command_adapter.cancel_basic()


func has_pending_basic_command() -> bool:
	return (
		basic_command_adapter != null
		and basic_command_adapter.has_pending_basic()
	)


func on_basic_command_target_changed(
	manager: Node,
	command: PendingBattleCommand,
	_targets: Array
) -> void:
	var selected: Combatant = selected_basic_target(manager, command)
	if selected != null:
		global_selected_target = selected
	if command.candidate_targets.size() <= 1:
		return
	show_basic_target_highlight(manager, command)
	manager.ui.set_battle_log("Select target")


func on_basic_command_cancelled(manager: Node, _command: PendingBattleCommand) -> void:
	active_basic_command_token = 0
	hide_basic_target_highlight(manager)
	manager.ui.set_battle_input_enabled(true)
	manager.ui.set_turn_text("Player Turn")
	manager.ui.set_battle_log("Void Strike cancelled.")
	manager._update_action_buttons(true)


func on_basic_command_committed(manager: Node, command: PendingBattleCommand) -> void:
	hide_basic_target_highlight(manager)
	manager._update_action_buttons(false)
	manager.ui.set_battle_input_enabled(false)
	manager.call_deferred("_execute_committed_basic_attack", command)


func on_basic_command_failed(
	manager: Node,
	_command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_basic_command_token = 0
	hide_basic_target_highlight(manager)
	if manager._is_battle_over():
		return
	manager.state = manager.BattleState.PLAYER_TURN
	manager.ui.set_battle_input_enabled(true)
	manager.ui.set_turn_text("Player Turn")
	manager.ui.set_battle_log(basic_command_failure_message(reason))
	manager._update_action_buttons(true)


func finish_basic_command_resolution(
	manager: Node,
	command: PendingBattleCommand,
	log_text: String
) -> void:
	if not is_committed_basic_command(command):
		return
	if not basic_command_adapter.resolve_committed_command(command):
		return
	if not basic_command_adapter.begin_recovery(command):
		return

	var token: int = command.commit_token
	if basic_recovery_tokens.has(token):
		return
	basic_recovery_tokens[token] = true
	manager._start_player_idle_animation()
	hide_basic_target_highlight(manager)
	if not basic_recovery_guard(manager, command):
		return
	if not basic_command_adapter.complete_recovery(command):
		return
	if basic_turn_completion_tokens.has(token):
		return
	basic_turn_completion_tokens[token] = true
	active_basic_command_token = 0
	manager._finish_player_action(log_text)


func abort_committed_basic_command(
	_manager: Node,
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_basic_command_token = 0
	if basic_command_adapter != null:
		basic_command_adapter.fail_basic(command, reason)
		basic_command_adapter.reset()


func validate_basic_attack_command(manager: Node, command: PendingBattleCommand) -> String:
	if command == null:
		return "missing_command"
	if command.command_type != PendingBattleCommand.CommandType.BASIC_ATTACK:
		return "unsupported_command"
	if manager._is_battle_over():
		return "battle_already_finished"
	if manager.state != manager.BattleState.PLAYER_TURN:
		return "battle_state_not_player_turn"
	if active_basic_command_token != 0 or active_skill_command_token != 0:
		return "action_execution_already_active"
	if not is_instance_valid(manager.player) or manager.player.is_defeated():
		return "actor_invalid"
	if not command.has_required_targets():
		return "target_invalid"
	if selected_basic_target(manager, command) == null:
		return "target_not_targetable"
	return ""


func commit_basic_attack_command_resources(
	manager: Node,
	command: PendingBattleCommand
) -> bool:
	return validate_basic_attack_command(manager, command).is_empty()


func get_basic_attack_candidate_targets(manager: Node) -> Array[Node]:
	return BattleTargetingSystemScript.get_enemy_candidates(manager.battle_scene, manager.player)


func is_basic_attack_targetable(manager: Node, target: Node) -> bool:
	return BattleTargetingSystemScript.is_enemy_targetable(target, manager.player)


func selected_basic_target(manager: Node, command: PendingBattleCommand) -> Combatant:
	return BattleTargetingSystemScript.get_selected_target(command, manager.player)


func repair_basic_pending_target(manager: Node) -> bool:
	var command: PendingBattleCommand = basic_command_adapter.get_pending_command() if basic_command_adapter != null else null
	return BattleTargetingSystemScript.repair_pending_target(command, manager.battle_scene, manager.player)


func cycle_basic_target(manager: Node, direction: int) -> bool:
	if not has_pending_basic_command():
		return false
	return BattleTargetingSystemScript.cycle_command_target(
		basic_command_adapter.get_pending_command(),
		get_basic_attack_candidate_targets(manager),
		direction,
		basic_command_adapter
	)


func select_basic_target_at_position(manager: Node, screen_position: Vector2) -> bool:
	if not has_pending_basic_command():
		return false
	return BattleTargetingSystemScript.select_target_at_position(
		basic_command_adapter.get_pending_command(),
		get_basic_attack_candidate_targets(manager),
		screen_position,
		basic_command_adapter,
		manager.battle_presentation_3d
	)


func basic_execution_guard(
	manager: Node,
	command: PendingBattleCommand,
	target: Combatant,
	require_live_target: bool = true
) -> bool:
	if (
		not manager.is_inside_tree()
		or manager.state != manager.BattleState.ACTION_RESOLUTION
		or manager._is_battle_over()
		or not is_instance_valid(manager.player)
		or manager.player.is_defeated()
		or target == null
		or not is_instance_valid(target)
		or (require_live_target and target.is_defeated())
	):
		return false
	if command == null:
		return true
	return (
		basic_command_adapter != null
		and command == basic_command_adapter.get_pending_command()
		and command.is_committed
		and active_basic_command_token == command.commit_token
		and basic_command_adapter.is_token_active(command.commit_token)
	)


func basic_impact_guard(
	manager: Node,
	command: PendingBattleCommand,
	target: Node2D
) -> bool:
	if command == null:
		return manager.state == manager.BattleState.ACTION_RESOLUTION and manager.is_inside_tree()
	var combatant: Combatant = target as Combatant
	if combatant == null:
		return false
	return basic_execution_guard(manager, command, combatant, false)


func basic_recovery_guard(manager: Node, command: PendingBattleCommand) -> bool:
	return (
		manager.is_inside_tree()
		and manager.state == manager.BattleState.ACTION_RESOLUTION
		and not manager._is_battle_over()
		and basic_command_adapter != null
		and command == basic_command_adapter.get_pending_command()
		and command.is_committed
		and command.is_resolved
		and active_basic_command_token == command.commit_token
	)


func is_committed_basic_command(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command.command_type == PendingBattleCommand.CommandType.BASIC_ATTACK
		and command.is_committed
		and command.commit_token > 0
	)


func basic_command_failure_message(reason: StringName) -> String:
	match reason:
		&"target_invalid_before_confirm", &"target_not_targetable":
			return "Void Strike target is no longer valid."
		&"no_valid_targets", &"target_missing_during_execution":
			return "Void Strike has no valid target."
		&"battle_state_not_player_turn", &"action_execution_already_active":
			return "Void Strike is not available right now."
	return "Void Strike was cancelled safely."


func create_basic_target_highlight(manager: Node) -> void:
	if basic_target_highlight != null or manager.battle_scene == null:
		return
	basic_target_highlight = BattleTargetingSystemScript.create_reticle(
		manager.battle_scene,
		"BasicTargetHighlight",
		Color(0.98, 0.78, 0.28, 0.96),
		4.0,
		62.0,
		78.0,
		32,
		30
	)


func show_basic_target_highlight(manager: Node, command: PendingBattleCommand) -> void:
	if basic_target_highlight == null:
		return
	if manager._uses_3d_target_markers():
		basic_target_highlight.visible = false
		return
	basic_target_highlight.visible = selected_basic_target(manager, command) != null
	sync_basic_target_highlight(manager)


func hide_basic_target_highlight(manager: Node) -> void:
	if basic_target_highlight == null:
		return
	if manager._uses_3d_target_markers():
		basic_target_highlight.visible = false
		return
	if (
		manager.state == manager.BattleState.PLAYER_TURN
		and not has_pending_skill_command()
		and not has_pending_ultimate_command()
		and global_selected_target != null
	):
		basic_target_highlight.visible = true
	else:
		basic_target_highlight.visible = false


func sync_basic_target_highlight(manager: Node) -> void:
	if basic_target_highlight == null:
		return
	if manager._uses_3d_target_markers():
		basic_target_highlight.visible = false
		return

	var target: Combatant = null
	if has_pending_basic_command():
		target = selected_basic_target(manager, basic_command_adapter.get_pending_command())
	elif (
		manager.state == manager.BattleState.PLAYER_TURN
		and not has_pending_skill_command()
		and not has_pending_ultimate_command()
	):
		target = global_selected_target

	if target == null or not is_instance_valid(target) or target.is_defeated():
		if global_selected_target == target:
			global_selected_target = null
		basic_target_highlight.visible = false
		return

	BattleTargetingSystemScript.sync_reticle(
		basic_target_highlight,
		target,
		Vector2(0.0, -72.0),
		0.48,
		0.008,
		manager.battle_presentation_3d
	)


# =========================================================================
# Skill Command Flow
# =========================================================================

func setup_skill_command_runtime(manager: Node) -> void:
	setup_skill_command_adapter(manager)
	create_skill_target_highlight(manager)
	create_skill_command_panel(manager)


func setup_skill_command_adapter(manager: Node) -> void:
	if skill_command_adapter != null:
		return
	skill_command_adapter = SkillCommandAdapterScript.new()
	skill_command_adapter.name = "SkillCommandAdapter"
	manager.add_child(skill_command_adapter)
	skill_command_adapter.configure(
		manager.player,
		Callable(manager, "_get_skill_candidate_targets"),
		Callable(manager, "_validate_skill_command"),
		Callable(manager, "_commit_skill_command_resources")
	)
	skill_command_adapter.skill_ready.connect(Callable(manager, "_on_skill_command_ready"))
	skill_command_adapter.target_changed.connect(Callable(manager, "_on_skill_command_target_changed"))
	skill_command_adapter.skill_cancelled.connect(Callable(manager, "_on_skill_command_cancelled"))
	skill_command_adapter.skill_committed.connect(Callable(manager, "_on_skill_command_committed"))
	skill_command_adapter.skill_failed.connect(Callable(manager, "_on_skill_command_failed"))


func reset_skill_command_runtime(manager: Node) -> void:
	active_skill_command_token = 0
	skill_recovery_tokens.clear()
	skill_turn_completion_tokens.clear()
	skill_hit_tokens.clear()
	if skill_command_adapter != null:
		skill_command_adapter.reset()
	hide_skill_target_highlight(manager)
	set_skill_command_panel_visible(false)
	manager.skill_animation_looping = false


func uses_new_skill_command_flow(manager: Node) -> bool:
	return manager.use_new_skill_command_flow and skill_command_adapter != null


func begin_skill_command(manager: Node) -> bool:
	if not uses_new_skill_command_flow(manager):
		return false
	if manager.state != manager.BattleState.PLAYER_TURN or manager._is_battle_over():
		return false
	if has_pending_basic_command() or has_pending_skill_command():
		return false
	if manager.skill_points < manager.SKILL_POINT_COST_SKILL:
		manager.ui.set_battle_log("Triangle Rift needs %d Skill Point." % manager.SKILL_POINT_COST_SKILL)
		return false
	var preferred_target: Combatant = global_selected_target
	var started: bool = skill_command_adapter.begin_skill(
		&"triangle_rift",
		PendingBattleCommand.TargetRule.SINGLE_ENEMY,
		manager.SKILL_POINT_COST_SKILL
	)
	if started:
		var command: PendingBattleCommand = skill_command_adapter.get_pending_command()
		if preselect_pending_target_without_commit(command, preferred_target):
			on_skill_command_target_changed(manager, command, command.selected_targets.duplicate())
	return started


func confirm_skill_command(manager: Node) -> bool:
	if not has_pending_skill_command():
		return false
	repair_skill_pending_target(manager)
	return skill_command_adapter.confirm_skill()


func cancel_skill_command(_manager: Node) -> bool:
	if not has_pending_skill_command():
		return false
	return skill_command_adapter.cancel_skill()


func has_pending_skill_command() -> bool:
	return (
		skill_command_adapter != null
		and skill_command_adapter.has_pending_skill()
	)


func on_skill_command_ready(manager: Node, command: PendingBattleCommand) -> void:
	start_skill_ready_idle(manager)
	if manager.battle_presentation_3d != null:
		manager.battle_presentation_3d.camera_transition(BattleCamera3D.Preset.PLAYER_SKILL)
	manager._update_action_buttons(true)
	manager.ui.set_battle_input_enabled(true)
	manager.ui.set_turn_text("Triangle Rift")
	manager.ui.set_battle_log("Triangle Rift ready. Press Skill again or choose a target.")
	update_skill_command_panel(manager, command)


func on_skill_command_target_changed(
	manager: Node,
	command: PendingBattleCommand,
	_targets: Array
) -> void:
	var selected: Combatant = selected_skill_target(manager, command)
	if selected != null:
		global_selected_target = selected
	update_skill_command_panel(manager, command)
	show_skill_target_highlight(manager, command)


func on_skill_command_cancelled(manager: Node, _command: PendingBattleCommand) -> void:
	active_skill_command_token = 0
	manager._stop_player_skill_animation()
	manager._start_player_idle_animation()
	if manager.battle_presentation_3d != null:
		manager.battle_presentation_3d.camera_return_to_idle()
	hide_skill_target_highlight(manager)
	set_skill_command_panel_visible(false)
	manager.ui.set_battle_input_enabled(true)
	manager.ui.set_turn_text("Player Turn")
	manager.ui.set_battle_log("Triangle Rift cancelled.")
	manager._update_action_buttons(true)


func on_skill_command_committed(manager: Node, command: PendingBattleCommand) -> void:
	hide_skill_target_highlight(manager)
	set_skill_command_panel_visible(false)
	manager._update_action_buttons(false)
	manager.ui.set_battle_input_enabled(false)
	manager.call_deferred("_execute_committed_skill", command)


func on_skill_command_failed(
	manager: Node,
	_command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_skill_command_token = 0
	manager._stop_player_skill_animation()
	manager._start_player_idle_animation()
	if manager.battle_presentation_3d != null:
		manager.battle_presentation_3d.camera_return_to_idle()
	hide_skill_target_highlight(manager)
	set_skill_command_panel_visible(false)
	if manager._is_battle_over():
		return
	manager.state = manager.BattleState.PLAYER_TURN
	manager.ui.set_battle_input_enabled(true)
	manager.ui.set_turn_text("Player Turn")
	manager.ui.set_battle_log(skill_command_failure_message(reason))
	manager._update_action_buttons(true)


func start_skill_ready_idle(manager: Node) -> void:
	manager._start_player_skill_animation(true)
	if manager.takashi_skill_frames.is_empty():
		manager._play_screen_flash(Color(0.42, 0.95, 1.0, 0.12), 0.08)


func finish_skill_command_resolution(
	manager: Node,
	command: PendingBattleCommand,
	log_text: String
) -> void:
	if not is_committed_skill_command(command):
		return
	if not skill_command_adapter.resolve_committed_command(command):
		return
	if not skill_command_adapter.begin_recovery(command):
		return

	var token: int = command.commit_token
	if skill_recovery_tokens.has(token):
		return
	skill_recovery_tokens[token] = true
	manager._start_player_idle_animation()
	hide_skill_target_highlight(manager)
	if not skill_recovery_guard(manager, command):
		return
	if not skill_command_adapter.complete_recovery(command):
		return
	if skill_turn_completion_tokens.has(token):
		return
	skill_turn_completion_tokens[token] = true
	active_skill_command_token = 0
	manager._finish_player_action(log_text)


func abort_committed_skill_command(
	_manager: Node,
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_skill_command_token = 0
	if skill_command_adapter != null:
		skill_command_adapter.fail_skill(command, reason)
		skill_command_adapter.reset()


func validate_skill_command(manager: Node, command: PendingBattleCommand) -> String:
	if command == null:
		return "missing_command"
	if command.command_type != PendingBattleCommand.CommandType.SKILL:
		return "unsupported_command"
	if command.action_id != &"triangle_rift":
		return "unsupported_skill"
	if manager._is_battle_over():
		return "battle_already_finished"
	if manager.state != manager.BattleState.PLAYER_TURN:
		return "battle_state_not_player_turn"
	if active_basic_command_token != 0 or active_skill_command_token != 0:
		return "action_execution_already_active"
	if not is_instance_valid(manager.player) or manager.player.is_defeated():
		return "actor_invalid"
	if manager.skill_points < command.skill_point_cost:
		return "not_enough_skill_points"
	if not command.has_required_targets():
		return "target_invalid"
	if selected_skill_target(manager, command) == null:
		return "target_not_targetable"
	return ""


func commit_skill_command_resources(
	manager: Node,
	command: PendingBattleCommand
) -> bool:
	if not validate_skill_command(manager, command).is_empty():
		return false
	if command.skill_point_cost > 0:
		manager._spend_skill_points(command.skill_point_cost)
	return true


func get_skill_candidate_targets(manager: Node) -> Array[Node]:
	return BattleTargetingSystemScript.get_enemy_candidates(manager.battle_scene, manager.player)


func is_skill_targetable(manager: Node, target: Node) -> bool:
	return BattleTargetingSystemScript.is_enemy_targetable(target, manager.player)


func selected_skill_target(manager: Node, command: PendingBattleCommand) -> Combatant:
	return BattleTargetingSystemScript.get_selected_target(command, manager.player)


func repair_skill_pending_target(manager: Node) -> bool:
	var command: PendingBattleCommand = skill_command_adapter.get_pending_command() if skill_command_adapter != null else null
	return BattleTargetingSystemScript.repair_pending_target(command, manager.battle_scene, manager.player)


func cycle_skill_target(manager: Node, direction: int) -> bool:
	if not has_pending_skill_command():
		return false
	return BattleTargetingSystemScript.cycle_command_target(
		skill_command_adapter.get_pending_command(),
		get_skill_candidate_targets(manager),
		direction,
		skill_command_adapter
	)


func select_skill_target_at_position(manager: Node, screen_position: Vector2) -> bool:
	if not has_pending_skill_command():
		return false
	return BattleTargetingSystemScript.select_target_at_position(
		skill_command_adapter.get_pending_command(),
		get_skill_candidate_targets(manager),
		screen_position,
		skill_command_adapter,
		manager.battle_presentation_3d
	)


func skill_execution_guard(
	manager: Node,
	command: PendingBattleCommand,
	target: Combatant,
	require_live_target: bool = true
) -> bool:
	if (
		not manager.is_inside_tree()
		or manager.state != manager.BattleState.ACTION_RESOLUTION
		or manager._is_battle_over()
		or not is_instance_valid(manager.player)
		or manager.player.is_defeated()
		or target == null
		or not is_instance_valid(target)
		or (require_live_target and target.is_defeated())
	):
		return false
	if command == null:
		return true
	return (
		skill_command_adapter != null
		and command == skill_command_adapter.get_pending_command()
		and command.is_committed
		and active_skill_command_token == command.commit_token
		and skill_command_adapter.is_token_active(command.commit_token)
	)


func skill_impact_guard(
	manager: Node,
	command: PendingBattleCommand,
	target: Node2D
) -> bool:
	if command == null:
		return manager.state == manager.BattleState.ACTION_RESOLUTION and manager.is_inside_tree()
	var combatant: Combatant = target as Combatant
	if combatant == null:
		return false
	return skill_execution_guard(manager, command, combatant, false)


func skill_recovery_guard(manager: Node, command: PendingBattleCommand) -> bool:
	return (
		manager.is_inside_tree()
		and manager.state == manager.BattleState.ACTION_RESOLUTION
		and not manager._is_battle_over()
		and skill_command_adapter != null
		and command == skill_command_adapter.get_pending_command()
		and command.is_committed
		and command.is_resolved
		and active_skill_command_token == command.commit_token
	)


func is_committed_skill_command(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command.command_type == PendingBattleCommand.CommandType.SKILL
		and command.is_committed
		and command.commit_token > 0
	)


func consume_skill_hit(command: PendingBattleCommand, pulse_index: int) -> bool:
	if command == null:
		return true
	var key := "%d:%d" % [command.commit_token, pulse_index]
	if skill_hit_tokens.has(key):
		return false
	skill_hit_tokens[key] = true
	return true


func claim_skill_hit_token(command: PendingBattleCommand, pulse_index: int) -> bool:
	return consume_skill_hit(command, pulse_index)


func skill_command_failure_message(reason: StringName) -> String:
	match reason:
		&"not_enough_skill_points":
			return "Triangle Rift needs 1 Skill Point."
		&"target_invalid_before_confirm", &"target_not_targetable":
			return "Triangle Rift target is no longer valid."
		&"no_valid_targets", &"target_missing_during_execution":
			return "Triangle Rift has no valid target."
		&"battle_state_not_player_turn", &"action_execution_already_active":
			return "Triangle Rift is not available right now."
	return "Triangle Rift was cancelled safely."


func create_skill_target_highlight(manager: Node) -> void:
	if skill_target_highlight != null or manager.battle_scene == null:
		return
	skill_target_highlight = BattleTargetingSystemScript.create_reticle(
		manager.battle_scene,
		"SkillTargetHighlight",
		Color(0.42, 0.96, 1.0, 0.98),
		4.0,
		70.0,
		86.0,
		36,
		31
	)


func show_skill_target_highlight(manager: Node, command: PendingBattleCommand) -> void:
	if skill_target_highlight == null:
		return
	if manager._uses_3d_target_markers():
		skill_target_highlight.visible = false
		return
	skill_target_highlight.visible = selected_skill_target(manager, command) != null
	sync_skill_target_highlight(manager)


func hide_skill_target_highlight(_manager: Node) -> void:
	if skill_target_highlight != null:
		skill_target_highlight.visible = false


func sync_skill_target_highlight(manager: Node) -> void:
	if skill_target_highlight == null or not skill_target_highlight.visible:
		return
	if manager._uses_3d_target_markers():
		skill_target_highlight.visible = false
		return
	if not has_pending_skill_command():
		skill_target_highlight.visible = false
		return
	var target: Combatant = selected_skill_target(manager, skill_command_adapter.get_pending_command())
	if target == null:
		skill_target_highlight.visible = false
		return
	BattleTargetingSystemScript.sync_reticle(
		skill_target_highlight,
		target,
		Vector2(0.0, -76.0),
		0.5,
		-0.01,
		manager.battle_presentation_3d
	)


func create_skill_command_panel(manager: Node) -> void:
	if skill_command_panel != null or manager.canvas_layer == null:
		return
	var elements: Dictionary = BattleLegacyCommandPanelsScript.create_skill_command_panel(
		manager.canvas_layer,
		Callable(manager, "_confirm_skill_command"),
		Callable(manager, "_cancel_skill_command")
	)
	if elements.is_empty():
		return
	skill_command_panel = elements["panel"]
	skill_ready_label = elements["ready_label"]
	skill_cost_label = elements["cost_label"]
	skill_target_label = elements["target_label"]
	skill_confirm_button = elements["confirm_button"]
	skill_cancel_button = elements["cancel_button"]


func set_skill_command_panel_visible(is_visible: bool) -> void:
	if skill_command_panel != null:
		skill_command_panel.visible = is_visible


func update_skill_command_panel(manager: Node, command: PendingBattleCommand) -> void:
	var labels := {
		"ready": skill_ready_label,
		"cost": skill_cost_label,
		"target": skill_target_label
	}
	BattleLegacyCommandPanelsScript.update_skill_panel(
		labels,
		skill_confirm_button,
		selected_skill_target(manager, command),
		command,
		manager.skill_points,
		manager.MAX_SKILL_POINTS
	)


# =========================================================================
# Ultimate Command Flow
# =========================================================================

func setup_ultimate_command_runtime(manager: Node) -> void:
	setup_ultimate_command_adapter(manager)
	create_ultimate_target_highlight(manager)
	create_ultimate_command_panel(manager)


func setup_ultimate_command_adapter(manager: Node) -> void:
	if ultimate_command_adapter != null:
		return
	ultimate_command_adapter = UltimateCommandAdapterScript.new()
	ultimate_command_adapter.name = "UltimateCommandAdapter"
	manager.add_child(ultimate_command_adapter)
	ultimate_command_adapter.configure(
		manager.player,
		Callable(manager, "_get_ultimate_candidate_targets"),
		Callable(manager, "_validate_ultimate_command"),
		Callable(manager, "_commit_ultimate_command_resources")
	)
	ultimate_command_adapter.ultimate_ready.connect(Callable(manager, "_on_ultimate_command_ready"))
	ultimate_command_adapter.target_changed.connect(Callable(manager, "_on_ultimate_command_target_changed"))
	ultimate_command_adapter.ultimate_cancelled.connect(Callable(manager, "_on_ultimate_command_cancelled"))
	ultimate_command_adapter.ultimate_committed.connect(Callable(manager, "_on_ultimate_command_committed"))
	ultimate_command_adapter.ultimate_failed.connect(Callable(manager, "_on_ultimate_command_failed"))


func reset_ultimate_command_runtime(manager: Node) -> void:
	active_ultimate_command_token = 0
	ultimate_recovery_tokens.clear()
	ultimate_turn_completion_tokens.clear()
	ultimate_hit_tokens.clear()
	if ultimate_command_adapter != null:
		ultimate_command_adapter.reset()
	hide_ultimate_target_highlight(manager)
	set_ultimate_command_panel_visible(false)
	manager._reset_ultimate_interrupt_queue()


func uses_new_ultimate_command_flow(manager: Node) -> bool:
	return manager.use_new_ultimate_command_flow and ultimate_command_adapter != null


func begin_ultimate_command(manager: Node) -> bool:
	if not uses_new_ultimate_command_flow(manager):
		return false
	if manager.state != manager.BattleState.PLAYER_TURN or manager._is_battle_over():
		return false
	if (
		has_pending_basic_command()
		or has_pending_skill_command()
		or has_pending_ultimate_command()
	):
		return false
	if manager.ultimate_energy < manager.MAX_ULTIMATE_ENERGY:
		manager.ui.set_battle_log("Octagram Fragment needs full Energy.")
		return false
	var preferred_target: Combatant = global_selected_target
	var started: bool = ultimate_command_adapter.begin_ultimate(
		&"octagram_fragment",
		PendingBattleCommand.TargetRule.SINGLE_ENEMY,
		manager.MAX_ULTIMATE_ENERGY
	)
	if started:
		var command: PendingBattleCommand = ultimate_command_adapter.get_pending_command()
		if preselect_pending_target_without_commit(command, preferred_target):
			on_ultimate_command_target_changed(manager, command, command.selected_targets.duplicate())
	return started


func confirm_ultimate_command(manager: Node) -> bool:
	if not has_pending_ultimate_command():
		return false
	repair_ultimate_pending_target(manager)
	return ultimate_command_adapter.confirm_ultimate()


func cancel_ultimate_command(manager: Node) -> bool:
	if not has_pending_ultimate_command():
		return false
	manager._show_ultimate_locked_message()
	return false


func has_pending_ultimate_command() -> bool:
	return (
		ultimate_command_adapter != null
		and ultimate_command_adapter.has_pending_ultimate()
	)


func on_ultimate_command_ready(manager: Node, command: PendingBattleCommand) -> void:
	start_ultimate_ready_idle(manager)
	if manager.battle_presentation_3d != null:
		manager.battle_presentation_3d.camera_transition(BattleCamera3D.Preset.PLAYER_ULTIMATE)
	manager._update_action_buttons(true)
	manager.ui.set_battle_input_enabled(true)
	manager.ui.set_turn_text("Octagram Fragment")
	manager.ui.set_battle_log("Octagram Fragment ready. Press Ultimate again or choose a target.")
	update_ultimate_command_panel(manager, command)


func on_ultimate_command_target_changed(
	manager: Node,
	command: PendingBattleCommand,
	_targets: Array
) -> void:
	var selected: Combatant = selected_ultimate_target(manager, command)
	if selected != null:
		global_selected_target = selected
	update_ultimate_command_panel(manager, command)
	show_ultimate_target_highlight(manager, command)


func on_ultimate_command_cancelled(manager: Node, command: PendingBattleCommand) -> void:
	var was_interrupt: bool = is_interrupt_sourced(command)
	active_ultimate_command_token = 0
	manager._start_player_idle_animation()
	if manager.battle_presentation_3d != null:
		manager.battle_presentation_3d.camera_return_to_idle()
	hide_ultimate_target_highlight(manager)
	set_ultimate_command_panel_visible(false)
	if was_interrupt:
		if not manager._consume_interrupt_resume_token(manager.interrupt_resume_token):
			return
		manager.is_processing_interrupt_queue = false
		manager.active_interrupt_request = null
		manager._resume_after_interrupt("Octagram Fragment cancelled.")
		return
	manager.ui.set_battle_input_enabled(true)
	manager.ui.set_turn_text("Player Turn")
	manager.ui.set_battle_log("Octagram Fragment cancelled.")
	manager._update_action_buttons(true)


func on_ultimate_command_committed(manager: Node, command: PendingBattleCommand) -> void:
	hide_ultimate_target_highlight(manager)
	set_ultimate_command_panel_visible(false)
	manager._update_action_buttons(false)
	manager.ui.set_battle_input_enabled(false)
	manager.call_deferred("_execute_committed_ultimate", command)


func on_ultimate_command_failed(
	manager: Node,
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	var was_interrupt: bool = is_interrupt_sourced(command)
	active_ultimate_command_token = 0
	manager._start_player_idle_animation()
	manager._exit_ultimate_cutscene_presentation()
	if manager.battle_presentation_3d != null:
		manager.battle_presentation_3d.camera_return_to_idle()
	hide_ultimate_target_highlight(manager)
	set_ultimate_command_panel_visible(false)
	if manager._is_battle_over():
		return
	if was_interrupt:
		if not manager._consume_interrupt_resume_token(manager.interrupt_resume_token):
			return
		manager.is_processing_interrupt_queue = false
		manager.active_interrupt_request = null
		manager._resume_after_interrupt(ultimate_command_failure_message(reason))
		return
	manager.state = manager.BattleState.PLAYER_TURN
	manager.ui.set_battle_input_enabled(true)
	manager.ui.set_turn_text("Player Turn")
	manager.ui.set_battle_log(ultimate_command_failure_message(reason))
	manager._update_action_buttons(true)


func is_interrupt_sourced(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command.request_source == PendingBattleCommand.RequestSource.INTERRUPT_REQUEST
	)


func start_ultimate_ready_idle(manager: Node) -> void:
	manager._stop_player_idle_animation()
	manager._stop_player_basic_animation()
	manager._stop_player_skill_animation()
	manager._set_player_action_texture(manager.TAKASHI_ULTIMATE_TEXTURE)


func finish_ultimate_command_resolution(
	manager: Node,
	command: PendingBattleCommand,
	log_text: String,
	is_interrupt: bool = false
) -> void:
	if not is_committed_ultimate_command(command):
		return
	if not ultimate_command_adapter.resolve_committed_command(command):
		return
	if not ultimate_command_adapter.begin_recovery(command):
		return

	var token: int = command.commit_token
	if ultimate_recovery_tokens.has(token):
		return
	ultimate_recovery_tokens[token] = true
	manager._start_player_idle_animation()
	hide_ultimate_target_highlight(manager)
	if not ultimate_recovery_guard(manager, command):
		return
	if not ultimate_command_adapter.complete_recovery(command):
		return
	if ultimate_turn_completion_tokens.has(token):
		return
	ultimate_turn_completion_tokens[token] = true
	active_ultimate_command_token = 0
	if is_interrupt:
		manager._finish_interrupt_ultimate_action(log_text)
	else:
		manager._finish_player_action(log_text)


func abort_committed_ultimate_command(
	manager: Node,
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	active_ultimate_command_token = 0
	manager._abort_ultimate_cutscene_visuals()
	if ultimate_command_adapter != null:
		ultimate_command_adapter.fail_ultimate(command, reason)
		ultimate_command_adapter.reset()


func is_ultimate_command_state_allowed(manager: Node) -> bool:
	return manager.state == manager.BattleState.PLAYER_TURN


func validate_ultimate_command(manager: Node, command: PendingBattleCommand) -> String:
	if command == null:
		return "missing_command"
	if command.command_type != PendingBattleCommand.CommandType.ULTIMATE:
		return "unsupported_command"
	if command.action_id != &"octagram_fragment":
		return "unsupported_ultimate"
	if manager._is_battle_over():
		return "battle_already_finished"
	if not is_ultimate_command_state_allowed(manager):
		return "battle_state_not_player_turn"
	if (
		active_basic_command_token != 0
		or active_skill_command_token != 0
		or active_ultimate_command_token != 0
	):
		return "action_execution_already_active"
	if not is_instance_valid(manager.player) or manager.player.is_defeated():
		return "actor_invalid"
	if manager.ultimate_energy < command.energy_cost:
		return "not_enough_energy"
	if not command.has_required_targets():
		return "target_invalid"
	if selected_ultimate_target(manager, command) == null:
		return "target_not_targetable"
	return ""


func commit_ultimate_command_resources(
	manager: Node,
	command: PendingBattleCommand
) -> bool:
	if not validate_ultimate_command(manager, command).is_empty():
		return false
	manager.ultimate_energy = maxi(manager.ultimate_energy - command.energy_cost, 0)
	manager._refresh_energy_ui()
	return true


func get_ultimate_candidate_targets(manager: Node) -> Array[Node]:
	return BattleTargetingSystemScript.get_enemy_candidates(manager.battle_scene, manager.player)


func is_ultimate_targetable(manager: Node, target: Node) -> bool:
	return BattleTargetingSystemScript.is_enemy_targetable(target, manager.player)


func selected_ultimate_target(manager: Node, command: PendingBattleCommand) -> Combatant:
	return BattleTargetingSystemScript.get_selected_target(command, manager.player)


func repair_ultimate_pending_target(manager: Node) -> bool:
	var command: PendingBattleCommand = ultimate_command_adapter.get_pending_command() if ultimate_command_adapter != null else null
	return BattleTargetingSystemScript.repair_pending_target(command, manager.battle_scene, manager.player)


func cycle_ultimate_target(manager: Node, direction: int) -> bool:
	if not has_pending_ultimate_command():
		return false
	return BattleTargetingSystemScript.cycle_command_target(
		ultimate_command_adapter.get_pending_command(),
		get_ultimate_candidate_targets(manager),
		direction,
		ultimate_command_adapter
	)


func select_ultimate_target_at_position(manager: Node, screen_position: Vector2) -> bool:
	if not has_pending_ultimate_command():
		return false
	return BattleTargetingSystemScript.select_target_at_position(
		ultimate_command_adapter.get_pending_command(),
		get_ultimate_candidate_targets(manager),
		screen_position,
		ultimate_command_adapter,
		manager.battle_presentation_3d
	)


func ultimate_execution_guard(
	manager: Node,
	command: PendingBattleCommand,
	target: Combatant,
	require_live_target: bool = true
) -> bool:
	if (
		not manager.is_inside_tree()
		or manager.state != manager.BattleState.ACTION_RESOLUTION
		or manager._is_battle_over()
		or not is_instance_valid(manager.player)
		or manager.player.is_defeated()
		or target == null
		or not is_instance_valid(target)
		or (require_live_target and target.is_defeated())
	):
		return false
	if command == null:
		return true
	return (
		ultimate_command_adapter != null
		and command == ultimate_command_adapter.get_pending_command()
		and command.is_committed
		and active_ultimate_command_token == command.commit_token
		and ultimate_command_adapter.is_token_active(command.commit_token)
	)


func ultimate_impact_guard(
	manager: Node,
	command: PendingBattleCommand,
	target: Node2D
) -> bool:
	if command == null:
		return manager.state == manager.BattleState.ACTION_RESOLUTION and manager.is_inside_tree()
	var combatant: Combatant = target as Combatant
	if combatant == null:
		return false
	return ultimate_execution_guard(manager, command, combatant, false)


func ultimate_recovery_guard(manager: Node, command: PendingBattleCommand) -> bool:
	return (
		manager.is_inside_tree()
		and manager.state == manager.BattleState.ACTION_RESOLUTION
		and not manager._is_battle_over()
		and ultimate_command_adapter != null
		and command == ultimate_command_adapter.get_pending_command()
		and command.is_committed
		and command.is_resolved
		and active_ultimate_command_token == command.commit_token
	)


func is_committed_ultimate_command(command: PendingBattleCommand) -> bool:
	return (
		command != null
		and command.command_type == PendingBattleCommand.CommandType.ULTIMATE
		and command.is_committed
		and command.commit_token > 0
	)


func consume_ultimate_hit(command: PendingBattleCommand, hit_index: int) -> bool:
	if command == null:
		return true
	var key := "%d:%d" % [command.commit_token, hit_index]
	if ultimate_hit_tokens.has(key):
		return false
	ultimate_hit_tokens[key] = true
	return true


func claim_ultimate_hit_token(command: PendingBattleCommand, hit_index: int) -> bool:
	return consume_ultimate_hit(command, hit_index)


func ultimate_command_failure_message(reason: StringName) -> String:
	match reason:
		&"not_enough_energy":
			return "Octagram Fragment needs full Energy."
		&"target_invalid_before_confirm", &"target_not_targetable":
			return "Octagram Fragment target is no longer valid."
		&"no_valid_targets", &"target_missing_during_execution":
			return "Octagram Fragment has no valid target."
		&"battle_state_not_player_turn", &"action_execution_already_active":
			return "Octagram Fragment is not available right now."
	return "Octagram Fragment was cancelled safely."


func create_ultimate_target_highlight(manager: Node) -> void:
	if ultimate_target_highlight != null or manager.battle_scene == null:
		return
	ultimate_target_highlight = BattleTargetingSystemScript.create_reticle(
		manager.battle_scene,
		"UltimateTargetHighlight",
		Color(0.72, 0.95, 1.0, 0.98),
		4.0,
		78.0,
		94.0,
		40,
		32
	)


func show_ultimate_target_highlight(manager: Node, command: PendingBattleCommand) -> void:
	if ultimate_target_highlight == null:
		return
	if manager._uses_3d_target_markers():
		ultimate_target_highlight.visible = false
		return
	ultimate_target_highlight.visible = selected_ultimate_target(manager, command) != null
	sync_ultimate_target_highlight(manager)


func hide_ultimate_target_highlight(_manager: Node) -> void:
	if ultimate_target_highlight != null:
		ultimate_target_highlight.visible = false


func sync_ultimate_target_highlight(manager: Node) -> void:
	if ultimate_target_highlight == null or not ultimate_target_highlight.visible:
		return
	if manager._uses_3d_target_markers():
		ultimate_target_highlight.visible = false
		return
	if not has_pending_ultimate_command():
		ultimate_target_highlight.visible = false
		return
	var target: Combatant = selected_ultimate_target(manager, ultimate_command_adapter.get_pending_command())
	if target == null:
		ultimate_target_highlight.visible = false
		return
	BattleTargetingSystemScript.sync_reticle(
		ultimate_target_highlight,
		target,
		Vector2(0.0, -80.0),
		0.52,
		0.012,
		manager.battle_presentation_3d
	)


func create_ultimate_command_panel(manager: Node) -> void:
	if ultimate_command_panel != null or manager.canvas_layer == null:
		return
	var elements: Dictionary = BattleLegacyCommandPanelsScript.create_ultimate_command_panel(
		manager.canvas_layer,
		Callable(manager, "_confirm_ultimate_command"),
		Callable(manager, "_cancel_ultimate_command")
	)
	if elements.is_empty():
		return
	ultimate_command_panel = elements["panel"]
	ultimate_ready_label = elements["ready_label"]
	ultimate_cost_label = elements["cost_label"]
	ultimate_target_label = elements["target_label"]
	ultimate_confirm_button = elements["confirm_button"]
	ultimate_cancel_button = elements["cancel_button"]


func set_ultimate_command_panel_visible(is_visible: bool) -> void:
	if ultimate_command_panel != null:
		ultimate_command_panel.visible = is_visible


func update_ultimate_command_panel(manager: Node, command: PendingBattleCommand) -> void:
	var labels := {
		"ready": ultimate_ready_label,
		"cost": ultimate_cost_label,
		"target": ultimate_target_label
	}
	BattleLegacyCommandPanelsScript.update_ultimate_panel(
		labels,
		ultimate_confirm_button,
		selected_ultimate_target(manager, command),
		command,
		manager.ultimate_energy,
		manager.MAX_ULTIMATE_ENERGY
	)


# =========================================================================
# Command Action Button Handlers
# =========================================================================

func on_attack_pressed(manager: Node) -> void:
	if manager.state != manager.BattleState.PLAYER_TURN:
		return
	if has_pending_skill_command():
		cancel_skill_command(manager)
		return
	if has_pending_ultimate_command():
		show_ultimate_locked_message(manager)
		return

	if has_pending_basic_command():
		confirm_basic_attack_command(manager)
		return

	if uses_new_basic_command_flow(manager):
		begin_basic_attack_command(manager)
		return

	await manager._start_legacy_basic_attack()


func on_confirm_pressed(manager: Node) -> void:
	if uses_new_basic_command_flow(manager) and has_pending_basic_command():
		confirm_basic_attack_command(manager)
		return
	if uses_new_skill_command_flow(manager) and has_pending_skill_command():
		confirm_skill_command(manager)
		return
	if uses_new_ultimate_command_flow(manager) and has_pending_ultimate_command():
		confirm_ultimate_command(manager)
		return
	if manager.state == manager.BattleState.PLAYER_TURN:
		await on_attack_pressed(manager)


func on_skill_pressed(manager: Node) -> void:
	if manager.state != manager.BattleState.PLAYER_TURN:
		return
	if has_pending_skill_command():
		confirm_skill_command(manager)
		return
	if has_pending_basic_command():
		cancel_basic_attack_command(manager)
		return
	if has_pending_ultimate_command():
		show_ultimate_locked_message(manager)
		return

	if uses_new_skill_command_flow(manager):
		begin_skill_command(manager)
		return

	if manager.skill_points < manager.SKILL_POINT_COST_SKILL:
		return
	await manager._start_legacy_skill()


func on_ultimate_pressed(manager: Node) -> void:
	if has_pending_ultimate_command():
		confirm_ultimate_command(manager)
		return
	if manager.state != manager.BattleState.PLAYER_TURN:
		manager.request_off_turn_ultimate(manager.player)
		return
	if has_pending_basic_command():
		cancel_basic_attack_command(manager)
		return
	if has_pending_skill_command():
		cancel_skill_command(manager)
		return

	if uses_new_ultimate_command_flow(manager):
		begin_ultimate_command(manager)
		return

	if manager.ultimate_energy < manager.MAX_ULTIMATE_ENERGY:
		return
	await manager._start_legacy_ultimate()


func show_ultimate_locked_message(manager: Node) -> void:
	if manager.ui != null:
		manager.ui.set_battle_log("Octagram Fragment is locked in. Press Ultimate again or choose a target.")

