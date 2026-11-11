# MCP server

A local stdlib-only MCP tools server using newline-delimited JSON-RPC over stdio. The server itself does not make network requests or send telemetry. It discovers metadata from this checkout's `docs/catalog.json` and runs CLIs installed in one selected Godot project.

## Trust and safety

**This is not a sandbox.** Use it only with a trusted project, Godot executable, MCP client, and tool arguments. Godot and some addons can execute project code, launch processes, access the network, or write files; arguments such as `--out` or `--apply` may modify files, including outside the project. CLI output is not redacted and can contain project data or secrets. Your MCP client or AI provider may transmit that output elsewhere. Review each addon's README and approve actions appropriate for your environment.

The server checks that an advertised CLI file resolves inside the selected project; that check does not confine the CLI's inputs, outputs, dependencies, or subprocesses. A timeout is best-effort: detached descendants and Windows child processes can survive, and partial writes are not rolled back. MCP cancellation notifications are not implemented.

## Setup

1. Keep this repository checkout, including `docs/catalog.json` and `mcp/mcp_server.py`, on the machine running the server. Python 3 and a compatible Godot executable are required; there are no Python runtime dependencies.
2. Select a trusted directory containing `project.godot`. Copy any desired addon directories into its `addons/` folder. Enabling the plugins in the editor is not required for their CLIs.
3. Adapt [`mcp_config.json`](mcp_config.json) to your client's MCP configuration format, using absolute paths for the server script, Godot executable and selected project. Restart the client after changing its environment. For example:

```json
{
  "mcpServers": {
    "godot-dev-tools": {
      "command": "python3",
      "args": ["/absolute/path/to/GodotDevTools/mcp/mcp_server.py"],
      "env": {
        "GDT_PROJECT_ROOT": "/absolute/path/to/trusted/godot-project",
        "GODOT_BIN": "/absolute/path/to/godot",
        "GDT_MCP_TIMEOUT": "300"
      }
    }
  }
}
```

Client configuration formats and executable paths differ; on Windows use an installed Python and, when available, Godot's console executable. Alternatively, a stdio MCP client can launch the server directly:

```sh
GDT_PROJECT_ROOT="/path/to/trusted/project" GODOT_BIN="/path/to/godot" python3 mcp/mcp_server.py
```

| Variable | Meaning |
|---|---|
| `GDT_PROJECT_ROOT` | Project containing `project.godot` and the desired addons. If unset, the checkout containing the server is used. Relative paths are resolved at server startup; an empty or invalid path is an error. |
| `GODOT_BIN` | Godot executable, default `godot` on `PATH`. A relative path containing a separator is resolved from the server's startup directory. |
| `GDT_MCP_TIMEOUT` | Per-call timeout in seconds, default 300; accepts a finite number greater than 0 and at most 3600. Cleanup can take additional time. |

The subprocess runs with the selected project as its working directory and receives the CLI arguments as individual strings, without a shell. The selected project is fixed for the server process; start another server to select a different one.

## Tools and results

- `list_tools` returns the checkout's full catalog as JSON text, with an `installed` boolean for each entry.
- `search_tools` accepts `{"query": "android logcat crash"}` and returns ranked catalog entries as JSON text. It matches words and simple plurals in title, ID and description; `score` and `why` explain each match. Ties are ordered by ID. It is a simple offline keyword search, not the separate Tool Finder's problem-phrase recommendation engine.
- `run_<tool_id>` appears in `tools/list` only if the catalog's CLI file exists and resolves inside the project, for example `run_android_export_audit`. `{"args": ["--help"]}` passes `--help` to that CLI. Check the addon's README for its actual options and report paths.

`installed` only checks the expected CLI file; it does not verify its version, dependencies, plugin state, or correctness. Catalog metadata comes from the server checkout and may differ from the installed addon. Discovery is refreshed on each listing, but the server does not send tool-list-change notifications, so refresh or restart a client after installing/removing an addon.

A run result contains `exit=<code>`, followed by labeled stdout and stderr. By convention the server treats exit 0 and 2 as non-error tool results; many CLIs use 2 for a selected gated finding. Other exits, startup failures, timeouts and incomplete capture set `isError: true`. **Always inspect the exit code, output and generated reports**: 0 does not mean no findings, and the server cannot prove that 0/2 came from a successful CLI rather than an engine or script problem. A known but uninstalled addon returns an error tool result; unknown names and invalid arguments receive JSON-RPC errors.

Each request is limited to 1 MiB. A run accepts at most 64 arguments, each at most 4096 characters, without NUL or surrogate characters. Queries are limited to 2048 characters. Child stdout and stderr are each capped at 64 KiB of retained bytes, with truncation noted in the result; undecodable bytes are replaced. Output pipes are drained concurrently. The server handles requests serially, so a long run blocks later requests. On POSIX, timeout or server SIGTERM/SIGINT attempts to kill the Godot process group; on Windows only the direct process is killed. Detached children may survive on either platform, and abrupt termination cannot be cleaned up reliably.

## Protocol and verification

This implements a small MCP `2024-11-05` tools subset: `initialize`, `ping`, `tools/list`, and `tools/call` over stdio. Clients offering newer versions must accept the server's `2024-11-05` response to connect. Notifications are ignored without a response. There is no HTTP/SSE transport, authentication, batching, progress, cancellation, resources, or prompts. Stdout is reserved for JSON-RPC messages; startup diagnostics go to stderr.

```sh
# Protocol, fake-Godot, timeout and cleanup regressions; no Godot needed.
python3 tests/test_mcp.py

# Real Godot, one installed Android Export Audit addon in a disposable project.
python3 tests/mcp_godot_smoke.py --godot /path/to/godot
```

CI is configured to run the stdlib suite on Linux and Windows and the Godot smoke in the Linux version matrix and on Windows 4.3. An optional client interoperability smoke uses the MCP Python SDK, **only for testing**, not for running the server:

```sh
python3 -m venv /tmp/gdt-mcp-sdk-venv
/tmp/gdt-mcp-sdk-venv/bin/python -m pip install 'mcp==2.3.0'
/tmp/gdt-mcp-sdk-venv/bin/python tests/mcp_sdk_smoke.py --godot /path/to/godot
```

The stdio and SDK smokes exercise one addon on synthetic clean, gated-finding and invalid-input fixtures; they do not validate every addon, external client application, or Android device. A local run passed with a minimal source-built Godot 4.3 template and SDK 2.3.0. That stripped build reported unavailable renderer/global-script-cache startup diagnostics and is not full-editor verification; inspect the CI results for official binaries.

## VS Code

See [`editors/vscode/`](../editors/vscode/) for a separate SARIF diagnostics extension. It renders `sarif_export` output inline; it is not an MCP client.
