extends Node
class_name BattleManager

enum BattleState {
	PLAYER_TURN,
	ATTACK_TIMING,
	ENEMY_TURN,
	WIN,
	LOSE
}

const PLAYER_MAX_HP: int = 100
const ENEMY_MAX_HP: int = 80
const PLAYER_BASE_DAMAGE: int = 15
const PLAYER_GOOD_DAMAGE: int = 25
const ENEMY_BASE_DAMAGE: int = 12
const GUARDED_DAMAGE_MULTIPLIER: float = 0.5
const TURN_DELAY_SECONDS: float = 0.6
const FLOATING_TEXT_RISE: float = 42.0
const CAMERA_SHAKE_OFFSET: float = 6.0

@onready var player: Combatant = $"../Player"
@onready var enemy: Combatant = $"../Enemy"
@onready var ui: BattleUI = $"../CanvasLayer/BattleUI"
@onready var timing_bar: TimingBar = $"../CanvasLayer/BattleUI/TimingBar"
@onready var battle_scene: Node2D = $".."
@onready var battle_camera: Camera2D = get_node_or_null("../BattleCamera") as Camera2D

var state: int = BattleState.PLAYER_TURN
var player_guarded: bool = false


func _ready() -> void:
	player.setup("Player", PLAYER_MAX_HP, PLAYER_BASE_DAMAGE)
	enemy.setup("Enemy", ENEMY_MAX_HP, ENEMY_BASE_DAMAGE)

	ui.attack_pressed.connect(_on_attack_pressed)
	ui.guard_pressed.connect(_on_guard_pressed)
	ui.restart_pressed.connect(_on_restart_pressed)
	ui.confirm_pressed.connect(_on_confirm_pressed)
	timing_bar.timing_finished.connect(_on_timing_finished)

	await get_tree().process_frame
	restart_battle()


func restart_battle() -> void:
	player.reset_hp()
	enemy.reset_hp()
	player_guarded = false
	_reset_camera()
	timing_bar.cancel_window()
	ui.set_timing_mode(false)
	ui.set_restart_visible(false)
	_refresh_hp_labels()
	_begin_player_turn("Battle started. Choose an action.")


func _begin_player_turn(log_text: String = "Your turn. Choose an action.") -> void:
	if _is_battle_over():
		return

	state = BattleState.PLAYER_TURN
	player_guarded = false
	ui.set_turn_text("Player Turn")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	ui.set_actions_enabled(true)


func _begin_enemy_turn(log_text: String = "Enemy is preparing to attack.") -> void:
	if _is_battle_over():
		return

	state = BattleState.ENEMY_TURN
	ui.set_turn_text("Enemy Turn")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	ui.set_actions_enabled(false)

	await get_tree().create_timer(TURN_DELAY_SECONDS).timeout
	if state == BattleState.ENEMY_TURN:
		_enemy_attack()


func _start_attack_timing() -> void:
	state = BattleState.ATTACK_TIMING
	ui.set_turn_text("Attack Timing")
	ui.set_battle_log("Press Space, Enter, or click Confirm near the middle of the bar.")
	ui.set_timing_mode(true)
	timing_bar.start_window()


func _enemy_attack() -> void:
	var damage: int = enemy.base_attack_damage
	var log_text: String = "Enemy attacks for %d damage." % damage

	if player_guarded:
		damage = int(ceil(damage * GUARDED_DAMAGE_MULTIPLIER))
		log_text = "Your guard reduces the enemy attack to %d damage." % damage

	await enemy.play_attack_movement(player)
	if state != BattleState.ENEMY_TURN:
		return

	player.take_damage(damage)
	_show_floating_damage(player, damage)
	await player.play_hit_feedback()
	_shake_camera()
	player_guarded = false
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


func _on_guard_pressed() -> void:
	if state != BattleState.PLAYER_TURN:
		return

	player_guarded = true
	state = BattleState.ENEMY_TURN
	ui.set_actions_enabled(false)
	ui.set_battle_log("You guard and brace for the next attack.")
	await player.play_guard_feedback()
	if state == BattleState.ENEMY_TURN and player_guarded:
		_begin_enemy_turn("You guard and brace for the next attack.")


func _on_restart_pressed() -> void:
	restart_battle()


func _on_timing_finished(good_timing: bool, confirmed: bool) -> void:
	if state != BattleState.ATTACK_TIMING:
		return

	ui.set_timing_mode(false)
	ui.set_actions_enabled(false)

	var damage: int = PLAYER_GOOD_DAMAGE if good_timing else player.base_attack_damage
	await player.play_attack_movement(enemy)
	if state != BattleState.ATTACK_TIMING:
		return

	enemy.take_damage(damage)
	_show_floating_damage(enemy, damage)
	await enemy.play_hit_feedback()
	_shake_camera()
	_refresh_hp_labels()

	var log_text: String = "Attack lands for %d damage." % damage
	if good_timing:
		log_text = "Good timing! Attack deals %d damage." % damage
	elif not confirmed:
		log_text = "The timing window closes. Attack deals %d damage." % damage

	if enemy.is_defeated():
		_win("Enemy defeated. You win!")
		return

	_begin_enemy_turn(log_text)


func _win(log_text: String) -> void:
	state = BattleState.WIN
	timing_bar.cancel_window()
	ui.set_turn_text("Victory")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	ui.set_actions_enabled(false)
	ui.set_restart_visible(true)


func _lose(log_text: String) -> void:
	state = BattleState.LOSE
	timing_bar.cancel_window()
	ui.set_turn_text("Defeat")
	ui.set_battle_log(log_text)
	ui.set_timing_mode(false)
	ui.set_actions_enabled(false)
	ui.set_restart_visible(true)


func _refresh_hp_labels() -> void:
	ui.set_hp_text(player.get_hp_text(), enemy.get_hp_text())


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
