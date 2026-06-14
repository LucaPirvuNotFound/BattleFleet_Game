# Admiral AI Evaluation Pipeline

This evaluation framework tests the admiral AI decision-making across diverse game scenarios, measuring both performance metrics and decision accuracy.

## Directory Structure

```
backend/
├── eval_dataset/
│   └── game_states.json          # 10 curated game scenarios
├── evals_output/
│   ├── eval_admiral.py           # Main evaluation script
│   ├── evaluation_results.json    # Output results (generated after running)
│   └── README.md                 # This file
└── services/
    └── ai_service.py             # Admiral AI service being tested
```

## Game Scenarios

The `game_states.json` contains 10 diverse scenarios:

1. **scenario_1_close_target_direct_ahead**: Single corvette vs corvette, target directly ahead
2. **scenario_2_medium_distance_angled**: Cruiser vs Destroyer at medium range, 45° angle
3. **scenario_3_far_target**: Battleship vs Cruiser at maximum weapon range
4. **scenario_4_multiple_targets**: Single destroyer with 2 visible enemy ships
5. **scenario_5_low_hp_target**: Corvette vs critically low-HP torpedo boat
6. **scenario_6_rear_enemy**: Destroyer vs enemy at rear (180° angle)
7. **scenario_7_side_attack**: Battleship vs Destroyer on starboard side (90° angle)
8. **scenario_8_out_of_range**: Light Cannon corvette vs far cruiser (just out of range)
9. **scenario_9_multiple_ai_ships**: Two AI ships (corvette + destroyer) vs single enemy cruiser
10. **scenario_10_complex_tactical**: Low-HP battleship vs multiple enemies (resource-constrained scenario)

## Metrics Collected

### Performance Metrics
- **latency_ms**: Total time from request to response (milliseconds)
- **ttft_ms**: Time to First Token (estimated from response size)
- **tps**: Tokens Per Second (throughput)

### Validation Metrics
- **validation.success**: Response has correct JSON structure
- **validation.errors**: List of validation failures

### Decision Accuracy Metrics
- **decision_to_shoot**: Boolean - did the AI decide to fire a weapon?
- **bearing_error_deg**: How far off was the chosen bearing from the target? (degrees)
- **weapon_valid**: Did the AI choose an available weapon?
- **closest_enemy_dist**: Distance to the closest enemy ship
- **target_selection_valid**: Is the target within weapon range?

### Summary Statistics
- **decision_to_shoot_rate**: Percentage of scenarios where AI chooses to shoot
- **avg_bearing_error_deg**: Average angular error when aiming
- **weapon_validity_rate**: Percentage of shots using valid weapons

## Running the Evaluation

### Option 1: Direct Python Import (Recommended)
```bash
cd /home/lucap/BattleFleet_Game/backend
python3 evals_output/eval_admiral.py
```

This uses the `get_admiral_decision()` function directly from `ai_service.py`.

### Option 2: Via HTTP API
Modify `eval_admiral.py` to import `requests` and call the HTTP endpoint at `http://localhost:8001/ai/admiral_turn` instead of the direct function.

## Example Output

After running, `evaluation_results.json` will contain:

```json
{
  "metadata": {
    "evaluation_date": "2026-06-14T...",
    "total_scenarios": 10,
    "dataset_file": "..."
  },
  "scenarios": [
    {
      "scenario_id": "scenario_1_close_target_direct_ahead",
      "description": "...",
      "status": "success",
      "latency_ms": 8.42,
      "ttft_ms": 0.84,
      "tps": 125.5,
      "response": {...},
      "validation": {
        "success": true,
        "errors": []
      },
      "accuracy": {
        "decision_to_shoot": true,
        "bearing_error_deg": 2.3,
        "weapon_valid": true,
        "closest_enemy_dist": 80.0,
        "target_selection_valid": true
      }
    },
    ...
  ],
  "summary": {
    "total_evaluated": 10,
    "successful": 10,
    "failed": 0,
    "invalid_responses": 0,
    "avg_latency_ms": 8.15,
    "avg_ttft_ms": 0.82,
    "avg_tps": 123.4,
    "decision_to_shoot_rate": 80.0,
    "avg_bearing_error_deg": 3.7,
    "weapon_validity_rate": 95.0
  }
}
```

## Interpreting Results

### Performance
- **Latency < 20ms**: Excellent (model cached in RAM)
- **Latency 20-100ms**: Good (acceptable for turn-based gameplay)
- **Latency > 100ms**: Poor (model loading overhead or generation delay)

### Accuracy
- **Bearing Error < 5°**: Excellent aiming
- **Bearing Error 5-15°**: Good aiming
- **Bearing Error > 15°**: Poor aiming

- **Decision to Shoot Rate > 70%**: AI is aggressive/tactical
- **Weapon Validity Rate > 90%**: AI chooses appropriate weapons

## Extending the Evaluation

To add new metrics or test scenarios:

1. **Add new game state** to `eval_dataset/game_states.json`
2. **Add new validation** logic in `validate_response()`
3. **Add new accuracy metric** in `measure_accuracy()`
4. **Update summary statistics** in `evaluate_all_scenarios()`

### Example: Add Damage Output Metric
```python
def estimate_damage(response: dict, game_context: dict) -> float:
    """Estimate total damage output from the decision."""
    total_damage = 0
    for action in response.get("actions", []):
        for order in action.get("orders", []):
            if order.get("type") == "fire":
                weapon = order.get("weapon")
                # Look up weapon damage from rules
                ...
    return total_damage
```

## Troubleshooting

### "Import Error: No module named 'services'"
Run from the `backend/` directory and ensure `PYTHONPATH` includes the backend folder.

### "Network error connecting to Ollama"
If using the fallback admiral (rule-based), the script will still work. Check `ai_service.py` logs for Ollama errors.

### Slow evaluation
If latency is high (>30s per scenario), the Ollama model may be loading from disk. This is expected on first run after server restart.

## Future Enhancements

- [ ] HTTP API tests (via `requests` library)
- [ ] Multi-turn decision consistency tests
- [ ] Adversarial scenario generation (auto-create challenging scenarios)
- [ ] Performance profiling (memory usage, CPU load)
- [ ] Comparison tests (admiral vs fallback rule-based AI)
- [ ] Batch evaluation across model versions
