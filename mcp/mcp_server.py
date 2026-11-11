#!/usr/bin/env python3
"""Offline GodotDevTools MCP server using newline-delimited JSON-RPC over stdio.

Set GDT_PROJECT_ROOT to a trusted Godot project containing the desired addons;
otherwise the checkout containing this server is used. GODOT_BIN selects the
Godot executable. This is a deliberately small MCP 2024-11-05 tools subset.
"""

import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import signal
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "docs" / "catalog.json"
PROTOCOL_VERSION = "2024-11-05"
MAX_REQUEST_BYTES = 1024 * 1024
MAX_STREAM_BYTES = 64 * 1024
MAX_ARGS = 64
MAX_ARG_LENGTH = 4096
MAX_QUERY_LENGTH = 2048
STOP_WORDS = {
    "a", "an", "and", "are", "can", "could", "do", "does", "for", "from", "how", "i", "in", "is", "it",
    "me", "my", "of", "on", "or", "please", "so", "the", "this", "to", "what", "when", "where", "why", "with",
}
ID_PATTERN = re.compile(r"[a-z0-9_]+\Z")
WORD_PATTERN = re.compile(r"[^\W_]+")


class RpcError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def load_catalog(path=CATALOG):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    entries = data.get("tools") if isinstance(data, dict) else None
    if not isinstance(entries, list):
        raise ValueError("catalog must contain a tools array")
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("catalog entries must be objects")
        tool_id = entry.get("id")
        if not isinstance(tool_id, str) or not ID_PATTERN.fullmatch(tool_id) or tool_id in seen:
            raise ValueError(f"invalid or duplicate tool id: {tool_id!r}")
        if not all(isinstance(entry.get(key), str) for key in ("title", "description", "cli")):
            raise ValueError(f"invalid catalog fields for {tool_id}")
        seen.add(tool_id)
    return entries


def configured_timeout(value):
    try:
        timeout = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError("GDT_MCP_TIMEOUT must be a number greater than 0 and at most 3600 seconds") from exc
    if not math.isfinite(timeout) or timeout <= 0 or timeout > 3600:
        raise ValueError("GDT_MCP_TIMEOUT must be a number greater than 0 and at most 3600 seconds")
    return timeout


def text_result(text, is_error=False):
    result = {"content": [{"type": "text", "text": text}]}
    if is_error:
        result["isError"] = True
    return result


def word_forms(word):
    """Return a word and a few simple plural forms, not arbitrary substrings."""
    forms = {word}
    if len(word) >= 5 and word.endswith("ies"):
        forms.add(word[:-3] + "y")
    elif len(word) >= 5 and word.endswith("es"):
        forms.update((word[:-1], word[:-2]))
    elif len(word) >= 4 and word.endswith("s") and not word.endswith("ss"):
        forms.add(word[:-1])
    return forms


def field_words(text):
    return set().union(*(word_forms(word) for word in WORD_PATTERN.findall(text.casefold())))


def has_surrogate(text):
    return any(0xD800 <= ord(char) <= 0xDFFF for char in text)


class StreamCapture:
    """Drain a child pipe while retaining at most MAX_STREAM_BYTES in memory."""

    def __init__(self, stream):
        self.stream = stream
        self.data = bytearray()
        self.total = 0
        self.error = None
        self.lock = threading.Lock()

    def read(self):
        try:
            while True:
                chunk = self.stream.read(8192)
                if not chunk:
                    break
                with self.lock:
                    self.total += len(chunk)
                    remaining = max(0, MAX_STREAM_BYTES - len(self.data))
                    self.data.extend(chunk[:remaining])
        except (OSError, ValueError) as exc:
            with self.lock:
                self.error = str(exc)
        finally:
            self.stream.close()

    def text(self, label):
        with self.lock:
            data = bytes(self.data)
            total = self.total
            error = self.error
        result = data.decode("utf-8", errors="replace")
        if total > len(data):
            result += f"\n[{label} truncated after {len(data)} of {total} bytes]"
        if error:
            result += f"\n[{label} capture error: {error}]"
        return result, error is not None


def kill_group(process):
    """Best-effort cleanup; detached descendants and Windows children may survive."""
    if os.name == "posix":
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except OSError:
            pass
    if process.poll() is None:
        try:
            process.kill()
        except OSError:
            pass


def wait_readers(readers, timeout):
    deadline = time.monotonic() + timeout
    for reader in readers:
        reader.join(timeout=max(0, deadline - time.monotonic()))


def run_process(command, cwd, timeout):
    try:
        process = subprocess.Popen(
            command, cwd=cwd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            bufsize=0, start_new_session=(os.name == "posix"),
        )
    except OSError as exc:
        return text_result(f"Could not start Godot: {exc}", True)

    try:
        return collect_process_output(process, timeout)
    except BaseException:
        # SIGINT/SIGTERM or an unexpected capture failure should not leave an
        # ordinary same-group Godot child running on POSIX.
        kill_group(process)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        raise


def collect_process_output(process, timeout):
    captures = [StreamCapture(process.stdout), StreamCapture(process.stderr)]
    readers = [threading.Thread(target=capture.read, daemon=True) for capture in captures]
    for reader in readers:
        reader.start()
    timed_out = False
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        kill_group(process)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
    wait_readers(readers, 1)
    # A child that inherited a pipe can keep it open after its parent exits.
    held_pipe = any(reader.is_alive() for reader in readers)
    if held_pipe:
        kill_group(process)
        wait_readers(readers, 1)
    incomplete = any(reader.is_alive() for reader in readers)
    stdout, stdout_error = captures[0].text("stdout")
    stderr, stderr_error = captures[1].text("stderr")
    status = "timeout" if timed_out else str(process.returncode)
    text = f"exit={status}\nstdout:\n{stdout}\nstderr:\n{stderr}"
    if timed_out:
        text += f"\nGodot timed out after {timeout:g} seconds."
    if held_pipe:
        text += "\nA child held an output pipe open after Godot exited; cleanup was attempted and the result may be incomplete."
    if incomplete:
        text += "\nOutput capture is incomplete; a child may still hold a pipe open."
    return text_result(text, timed_out or held_pipe or incomplete or stdout_error or stderr_error or process.returncode not in (0, 2))


class Server:
    def __init__(self, project, godot, timeout, catalog):
        if isinstance(project, str) and not project.strip():
            raise ValueError("GDT_PROJECT_ROOT must not be empty")
        self.project = Path(project).expanduser().resolve()
        if not self.project.is_dir() or not (self.project / "project.godot").is_file():
            raise ValueError(f"GDT_PROJECT_ROOT must be a Godot project containing project.godot: {self.project}")
        if not isinstance(godot, str) or not godot.strip():
            raise ValueError("GODOT_BIN must not be empty")
        # A relative executable path is relative to the server's startup directory,
        # not to the selected project used as the child's working directory.
        if os.sep in godot or (os.altsep and os.altsep in godot):
            godot = str(Path(godot).expanduser().resolve())
        self.godot = godot
        self.timeout = timeout
        self.catalog = catalog
        self.by_id = {entry["id"]: entry for entry in catalog}

    def installed_cli(self, entry):
        cli = entry["cli"]
        if not cli or "\\" in cli:
            return None
        path = PurePosixPath(cli)
        parts = path.parts
        if path.is_absolute() or len(parts) != 4 or parts[:3] != ("addons", entry["id"], "cli"):
            return None
        if not parts[-1].endswith("_cli.gd") or ".." in parts:
            return None
        candidate = self.project.joinpath(*parts)
        try:
            resolved = candidate.resolve(strict=True)
            resolved.relative_to(self.project)
        except (OSError, RuntimeError, ValueError):
            return None
        return cli if resolved.is_file() else None

    def catalog_view(self):
        return [{**entry, "installed": self.installed_cli(entry) is not None} for entry in self.catalog]

    def search(self, query):
        words = []
        for word in WORD_PATTERN.findall(query.casefold()):
            if len(word) >= 2 and word not in STOP_WORDS and word not in words:
                words.append(word)
        matches = []
        for entry in self.catalog_view():
            title_and_id = field_words(entry["title"] + " " + entry["id"])
            description = field_words(entry["description"])
            why = []
            score = 0
            for word in words:
                forms = word_forms(word)
                if not forms.isdisjoint(title_and_id):
                    score += 3
                    why.append(f"matches '{word}' in title or id")
                elif not forms.isdisjoint(description):
                    score += 1
                    why.append(f"matches '{word}' in description")
            if score:
                matches.append({**entry, "score": score, "why": why})
        return sorted(matches, key=lambda entry: (-entry["score"], entry["id"]))

    def definitions(self):
        tools = [{"name": "list_tools", "description": "List the catalog and indicate which CLI tools are installed in the selected project.",
                  "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}}]
        for entry in self.catalog:
            if self.installed_cli(entry) is not None:
                tools.append({"name": f"run_{entry['id']}",
                              "description": f"Run {entry['title']}: {entry['description']} CLI arguments may write files or execute project code.",
                              "inputSchema": {"type": "object", "properties": {"args": {"type": "array",
                              "items": {"type": "string", "maxLength": MAX_ARG_LENGTH}, "maxItems": MAX_ARGS,
                              "description": "Separate CLI arguments, e.g. ['--help']; see the addon README."}}, "additionalProperties": False}})
        tools.append({"name": "search_tools", "description": "Rank catalog entries by matched words in their title, description and id; each match explains why.",
                      "inputSchema": {"type": "object", "properties": {"query": {"type": "string", "minLength": 1, "maxLength": MAX_QUERY_LENGTH}},
                                      "required": ["query"], "additionalProperties": False}})
        return tools

    def call(self, params):
        name = params.get("name")
        if not isinstance(name, str) or not name:
            raise RpcError(-32602, "tools/call requires a tool name")
        arguments = params.get("arguments", {})
        if not isinstance(arguments, dict):
            raise RpcError(-32602, "tool arguments must be an object")
        if name == "list_tools":
            if arguments:
                raise RpcError(-32602, "list_tools takes no arguments")
            return text_result(json.dumps(self.catalog_view(), indent=2))
        if name == "search_tools":
            query = arguments.get("query")
            if (set(arguments) != {"query"} or not isinstance(query, str) or not query.strip()
                    or len(query) > MAX_QUERY_LENGTH or "\x00" in query or has_surrogate(query)):
                raise RpcError(-32602, f"query must be a nonempty string of at most {MAX_QUERY_LENGTH} characters without NUL or surrogate characters")
            return text_result(json.dumps(self.search(query), indent=2))
        if not name.startswith("run_") or name[4:] not in self.by_id:
            raise RpcError(-32602, f"unknown tool: {name}")
        entry = self.by_id[name[4:]]
        if set(arguments) - {"args"}:
            raise RpcError(-32602, "run tools accept only an args array")
        args = arguments.get("args", [])
        if (not isinstance(args, list) or len(args) > MAX_ARGS or
                any(not isinstance(arg, str) or len(arg) > MAX_ARG_LENGTH or "\x00" in arg or has_surrogate(arg) for arg in args)):
            raise RpcError(-32602, f"args must contain at most {MAX_ARGS} strings of at most {MAX_ARG_LENGTH} characters without NUL or surrogate characters")
        cli = self.installed_cli(entry)
        if cli is None:
            return text_result(f"Tool {entry['id']} is not installed in the selected project, or its CLI is outside the project.", True)
        command = [self.godot, "--headless", "--path", str(self.project), "--script", "res://" + cli, "--", *args]
        return run_process(command, self.project, self.timeout)

    def handle(self, method, params):
        if method == "initialize":
            return {"protocolVersion": PROTOCOL_VERSION, "capabilities": {"tools": {"listChanged": False}},
                    "serverInfo": {"name": "godot-dev-tools", "version": "1.1.0"}}
        if method == "ping":
            return {}
        if method == "tools/list":
            if params.get("cursor") is not None:
                raise RpcError(-32602, "pagination cursors are not supported")
            return {"tools": self.definitions()}
        if method == "tools/call":
            return self.call(params)
        raise RpcError(-32601, f"method not found: {method}")


def error_response(request_id, code, message):
    return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def dispatch(server, request):
    if not isinstance(request, dict) or request.get("jsonrpc") != "2.0" or not isinstance(request.get("method"), str):
        return error_response(None, -32600, "Invalid Request")
    request_id = request.get("id")
    if "id" in request and not (request_id is None or type(request_id) is int or isinstance(request_id, str)):
        return error_response(None, -32600, "Invalid Request")
    # MCP notifications have no id and must not receive a response. Ignore them,
    # including malformed attempts to invoke a request-only tool without an id.
    if "id" not in request:
        return None
    params = request.get("params", {})
    if not isinstance(params, dict):
        return error_response(request_id, -32602, "params must be an object")
    try:
        return {"jsonrpc": "2.0", "id": request_id, "result": server.handle(request["method"], params)}
    except RpcError as exc:
        return error_response(request_id, exc.code, exc.message)
    except Exception:
        return error_response(request_id, -32603, "Internal error")


def _bad_constant(value):
    raise ValueError(f"invalid JSON constant: {value}")


def terminate_on_signal(signum, _frame):
    raise SystemExit(128 + signum)


def main():
    if os.name == "posix":
        signal.signal(signal.SIGTERM, terminate_on_signal)
    try:
        project = os.environ.get("GDT_PROJECT_ROOT", str(ROOT))
        godot = os.environ.get("GODOT_BIN", "godot")
        timeout = configured_timeout(os.environ.get("GDT_MCP_TIMEOUT", "300"))
        server = Server(project, godot, timeout, load_catalog())
    except (OSError, UnicodeError, ValueError, RuntimeError) as exc:
        print(f"mcp: {exc}", file=sys.stderr)
        return 1
    reader = sys.stdin.buffer
    while True:
        line = reader.readline(MAX_REQUEST_BYTES + 1)
        if not line:
            break
        if len(line) > MAX_REQUEST_BYTES:
            while line and not line.endswith(b"\n"):
                line = reader.readline(MAX_REQUEST_BYTES + 1)
            response = error_response(None, -32600, "Request exceeds size limit")
        elif not line.strip():
            continue
        else:
            try:
                request = json.loads(line.decode("utf-8"), parse_constant=_bad_constant)
                response = dispatch(server, request)
            except (UnicodeError, ValueError, RecursionError):
                response = error_response(None, -32700, "Parse error")
        if response is not None:
            print(json.dumps(response, ensure_ascii=True, separators=(",", ":")), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
