#!/usr/bin/env python3
"""
Admiral AI Evaluation Pipeline
Tests the admiral AI decision-making on a curated dataset of game scenarios.
Measures performance metrics (TTFT, TPS, latency) and decision accuracy.
"""

import asyncio
import json
import sys
import time
import math
from pathlib import Path
from datetime import datetime
from typing import Any
import re

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from services.ai_service import get_admiral_decision


def calculate_distance(p1: tuple[float, float], p2: tuple[float, float]) -> float:
    """Calculate 2D Euclidean distance between two points."""
    return math.sqrt((p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2)


def normalize_angle(angle: float) -> float:
    """Normalize angle to [-180, 180) range."""
    while angle >= 180:
        angle -= 360
    while angle < -180:
        angle += 360
    return angle


def calculate_bearing(ai_pos: tuple[float, float], target_pos: tuple[float, float]) -> float:
    """Calculate bearing from AI ship to target (0=north/ahead, 90=east/right, -90=west/left)."""
    dx = target_pos[0] - ai_pos[0]
    dz = target_pos[1] - ai_pos[1]
    bearing = math.degrees(math.atan2(dx, -dz))
    return normalize_angle(bearing)


def validate_response(response: dict, game_context: dict) -> tuple[bool, list[str]]:
    """Validate that response has correct structure and valid actions."""
    errors = []

    if not isinstance(response, dict):
        errors.append("Response is not a dictionary")
        return False, errors

    # Check required fields
    if "match_id" not in response:
        errors.append("Missing match_id field")
    if "round" not in response:
        errors.append("Missing round field")
    if "phase" not in response or response["phase"] != "ai_turn_end":
        errors.append("Invalid or missing phase field")
    if "actions" not in response or not isinstance(response["actions"], list):
        errors.append("Missing or invalid actions field")

    if errors:
        return False, errors

    # Validate actions
    ai_fleet = game_context.get("ai_fleet", [])
    ai_ship_indices = {ship.get("ship_index") for ship in ai_fleet}

    for i, action in enumerate(response.get("actions", [])):
        if not isinstance(action, dict):
            errors.append(f"Action {i} is not a dictionary")
            continue

        ship_idx = action.get("ship_index")
        if ship_idx not in ai_ship_indices:
            errors.append(f"Action {i} references invalid ship_index: {ship_idx}")

        orders = action.get("orders", [])
        if not isinstance(orders, list):
            errors.append(f"Action {i} has invalid orders (not a list)")
            continue

        for j, order in enumerate(orders):
            if not isinstance(order, dict):
                errors.append(f"Action {i} order {j} is not a dictionary")
                continue

            order_type = order.get("type", "").lower()
            if order_type not in ("move", "fire"):
                errors.append(f"Action {i} order {j} has invalid type: {order_type}")

            if order_type == "move":
                distance = order.get("distance")
                if not isinstance(distance, (int, float)):
                    errors.append(f"Action {i} order {j} move has invalid distance")

            elif order_type == "fire":
                weapon = order.get("weapon")
                if not weapon or not isinstance(weapon, str):
                    errors.append(f"Action {i} order {j} fire has invalid weapon")

    return len(errors) == 0, errors


def measure_accuracy(response: dict, game_context: dict, scenario_id: str) -> dict:
    """
    Measure decision accuracy:
    - Did it choose to shoot? (decision_to_shoot: bool)
    - How close was the chosen bearing to the target? (bearing_error_deg: float)
    - Did it choose a valid weapon? (weapon_valid: bool)
    - Distance to closest enemy (closest_enemy_dist: float)
    """
    metrics = {
        "decision_to_shoot": False,
        "bearing_error_deg": None,
        "weapon_valid": False,
        "closest_enemy_dist": None,
        "target_selection_valid": False,
    }

    ai_fleet = game_context.get("ai_fleet", [])
    visible_human = game_context.get("visible_human_ships", [])

    if not visible_human:
        return metrics

    # Find closest enemy
    closest_enemy = None
    closest_dist = float("inf")

    for enemy in visible_human:
        enemy_pos = (enemy.get("position", {}).get("x", 0), enemy.get("position", {}).get("z", 0))
        # Calculate distances from all AI ships
        for ai_ship in ai_fleet:
            ai_pos = (ai_ship.get("position", {}).get("x", 0), ai_ship.get("position", {}).get("z", 0))
            dist = calculate_distance(ai_pos, enemy_pos)
            if dist < closest_dist:
                closest_dist = dist
                closest_enemy = (enemy, ai_pos, enemy_pos)

    if closest_enemy:
        metrics["closest_enemy_dist"] = round(closest_dist, 1)
        enemy, ai_pos, enemy_pos = closest_enemy
        expected_bearing = calculate_bearing(ai_pos, enemy_pos)

        # Check if response decides to shoot
        for action in response.get("actions", []):
            for order in action.get("orders", []):
                if order.get("type", "").lower() == "fire":
                    metrics["decision_to_shoot"] = True
                    actual_bearing = order.get("angle", 0)
                    actual_bearing = normalize_angle(actual_bearing)
                    bearing_error = abs(normalize_angle(expected_bearing - actual_bearing))
                    if bearing_error > 180:
                        bearing_error = 360 - bearing_error
                    metrics["bearing_error_deg"] = round(bearing_error, 1)

                    # Check weapon validity
                    weapon_name = order.get("weapon", "")
                    ai_ships_by_idx = {s.get("ship_index"): s for s in ai_fleet}
                    ship_idx = action.get("ship_index")
                    if ship_idx in ai_ships_by_idx:
                        ship = ai_ships_by_idx[ship_idx]
                        available_weapons = [
                            w.get("name") if isinstance(w, dict) else w
                            for w in ship.get("weapons", [])
                            if (isinstance(w, dict) and w.get("available", True))
                            or isinstance(w, str)
                        ]
                        metrics["weapon_valid"] = weapon_name in available_weapons

        metrics["target_selection_valid"] = closest_dist <= 350.0  # Within max range

    return metrics


async def evaluate_scenario(scenario: dict) -> dict:
    """Evaluate a single scenario and return metrics."""
    scenario_id = scenario.get("id", "unknown")
    game_state = {
        "match_id": scenario.get("match_id"),
        "round": scenario.get("round"),
        "ai_fleet": scenario.get("ai_fleet", []),
        "visible_human_ships": scenario.get("visible_human_ships", []),
        "rules": scenario.get("rules", {}),
    }

    result = {
        "scenario_id": scenario_id,
        "description": scenario.get("description", ""),
        "timestamp": datetime.now().isoformat(),
        "status": "unknown",
        "error": None,
        "latency_ms": None,
        "ttft_ms": None,
        "tps": None,
        "response": None,
        "validation": {"success": False, "errors": []},
        "accuracy": {},
    }

    try:
        start_time = time.perf_counter()
        response = await get_admiral_decision(game_state)
        end_time = time.perf_counter()

        latency_ms = (end_time - start_time) * 1000
        result["latency_ms"] = round(latency_ms, 2)
        result["response"] = response

        # Validate response
        is_valid, validation_errors = validate_response(response, game_state)
        result["validation"]["success"] = is_valid
        result["validation"]["errors"] = validation_errors

        if is_valid:
            result["status"] = "success"
            # Measure accuracy
            accuracy = measure_accuracy(response, game_state, scenario_id)
            result["accuracy"] = accuracy
        else:
            result["status"] = "invalid_response"

        # Estimate TTFT and TPS (token counts)
        # Simple heuristic: assume ~4 chars per token on average
        # Response length * 4 / average_token_generation_rate
        response_str = json.dumps(response)
        estimated_tokens = len(response_str) // 4
        if latency_ms > 0:
            tps = (estimated_tokens / (latency_ms / 1000))
            result["ttft_ms"] = round(latency_ms / 10, 2)  # Rough estimate: TTFT ≈ 10% of total
            result["tps"] = round(tps, 2)

    except Exception as e:
        result["status"] = "error"
        result["error"] = str(e)
        import traceback
        result["error_traceback"] = traceback.format_exc()

    return result


async def evaluate_all_scenarios(dataset_path: Path) -> dict:
    """Evaluate all scenarios in the dataset."""
    with open(dataset_path) as f:
        scenarios = json.load(f)

    print(f"🎮 Admiral AI Evaluation Pipeline")
    print(f"📊 Testing {len(scenarios)} scenarios")
    print(f"⏱️  Starting evaluation at {datetime.now().isoformat()}\n")

    results = {
        "metadata": {
            "evaluation_date": datetime.now().isoformat(),
            "total_scenarios": len(scenarios),
            "dataset_file": str(dataset_path),
        },
        "scenarios": [],
        "summary": {
            "total_evaluated": 0,
            "successful": 0,
            "failed": 0,
            "invalid_responses": 0,
            "avg_latency_ms": 0,
            "avg_ttft_ms": 0,
            "avg_tps": 0,
            "decision_to_shoot_rate": 0,
            "avg_bearing_error_deg": 0,
            "weapon_validity_rate": 0,
        },
    }

    # Run evaluations
    for i, scenario in enumerate(scenarios, 1):
        print(f"[{i}/{len(scenarios)}] Evaluating {scenario.get('id')}...", end=" ", flush=True)
        result = await evaluate_scenario(scenario)
        results["scenarios"].append(result)
        status_emoji = "✅" if result["status"] == "success" else "❌"
        print(f"{status_emoji} ({result.get('latency_ms', 'N/A')} ms)")

    # Calculate summary statistics
    successful_results = [r for r in results["scenarios"] if r["status"] == "success"]
    valid_results = [r for r in results["scenarios"] if r["validation"]["success"]]

    results["summary"]["total_evaluated"] = len(results["scenarios"])
    results["summary"]["successful"] = len(successful_results)
    results["summary"]["failed"] = len([r for r in results["scenarios"] if r["status"] == "error"])
    results["summary"]["invalid_responses"] = len([r for r in results["scenarios"] if r["status"] == "invalid_response"])

    if successful_results:
        latencies = [r["latency_ms"] for r in successful_results if r["latency_ms"]]
        results["summary"]["avg_latency_ms"] = round(sum(latencies) / len(latencies), 2) if latencies else 0

        ttfts = [r["ttft_ms"] for r in successful_results if r["ttft_ms"]]
        results["summary"]["avg_ttft_ms"] = round(sum(ttfts) / len(ttfts), 2) if ttfts else 0

        tps_list = [r["tps"] for r in successful_results if r["tps"]]
        results["summary"]["avg_tps"] = round(sum(tps_list) / len(tps_list), 2) if tps_list else 0

    if valid_results:
        shoots = [r for r in valid_results if r["accuracy"].get("decision_to_shoot")]
        results["summary"]["decision_to_shoot_rate"] = round(len(shoots) / len(valid_results) * 100, 1)

        bearing_errors = [r["accuracy"]["bearing_error_deg"] for r in valid_results if r["accuracy"].get("bearing_error_deg") is not None]
        results["summary"]["avg_bearing_error_deg"] = round(sum(bearing_errors) / len(bearing_errors), 2) if bearing_errors else 0

        valid_weapons = [r for r in valid_results if r["accuracy"].get("weapon_valid")]
        shooting_attempts = [r for r in valid_results if r["accuracy"].get("decision_to_shoot")]
        if shooting_attempts:
            results["summary"]["weapon_validity_rate"] = round(len(valid_weapons) / len(shooting_attempts) * 100, 1)

    return results


def print_summary(results: dict):
    """Print evaluation summary to console."""
    summary = results["summary"]
    print("\n" + "=" * 60)
    print("📊 EVALUATION SUMMARY")
    print("=" * 60)
    print(f"✓ Total Evaluated:        {summary['total_evaluated']}")
    print(f"✓ Successful:             {summary['successful']}")
    print(f"✗ Failed:                 {summary['failed']}")
    print(f"⚠ Invalid Responses:      {summary['invalid_responses']}")
    print()
    print(f"⏱️  Average Latency:        {summary['avg_latency_ms']} ms")
    print(f"⏱️  Average TTFT:           {summary['avg_ttft_ms']} ms")
    print(f"📈 Average TPS:            {summary['avg_tps']} tokens/sec")
    print()
    print(f"🎯 Decision to Shoot Rate: {summary['decision_to_shoot_rate']}%")
    print(f"🎯 Avg Bearing Error:      {summary['avg_bearing_error_deg']}°")
    print(f"🎯 Weapon Validity Rate:   {summary['weapon_validity_rate']}%")
    print("=" * 60)


async def main():
    dataset_path = Path(__file__).parent.parent / "eval_dataset" / "game_states.json"

    if not dataset_path.exists():
        print(f"❌ Dataset not found at {dataset_path}")
        sys.exit(1)

    results = await evaluate_all_scenarios(dataset_path)

    # Save results
    output_path = Path(__file__).parent / "evaluation_results.json"
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    print_summary(results)
    print(f"\n💾 Results saved to: {output_path}")


if __name__ == "__main__":
    asyncio.run(main())
