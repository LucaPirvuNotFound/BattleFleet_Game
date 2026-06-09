
---

# AI GDScript Style & Generation Guidelines

**System Directive for AI Agents:** When generating, modifying, or reviewing GDScript for this project, you must adhere strictly to the following stylistic and architectural rules. Consistency is prioritized to maintain a clean, readable, and unified codebase for the development team.

## 1. Indentation & Formatting

* **Tabs over Spaces:** Use Tabs for all indentation.
* **Continuation Lines:** Use 2 tab indents for multi-line continuation to distinguish them from regular code blocks.
* **Data Structures:** Use 1 tab indent for multi-line arrays, dictionaries, and enums.
* **Line Length:** Keep all lines strictly under 100 characters (aim for 80 when possible).
* **Blank Lines:** Surround functions and class definitions with exactly two blank lines. Use one blank line inside functions to separate logical sections.
* **Trailing Commas:** Always include a trailing comma on the last item of multi-line arrays, dictionaries, and enums. Do not use trailing commas on single-line lists.

## 2. Syntax & Best Practices

* **Single Statement Per Line:** Do not combine multiple statements on one line. The only exception is the ternary operator (`x if y else z`).
* **Parentheses in Multiline:** Wrap long conditional statements over multiple lines using parentheses `()` rather than backslashes.
* **Operator Placement:** When wrapping conditionals, place `and`/`or` keywords at the *beginning* of the continuation line.
* **Boolean Operators:** Use plain English (`and`, `or`, `not`). Never use C-style symbols (`&&`, `||`, `!`).
* **Avoid Unnecessary Parentheses:** Do not wrap standard `if` conditions in parentheses (e.g., use `if is_colliding():`, not `if (is_colliding()):`).
* **Spacing:** Use one space around operators and after commas. Do not vertically align variables using spaces.
* **Comments:** Regular (`#`) and documentation (`##`) comments must start with a single space. Code region comments (`#region`/`#endregion`) and commented-out code should *not* have a space. Prefer placing comments on their own line above the code.

## 3. Data Types & Literals

* **Strings:** Default to double quotes (`"text"`). Only use single quotes if it prevents having to escape double quotes inside the string.
* **Floats:** Never omit leading or trailing zeros (use `0.234` or `13.0`, never `.234` or `13.`).
* **Hexadecimals:** Use lowercase for hex letters (e.g., `0xfb8c0b`).
* **Large Numbers:** Use underscores to separate thousands in numbers larger than 1,000,000 (e.g., `1_234_567_890`).

## 4. Naming Conventions

| Entity | Convention | Example |
| --- | --- | --- |
| **File names** | `snake_case` | `yaml_parser.gd` |
| **Class names** | `PascalCase` | `class_name YAMLParser` |
| **Node names** | `PascalCase` | `Camera3D`, `Player` |
| **Functions** | `snake_case` | `func load_level():` |
| **Variables** | `snake_case` | `var particle_effect` |
| **Signals** | `snake_case` (Past Tense) | `signal door_opened` |
| **Constants** | `CONSTANT_CASE` | `const MAX_SPEED = 200` |
| **Enum names** | `PascalCase` (Singular) | `enum Element` |
| **Enum members** | `CONSTANT_CASE` | `EARTH`, `WATER` |

* **Private/Virtual Identifiers:** Prepend a single underscore (`_`) to virtual methods, private functions, and private variables (e.g., `var _counter = 0`, `func _recalculate_path():`).

## 5. Architectural Code Order

Declare your script components in the exact top-to-bottom order listed below. Put public methods before private methods.

1. `@tool`, `@icon`, `@static_unload`
2. `class_name` (Use `@abstract class_name` if applicable)
3. `extends`
4. Documentation comments (`##`)
5. Signals
6. Enums
7. Constants
8. Static variables
9. `@export` variables
10. Regular variables
11. `@onready` variables
12. `_static_init()` and remaining static methods
13. Built-in virtual methods (Order: `_init`, `_enter_tree`, `_ready`, `_process`, `_physics_process`, etc.)
14. Custom methods (Public first, then private)
15. Inner classes

## 6. Variables & Static Typing

* **Local Variables:** Declare local variables as close to their first use as possible. Do not create member variables for data only used locally.
* **Explicit Typing:** Use explicit typing (`var health: int = 0`) when the type is ambiguous.
* **Inferred Typing:** Use inferred typing (`:=`) only when the type is definitively clear on the right side of the assignment (e.g., `var direction := Vector3(1, 2, 3)`).
* **Node Fetching:** Always explicitly type nodes fetched from the tree, or use the `as` keyword to cast them (e.g., `@onready var health_bar := get_node("UI/LifeBar") as ProgressBar`).