extends Node

## Block 15: arena context resolution tests.
## Validates:
##   - abyss_forest resolves to the Abyss battle arena
##   - unknown area_id fails safely (returns null)
##   - BattleEnvironmentRegistry.resolve_from_context() works
##   - register/has_arena API

var _pass_count := 0
var _fail_count := 0
var _results: Array[String] = []


const BattleEnvProfileScript := preload("res://scripts/battle/battle_environment_profile.gd")

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run_all()
	_print_summary()
	get_tree().quit()


func _run_all() -> void:
	_test_abyss_resolves()
	_test_unknown_fails_safely()
	_test_from_context()
	_test_empty_area_id()
	_test_has_arena()
	_test_register_custom()


func _test_abyss_resolves() -> void:
	var profile = BattleEnvironmentRegistry.resolve_arena(&"abyss_forest")
	_assert("abyss_forest resolves to a non-null profile", profile != null)
	if profile != null:
		_assert("abyss_forest profile has correct area_id", profile.area_id == &"abyss_forest")
		_assert("abyss_forest profile has non-empty environment_scene",
			not profile.environment_scene.is_empty())


func _test_unknown_fails_safely() -> void:
	## Expect a push_warning but no crash; return value must be null.
	var profile = BattleEnvironmentRegistry.resolve_arena(&"nonexistent_area_xyz")
	_assert("Unknown area_id returns null safely", profile == null)


func _test_from_context() -> void:
	var context := EncounterContext.new()
	context.source_area_id = &"abyss_forest"
	var profile = BattleEnvironmentRegistry.resolve_from_context(context)
	_assert("resolve_from_context: abyss_forest resolves correctly", profile != null)


func _test_empty_area_id() -> void:
	var context := EncounterContext.new()
	context.source_area_id = &""
	var profile = BattleEnvironmentRegistry.resolve_from_context(context)
	_assert("resolve_from_context: empty area_id returns null", profile == null)


func _test_has_arena() -> void:
	_assert("has_arena: abyss_forest returns true", BattleEnvironmentRegistry.has_arena(&"abyss_forest"))
	_assert("has_arena: fake_area returns false", not BattleEnvironmentRegistry.has_arena(&"fake_area"))


func _test_register_custom() -> void:
	var custom = BattleEnvProfileScript.new()
	custom.arena_id = &"test_custom_arena"
	custom.area_id = &"test_area_99"
	BattleEnvironmentRegistry.register(custom)
	_assert("register: custom arena becomes resolvable",
		BattleEnvironmentRegistry.has_arena(&"test_area_99"))
	var resolved = BattleEnvironmentRegistry.resolve_arena(&"test_area_99")
	_assert("register: resolved profile matches registered profile", resolved == custom)


func _assert(test_name: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		_results.append("  PASS  %s" % test_name)
	else:
		_fail_count += 1
		_results.append("  FAIL  %s" % test_name)


func _print_summary() -> void:
	print("=== Block 15 Arena Context Tests ===")
	for r in _results:
		print(r)
	var total := _pass_count + _fail_count
	print("--- %d/%d passed ---" % [_pass_count, total])
