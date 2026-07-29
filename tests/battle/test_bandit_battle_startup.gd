extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

func _ready() -> void:
	WorldProgress.begin_bandit_encounter()
	var battle := BATTLE_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(battle)
	_verify.call_deferred(battle)

func _verify(battle: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var manager := battle.get_node("BattleManager") as BattleManager
	if not manager.is_bandit_encounter:
		push_error("Bandit encounter configuration did not load")
		get_tree().quit(1)
		return
	if manager.enemy.combatant_name != "Bandit Captain":
		push_error("Bandit Captain combatant did not initialize")
		get_tree().quit(1)
		return
	print("PASS: Bandit Captain legacy battle startup")
	get_tree().quit(0)
