extends Node
class_name BattleManager

enum BattleState {
	PLAYER_TURN,
	ATTACK_TIMING,
	ACTION_RESOLUTION,
	ENEMY_TURN,
	WIN,
	LOSE
}

const PLAYER_MAX_HP: int = 100
const ENEMY_MAX_HP: int = 120
const BASIC_ATTACK_DAMAGE: int = 12
const BASIC_ATTACK_GOOD_DAMAGE: int = 18
const BASIC_ATTACK_ENERGY: int = 25
const SKILL_DAMAGE: int = 25
const SKILL_ENERGY: int = 15
const SKILL_POINT_GAIN_BASIC: int = 1
const SKILL_POINT_COST_SKILL: int = 1
const START_SKILL_POINTS: int = 3
const MAX_SKILL_POINTS: int = 5
const ULTIMATE_DAMAGE: int = 45
const MAX_ULTIMATE_ENERGY: int = 100
const ENEMY_BASE_DAMAGE: int = 14
const TURN_DELAY_SECONDS: float = 0.6
const FLOATING_TEXT_RISE: float = 42.0
const CAMERA_SHAKE_OFFSET: float = 6.0
const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const PLAYER_VIEWPORT_POSITION: Vector2 = Vector2(0.25, 0.68)
const ENEMY_VIEWPORT_POSITION: Vector2 = Vector2(0.72, 0.68)
const PROLOGUE_SCENE_PATH: String = "res://scenes/prologue/prologue_scene.tscn"
const ENDING_SCENE_PATH: String = "res://scenes/ending/ending_scene.tscn"

@onready var player: Combatant = $"../Player"
@onready var enemy: Combatant = $"../Enemy"
@onready var ui: BattleUI = $"../CanvasLayer/BattleUI"
@onready var timing_bar: TimingBar = $"../CanvasLayer/BattleUI/TimingBar"
@onready var battle_scene: Node2D = $".."
@onready var battle_camera: Camera2D = get_node_or_null("../BattleCamera") as Camera2D
@onready var sky: Polygon2D = get_node_or_null("../Background/Sky") as Polygon2D
@onready var forest_line: Polygon2D = get_node_or_null("../Background/ForestLine") as Polygon2D
@onready var ground: Polygon2D = get_node_or_null("../Background/Ground") as Polygon2D

var state: int = BattleState.PLAYER_TURN
var ultimate_energy: int = 0
var skill_points: int = START_SKILL_POINTS


func _ready() -> void:
	player.setup("Takashi", PLAYER_MAX_HP, BASIC_ATTACK_DAMAGE)
	enemy.setup("Lesser Abyss", ENEMY_MAX_HP, ENEMY_BASE_DAMAGE)

	ui.attack_pressed.connect(_on_attack_pressed)
	ui.skill_pressed.connect(_on_skill_pressed)
	ui.ultimate_pressed.connect(_on_ultimate_pressed)
	ui.restart_pressed.connect(_on_restart_pressed)
	ui.confirm_pressed.connect(_on_confirm_pressed)
	timing_bar.timing_finished.connect(_on_timing_finished)
	if battle_camera != null:
		battle_camera.enabled = true

	await get_tree().process_frame
	_apply_runtime_layout()
	restart_battle()


func restart_battle() -> void:
	_reset_battle_values()
	_begin_player_turn("A Lesser Abyss appears. Choose Takashi's first action.")


func _reset_battle_values() -> void:
	player.reset_hp()
	enemy.reset_hp()
	ultimate_energy = 0
	skill_points = START_SKILL_POINTS
	_reset_camera()
	timing_bar.cancel_window()
	ui.set_timing_mode(false)
	ui.set_restart_visible(false)
	_refresh_hp_labels()
	_refresh_energy_ui()
	_refresh_skill_points_ui()


func _apply_runtime_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_VIEWPORT_SIZE

	if battle_camera != null:
		battle_camera.enabled = true
		battle_camera.position = viewport_size * 0.5
		battle_camera.offset = Vector2.ZERO

	if sky != null:
		sky.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(viewport_size.x, 0.0),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])
	if forest_line != null:
		forest_line.polygon = PackedVector2Array([
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
	if ground != null:
		ground.polygon = PackedVector2Array([
			Vector2(0.0, viewport_size.y * 0.72),
			Vector2(viewport_size.x, viewport_size.y * 0.69),
			viewport_size,
			Vector2(0.0, viewport_size.y)
		])

	player.z_index = 5
	enemy.z_index = 5
	player.set_home_position(Vector2(viewport_size.x * PLAYER_VIEWPORT_POSITION.x, viewport_size.y * PLAYER_VIEWPORT_POSITION.y))
	enemy.set_home_position(Vector2(viewport_size.x * ENEMY_VIEWPORT_POSITION.x, viewport_size.y * ENEMY_VIEWPORT_POSITION.y))


func _begin_player_turn(log_text: String = "Your turn. Choose an action.") -> void:
	if _is_battle_over():
		return

	state = BattleState.PLAYER_TURN
	ui.set_battle_input_enabled(true)
	ui.set_turn_text("Player Turn")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	ui.set_restart_visible(true)
	_update_action_buttons(true)


func _begin_enemy_turn(log_text: String = "Enemy is preparing to attack.") -> void:
	if _is_battle_over():
		return

	state = BattleState.ENEMY_TURN
	ui.set_turn_text("Enemy Turn")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	_update_action_buttons(false)

	await get_tree().create_timer(TURN_DELAY_SECONDS).timeout
	if state == BattleState.ENEMY_TURN:
		_enemy_attack()


func _start_attack_timing() -> void:
	state = BattleState.ATTACK_TIMING
	ui.set_turn_text("Void Strike")
	ui.set_battle_log("Confirm near the green timing zone for stronger Void Strike damage.")
	ui.set_timing_mode(true)
	timing_bar.start_window()


func _enemy_attack() -> void:
	var damage: int = enemy.base_attack_damage
	var log_text: String = "Enemy attacks for %d damage." % damage

	await enemy.play_attack_movement(player)
	if state != BattleState.ENEMY_TURN:
		return

	player.take_damage(damage)
	_show_floating_damage(player, damage)
	await player.play_hit_feedback()
	_shake_camera()
	_refresh_hp_labels()

	if player.is_defeated():
		_lose("You were defeated.")
		return

	_begin_player_turn(log_text)


func _on_attack_pressed() -> void:
	if state == BattleState.PLAYER_TURN:
		_start_attack_timing()
	elif state == BattleState.ATTACK_TIMING:
		timing_bar.confirm()


func _on_confirm_pressed() -> void:
	if state == BattleState.ATTACK_TIMING:
		timing_bar.confirm()


func _on_skill_pressed() -> void:
	if state != BattleState.PLAYER_TURN or skill_points < SKILL_POINT_COST_SKILL:
		return

	state = BattleState.ACTION_RESOLUTION
	_update_action_buttons(false)
	ui.set_turn_text("Triangle Rift")
	ui.set_battle_log("Triangle Rift spends %d Skill Point and generates %d energy." % [SKILL_POINT_COST_SKILL, SKILL_ENERGY])
	_spend_skill_points(SKILL_POINT_COST_SKILL)
	await player.play_skill_movement(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		return

	enemy.take_damage(SKILL_DAMAGE)
	_show_floating_damage(enemy, SKILL_DAMAGE)
	await enemy.play_hit_feedback()
	_shake_camera()
	_add_ultimate_energy(SKILL_ENERGY)
	_refresh_hp_labels()
	_finish_player_action("Triangle Rift deals %d damage." % SKILL_DAMAGE)


func _on_ultimate_pressed() -> void:
	if state != BattleState.PLAYER_TURN or ultimate_energy < MAX_ULTIMATE_ENERGY:
		return

	state = BattleState.ACTION_RESOLUTION
	_update_action_buttons(false)
	ui.set_turn_text("Octagram Fragment")
	ui.set_battle_log("Octagram Fragment flashes for %d damage." % ULTIMATE_DAMAGE)
	ultimate_energy = 0
	_refresh_energy_ui()
	await player.play_ultimate_feedback()
	if state != BattleState.ACTION_RESOLUTION:
		return

	await player.play_skill_movement(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		return

	enemy.take_damage(ULTIMATE_DAMAGE)
	_show_floating_damage(enemy, ULTIMATE_DAMAGE)
	await enemy.play_hit_feedback()
	_shake_camera()
	_refresh_hp_labels()
	_finish_player_action("Octagram Fragment deals %d damage and consumes all energy." % ULTIMATE_DAMAGE)


func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file(PROLOGUE_SCENE_PATH)


func _on_timing_finished(good_timing: bool, confirmed: bool) -> void:
	if state != BattleState.ATTACK_TIMING:
		return

	ui.set_timing_mode(false)
	_update_action_buttons(false)
	state = BattleState.ACTION_RESOLUTION

	var damage: int = BASIC_ATTACK_GOOD_DAMAGE if good_timing else BASIC_ATTACK_DAMAGE
	await player.play_attack_movement(enemy)
	if state != BattleState.ACTION_RESOLUTION:
		return

	enemy.take_damage(damage)
	_show_floating_damage(enemy, damage)
	await enemy.play_hit_feedback()
	_shake_camera()
	_add_ultimate_energy(BASIC_ATTACK_ENERGY)
	_add_skill_points(SKILL_POINT_GAIN_BASIC)
	_refresh_hp_labels()

	var log_text: String = "Void Strike deals %d damage, gains %d energy, and restores %d Skill Point." % [damage, BASIC_ATTACK_ENERGY, SKILL_POINT_GAIN_BASIC]
	if good_timing:
		log_text = "Good timing. Void Strike deals %d damage, gains %d energy, and restores %d Skill Point." % [damage, BASIC_ATTACK_ENERGY, SKILL_POINT_GAIN_BASIC]
	elif not confirmed:
		log_text = "Timing window closes. Void Strike deals %d damage, gains %d energy, and restores %d Skill Point." % [damage, BASIC_ATTACK_ENERGY, SKILL_POINT_GAIN_BASIC]

	_finish_player_action(log_text)


func _win(log_text: String) -> void:
	state = BattleState.WIN
	timing_bar.cancel_window()
	ui.set_turn_text("Victory")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	_update_action_buttons(false)
	ui.set_restart_visible(true)
	await get_tree().create_timer(0.8).timeout
	if state == BattleState.WIN:
		get_tree().change_scene_to_file(ENDING_SCENE_PATH)


func _lose(log_text: String) -> void:
	state = BattleState.LOSE
	timing_bar.cancel_window()
	ui.set_turn_text("Defeat")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	_update_action_buttons(false)
	ui.set_restart_visible(true)


func _refresh_hp_labels() -> void:
	ui.set_hp_text(player.get_hp_text(), enemy.get_hp_text())


func _refresh_energy_ui() -> void:
	ui.set_energy(ultimate_energy, MAX_ULTIMATE_ENERGY)


func _refresh_skill_points_ui() -> void:
	ui.set_skill_points(skill_points, MAX_SKILL_POINTS)


func _update_action_buttons(enabled: bool) -> void:
	ui.set_actions_enabled(enabled, ultimate_energy >= MAX_ULTIMATE_ENERGY, skill_points >= SKILL_POINT_COST_SKILL)


func _add_ultimate_energy(amount: int) -> void:
	ultimate_energy = mini(ultimate_energy + amount, MAX_ULTIMATE_ENERGY)
	_refresh_energy_ui()


func _add_skill_points(amount: int) -> void:
	skill_points = mini(skill_points + amount, MAX_SKILL_POINTS)
	_refresh_skill_points_ui()


func _spend_skill_points(amount: int) -> void:
	skill_points = maxi(skill_points - amount, 0)
	_refresh_skill_points_ui()


func _finish_player_action(log_text: String) -> void:
	_refresh_energy_ui()
	_refresh_skill_points_ui()
	if enemy.is_defeated():
		_win("Enemy defeated. You win!")
		return

	_begin_enemy_turn(log_text)


func _is_battle_over() -> bool:
	return state == BattleState.WIN or state == BattleState.LOSE


func _show_floating_damage(target: Combatant, damage: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % damage
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	battle_scene.add_child(label)

	var start_position: Vector2 = target.position + Vector2(-18.0, -105.0)
	label.position = start_position

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", start_position + Vector2(0.0, -FLOATING_TEXT_RISE), 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)


func _shake_camera() -> void:
	if battle_camera == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(battle_camera, "offset", Vector2(CAMERA_SHAKE_OFFSET, 0.0), 0.03)
	tween.tween_property(battle_camera, "offset", Vector2(-CAMERA_SHAKE_OFFSET, 0.0), 0.05)
	tween.tween_property(battle_camera, "offset", Vector2.ZERO, 0.04)


func _reset_camera() -> void:
	if battle_camera != null:
		battle_camera.offset = Vector2.ZERO
