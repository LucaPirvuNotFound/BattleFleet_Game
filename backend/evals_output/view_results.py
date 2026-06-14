#!/usr/bin/env python3
"""
Admiral AI Evaluation Results Viewer
Displays evaluation results in a human-readable table format.
"""

import json
import sys
from pathlib import Path
from typing import Any


def print_table(data: list[dict], columns: list[str], widths: list[int] = None):
    """Print a formatted table."""
    if not data:
        print("  (no data)")
        return

    if widths is None:
        widths = [max(len(str(col)), 12) for col in columns]

    # Header
    header = " | ".join(col.ljust(w) for col, w in zip(columns, widths))
    print(header)
    print("-" * len(header))

    # Rows
    for row in data:
        values = [str(row.get(col, "—")).ljust(w) for col, w in zip(columns, widths)]
        print(" | ".join(values))


def view_results(results_path: Path):
    """Display evaluation results."""
    try:
        with open(results_path) as f:
            results = json.load(f)
    except FileNotFoundError:
        print(f"❌ Results file not found: {results_path}")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"❌ Invalid JSON in results file")
        sys.exit(1)

    # Header
    print("\n" + "=" * 80)
    print("📊 ADMIRAL AI EVALUATION RESULTS")
    print("=" * 80)

    # Metadata
    meta = results.get("metadata", {})
    print(f"\n📅 Evaluation Date:  {meta.get('evaluation_date', 'N/A')}")
    print(f"📊 Total Scenarios:  {meta.get('total_scenarios', 0)}")

    # Summary Statistics
    summary = results.get("summary", {})
    print("\n" + "-" * 80)
    print("📈 SUMMARY STATISTICS")
    print("-" * 80)
    print(f"  ✓ Successful:            {summary.get('successful', 0)}/{summary.get('total_evaluated', 0)}")
    print(f"  ✗ Failed:                {summary.get('failed', 0)}")
    print(f"  ⚠ Invalid Responses:     {summary.get('invalid_responses', 0)}")
    print(f"\n  ⏱️  Average Latency:        {summary.get('avg_latency_ms', 0)} ms")
    print(f"  ⏱️  Average TTFT:           {summary.get('avg_ttft_ms', 0)} ms")
    print(f"  📈 Average TPS:            {summary.get('avg_tps', 0)} tokens/sec")
    print(f"\n  🎯 Decision to Shoot:      {summary.get('decision_to_shoot_rate', 0)}%")
    print(f"  🎯 Avg Bearing Error:      {summary.get('avg_bearing_error_deg', 0)}°")
    print(f"  🎯 Weapon Validity:        {summary.get('weapon_validity_rate', 0)}%")

    # Per-Scenario Results
    scenarios = results.get("scenarios", [])
    if scenarios:
        print("\n" + "-" * 80)
        print("🎮 PER-SCENARIO RESULTS")
        print("-" * 80)

        table_data = []
        for s in scenarios:
            accuracy = s.get("accuracy", {})
            row = {
                "Scenario": s.get("scenario_id", "?")[:20],
                "Status": s.get("status", "?")[0].upper(),
                "Latency": f"{s.get('latency_ms', 0):.1f}ms" if s.get("latency_ms") else "—",
                "Shoot": "✓" if accuracy.get("decision_to_shoot") else "✗",
                "Bearing Err": f"{accuracy.get('bearing_error_deg', 0):.1f}°" if accuracy.get("bearing_error_deg") is not None else "—",
                "Weapon": "✓" if accuracy.get("weapon_valid") else "✗" if accuracy.get("decision_to_shoot") else "—",
                "Range": "✓" if accuracy.get("target_selection_valid") else "✗" if accuracy.get("closest_enemy_dist") is not None else "—",
            }
            table_data.append(row)

        columns = ["Scenario", "Status", "Latency", "Shoot", "Bearing Err", "Weapon", "Range"]
        widths = [20, 6, 10, 5, 11, 6, 6]
        print_table(table_data, columns, widths)

    # Detailed Results on Request
    if len(scenarios) > 0:
        print("\n" + "-" * 80)
        print("💡 TIP: To see detailed results for a scenario, check evaluation_results.json")
        print("-" * 80)

    # Assessment
    print("\n" + "-" * 80)
    print("📋 ASSESSMENT")
    print("-" * 80)

    success_rate = (summary.get("successful", 0) / summary.get("total_evaluated", 1) * 100) if summary.get("total_evaluated") else 0
    if success_rate >= 90:
        print("  ✅ EXCELLENT - High success rate and valid responses")
    elif success_rate >= 70:
        print("  ⚠️  GOOD - Mostly working with some issues")
    elif success_rate > 0:
        print("  ⚠️  POOR - Many failures or invalid responses")
    else:
        print("  ❌ FAILED - No successful evaluations")

    latency = summary.get("avg_latency_ms", 0)
    if latency < 20:
        print(f"  ⚡ FAST latency ({latency}ms) - model is cached in RAM")
    elif latency < 100:
        print(f"  ⏱️  ACCEPTABLE latency ({latency}ms)")
    else:
        print(f"  🐢 SLOW latency ({latency}ms) - model may be loading from disk")

    bearing_err = summary.get("avg_bearing_error_deg", 0)
    if bearing_err < 5:
        print(f"  🎯 EXCELLENT aiming ({bearing_err}° error)")
    elif bearing_err < 15:
        print(f"  🎯 GOOD aiming ({bearing_err}° error)")
    else:
        print(f"  🎯 POOR aiming ({bearing_err}° error)")

    shoot_rate = summary.get("decision_to_shoot_rate", 0)
    if shoot_rate > 70:
        print(f"  🤖 AGGRESSIVE strategy ({shoot_rate}% decide to shoot)")
    elif shoot_rate > 30:
        print(f"  🤖 TACTICAL strategy ({shoot_rate}% decide to shoot)")
    else:
        print(f"  🤖 CONSERVATIVE strategy ({shoot_rate}% decide to shoot)")

    print("\n" + "=" * 80 + "\n")


def main():
    results_path = Path(__file__).parent / "evaluation_results.json"

    if len(sys.argv) > 1:
        results_path = Path(sys.argv[1])

    view_results(results_path)


if __name__ == "__main__":
    main()
