#!/bin/bash
GODOT="C:\Users\Lenovo\Downloads\Godot_v4.7-stable_win64.exe"
TESTS=(
  "tests/battle/test_production_basic_command_flow.tscn"
  "tests/battle/test_production_skill_command_flow.tscn"
  "tests/battle/test_production_ultimate_command_flow.tscn"
  "tests/battle/test_multi_enemy_targeting_production.tscn"
  "tests/battle/test_bandit_battle_startup.tscn"
  "tests/battle/test_window_a1_ultimate_interrupt.tscn"
  "tests/battle/test_ultimate_off_turn_interrupt.tscn"
  "tests/battle/test_interrupt_state_cleanup.tscn"
  "tests/battle/test_command_ux_no_panel.tscn"
  "tests/battle/test_block14_battle_bridge.tscn"
  "tests/battle/test_block14_5_hud_battle_flow.tscn"
  "tests/battle/test_block14_5_multi_enemy_target_selection.tscn"
  "tests/battle/test_block15_3d_presentation_wiring.tscn"
  "tests/battle/test_block15_3d_arena.tscn"
  "tests/battle/test_block15_battle_camera.tscn"
)
rm -f regression_fable_summary.log
for t in "${TESTS[@]}"; do
  logfile="regression_fable_$(basename "$t" .tscn).log"
  timeout 200 "$GODOT" --headless --path . "$t" > "$logfile" 2>&1
  code=$?
  echo "=== $t (exit $code) ===" >> regression_fable_summary.log
  tail -n 8 "$logfile" >> regression_fable_summary.log
  echo "" >> regression_fable_summary.log
done
echo "REGRESSION_FABLE_RUN_COMPLETE" >> regression_fable_summary.log
