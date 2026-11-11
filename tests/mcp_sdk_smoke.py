#!/usr/bin/env python3
"""Optional end-to-end smoke using the MCP Python SDK and a Godot binary.

Unlike the server and other MCP tests, this script requires the optional
third-party MCP SDK. See mcp/README.md for an isolated installation command.
"""

import argparse
from importlib.metadata import version
import json
import os
from pathlib import Path
import sys
import tempfile
import traceback

try:
    import anyio
    from mcp.client.session import ClientSession
    from mcp.client.stdio import StdioServerParameters, stdio_client
    from mcp.shared.exceptions import MCPError
except ImportError as exc:
    print(f"The optional MCP SDK smoke requires mcp==2.3.0: {exc}", file=sys.stderr)
    raise SystemExit(2)

import mcp_godot_smoke as smoke


def result_text(result):
    smoke.require(len(result.content) == 1 and getattr(result.content[0], "type", None) == "text",
                  "SDK received an unexpected tool result")
    return result.content[0].text


async def exercise(godot):
    if os.sep in godot or (os.altsep and os.altsep in godot):
        godot = str(Path(godot).expanduser().resolve())
    with tempfile.TemporaryDirectory(prefix="gdt mcp sdk ") as tmp:
        project = Path(tmp) / "trusted project"
        smoke.make_fixture_project(project)
        env = {**os.environ, "GDT_PROJECT_ROOT": str(project), "GODOT_BIN": godot, "GDT_MCP_TIMEOUT": "30"}
        params = StdioServerParameters(command=sys.executable, args=[str(smoke.SERVER)], env=env, cwd=tmp)
        async with stdio_client(params) as (reader, writer):
            async with ClientSession(reader, writer, read_timeout_seconds=45) as session:
                initialized = await session.initialize()
                smoke.require(initialized.protocol_version == "2024-11-05", "SDK negotiation failed")
                names = {item.name for item in (await session.list_tools()).tools}
                smoke.require(names == {"list_tools", "search_tools", "run_android_export_audit"},
                              "SDK received the wrong installed tool list")
                search = await session.call_tool("search_tools", arguments={"query": "android export"})
                hits = json.loads(result_text(search))
                smoke.require(any(item.get("id") == "android_export_audit" and item.get("installed") and item.get("why")
                                  for item in hits), "SDK search missed the installed addon")
                cases = [
                    ("clean", "export_clean.cfg", ["--fail-on=issues"], 0, False),
                    ("finding", "export_presets.cfg", ["--history=res://demo/android_dev/release_history.json",
                                                       "--fail-on=version_not_increased"], 2, False),
                    ("missing", "missing.cfg", [], 1, True),
                ]
                for label, preset, extra, exit_code, is_error in cases:
                    args = [f"--presets=res://demo/android_dev/{preset}", f"--out=res://reports/{label}", *extra]
                    result = await session.call_tool("run_android_export_audit", arguments={"args": args})
                    output = result_text(result)
                    smoke.require(f"exit={exit_code}\n" in output and bool(result.is_error) == is_error,
                                  f"{label}: wrong exit or error flag: {output}")
                    smoke.require("SCRIPT ERROR" not in output and "Parse Error" not in output,
                                  f"{label}: Godot script error: {output}")
                    smoke.require(smoke.SECRET not in output, f"{label}: fixture secret appeared in output")
                missing = await session.call_tool("run_android_touch_audit", arguments={})
                smoke.require(missing.is_error and "not installed" in result_text(missing), "missing addon did not fail")
                try:
                    await session.call_tool("run_android_export_audit", arguments={"args": "not an array"})
                except MCPError as exc:
                    smoke.require(exc.code == -32602, f"wrong JSON-RPC error for bad arguments: {exc.code}")
                else:
                    raise smoke.SmokeFailure("invalid arguments were not rejected")
        smoke.validate_reports(project)
    print(f"MCP SDK {version('mcp')} smoke passed: negotiation, discovery, search and Godot exits 0/2/1.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.3 executable")
    args = parser.parse_args(argv)
    try:
        anyio.run(exercise, args.godot)
    except Exception:
        print("MCP SDK smoke failed:", file=sys.stderr)
        traceback.print_exc()
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
