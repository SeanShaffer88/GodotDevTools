# Multiplayer Network Simulator

Add configurable latency, packet loss and disconnects to local multiplayer testing, with tools to inspect synchronisation issues.

Part of the **GodotDevTools** suite. Godot 4.3, no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/network_sim` into your project's `addons/` folder, then enable **Multiplayer Network Simulator** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

Run plays the built-in sync scenario: 180 authoritative updates through a channel with 150 ms latency and 10% loss; dropped updates show up as a final-state mismatch (the desync). In game, route packets through the Network Sim Proxy node (addons/network_sim/runtime/mns_proxy.gd) and set its latency/loss; compare two peers with Channel.first_desync_tick(a, b).

Every control in the dock has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/network_sim/cli/mns_cli.gd -- [options]
```

Run the CLI with no options once for a default report; each CLI writes JSON + Markdown into a `reports/` folder and supports `--fail-on=...` exit code 2 gates for CI. Full option lists are in the header comment of the CLI script.

## How it works

The work lives in one core operation under `core/` with no editor-only APIs, so the editor dock, the CLI and the tests all run exactly the same check. The dock and CLI add no logic of their own.
