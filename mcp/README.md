# MCP server

Local, offline MCP server exposing every GodotDevTools CLI as a tool for AI agents. Stdlib only; no network, no telemetry.

## Run

```sh
GODOT_BIN=/path/to/godot python3 mcp/mcp_server.py
```

## Configure (Claude / Cursor)

Copy `mcp_config.json` into your client's MCP config and adjust the `command`/`env` paths. Tools: `list_tools`, `search_tools`, and `run_<tool>` per catalog entry (e.g. `run_asset_health`). `run_*` shells to `godot --headless --script <cli>` and returns stdout + exit code (0 clean, 2 gated finding, 1 error).

## VSCode

See `editors/vscode/` for a SARIF diagnostics extension (renders `sarif_export` output inline). It does not phone home.
