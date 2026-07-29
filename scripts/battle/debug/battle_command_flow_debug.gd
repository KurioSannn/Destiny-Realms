extends BattleManager
class_name BattleCommandFlowDebug

const PendingCommand := preload(
	"res://scripts/battle/command/pending_battle_command.gd"
)
const CommandFlow := preload(
	"res://scripts/battle/command/battle_command_flow.gd"
)

@export var enemy_turn_enabled: bool = true

@onready var command_flow: BattleCommandFlow = $"../CommandFlow"
@onready var debug_panel: BattleCommandDebugPanel = (
	$"../CanvasLayer/CommandDebugPanel"
)

var echo_enemy: Combatant
var target_highlight: Line2D
var active_targets: Array[Node] = []
var ready_frames: Array[Texture2D] = []
var ready_frame_index: int = 0
var ready_frame_elapsed: float = 0.0
var ready_frame_rate: float = 4.0
var current_error: String = ""
var recovery_hold_seconds: float = 0.3


func _ready() -> void:
	player.setup("Takashi", PLAYER_MAX_HP, BASIC_ATTACK_DAMAGE)
	enemy.setup("Lesser Abyss", ENEMY_MAX_HP, ENEMY_BASE_DAMAGE)
	ultimate_energy = 0
	skill_points = START_SKILL_POINTS
	state = BattleState.PLAYER_TURN

	ui.attack_pressed.connect(
		_begin_debug_command.bind(PendingCommand.CommandType.BASIC_ATTACK)
	)
	ui.skill_pressed.connect(
		_begin_debug_command.bind(PendingCommand.CommandType.SKILL)
	)
	ui.ultimate_pressed.connect(
		_begin_debug_command.bind(PendingCommand.CommandType.ULTIMATE)
	)
	ui.confirm_pressed.connect(_confirm_pending_command)

	command_flow.configure_resource_callbacks(
		_validate_command_resources,
		_commit_command_resources
	)
	command_flow.command_ready.connect(_on_command_ready)
	command_flow.target_changed.connect(_on_target_changed)
	command_flow.command_committed.connect(_on_command_committed)
	command_flow.command_cancelled.connect(_on_command_cancelled)
	command_flow.command_failed.connect(_on_command_failed)
	command_flow.flow_state_changed.connect(_on_flow_state_changed)

	debug_panel.confirm_requested.connect(_confirm_pending_command)
	debug_panel.cancel_requested.connect(_cancel_pending_command)
	debug_panel.previous_target_requested.connect(_cycle_target.bind(-1))
	debug_panel.next_target_requested.connect(_cycle_target.bind(1))
	debug_panel.fill_energy_requested.connect(_fill_energy)
	debug_panel.invalidate_target_requested.connect(_invalidate_selected_target)

	_setup_takashi_idle_frames()
	_setup_takashi_basic_frames()
	_setup_takashi_skill_frames()
	_setup_takashi_ulti_pre_frames()
	_setup_takashi_ulti_post_frames()
	_setup_takashi_ultimate_fvx_frames()
	_load_ultimate_frames()
	_setup_battle_bgm()
	_start_player_idle_animation()

	await get_tree().process_frame
	_setup_battle_effects()
	_apply_runtime_layout()
	_create_echo_enemy()
	_create_target_highlight()
	_refresh_player_status_ui()
	_refresh_energy_ui()
	_refresh_skill_points_ui()
	_enter_command_select("Vertical slice ready. Select a command.")


func _process(delta: float) -> void:
	_advance_player_idle_animation(delta)
	_advance_player_basic_animation(delta)
	_advance_takashi_ultimate_fvx(delta)
	_advance_ready_frames(delta)
	_sync_target_highlight()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _cancel_pending_command():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _confirm_pending_command():
			get_viewport().set_input_as_handled()


func _begin_debug_command(command_type: int) -> bool:
	if command_flow.battle_state != CommandFlow.BattleFlowState.COMMAND_SELECT:
		if not _cancel_pending_command():
			return false

	var candidates := _get_valid_targets()
	var action_id: StringName = &"void_strike"
	var skill_cost := 0
	var energy_cost := 0
	match command_type:
		PendingCommand.CommandType.SKILL:
			action_id = &"triangle_rift"
			skill_cost = SKILL_POINT_COST_SKILL
		PendingCommand.CommandType.ULTIMATE:
			action_id = &"octagram_fragment"
			energy_cost = MAX_ULTIMATE_ENERGY
			candidates.clear()
			if not enemy.is_defeated():
				candidates.append(enemy)

	return command_flow.begin_command(
		player,
		command_type,
		action_id,
		PendingCommand.TargetRule.SINGLE_ENEMY,
		candidates,
		skill_cost,
		energy_cost,
		0,
		CommandFlow.BattleFlowState.COMMAND_SELECT,
		PendingCommand.RequestSource.TURN_COMMAND
	)


func _confirm_pending_command() -> bool:
	return command_flow.confirm_pending_command()


func _cancel_pending_command() -> bool:
	return command_flow.cancel_pending_command()


func _on_command_ready(command: PendingBattleCommand) -> void:
	current_error = ""
	debug_panel.reset_message_color()
	_start_ready_idle(command.command_type)
	_update_pending_panel(command)
	_update_action_buttons(false)


func _on_target_changed(
	command: PendingBattleCommand,
	_targets: Array
) -> void:
	_update_pending_panel(command)
	_show_target_highlight(command)


func _on_command_committed(command: PendingBattleCommand) -> void:
	_stop_ready_idle()
	_hide_target_highlight()
	debug_panel.show_execution(
		"ACTION_EXECUTION",
		_command_name(command.command_type),
		"Resource committed once. Executing existing presentation path."
	)
	call_deferred("_execute_committed_command", command)


func _on_command_cancelled(_command: PendingBattleCommand) -> void:
	_stop_ready_idle()
	_hide_target_highlight()
	_start_player_idle_animation()
	_enter_command_select("Cancelled. HP, SP, Energy, and turn are unchanged.")


func _on_command_failed(
	_command: PendingBattleCommand,
	reason: StringName
) -> void:
	current_error = String(reason)
	_stop_ready_idle()
	_hide_target_highlight()
	_start_player_idle_animation()
	_enter_command_select("Command failed safely.")
	debug_panel.show_failure(current_error)


func _on_flow_state_changed(
	battle_flow_state: int,
	_animation_state: int,
	_ui_state: int
) -> void:
	if battle_flow_state == CommandFlow.BattleFlowState.DAMAGE_AND_EFFECT_RESOLUTION:
		var command := command_flow.get_pending_command()
		if command != null:
			debug_panel.show_execution(
				"DAMAGE_AND_EFFECT_RESOLUTION",
				_command_name(command.command_type),
				"Authoritative damage entry point reached."
			)
	elif battle_flow_state == CommandFlow.BattleFlowState.ACTION_RECOVERY:
		var command := command_flow.get_pending_command()
		if command != null:
			debug_panel.show_execution(
				"ACTION_RECOVERY",
				_command_name(command.command_type),
				"Returning actor, camera, highlight, and UI to idle."
			)


func _execute_committed_command(command: PendingBattleCommand) -> void:
	if not command_flow.execute_committed_command():
		return
	state = BattleState.ACTION_RESOLUTION
	match command.command_type:
		PendingCommand.CommandType.BASIC_ATTACK:
			await _execute_basic(command)
		PendingCommand.CommandType.SKILL:
			await _execute_skill(command)
		PendingCommand.CommandType.ULTIMATE:
			await _execute_ultimate(command)


func _execute_basic(command: PendingBattleCommand) -> void:
	var target := _selected_target(command)
	if target == null:
		_abort_committed_command(command, &"target_missing_during_execution")
		return

	_set_player_action_texture(TAKASHI_BASIC_TEXTURE)
	_play_basic_sfx()
	await player.play_attack_movement(target)
	if not _execution_is_valid(command, target):
		return

	_spawn_basic_slash_effect(target)
	await get_tree().create_timer(0.08).timeout
	if not _execution_is_valid(command, target):
		return
	if not command_flow.begin_resolution(command):
		return

	target.take_damage(BASIC_ATTACK_DAMAGE)
	_show_floating_damage(target, BASIC_ATTACK_DAMAGE)
	await _play_basic_cetar_impact(target)
	if not _execution_is_valid(command, target, false):
		return
	await target.play_hit_feedback()
	if not _execution_is_valid(command, target, false):
		return

	_shake_camera()
	_add_ultimate_energy(BASIC_ATTACK_ENERGY)
	_add_skill_points(SKILL_POINT_GAIN_BASIC)
	await _finish_debug_resolution(command)


func _execute_skill(command: PendingBattleCommand) -> void:
	var target := _selected_target(command)
	if target == null:
		_abort_committed_command(command, &"target_missing_during_execution")
		return

	_set_player_action_texture(TAKASHI_SKILL_TEXTURE)
	_play_skill_sfx()
	_spawn_skill_charge_effect(player)
	await ui.play_skill_cast_feedback()
	if not _execution_is_valid(command, target):
		return

	await player.play_skill_movement(target)
	if not _execution_is_valid(command, target):
		return
	_play_skill_release_sfx()
	_spawn_triangle_rift_projectile(player, target)
	await get_tree().create_timer(SKILL_RIFT_PROJECTILE_DURATION).timeout
	if not _execution_is_valid(command, target):
		return
	if not command_flow.begin_resolution(command):
		return

	target.take_damage(SKILL_DAMAGE)
	_show_floating_damage(target, SKILL_DAMAGE)
	await _play_triangle_rift_impact(target)
	if not _execution_is_valid(command, target, false):
		return
	await target.play_hit_feedback()
	if not _execution_is_valid(command, target, false):
		return

	_add_ultimate_energy(SKILL_ENERGY)
	await _finish_debug_resolution(command)


func _execute_ultimate(command: PendingBattleCommand) -> void:
	var target := _selected_target(command)
	if target == null or target != enemy:
		_abort_committed_command(command, &"ultimate_target_not_supported")
		return

	_set_battle_ui_for_ultimate(false)
	_start_ultimate_camera_zoom_in()
	await _play_takashi_ultimate_fvx_intro()
	if not _execution_is_valid(command, target):
		_restore_after_interrupted_ultimate()
		return
	await _play_takashi_ulti_pre_animation()
	if not _execution_is_valid(command, target):
		_restore_after_interrupted_ultimate()
		return
	await _wait_for_remaining_ultimate_zoom_in()
	if not _execution_is_valid(command, target):
		_restore_after_interrupted_ultimate()
		return
	await _play_ultimate_sequence()
	if not _execution_is_valid(command, target):
		_restore_after_interrupted_ultimate()
		return

	_play_ultimate_shatter_sfx()
	_play_screen_flash(Color(0.72, 0.95, 1.0, 0.24), 0.12)
	await _play_takashi_ulti_post_animation()
	if not _execution_is_valid(command, target):
		_restore_after_interrupted_ultimate()
		return
	await _play_ultimate_camera_zoom_out()
	_set_battle_ui_for_ultimate(true)
	if not _execution_is_valid(command, target):
		return
	await player.play_ultimate_feedback()
	if not _execution_is_valid(command, target):
		return
	await player.play_skill_movement(target)
	if not _execution_is_valid(command, target):
		return
	await _play_enemy_octagram_impact()
	if not _execution_is_valid(command, target):
		return
	if not command_flow.begin_resolution(command):
		return

	target.take_damage(ULTIMATE_DAMAGE)
	_show_floating_damage(target, ULTIMATE_DAMAGE)
	await target.play_hit_feedback()
	if not _execution_is_valid(command, target, false):
		return
	await _fade_out_takashi_ultimate_glow_effect(0.26)
	await _play_enemy_impact_camera_zoom_out()
	_shake_camera()
	await _finish_debug_resolution(command)


func _finish_debug_resolution(command: PendingBattleCommand) -> void:
	if not command_flow.resolve_committed_command(command):
		return
	if not command_flow.begin_recovery(command):
		return

	_start_player_idle_animation()
	_hide_target_highlight()
	await get_tree().create_timer(recovery_hold_seconds).timeout
	if not is_instance_valid(command) or command != command_flow.get_pending_command():
		return

	if _all_targets_defeated():
		command_flow.lock_for_outcome(true)
		state = BattleState.WIN
		_update_action_buttons(false)
		debug_panel.show_outcome(true)
		return
	if not command_flow.complete_recovery(command):
		return

	if enemy_turn_enabled:
		await _run_enemy_turn()
	else:
		_enter_command_select("Recovery complete. Enemy turn disabled for test.")


func _run_enemy_turn() -> void:
	state = BattleState.ENEMY_TURN
	ui.set_turn_text("Enemy Turn")
	_update_action_buttons(false)
	debug_panel.show_execution(
		"ENEMY_TURN",
		"Enemy action",
		"Legacy enemy behavior remains active after player recovery."
	)
	await get_tree().create_timer(TURN_DELAY_SECONDS).timeout
	if state != BattleState.ENEMY_TURN:
		return

	var attacker := _first_valid_target()
	if attacker == null:
		command_flow.lock_for_outcome(true)
		debug_panel.show_outcome(true)
		return
	await attacker.play_attack_movement(player)
	if state != BattleState.ENEMY_TURN or not is_instance_valid(player):
		return

	var damage := attacker.base_attack_damage
	_play_impact_sfx()
	_spawn_enemy_claw_effect(player)
	player.take_damage(damage)
	_refresh_player_status_ui()
	_show_floating_damage(player, damage)
	await player.play_hit_feedback()
	if player.is_defeated():
		state = BattleState.LOSE
		command_flow.lock_for_outcome(false)
		_update_action_buttons(false)
		debug_panel.show_outcome(false)
		return
	_enter_command_select("Enemy turn complete. Choose the next command.")


func _validate_command_resources(command: PendingBattleCommand) -> String:
	if state in [BattleState.WIN, BattleState.LOSE]:
		return "battle_already_finished"
	if not command.has_valid_actor():
		return "actor_invalid"
	if not command.has_required_targets():
		return "target_invalid"
	if skill_points < command.skill_point_cost:
		return "insufficient_skill_points"
	if ultimate_energy < command.energy_cost:
		return "insufficient_energy"
	return ""


func _commit_command_resources(command: PendingBattleCommand) -> bool:
	if skill_points < command.skill_point_cost:
		return false
	if ultimate_energy < command.energy_cost:
		return false

	if command.skill_point_cost > 0:
		_spend_skill_points(command.skill_point_cost)
	if command.energy_cost > 0:
		ultimate_energy = maxi(ultimate_energy - command.energy_cost, 0)
		_refresh_energy_ui()
	return true


func _enter_command_select(message: String) -> void:
	state = BattleState.PLAYER_TURN
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_turn_order_highlight(true)
	_update_action_buttons(true)
	debug_panel.set_command_select(message, skill_points, ultimate_energy)


func _start_ready_idle(command_type: int) -> void:
	_stop_player_idle_animation()
	_stop_player_basic_animation()
	_stop_player_skill_animation()
	ready_frame_index = 0
	ready_frame_elapsed = 0.0
	match command_type:
		PendingCommand.CommandType.BASIC_ATTACK:
			ready_frames.assign(takashi_basic_frames)
			ready_frame_rate = TAKASHI_BASIC_FRAME_RATE
		PendingCommand.CommandType.SKILL:
			ready_frames.assign(takashi_skill_frames)
			ready_frame_rate = TAKASHI_SKILL_FRAME_RATE
		PendingCommand.CommandType.ULTIMATE:
			ready_frames.assign(takashi_ulti_pre_frames)
			ready_frame_rate = TAKASHI_ULTI_PRE_FRAME_RATE
	if not ready_frames.is_empty():
		_set_player_action_frame(ready_frames[0])


func _stop_ready_idle() -> void:
	ready_frames.clear()
	ready_frame_index = 0
	ready_frame_elapsed = 0.0


func _advance_ready_frames(delta: float) -> void:
	if ready_frames.is_empty() or player_action_sprite == null:
		return
	ready_frame_elapsed += delta
	var frame_duration := 1.0 / maxf(ready_frame_rate, 1.0)
	while ready_frame_elapsed >= frame_duration:
		ready_frame_elapsed -= frame_duration
		ready_frame_index = (ready_frame_index + 1) % ready_frames.size()
		_set_player_action_frame(ready_frames[ready_frame_index])


func _cycle_target(direction: int) -> void:
	var command := command_flow.get_pending_command()
	if command == null or command.candidate_targets.size() < 2:
		return
	command.refresh_candidates()
	if command.candidate_targets.is_empty():
		return

	var current_index := 0
	if not command.selected_targets.is_empty():
		current_index = command.candidate_targets.find(
			command.selected_targets[0]
		)
	var next_index := wrapi(
		current_index + direction,
		0,
		command.candidate_targets.size()
	)
	command_flow.set_pending_target(command.candidate_targets[next_index])


func _fill_energy() -> void:
	if command_flow.has_pending_command():
		return
	ultimate_energy = MAX_ULTIMATE_ENERGY
	_refresh_energy_ui()
	_enter_command_select("Debug Energy filled. Ultimate is now available.")


func _invalidate_selected_target() -> void:
	var command := command_flow.get_pending_command()
	var target := _selected_target(command)
	if target == null:
		return
	target.take_damage(target.max_hp)
	_show_floating_damage(target, target.max_hp)
	_update_pending_panel(command)


func _update_pending_panel(command: PendingBattleCommand) -> void:
	var target_name := "None"
	if not command.selected_targets.is_empty():
		var target := command.selected_targets[0] as Combatant
		if target != null:
			target_name = target.combatant_name
	var cost_text := "None"
	if command.skill_point_cost > 0:
		cost_text = "%d SP" % command.skill_point_cost
	elif command.energy_cost > 0:
		cost_text = "%d Energy" % command.energy_cost
	debug_panel.show_pending(
		"TARGET_SELECT",
		_command_name(command.command_type),
		cost_text,
		target_name,
		command.candidate_targets.size() > 1
	)


func _create_echo_enemy() -> void:
	echo_enemy = enemy.duplicate() as Combatant
	echo_enemy.name = "AbyssEcho"
	battle_scene.add_child(echo_enemy)
	echo_enemy.setup("Abyss Echo", 80, 10)
	var viewport_size := get_viewport().get_visible_rect().size
	echo_enemy.set_home_position(
		Vector2(viewport_size.x * 0.82, viewport_size.y * 0.70)
	)
	enemy.set_home_position(
		Vector2(viewport_size.x * 0.66, viewport_size.y * 0.70)
	)
	active_targets = [enemy, echo_enemy]


func _create_target_highlight() -> void:
	target_highlight = Line2D.new()
	target_highlight.name = "DebugTargetHighlight"
	target_highlight.width = 4.0
	target_highlight.default_color = Color(0.35, 0.95, 0.92, 0.98)
	target_highlight.closed = true
	target_highlight.z_index = 30
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		target_highlight.add_point(
			Vector2(cos(angle) * 64.0, sin(angle) * 82.0)
		)
	battle_scene.add_child(target_highlight)
	target_highlight.visible = false


func _show_target_highlight(command: PendingBattleCommand) -> void:
	target_highlight.visible = not command.selected_targets.is_empty()
	_sync_target_highlight()


func _hide_target_highlight() -> void:
	if target_highlight != null:
		target_highlight.visible = false


func _sync_target_highlight() -> void:
	if target_highlight == null or not target_highlight.visible:
		return
	var command := command_flow.get_pending_command()
	var target := _selected_target(command)
	if target == null:
		target_highlight.visible = false
		return
	target_highlight.global_position = target.global_position + Vector2(0.0, -72.0)
	target_highlight.rotation += 0.008


func _selected_target(command: PendingBattleCommand) -> Combatant:
	if command == null or command.selected_targets.is_empty():
		return null
	var target := command.selected_targets[0] as Combatant
	if target == null or not is_instance_valid(target) or target.is_defeated():
		return null
	return target


func _get_valid_targets() -> Array[Node]:
	var result: Array[Node] = []
	for target in active_targets:
		if is_instance_valid(target) and not target.is_defeated():
			result.append(target)
	return result


func _first_valid_target() -> Combatant:
	for target in active_targets:
		var combatant := target as Combatant
		if combatant != null and is_instance_valid(combatant) and not combatant.is_defeated():
			return combatant
	return null


func _all_targets_defeated() -> bool:
	return _first_valid_target() == null


func _execution_is_valid(
	command: PendingBattleCommand,
	target: Combatant,
	require_live_target: bool = true
) -> bool:
	return (
		is_inside_tree()
		and state == BattleState.ACTION_RESOLUTION
		and command_flow.is_token_active(command.commit_token)
		and is_instance_valid(player)
		and is_instance_valid(target)
		and not player.is_defeated()
		and (not require_live_target or not target.is_defeated())
	)


func _abort_committed_command(
	command: PendingBattleCommand,
	reason: StringName
) -> void:
	command_flow.command_failed.emit(command, reason)
	command_flow.lock_for_outcome(false)
	_update_action_buttons(false)


func _restore_after_interrupted_ultimate() -> void:
	_hide_takashi_ultimate_glow_effect()
	_hide_enemy_impact_fvx()
	_set_battle_ui_for_ultimate(true)
	_reset_camera()


func _command_name(command_type: int) -> String:
	match command_type:
		PendingCommand.CommandType.BASIC_ATTACK:
			return "Void Strike"
		PendingCommand.CommandType.SKILL:
			return "Triangle Rift"
		PendingCommand.CommandType.ULTIMATE:
			return "Octagram Fragment"
	return "Unknown Command"
