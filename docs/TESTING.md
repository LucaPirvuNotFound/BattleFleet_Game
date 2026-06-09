# Testing

## Godot GUT Tests (`game/tests/`)

Unit and acceptance tests for the Godot game, using [GUT](https://github.com/bitwes/Gut) v9.2.0.

### Prerequisites

- Godot 4.6.1 (headless mode works — no GPU required)
- GUT is already installed at `game/addons/gut/`

### Running Locally

```bash
# Run all Godot tests
godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests

# Run a specific test file (substring match on filename)
godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=acceptance

# Hide orphan counts (faster, less noise)
godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ghide_orphans
```

### Test Suites

#### `test_acceptance_fog_of_war.gd` (5 tests)

Integration tests for the Fog-of-War system. Validates that `FogOfWar.tscn` auto-discovers terrain and ships via groups, correctly positions vision circles, and cleans up on ship removal.

| Test | What it checks |
|------|----------------|
| `test_terrain_group_discovered_by_fog` | `_find_terrain()` updates `map_size` from the `terrain` group |
| `test_fog_auto_discovers_ship` | `_process()` registers a ship in `active_ships` via the `ships` group |
| `test_vision_circle_position_matches_ship_world` | Vision circle position in the SubViewport matches the ship's 3D world position |
| `test_vision_circle_follows_ship_movement` | After moving the ship, the vision circle position updates accordingly |
| `test_removed_ship_cleans_up_circle` | `queue_free()` on the ship triggers `tree_exiting` signal and removes it from `active_ships` |

#### `test_camera_math.gd` (4 tests)

Pure-logic tests for camera zoom clamping and drag bounds.

| Test | What it checks |
|------|----------------|
| `test_zoom_clamps_to_min` | Zoom divides by factor and clamps to minimum |
| `test_zoom_clamps_to_max` | Zoom clamps to maximum when exceeding bounds |
| `test_drag_does_not_exceed_map_bounds` | Drag position clamps to ±half map size |
| `test_drag_stays_within_bounds` | Drag position inside bounds is unchanged |

#### `test_fog_uv.gd` (5 tests)

Pure-math tests for the fog-of-war UV coordinate formulas.

| Test | What it checks |
|------|----------------|
| `test_origin_maps_to_center` | World origin (0,0) maps to UV (0.5, 0.5) |
| `test_positive_edge_maps_to_one` | Positive map edge maps to UV 1.0 |
| `test_negative_edge_maps_to_zero` | Negative map edge maps to UV 0.0 |
| `test_ship_position_matches_uv` | Arbitrary ship position produces correct UV |
| `test_clamped_uv_outside_map` | Positions outside the map clamp to [0, 1] |

#### `test_map_generator.gd` (8 tests)

Tests for the `MapGenerator` static class that builds the runtime map.

| Test | What it checks |
|------|----------------|
| `test_build_map_returns_dict_with_expected_keys` | Result dict has `root`, `terrain`, `water` keys |
| `test_build_map_root_is_node3d` | Root node is a `Node3D` named `Map` |
| `test_build_map_terrain_is_meshinstance3d` | Terrain is a `MeshInstance3D` |
| `test_build_map_water_is_node3d` | Water is a `Node3D` named `WaterPlane` |
| `test_build_map_terrain_has_noise` | Terrain has a `noise` property |
| `test_build_map_different_seeds_different_terrain` | Different seeds produce different noise objects |
| `test_build_map_same_seed_same_noise` | Same seed produces identical noise values |
| `test_build_terrain_static` | `build_terrain()` returns a `MeshInstance3D` |

#### `test_terrain.gd` (4 tests)

Unit tests for `Terrain.gd` height and normal calculations.

| Test | What it checks |
|------|----------------|
| `test_get_height_consistent` | Same input returns the same height |
| `test_get_height_different_positions_different_values` | Different positions return different heights |
| `test_get_height_range` | Height is within `[-height, height]` |
| `test_get_normal_returns_vector` | `get_normal()` returns a non-zero `Vector3` |

### Writing New Tests

1. Create `game/tests/test_<name>.gd` extending `GutTest`
2. Name test methods with the `test_` prefix
3. Use `assert_eq`, `assert_ne`, `assert_true`, `assert_has`, `assert_does_not_have`, `assert_almost_eq`, etc.
4. Use `add_child_autofree()` to add nodes that auto-clean after each test
5. Use `await wait_frames(N)` when signals or frame-delayed logic is needed
6. No rendering is required — all tests run headless

```gdscript
extends GutTest

func test_something() -> void:
	var value = some_function()
	assert_eq(value, expected, "description")
```

---

## Python Database Tests (`database/tests/`)

Unit tests for the Python database layer, using `pytest`.

### Prerequisites

- Python 3.10+
- `pytest` and `pytest-cov`

### Running Locally

```bash
cd database
pytest tests/ -v --tb=short --cov=. --cov-report=term-missing
```

### Test Files

| File | What it tests |
|------|---------------|
| `test_unit_players.py` | Player repository CRUD operations |

---

## CI (`tests.yml`)

Two parallel jobs run automatically on every push and PR:

- **Godot GUT** — inside `barichello/godot-ci:4.6` container, runs all `game/tests/` via GUT
- **Python** — on `ubuntu-latest` with Python 3.10–3.12 matrix, runs `database/tests/` via pytest
