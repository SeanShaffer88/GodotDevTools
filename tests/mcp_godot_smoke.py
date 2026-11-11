#!/usr/bin/env python3
"""Exercise MCP against an installed addon in a disposable Godot project."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "mcp/mcp_server.py"
SECRET = "DEMO_SECRET_NOT_REAL"


class SmokeFailure(Exception):
    pass


def require(condition, message):
    if not condition:
        raise SmokeFailure(message)


def rpc(request_id, method, params=None):
    result = {"jsonrpc": "2.0", "id": request_id, "method": method}
    if params is not None:
        result["params"] = params
    return result


def call(request_id, name, arguments):
    return rpc(request_id, "tools/call", {"name": name, "arguments": arguments})


def content(response):
    try:
        return response["result"]["content"][0]["text"]
    except (KeyError, IndexError, TypeError) as exc:
        raise SmokeFailure(f"unexpected MCP response: {response}") from exc


def read_report(project, label):
    directory = project / "reports" / label
    try:
        raw = (directory / "android_export_audit.json").read_text(encoding="utf-8")
        markdown = (directory / "android_export_audit.md").read_text(encoding="utf-8")
        data = json.loads(raw)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SmokeFailure(f"{label}: cannot read generated reports: {exc}") from exc
    require(SECRET not in raw and SECRET not in markdown, f"{label}: fixture secret appeared in a report")
    require(bool(markdown.strip()) and isinstance(data, dict) and isinstance(data.get("summary"), dict)
            and isinstance(data.get("issues"), list), f"{label}: invalid report structure")
    require(data["summary"].get("issues") == len(data["issues"]), f"{label}: issue count mismatch")
    return data


def make_fixture_project(project):
    (project / "addons").mkdir(parents=True)
    shutil.copytree(ROOT / "addons/android_export_audit", project / "addons/android_export_audit")
    fixtures = project / "demo/android_dev"
    fixtures.mkdir(parents=True)
    for name in ("export_clean.cfg", "export_presets.cfg", "release_history.json"):
        shutil.copyfile(ROOT / "demo/android_dev" / name, fixtures / name)
    require(SECRET in (fixtures / "export_presets.cfg").read_text(encoding="utf-8"), "fixture secret marker is missing")
    (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="MCP smoke"\n', encoding="utf-8")


def validate_reports(project):
    clean = read_report(project, "clean")
    require(clean["summary"].get("android_presets") == 1 and not clean["issues"], "clean report is incorrect")
    finding = read_report(project, "finding")
    require(any(isinstance(issue, dict) and issue.get("kind") == "version_not_increased" for issue in finding["issues"]),
            "selected finding missing")
    missing = read_report(project, "missing")
    require(any(isinstance(issue, dict) and issue.get("kind") == "bad_input" for issue in missing["issues"]),
            "missing-input error absent")


def run_smoke(godot):
    if os.sep in godot or (os.altsep and os.altsep in godot):
        godot = str(Path(godot).expanduser().resolve())
    with tempfile.TemporaryDirectory(prefix="gdt mcp smoke ") as tmp:
        project = Path(tmp) / "trusted project"
        make_fixture_project(project)
        messages = [
            rpc(1, "initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "smoke", "version": "1"}}),
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            rpc(2, "tools/list"), call(3, "search_tools", {"query": "android export"}),
            call(4, "run_android_export_audit", {"args": [
                "--presets=res://demo/android_dev/export_clean.cfg", "--out=res://reports/clean", "--fail-on=issues"]}),
            call(5, "run_android_export_audit", {"args": [
                "--presets=res://demo/android_dev/export_presets.cfg", "--history=res://demo/android_dev/release_history.json",
                "--out=res://reports/finding", "--fail-on=version_not_increased"]}),
            call(6, "run_android_export_audit", {"args": [
                "--presets=res://demo/android_dev/missing.cfg", "--out=res://reports/missing"]}),
            call(7, "run_android_touch_audit", {}),
            rpc(8, "ping"),
        ]
        payload = "".join(json.dumps(message) + "\n" for message in messages)
        env = {**os.environ, "GDT_PROJECT_ROOT": str(project), "GODOT_BIN": godot, "GDT_MCP_TIMEOUT": "30"}
        try:
            process = subprocess.run([sys.executable, str(SERVER)], input=payload, cwd=tmp, env=env,
                                     capture_output=True, text=True, encoding="utf-8", errors="replace",
                                     timeout=120, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise SmokeFailure(f"could not run MCP server: {exc}") from exc
        require(process.returncode == 0, f"MCP server exit {process.returncode}: {process.stderr}")
        require(SECRET not in process.stdout and SECRET not in process.stderr, "fixture secret appeared in server output")
        try:
            responses = [json.loads(line) for line in process.stdout.splitlines()]
            require([item.get("id") for item in responses] == list(range(1, 9)), "unexpected ids or notification response")
            by_id = {item["id"]: item for item in responses}
            require(by_id[1]["result"]["protocolVersion"] == "2024-11-05", "initialize response missing")
            names = {entry["name"] for entry in by_id[2]["result"]["tools"]}
            require(names == {"list_tools", "search_tools", "run_android_export_audit"}, "installed tool discovery is incorrect")
            hits = json.loads(content(by_id[3]))
            require(any(item.get("id") == "android_export_audit" and item.get("installed") and item.get("why")
                        for item in hits), "catalog search did not explain the installed addon")
            for request_id, exit_code, is_error in ((4, 0, False), (5, 2, False), (6, 1, True)):
                response = by_id[request_id]
                output = content(response)
                require(f"exit={exit_code}\n" in output, f"request {request_id}: incorrect exit: {output}")
                require(bool(response["result"].get("isError", False)) == is_error, f"request {request_id}: incorrect error flag")
                require("SCRIPT ERROR" not in output and "Parse Error" not in output, f"request {request_id}: Godot script error")
            require(by_id[7]["result"].get("isError") and "not installed" in content(by_id[7]), "missing addon did not fail")
            require(by_id[8]["result"] == {}, "server did not respond after tool calls")
        except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
            raise SmokeFailure(f"unexpected MCP output: {exc}; stdout={process.stdout}; stderr={process.stderr}") from exc
        validate_reports(project)
    print("MCP Godot smoke passed: external project, discovery, search, exits 0/2/1 and reports.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.3 executable")
    args = parser.parse_args(argv)
    try:
        run_smoke(args.godot)
    except (SmokeFailure, OSError) as exc:
        print(f"MCP Godot smoke: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
