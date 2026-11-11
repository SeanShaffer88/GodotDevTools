#!/usr/bin/env python3
"""MCP protocol, catalog search and project-runner regression tests (no Godot required)."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "mcp" / "mcp_server.py"
spec = importlib.util.spec_from_file_location("gdt_mcp_server", SERVER)
mcp_server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mcp_server)
import mcp_godot_smoke

FAKE_GODOT = r'''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys, time
args = sys.argv[1:]
trace = os.environ.get("MCP_FAKE_TRACE")
if trace:
    with open(trace, "a", encoding="utf-8") as out:
        out.write(json.dumps({"cwd": os.getcwd(), "args": args}) + "\n")
mode = next((x.split("=", 1)[1] for x in args if x.startswith("--case=")), "clean")
if mode == "sleep":
    os.write(1, b"partial before timeout\n")
    time.sleep(10)
if mode in ("spawn", "spawn-exit"):
    marker = os.environ["MCP_CHILD_MARKER"]
    ready = os.environ["MCP_CHILD_READY"]
    subprocess.Popen([sys.executable, "-c", "import pathlib,sys,time; pathlib.Path(sys.argv[2]).write_text('ready'); time.sleep(2); pathlib.Path(sys.argv[1]).write_text('survived')", marker, ready])
    if mode == "spawn-exit":
        for _ in range(100):
            if pathlib.Path(ready).exists():
                break
            time.sleep(0.01)
        print("parent exited")
        sys.exit(0)
    time.sleep(10)
if mode == "large":
    os.write(1, b"OUT-START\n" + b"x" * 150000)
    os.write(2, b"ERR-START\n" + b"y" * 150000)
    sys.exit(0)
if mode == "bytes":
    os.write(1, b"invalid utf8: \xff\xfe\n")
    sys.exit(0)
print("fake Godot stdout")
print("fake Godot stderr", file=sys.stderr)
sys.exit({"clean": 0, "finding": 2, "error": 1}.get(mode, 0))
'''

SMOKE_FAKE_GODOT = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
project = pathlib.Path(args[args.index("--path") + 1])
assert args[args.index("--script") + 1] == "res://addons/android_export_audit/cli/aea_cli.gd"
assert (project / "addons/android_export_audit/core/aea_audit.gd").is_file()
preset = next(x.split("=", 1)[1] for x in args if x.startswith("--presets="))
out = next(x.split("=", 1)[1] for x in args if x.startswith("--out="))
assert out.startswith("res://")
directory = project / out[len("res://"):]
directory.mkdir(parents=True)
if preset.endswith("export_clean.cfg"):
    issues, status = [], 0
elif preset.endswith("export_presets.cfg"):
    assert any(x.startswith("--history=") for x in args)
    issues, status = [{"kind": "version_not_increased"}], 2
else:
    issues, status = [{"kind": "bad_input"}], 1
fault = os.environ.get("MCP_SMOKE_FAULT")
if fault == "script-error" and status == 0:
    print("SCRIPT ERROR: fake failure despite exit 0", file=sys.stderr)
if fault == "secret" and status == 0:
    print("DEMO_SECRET_NOT_REAL")
if fault == "wrong-exit" and status == 2:
    status = 0
report = {"summary": {"issues": len(issues), "android_presets": 1}, "issues": issues}
if fault == "wrong-report" and status == 0:
    report["summary"]["issues"] = 99
(directory / "android_export_audit.json").write_text(json.dumps(report))
(directory / "android_export_audit.md").write_text("report")
sys.exit(status)
'''


def request(request_id, method, params=None):
    message = {"jsonrpc": "2.0", "id": request_id, "method": method}
    if params is not None:
        message["params"] = params
    return message


def call(request_id, name, arguments=None):
    params = {"name": name}
    if arguments is not None:
        params["arguments"] = arguments
    return request(request_id, "tools/call", params)


def text(response):
    return response["result"]["content"][0]["text"]


class MCPTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gdt-mcp-test-")
        self.work = Path(self.temp.name)
        self.project = self.work / "trusted project with spaces"
        self.project.mkdir()
        (self.project / "project.godot").write_text('config_version=5\n', encoding="utf-8")
        cli = self.project / "addons/android_export_audit/cli/aea_cli.gd"
        cli.parent.mkdir(parents=True)
        cli.write_text("# test-only placeholder\n", encoding="utf-8")
        self.trace = self.work / "trace.jsonl"
        self.fake = self.work / "fake-godot"
        self.fake.write_text(FAKE_GODOT, encoding="utf-8")
        if os.name == "posix":
            self.fake.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update({"GDT_PROJECT_ROOT": str(self.project), "GODOT_BIN": str(self.fake),
                         "GDT_MCP_TIMEOUT": "4", "MCP_FAKE_TRACE": str(self.trace)})

    def tearDown(self):
        self.temp.cleanup()

    def run_raw(self, content, env=None, timeout=15, cwd=None):
        result = subprocess.run([sys.executable, str(SERVER)], input=content, capture_output=True,
                                env=env or self.env, cwd=cwd, timeout=timeout, check=False)
        return result

    def exchange(self, messages, env=None, timeout=15):
        raw = b"".join(json.dumps(message).encode("utf-8") + b"\n" for message in messages)
        result = self.run_raw(raw, env=env, timeout=timeout)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))
        return [json.loads(line) for line in result.stdout.splitlines()]

    def test_lifecycle_notifications_and_request_ids(self):
        messages = [
            request(0, "initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}}),
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "run_android_export_audit"}},
            request("unknown-id", "not/a/method"), request(None, "ping"), request(2, "ping"),
        ]
        responses = self.exchange(messages)
        self.assertEqual([r["id"] for r in responses], [0, "unknown-id", None, 2])
        self.assertEqual(responses[0]["result"]["protocolVersion"], "2024-11-05")
        self.assertEqual(responses[1]["error"]["code"], -32601)
        self.assertEqual(responses[2]["result"], {})
        self.assertFalse(self.trace.exists(), "notification must not run a request-only tool")

    def test_parse_and_invalid_request_errors_do_not_break_later_requests(self):
        lines = [b"not-json", b'[]', b'{"jsonrpc":"1.0","id":1,"method":"ping"}',
                 b'{"jsonrpc":"2.0","id":true,"method":"ping"}',
                 b'{"jsonrpc":"2.0","id":7,"method":"ping","params":[]}',
                 b'{"jsonrpc":"2.0","id":8,"method":"ping","params":{"x":NaN}}',
                 b'\xff', b'[' * 1100 + b'0' + b']' * 1100,
                 b'{"jsonrpc":"2.0","id":"after","method":"ping"}']
        result = self.run_raw(b"\n".join(lines) + b"\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual([r["error"]["code"] for r in responses[:7]],
                         [-32700, -32600, -32600, -32600, -32602, -32700, -32700])
        # JSON nesting limits vary by Python version: the deep array may be
        # rejected by the decoder or decoded and rejected as a non-request.
        self.assertIn(responses[7]["error"]["code"], (-32700, -32600))
        self.assertEqual(responses[4]["id"], 7)
        self.assertEqual(responses[-1]["id"], "after")
        self.assertEqual(responses[-1]["result"], {})

    def test_oversized_request_is_drained_and_server_recovers(self):
        huge = b'{"jsonrpc":"2.0","id":1,"method":"ping","padding":"' + b'x' * (mcp_server.MAX_REQUEST_BYTES + 50) + b'"}\n'
        followup = json.dumps(request("after", "ping")).encode() + b"\n"
        result = self.run_raw(huge + followup)
        self.assertEqual(result.returncode, 0, result.stderr)
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(len(responses), 2)
        self.assertEqual(responses[0]["error"]["code"], -32600)
        self.assertIn("size limit", responses[0]["error"]["message"])
        self.assertEqual(responses[1]["id"], "after")

    def test_catalog_installed_tools_and_ranked_explained_search(self):
        responses = self.exchange([request(1, "tools/list"), call(2, "list_tools"),
                                   call(3, "search_tools", {"query": "android logcat crash"})])
        definitions = {item["name"]: item for item in responses[0]["result"]["tools"]}
        self.assertEqual(set(definitions), {"list_tools", "search_tools", "run_android_export_audit"})
        args_schema = definitions["run_android_export_audit"]["inputSchema"]["properties"]["args"]
        self.assertEqual(args_schema["maxItems"], mcp_server.MAX_ARGS)
        self.assertEqual(args_schema["items"]["maxLength"], mcp_server.MAX_ARG_LENGTH)
        self.assertIn("write files", definitions["run_android_export_audit"]["description"])
        catalog = json.loads(text(responses[1]))
        by_id = {entry["id"]: entry for entry in catalog}
        self.assertGreater(len(catalog), 100)
        self.assertTrue(by_id["android_export_audit"]["installed"])
        self.assertFalse(by_id["android_logcat_triage"]["installed"])
        hits = json.loads(text(responses[2]))
        self.assertEqual(hits[0]["id"], "android_logcat_triage")
        self.assertTrue(all(hit["why"] and hit["score"] > 0 for hit in hits))
        self.assertEqual(hits, sorted(hits, key=lambda hit: (-hit["score"], hit["id"])))
        self.assertFalse(hits[0]["installed"])

    def test_search_uses_words_and_simple_plurals_without_substring_noise(self):
        entries = [
            {"id": "catalog_helper", "title": "Catalog Assistant", "description": "Find items in a catalog.", "cli": ""},
            {"id": "log_review", "title": "Log Review", "description": "Analyze crash logs.", "cli": ""},
            {"id": "texture_health", "title": "Texture Health", "description": "Review texture sizes.", "cli": ""},
        ]
        server = mcp_server.Server(self.project, "godot", 1, entries)
        self.assertEqual([hit["id"] for hit in server.search("log")], ["log_review"])
        plural = server.search("why are textures so large")
        self.assertEqual([hit["id"] for hit in plural], ["texture_health"])
        self.assertEqual(plural[0]["why"], ["matches 'textures' in title or id"])
        self.assertEqual(server.search("why are so"), [])
        self.assertEqual(server.search("TEXTURES, textures"), server.search("textures"))

    def test_internal_error_keeps_the_id_without_exposing_details(self):
        class BrokenServer:
            def handle(self, method, params):
                raise RuntimeError("private detail")

        response = mcp_server.dispatch(BrokenServer(), request("keep-id", "ping"))
        self.assertEqual(response, {"jsonrpc": "2.0", "id": "keep-id",
                                    "error": {"code": -32603, "message": "Internal error"}})

    def test_invalid_tool_arguments_are_protocol_errors_with_original_ids(self):
        messages = [call("unknown", "run_not_a_tool"), call("bad-name", 42),
                    call("string", "run_android_export_audit", {"args": "--bad"}),
                    call("number", "run_android_export_audit", {"args": [1]}),
                    call("nul", "run_android_export_audit", {"args": ["x\u0000y"]}),
                    call("surrogate", "run_android_export_audit", {"args": ["\ud800"]}),
                    call("long", "run_android_export_audit", {"args": ["x" * (mcp_server.MAX_ARG_LENGTH + 1)]}),
                    call("many", "run_android_export_audit", {"args": ["x"] * 65}),
                    call("extra", "run_android_export_audit", {"args": [], "other": True}),
                    call("empty", "search_tools", {"query": "  "}),
                    call("wrong", "search_tools", {"query": 17}),
                    call("long-query", "search_tools", {"query": "x" * (mcp_server.MAX_QUERY_LENGTH + 1)}),
                    call("query-surrogate", "search_tools", {"query": "\udfff"}),
                    call("list", "list_tools", {"unexpected": True}),
                    request("cursor", "tools/list", {"cursor": "unexpected"})]
        responses = self.exchange(messages)
        self.assertEqual([r["id"] for r in responses], [m["id"] for m in messages])
        self.assertTrue(all(r["error"]["code"] == -32602 for r in responses))
        self.assertFalse(self.trace.exists())

    def test_missing_addon_is_not_advertised_and_call_fails_cleanly(self):
        responses = self.exchange([request(1, "tools/list"), call(2, "run_android_touch_audit")])
        names = {item["name"] for item in responses[0]["result"]["tools"]}
        self.assertNotIn("run_android_touch_audit", names)
        self.assertTrue(responses[1]["result"]["isError"])
        self.assertIn("not installed", text(responses[1]))

    def test_bad_project_and_timeout_are_rejected_at_startup(self):
        for changes, message in [({"GDT_PROJECT_ROOT": str(self.work / "missing")}, b"project.godot"),
                                 ({"GDT_PROJECT_ROOT": ""}, b"GDT_PROJECT_ROOT"),
                                 ({"GODOT_BIN": ""}, b"GODOT_BIN"),
                                 ({"GDT_MCP_TIMEOUT": "nan"}, b"GDT_MCP_TIMEOUT"),
                                 ({"GDT_MCP_TIMEOUT": "0"}, b"GDT_MCP_TIMEOUT"),
                                 ({"GDT_MCP_TIMEOUT": "3601"}, b"GDT_MCP_TIMEOUT")]:
            with self.subTest(changes=changes):
                env = {**self.env, **changes}
                result = self.run_raw(json.dumps(request(1, "ping")).encode() + b"\n", env=env)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, b"")
                self.assertIn(message, result.stderr)

    def test_default_project_and_dynamic_install_discovery(self):
        env = dict(self.env)
        del env["GDT_PROJECT_ROOT"]
        responses = self.exchange([call(1, "list_tools")], env=env)
        catalog = json.loads(text(responses[0]))
        self.assertTrue(next(entry for entry in catalog if entry["id"] == "android_touch_audit")["installed"])

        server = mcp_server.Server(self.project, "godot", 1, mcp_server.load_catalog())
        entry = server.by_id["android_export_audit"]
        cli = self.project / entry["cli"]
        self.assertIsNotNone(server.installed_cli(entry))
        cli.unlink()
        self.assertIsNone(server.installed_cli(entry))
        self.assertNotIn("run_android_export_audit", {item["name"] for item in server.definitions()})
        cli.write_text("# restored\n", encoding="utf-8")
        self.assertIn("run_android_export_audit", {item["name"] for item in server.definitions()})

    def test_invalid_catalog_and_escaping_cli_paths_are_rejected(self):
        catalog = self.work / "catalog.json"
        catalog.write_text(json.dumps({"tools": [{"id": "../x", "title": "X", "description": "", "cli": ""}]}))
        with self.assertRaises(ValueError):
            mcp_server.load_catalog(catalog)
        duplicate = {"id": "valid", "title": "X", "description": "", "cli": ""}
        catalog.write_text(json.dumps({"tools": [duplicate, duplicate]}))
        with self.assertRaises(ValueError):
            mcp_server.load_catalog(catalog)
        server = mcp_server.Server(self.project, "godot", 1, [])
        for path in ("../escape_cli.gd", "/addons/valid/cli/a_cli.gd", "addons/valid/cli/../../evil_cli.gd",
                     "addons/valid/cli/evil\\name_cli.gd"):
            with self.subTest(path=path):
                self.assertIsNone(server.installed_cli({"id": "valid", "cli": path}))

    @unittest.skipUnless(os.name == "posix", "symlinks and fake executable require POSIX")
    def test_symlinked_cli_cannot_escape_selected_project(self):
        cli = self.project / "addons/android_export_audit/cli/aea_cli.gd"
        cli.unlink()
        outside = self.work / "outside.gd"
        outside.write_text("outside")
        cli.symlink_to(outside)
        responses = self.exchange([request(1, "tools/list"), call(2, "run_android_export_audit")])
        self.assertNotIn("run_android_export_audit", {t["name"] for t in responses[0]["result"]["tools"]})
        self.assertTrue(responses[1]["result"]["isError"])
        self.assertFalse(self.trace.exists())

    @unittest.skipUnless(os.name == "posix", "fake executable requires POSIX")
    def test_real_argv_cwd_exit_codes_and_no_shell_interpolation(self):
        marker = self.work / "should-not-exist"
        injection = f"$(touch {marker})"
        responses = self.exchange([
            call(1, "run_android_export_audit", {"args": ["--case=clean", "argument with spaces", injection]}),
            call(2, "run_android_export_audit", {"args": ["--case=finding"]}),
            call(3, "run_android_export_audit", {"args": ["--case=error"]}),
        ])
        self.assertEqual([r["id"] for r in responses], [1, 2, 3])
        self.assertIn("exit=0\nstdout:\n", text(responses[0]))
        self.assertIn("\nstderr:\nfake Godot stderr", text(responses[0]))
        self.assertNotIn("isError", responses[0]["result"])
        self.assertIn("exit=2", text(responses[1]))
        self.assertNotIn("isError", responses[1]["result"])
        self.assertIn("exit=1", text(responses[2]))
        self.assertTrue(responses[2]["result"]["isError"])
        self.assertFalse(marker.exists())
        calls = [json.loads(line) for line in self.trace.read_text().splitlines()]
        self.assertEqual(len(calls), 3)
        self.assertEqual(Path(calls[0]["cwd"]).resolve(), self.project.resolve())
        self.assertEqual(calls[0]["args"][:6], ["--headless", "--path", str(self.project), "--script",
                                                "res://addons/android_export_audit/cli/aea_cli.gd", "--"])
        self.assertEqual(calls[0]["args"][-2:], ["argument with spaces", injection])

    @unittest.skipUnless(os.name == "posix", "fake executable requires POSIX")
    def test_godot_executable_resolves_from_startup_directory_or_path(self):
        payload = json.dumps(call(1, "run_android_export_audit", {"args": ["--case=clean"]})).encode() + b"\n"
        for executable in ("./fake-godot", "fake-godot"):
            with self.subTest(executable=executable):
                env = {**self.env, "GODOT_BIN": executable, "PATH": str(self.work) + os.pathsep + self.env.get("PATH", "")}
                result = self.run_raw(payload, env=env, cwd=self.work)
                self.assertEqual(result.returncode, 0, result.stderr)
                response = json.loads(result.stdout)
                self.assertIn("exit=0\n", text(response))
                self.assertFalse(response["result"].get("isError", False))

    @unittest.skipUnless(os.name == "posix", "fake executable requires POSIX")
    def test_large_and_non_utf8_child_output_is_bounded(self):
        responses = self.exchange([call(1, "run_android_export_audit", {"args": ["--case=large"]}),
                                   call(2, "run_android_export_audit", {"args": ["--case=bytes"]})])
        output = text(responses[0])
        self.assertIn("OUT-START", output)
        self.assertIn("ERR-START", output)
        self.assertIn("[stdout truncated", output)
        self.assertIn("[stderr truncated", output)
        self.assertLess(len(output), 2 * mcp_server.MAX_STREAM_BYTES + 500)
        self.assertNotIn("isError", responses[0]["result"])
        self.assertIn("\ufffd", text(responses[1]))

    @unittest.skipUnless(os.name == "posix", "fake executable requires POSIX")
    def test_timeout_is_a_tool_error_and_server_continues(self):
        env = {**self.env, "GDT_MCP_TIMEOUT": "0.2"}
        start = time.monotonic()
        responses = self.exchange([call("slow", "run_android_export_audit", {"args": ["--case=sleep"]}),
                                   request("next", "ping")], env=env, timeout=10)
        self.assertLess(time.monotonic() - start, 8)
        self.assertEqual(responses[0]["id"], "slow")
        self.assertTrue(responses[0]["result"]["isError"])
        self.assertIn("timed out", text(responses[0]))
        self.assertIn("partial before timeout", text(responses[0]))
        self.assertEqual(responses[1]["result"], {})

    @unittest.skipUnless(os.name == "posix", "process-group cleanup is POSIX-specific")
    def test_timeout_stops_same_group_child(self):
        marker = self.work / "child-survived"
        ready = self.work / "child-ready"
        env = {**self.env, "GDT_MCP_TIMEOUT": "1", "MCP_CHILD_MARKER": str(marker), "MCP_CHILD_READY": str(ready)}
        responses = self.exchange([call(1, "run_android_export_audit", {"args": ["--case=spawn"]})], env=env, timeout=10)
        self.assertTrue(responses[0]["result"]["isError"])
        self.assertIn("timed out", text(responses[0]))
        self.assertTrue(ready.exists(), "fake child did not start before timeout")
        time.sleep(1.2)  # The fake child would create the marker after two seconds if it survived.
        self.assertFalse(marker.exists())

    @unittest.skipUnless(os.name == "posix", "signal and process-group cleanup are POSIX-specific")
    def test_server_termination_stops_same_group_child(self):
        marker = self.work / "child-survived-server"
        ready = self.work / "child-ready-server"
        env = {**self.env, "MCP_CHILD_MARKER": str(marker), "MCP_CHILD_READY": str(ready)}
        payload = json.dumps(call(1, "run_android_export_audit", {"args": ["--case=spawn"]})).encode() + b"\n"
        process = subprocess.Popen([sys.executable, str(SERVER)], stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
        try:
            process.stdin.write(payload)
            process.stdin.flush()
            deadline = time.monotonic() + 4
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(ready.exists(), "fake child did not start")
            process.terminate()
            stdout, stderr = process.communicate(timeout=5)
            self.assertNotEqual(process.returncode, 0, (stdout, stderr))
            time.sleep(2.1)
            self.assertFalse(marker.exists(), "child survived termination of the server")
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.communicate(timeout=5)

    @unittest.skipUnless(os.name == "posix", "process-group cleanup is POSIX-specific")
    def test_inherited_output_pipe_marks_successful_parent_as_incomplete(self):
        marker = self.work / "child-survived-parent"
        ready = self.work / "child-ready-parent"
        env = {**self.env, "MCP_CHILD_MARKER": str(marker), "MCP_CHILD_READY": str(ready)}
        responses = self.exchange([call(1, "run_android_export_audit", {"args": ["--case=spawn-exit"]}),
                                   request(2, "ping")], env=env, timeout=10)
        self.assertTrue(ready.exists())
        self.assertTrue(responses[0]["result"]["isError"])
        self.assertIn("exit=0\n", text(responses[0]))
        self.assertIn("held an output pipe open", text(responses[0]))
        self.assertEqual(responses[1]["result"], {})
        time.sleep(1.2)  # The child would otherwise create the marker two seconds after starting.
        self.assertFalse(marker.exists())

    @unittest.skipUnless(os.name == "posix", "fake executable requires POSIX")
    def test_godot_smoke_harness_with_fake_executable(self):
        self.fake.write_text(SMOKE_FAKE_GODOT, encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()) as output:
            mcp_godot_smoke.run_smoke(str(self.fake))
        self.assertIn("MCP Godot smoke passed", output.getvalue())

    @unittest.skipUnless(os.name == "posix", "fake executable requires POSIX")
    def test_godot_smoke_harness_rejects_false_success(self):
        self.fake.write_text(SMOKE_FAKE_GODOT, encoding="utf-8")
        for fault, message in (("script-error", "Godot script error"), ("secret", "fixture secret"),
                               ("wrong-exit", "incorrect exit"), ("wrong-report", "issue count mismatch")):
            with self.subTest(fault=fault), mock.patch.dict(os.environ, {"MCP_SMOKE_FAULT": fault}):
                with self.assertRaisesRegex(mcp_godot_smoke.SmokeFailure, message):
                    mcp_godot_smoke.run_smoke(str(self.fake))

    def test_missing_godot_is_a_tool_error_and_server_continues(self):
        env = {**self.env, "GODOT_BIN": str(self.work / "no-such-godot")}
        responses = self.exchange([call("missing", "run_android_export_audit"), request("next", "ping")], env=env)
        self.assertTrue(responses[0]["result"]["isError"])
        self.assertIn("Could not start Godot", text(responses[0]))
        self.assertEqual(responses[1]["id"], "next")
        self.assertEqual(responses[1]["result"], {})


if __name__ == "__main__":
    unittest.main(verbosity=2)
