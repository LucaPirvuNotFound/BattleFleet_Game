# Admiral AI Evaluation Pipeline - Complete Guide

## 📋 Overview

You now have a complete evaluation framework for testing the admiral AI's decision-making across diverse game scenarios. The system measures both performance metrics (latency, throughput) and decision accuracy (aiming, weapon choice, tactical decisions).

## 📂 Files Created

### Dataset
- **`backend/eval_dataset/game_states.json`** (16 KB)
  - 10 diverse game scenarios
  - Each with AI fleet, visible enemies, positions, weapons, HP
  - Covers various tactical situations

### Evaluation System  
- **`backend/evals_output/eval_admiral.py`** (14 KB) — Main evaluation script
  - Loads game states
  - Calls `get_admiral_decision()` from `ai_service.py`
  - Measures performance and accuracy
  - Validates responses
  - Generates JSON results

- **`backend/evals_output/view_results.py`** — Results viewer
  - Pretty-prints evaluation results
  - Shows summary statistics and per-scenario breakdown
  - Provides tactical assessment

### Documentation
- **`backend/evals_output/README.md`** — Full documentation
- **`backend/evals_output/QUICK_START.md`** — Quick reference
- **`backend/evals_output/.gitignore`** — Prevents committing generated results

## 🚀 Quick Start

### Run the evaluation:
```bash
cd /home/lucap/BattleFleet_Game/backend
python3 evals_output/eval_admiral.py
```

### View results:
```bash
python3 evals_output/view_results.py
# Or: python3 evals_output/view_results.py evals_output/evaluation_results.json
```

## 📊 What Gets Measured

### Performance Metrics
| Metric | Meaning | Expected |
|--------|---------|----------|
| **latency_ms** | Total request time | < 20ms (cached) or ~80s (cold start) |
| **ttft_ms** | Time to first token | < 2ms |
| **tps** | Tokens per second | 100-200 tokens/sec |

### Validation Metrics
- ✅ Response has correct JSON structure
- ✅ All ship indices are valid
- ✅ All actions are valid (move/fire with correct fields)

### Accuracy Metrics
| Metric | Meaning | Interpretation |
|--------|---------|-----------------|
| **decision_to_shoot** | Did AI decide to fire? | Boolean (true/false) |
| **bearing_error_deg** | Angle error from target | 0-180°. Lower = better aim |
| **weapon_valid** | Is the chosen weapon available? | Boolean |
| **closest_enemy_dist** | Distance to nearest enemy | Used for context |
| **target_selection_valid** | Is target within weapon range? | Boolean |

### Summary Statistics
- **decision_to_shoot_rate** — % of scenarios where AI shoots (70-90% is tactical)
- **avg_bearing_error_deg** — Average aiming accuracy (< 5° is excellent)
- **weapon_validity_rate** — % of shots using valid weapons (> 90% is good)

## 🎮 The 10 Test Scenarios

Each scenario tests different aspects of decision-making:

1. **Close target, direct ahead** — Basic engagement, should move & shoot
2. **Medium distance, 45° angle** — Requires bearing calculation, angled attack
3. **Far target at max range** — Should use long-range weapon (Heavy Battery)
4. **Multiple targets** — Should pick closest/most dangerous
5. **Low HP target** — High priority, should aggress despite weakness
6. **Rear enemy (180°)** — Requires rotating, inverse bearing
7. **Side attack (90°)** — Perpendicular engagement
8. **Out of range** — Should move closer OR use long-range weapon
9. **Multiple AI ships** — Coordination challenge, one ship making decision
10. **Complex tactical** — Low HP battleship vs multiple enemies (defensive scenario)

## 📈 Example Output

After running, you'll see:

```
🎮 Admiral AI Evaluation Pipeline
📊 Testing 10 scenarios
⏱️  Starting evaluation at 2026-06-14T...

[1/10] Evaluating scenario_1_close_target_direct_ahead... ✅ (8.42 ms)
[2/10] Evaluating scenario_2_medium_distance_angled... ✅ (7.89 ms)
...
[10/10] Evaluating scenario_10_complex_tactical... ✅ (9.15 ms)

============================================================
📊 EVALUATION SUMMARY
============================================================
✓ Total Evaluated:        10
✓ Successful:             10
✗ Failed:                 0
⚠ Invalid Responses:      0

⏱️  Average Latency:        8.15 ms
⏱️  Average TTFT:           0.82 ms
📈 Average TPS:            123.4 tokens/sec

🎯 Decision to Shoot Rate: 80.0%
🎯 Avg Bearing Error:      3.7°
🎯 Weapon Validity Rate:   95.0%
============================================================

💾 Results saved to: evals_output/evaluation_results.json
```

## 📁 Output Files

The evaluation generates:
- **`evaluation_results.json`** — Complete detailed results
  - Metadata (date, total scenarios, file reference)
  - Per-scenario results (status, latency, response, validation, accuracy)
  - Summary statistics (counts, averages, rates)

## 🔍 Extending the Evaluation

### Add a new test scenario:
1. Edit `eval_dataset/game_states.json`
2. Add new object to the array with `id`, `description`, `match_id`, `round`, `ai_fleet`, `visible_human_ships`, `rules`
3. Re-run evaluation

### Add a new metric:
1. Create a new function in `eval_admiral.py` (e.g., `measure_damage_output()`)
2. Call it in `evaluate_scenario()`
3. Store result in the `result` dict

Example:
```python
def calculate_fleet_coordination(response: dict, game_context: dict) -> float:
    """Measure how coordinated multi-ship decisions are."""
    actions = response.get("actions", [])
    if len(actions) <= 1:
        return 0.0  # Single ship, no coordination needed
    # Calculate coordination score...
    return coordination_score
```

## 🔧 Troubleshooting

### "No module named 'services'"
```bash
cd backend  # Must run from backend directory
python3 evals_output/eval_admiral.py
```

### Slow first run (>60s latency)
Normal on first run after server restart — Ollama is loading models from disk. Subsequent runs will be 10-20ms.

### All responses invalid
Check `evaluation_results.json` for error details. Common issues:
- Ollama not running
- Invalid response format from LLM
- Python version mismatch

### Want to test via HTTP API instead?
Replace the import in `eval_admiral.py`:
```python
# Old: from services.ai_service import get_admiral_decision
# New: use httpx to call http://localhost:8001/ai/admiral_turn
```

## 📊 Interpreting Results

### Performance
- ✅ < 20ms — Excellent (model cached)
- ⚠️ 20-100ms — Good (acceptable delay)
- ❌ > 100ms — Poor (model loading/generation slow)

### Accuracy
- ✅ Bearing error < 5° — Excellent aiming
- ⚠️ Bearing error 5-15° — Good aiming
- ❌ Bearing error > 15° — Poor aiming

### Tactical Assessment
- ✅ 70-90% decision to shoot — Properly aggressive
- ✅ > 90% weapon validity — Good weapon choice
- ❌ < 30% decision to shoot — Too conservative
- ❌ < 80% weapon validity — Poor weapon selection

## 🚀 Next Steps

1. **Run the evaluation**: `python3 evals_output/eval_admiral.py`
2. **View results**: `python3 evals_output/view_results.py`
3. **Analyze results**: Check `evaluation_results.json` for detailed per-scenario data
4. **Iterate**: Make AI improvements and re-run evaluation to measure impact

## 📝 Files Reference

```
backend/
├── eval_dataset/
│   └── game_states.json          ← Test scenarios (10 cases)
├── evals_output/
│   ├── eval_admiral.py           ← Main evaluation script
│   ├── view_results.py           ← Results viewer/formatter
│   ├── evaluation_results.json    ← Generated output (after run)
│   ├── README.md                 ← Full documentation
│   ├── QUICK_START.md            ← Quick reference
│   └── .gitignore                ← Exclude results from git
└── services/
    └── ai_service.py             ← The AI being tested
```

---

**Happy evaluating! 🚀**
