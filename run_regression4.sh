#!/bin/bash
GODOT="C:\Users\Lenovo\Downloads\Godot_v4.7-stable_win64.exe"
TESTS=(
  "tests/system/test_party_runtime_state.tscn"
  "tests/system/test_battle_session_coordinator.tscn"
  "tests/system/test_block15_arena_context.tscn"
  "tests/system/test_music_overlap_guard.tscn"
  "tests/battle/test_block14_battle_bridge.tscn"
  "tests/battle/test_block14_5_hud_battle_flow.tscn"
  "tests/battle/test_block14_5_multi_enemy_target_selection.tscn"
  "tests/battle/test_block15_3d_presentation_wiring.tscn"
  "tests/battle/test_block15_3d_arena.tscn"
  "tests/battle/test_block15_battle_camera.tscn"
  "tests/battle/test_bandit_battle_startup.tscn"
  "tests/battle/test_multi_enemy_targeting_production.tscn"
  "tests/battle/test_production_basic_command_flow.tscn"
  "tests/battle/test_production_skill_command_flow.tscn"
  "tests/battle/test_production_ultimate_command_flow.tscn"
  "tests/battle/test_command_ux_no_panel.tscn"
  "tests/battle/test_combat_feel_timing.tscn"
  "tests/battle/test_enemy_attack_guard_chain.tscn"
  "tests/battle/test_interrupt_state_cleanup.tscn"
  "tests/battle/test_ultimate_interrupt_queue.tscn"
  "tests/battle/test_ultimate_off_turn_interrupt.tscn"
  "tests/battle/test_window_a1_ultimate_interrupt.tscn"
  "tests/battle/test_battle_command_debug_scene.tscn"
  "tests/world_3d/test_abyss_battle_return.tscn"
  "tests/world_3d/test_abyss_enemy_patrol_behavior.tscn"
  "tests/world_3d/test_abyss_enemy_testbed.tscn"
  "tests/world_3d/test_abyss_exploration_hud_actions.tscn"
  "tests/world_3d/test_abyss_forest_3d.tscn"
  "tests/world_3d/test_block15_exploration_actions.tscn"
  "tests/world_3d/test_camera_obstruction.tscn"
  "tests/world_3d/test_camera_player_control.tscn"
  "tests/world_3d/test_camera_presets.tscn"
  "tests/world_3d/test_controller_jump_isolated.tscn"
  "tests/world_3d/test_exploration_camera_reusability.tscn"
  "tests/world_3d/test_exploration_character_controller.tscn"
  "tests/world_3d/test_exploration_enemy_3d.tscn"
  "tests/world_3d/test_exploration_spawn_point.tscn"
  "tests/world_3d/test_input_gating_game_flow_state.tscn"
  "tests/world_3d/test_pickup_and_trigger.tscn"
)
rm -f regression4_summary.log
for t in "${TESTS[@]}"; do
  if [ ! -f "$t" ]; then
    echo "=== $t (MISSING FILE) ===" >> regression4_summary.log
    continue
  fi
  logfile="regression4_$(basename "$t" .tscn).log"
  timeout 60 "$GODOT" --headless --path . "$t" > "$logfile" 2>&1
  code=$?
  echo "=== $t (exit $code) ===" >> regression4_summary.log
  tail -n 8 "$logfile" >> regression4_summary.log
  echo "" >> regression4_summary.log
done
echo "REGRESSION4_RUN_COMPLETE" >> regression4_summary.log
