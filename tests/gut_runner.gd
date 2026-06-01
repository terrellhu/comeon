# GUT test runner — invoked by CI and /smoke-check
# Usage: godot --headless --script tests/gut_runner.gd
extends SceneTree

func _init() -> void:
    var gut_path := "res://addons/gut/gut.gd"
    if not ResourceLoader.exists(gut_path):
        push_error("GUT not found. Install via AssetLib: search 'GUT', then enable plugin.")
        quit(1)
        return

    var gut = load(gut_path).new()
    gut.add_directory("res://tests/unit")
    gut.add_directory("res://tests/integration")
    gut.set_yield_between_tests(true)
    get_root().add_child(gut)
    gut.test_scripts()

    await gut.end_run
    var result: int = 0 if gut.get_fail_count() == 0 else 1
    quit(result)
