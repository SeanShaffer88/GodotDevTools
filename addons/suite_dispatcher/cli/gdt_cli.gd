extends SceneTree
## Suite CLI Dispatcher. Usage (from the project root):
##   godot --headless --path . --script res://addons/suite_dispatcher/cli/gdt_cli.gd -- list
##   godot --headless --path . --script res://addons/suite_dispatcher/cli/gdt_cli.gd -- run <tool> [tool options]
##   godot --headless --path . --script res://addons/suite_dispatcher/cli/gdt_cli.gd -- all
## run: exits with the tool's exit code. all: runs every CLI with defaults; exit 2 if any
## exited 2, 1 if any exited 1. Unknown commands or tools exit 1.
const Core := preload("res://addons/suite_dispatcher/core/gdt_registry.gd")

func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var reg: Dictionary = op.run("res://addons")
    var tools: Dictionary = reg.get("tools", {})
    var cmd: String = args[0] if args.size() > 0 else "list"
    if cmd == "list":
        var names: Array = tools.keys()
        names.sort()
        for n in names:
            print("%-24s %s" % [n, tools[n]["title"]])
        print("%d tools. Run one: gdt_cli.gd -- run <tool> [options]" % names.size())
        quit(0)
    elif cmd == "run" and args.size() >= 2:
        var name := op.resolve(tools, args[1])
        if name == "":
            printerr("Unknown or ambiguous tool: ", args[1])
            quit(1)
            return
        quit(op.dispatch(tools[name]["cli"], Array(args.slice(2))))
    elif cmd == "all":
        var worst := 0
        var names: Array = tools.keys()
        names.sort()
        for n in names:
            if n == "suite_dispatcher":
                continue
            var code: int = op.dispatch(tools[n]["cli"], [])
            print("== %s exit %d" % [n, code])
            if code == 1 or (code == 2 and worst == 0):
                worst = code if worst != 1 else 1
        quit(worst)
    else:
        printerr("Usage: list | run <tool> [options] | all")
        quit(1)
