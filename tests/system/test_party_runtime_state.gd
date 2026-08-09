extends Node

## PartyRuntimeState: HP/Energy persistence, per-character independence,
## idempotent initialization, and the explicit defeat-checkpoint rule.


func _ready() -> void:
	# --- Fresh character starts full, matching today's battle-start behavior ---
	var takashi := PartyRuntimeState.ensure_initialized(&"test_takashi", 100, 100, 0)
	if takashi.current_hp != 100 or takashi.current_energy != 0:
		_fail("Fresh character must start at full HP and the given starting Energy")
		return

	# --- Idempotent: re-initializing an existing character must not reset it ---
	takashi.current_hp = 62
	takashi.current_energy = 40
	var takashi_again := PartyRuntimeState.ensure_initialized(&"test_takashi", 100, 100, 0)
	if takashi_again.current_hp != 62 or takashi_again.current_energy != 40:
		_fail("ensure_initialized() must not reinitialize an already-known character")
		return
	if takashi_again != takashi:
		_fail("ensure_initialized() must return the same state object for the same ID")
		return

	# --- Battle result persists ---
	PartyRuntimeState.apply_battle_result(&"test_takashi", 25, 78, false)
	var after_battle := PartyRuntimeState.get_state(&"test_takashi")
	if after_battle.current_hp != 25 or after_battle.current_energy != 78:
		_fail("apply_battle_result() did not persist the concluded HP/Energy")
		return
	if after_battle.is_defeated:
		_fail("apply_battle_result(is_defeated=false) must not mark the character defeated")
		return

	# --- Next encounter initializes from the persisted (damaged) value ---
	var next_encounter_state := PartyRuntimeState.ensure_initialized(&"test_takashi", 100, 100, 0)
	if next_encounter_state.current_hp != 25:
		_fail("Next encounter must begin from the persisted damaged HP, not full HP")
		return

	# --- HP is clamped to max_hp/0, never out of range ---
	PartyRuntimeState.apply_battle_result(&"test_takashi", 9999, -50, true)
	var clamped := PartyRuntimeState.get_state(&"test_takashi")
	if clamped.current_hp != clamped.max_hp or clamped.current_energy != 0:
		_fail("apply_battle_result() must clamp HP/Energy into [0, max]")
		return
	if not clamped.is_defeated:
		_fail("apply_battle_result(is_defeated=true) must mark the character defeated")
		return

	# --- Explicit checkpoint-recovery rule: heals HP, clears KO, leaves Energy ---
	PartyRuntimeState.restore_after_checkpoint_recovery(&"test_takashi")
	var recovered := PartyRuntimeState.get_state(&"test_takashi")
	if recovered.current_hp != recovered.max_hp:
		_fail("Checkpoint recovery must restore full HP")
		return
	if recovered.is_defeated:
		_fail("Checkpoint recovery must clear the defeated flag")
		return
	if recovered.current_energy != 0:
		_fail("Checkpoint recovery must not touch Energy")
		return

	# --- Party independence: characters never share state ---
	var makoto := PartyRuntimeState.ensure_initialized(&"test_makoto", 80, 100, 0)
	makoto.current_hp = 10
	var takashi_untouched := PartyRuntimeState.get_state(&"test_takashi")
	if takashi_untouched.current_hp == 10:
		_fail("Changing one character's runtime state must not affect another's")
		return
	if PartyRuntimeState.get_state(&"test_makoto").max_hp != 80:
		_fail("Each character keeps its own independent max_hp")
		return

	# --- Static/runtime safety: a fresh Resource-based profile is not mutated by battle ---
	var static_profile := ExplorationEnemyProfile.new()
	static_profile.enemy_id = &"static_check"
	static_profile.detection_range = 12.0
	var duplicate_ref := static_profile
	PartyRuntimeState.apply_battle_result(&"test_takashi", 1, 1, false)
	if duplicate_ref.detection_range != 12.0:
		_fail("Unrelated static resource must be unaffected by runtime-state writes")
		return

	print("PARTY_RUNTIME_STATE_OK persistence, idempotence, clamping, checkpoint recovery, and independence verified")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
