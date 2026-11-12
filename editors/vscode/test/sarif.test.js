'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const Module = require('node:module');
const { URI, Utils } = require('vscode-uri');
// VS Code exposes joinPath on Uri; vscode-uri exports the same operation as Utils.
const Uri = { file: URI.file, joinPath: Utils.joinPath };
const { convertSarif, loadSarif, createLoadCommand } = require('../src/sarif');

class Range {
  constructor(startLine, startColumn, endLine, endColumn) {
    this.start = { line: startLine, character: startColumn };
    this.end = { line: endLine, character: endColumn };
  }
}
class Diagnostic {
  constructor(range, message, severity) { Object.assign(this, { range, message, severity }); }
}
class Collection {
  constructor() { this.files = new Map(); this.clearCount = 0; }
  clear() { this.clearCount++; this.files.clear(); }
  set(entries) { for (const [uri, diagnostics] of entries) this.files.set(uri.toString(), diagnostics); }
  get(uri) { return this.files.get(uri.toString()); }
  dispose() {}
}

function mockVscode(folders = []) {
  const state = { selected: undefined, selectedFolder: 0, quickPickItems: [], errors: [], messages: [], registered: [] };
  const collection = new Collection();
  const vscode = {
    Uri, Range, Diagnostic,
    DiagnosticSeverity: { Error: 0, Warning: 1, Information: 2, Hint: 3 },
    workspace: {
      workspaceFolders: folders.map((folder, index) => ({ name: `project-${index}`, uri: Uri.file(folder) })),
      fs: { readFile: uri => fs.promises.readFile(uri.fsPath) },
    },
    window: {
      showOpenDialog: async () => state.selected,
      showQuickPick: async items => { state.quickPickItems = items; return items[state.selectedFolder]; },
      showErrorMessage: message => { state.errors.push(message); },
      showInformationMessage: message => { state.messages.push(message); },
    },
    languages: { createDiagnosticCollection: () => collection },
    commands: { registerCommand: (name, handler) => { state.registered.push({ name, handler }); return { dispose() {} }; } },
  };
  return { vscode, state, collection };
}

function tempDir(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'gdt-vscode-sarif-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}
function finding(uri, options = {}) {
  const artifactLocation = { uri };
  if (options.base !== null) artifactLocation.uriBaseId = options.base || 'PROJECTROOT';
  const physicalLocation = { artifactLocation };
  if (options.region !== undefined) physicalLocation.region = options.region;
  return {
    ruleId: options.rule || 'example_rule',
    level: options.level || 'warning',
    message: { text: options.message || 'Example finding. Fix: inspect it.' },
    locations: [{ physicalLocation }],
  };
}
function report(...runs) {
  return { version: '2.1.0', runs: runs.map(results => ({
    originalUriBaseIds: { PROJECTROOT: { uri: 'file:///' } }, results,
  })) };
}
function writeReport(dir, name, data) {
  const target = path.join(dir, name);
  fs.writeFileSync(target, typeof data === 'string' ? data : JSON.stringify(data));
  return Uri.file(target);
}
function diagnosticsAt(converted, uri) {
  const entry = converted.entries.find(([key]) => key.toString() === uri.toString());
  return entry && entry[1];
}

test('maps exporter-relative locations, ranges, severities and multiple runs', t => {
  const dir = tempDir(t);
  const { vscode } = mockVscode([dir]);
  const root = Uri.file(dir);
  const data = report([
    finding('scripts/player.gd', { region: { startLine: 17 } }),
    finding('scripts/player.gd', { rule: 'fatal', level: 'error', region: { startLine: 17, startColumn: 3, endLine: 17, endColumn: 7 } }),
    finding('art/orphan.png', { level: 'note' }),
    finding('notes.txt', { level: 'none' }),
  ], [finding('scripts/player.gd', { rule: 'second_run', region: { startLine: -1, startColumn: 0 } })]);
  const converted = convertSarif(vscode, data, root);
  assert.equal(converted.entries.length, 3);
  assert.equal(converted.findings, 5);
  assert.equal(converted.skipped, 0);
  const player = diagnosticsAt(converted, Uri.joinPath(root, 'scripts', 'player.gd'));
  assert.equal(player.length, 3);
  assert.deepEqual(player[0].range.start, { line: 16, character: 0 });
  assert.deepEqual(player[0].range.end, { line: 16, character: 1 });
  assert.equal(player[0].severity, vscode.DiagnosticSeverity.Warning);
  assert.equal(player[0].source, 'godot-dev-tools');
  assert.equal(player[0].code, 'example_rule');
  assert.equal(player[0].message, 'Example finding. Fix: inspect it.');
  assert.deepEqual(player[1].range.start, { line: 16, character: 2 });
  assert.deepEqual(player[1].range.end, { line: 16, character: 6 });
  assert.equal(player[1].severity, vscode.DiagnosticSeverity.Error);
  assert.deepEqual(player[2].range.start, { line: 0, character: 0 });
  assert.equal(diagnosticsAt(converted, Uri.joinPath(root, 'art', 'orphan.png'))[0].severity, vscode.DiagnosticSeverity.Information);
  assert.equal(diagnosticsAt(converted, Uri.joinPath(root, 'notes.txt'))[0].severity, vscode.DiagnosticSeverity.Hint);
});

test('preserves raw exporter paths with spaces, hash, percent and Unicode', t => {
  const dir = tempDir(t);
  const { vscode } = mockVscode([dir]);
  const root = Uri.file(dir);
  const converted = convertSarif(vscode, report([finding('scènes/100% # Café.gd', { base: null })]), root);
  const uri = Uri.joinPath(root, 'scènes', '100% # Café.gd');
  assert.equal(converted.findings, 1);
  assert.ok(diagnosticsAt(converted, uri));
  const expected = path.join(dir, 'scènes', '100% # Café.gd');
  assert.equal(Uri.file(uri.fsPath).toString(), Uri.file(expected).toString());
  assert.equal(path.basename(uri.fsPath), '100% # Café.gd');
  assert.match(uri.toString(), /%25/);
  assert.match(uri.toString(), /%23/);
});

test('skips missing, absolute, traversal, foreign-base and nonlocal locations', t => {
  const dir = tempDir(t);
  const { vscode } = mockVscode([dir]);
  const root = Uri.file(dir);
  const bad = [
    finding('../outside.gd'), finding('a/../outside.gd'), finding('/etc/passwd'),
    finding('C:/outside.gd'), finding('https://example.com/a.gd'), finding('a\\b.gd'),
    finding('bad\0path.gd'), finding('file.gd', { base: 'OTHER' }),
    { ruleId: 'without_location', message: { text: 'no location' } }, null,
  ];
  // The exporter writes raw paths: %2E%2E is a literal directory name, not '..'.
  const converted = convertSarif(vscode, report([...bad, finding('%2E%2E/literal.gd')]), root);
  assert.equal(converted.skipped, bad.length);
  assert.equal(converted.findings, 1);
  assert.ok(diagnosticsAt(converted, Uri.joinPath(root, '%2E%2E', 'literal.gd')));
});

test('rejects malformed SARIF structure rather than silently clearing diagnostics', t => {
  const dir = tempDir(t);
  const { vscode } = mockVscode([dir]);
  for (const bad of [null, [], {}, { version: '2.1.0', runs: {} }, { version: '1.0', runs: [] },
    { version: '2.1.0', runs: [null] }, { version: '2.1.0', runs: [{ results: 'invalid' }] }]) {
    assert.throws(() => convertSarif(vscode, bad, Uri.file(dir)));
  }
});

test('replaces old findings on success and keeps them on read or parse failure', async t => {
  const dir = tempDir(t);
  const { vscode, collection } = mockVscode([dir]);
  const root = Uri.file(dir);
  const oldUri = Uri.joinPath(root, 'old.gd');
  const newUri = Uri.joinPath(root, 'new.gd');
  const oldReport = writeReport(dir, 'old.sarif', report([finding('old.gd')]));
  const newReport = writeReport(dir, 'new.sarif', report([finding('new.gd')]));
  const invalid = writeReport(dir, 'invalid.sarif', '{');
  await loadSarif(vscode, collection, oldReport, root);
  assert.ok(collection.get(oldUri));
  const clears = collection.clearCount;
  await assert.rejects(loadSarif(vscode, collection, invalid, root));
  await assert.rejects(loadSarif(vscode, collection, Uri.file(path.join(dir, 'missing.sarif')), root));
  assert.equal(collection.clearCount, clears);
  assert.ok(collection.get(oldUri));
  await loadSarif(vscode, collection, newReport, root);
  assert.equal(collection.get(oldUri), undefined);
  assert.ok(collection.get(newUri));
  await loadSarif(vscode, collection, writeReport(dir, 'empty.sarif', report([])), root);
  assert.equal(collection.files.size, 0);
});

test('interactive errors and cancellation preserve the previous collection', async t => {
  const dir = tempDir(t);
  const { vscode, state, collection } = mockVscode([dir]);
  const root = Uri.file(dir);
  await loadSarif(vscode, collection, writeReport(dir, 'valid.sarif', report([finding('old.gd')])), root);
  const run = createLoadCommand(vscode, collection);
  await run();
  assert.ok(collection.get(Uri.joinPath(root, 'old.gd')));
  state.selected = [writeReport(dir, 'bad.sarif', '{')];
  await run();
  assert.equal(state.errors.length, 1);
  assert.match(state.errors[0], /could not load SARIF/i);
  assert.ok(collection.get(Uri.joinPath(root, 'old.gd')));
});

test('a slower earlier load cannot overwrite a newer report', async t => {
  const dir = tempDir(t);
  const { vscode, state, collection } = mockVscode([dir]);
  const firstUri = Uri.file(path.join(dir, 'first.sarif'));
  const secondUri = Uri.file(path.join(dir, 'second.sarif'));
  const pending = new Map();
  vscode.workspace.fs.readFile = uri => new Promise(resolve => pending.set(uri.toString(), resolve));
  const run = createLoadCommand(vscode, collection);
  state.selected = [firstUri];
  const first = run();
  await new Promise(resolve => setImmediate(resolve));
  state.selected = [secondUri];
  const second = run();
  await new Promise(resolve => setImmediate(resolve));
  pending.get(secondUri.toString())(Buffer.from(JSON.stringify(report([finding('new.gd')]))));
  await second;
  pending.get(firstUri.toString())(Buffer.from(JSON.stringify(report([finding('old.gd')]))));
  await first;
  const root = Uri.file(dir);
  assert.ok(collection.get(Uri.joinPath(root, 'new.gd')));
  assert.equal(collection.get(Uri.joinPath(root, 'old.gd')), undefined);
  assert.equal(state.messages.length, 1);
});

test('no workspace reports an actionable error without clearing diagnostics', async t => {
  const dir = tempDir(t);
  const { vscode, state, collection } = mockVscode();
  state.selected = [writeReport(dir, 'sample.sarif', report([finding('x.gd')]))];
  await createLoadCommand(vscode, collection)();
  assert.match(state.errors[0], /open a Godot project folder/i);
  assert.equal(collection.clearCount, 0);
});

test('multi-root selection resolves against the chosen folder; cancelling preserves the last report', async t => {
  const dir = tempDir(t);
  const first = path.join(dir, 'first');
  const second = path.join(dir, 'second');
  const { vscode, state, collection } = mockVscode([first, second]);
  state.selected = [writeReport(dir, 'sample.sarif', report([finding('scripts/player.gd'), { ruleId: 'no_location' }]))];
  state.selectedFolder = 1;
  const run = createLoadCommand(vscode, collection);
  await run();
  assert.equal(state.quickPickItems.length, 2);
  assert.ok(collection.get(Uri.joinPath(Uri.file(second), 'scripts', 'player.gd')));
  assert.equal(collection.get(Uri.joinPath(Uri.file(first), 'scripts', 'player.gd')), undefined);
  assert.match(state.messages[0], /loaded 1 diagnostic.*skipped 1 result/);
  const clears = collection.clearCount;
  state.selectedFolder = -1;
  await run();
  assert.equal(collection.clearCount, clears);
  assert.ok(collection.get(Uri.joinPath(Uri.file(second), 'scripts', 'player.gd')));
});

test('extension activation registers and disposes the command and collection', () => {
  const { vscode, state, collection } = mockVscode();
  const target = require.resolve('../src/extension');
  const originalLoad = Module._load;
  delete require.cache[target];
  let extension;
  try {
    Module._load = function(request, ...args) {
      return request === 'vscode' ? vscode : originalLoad.call(this, request, ...args);
    };
    extension = require(target);
  } finally {
    Module._load = originalLoad;
    delete require.cache[target];
  }
  const context = { subscriptions: [] };
  extension.activate(context);
  assert.equal(state.registered[0].name, 'gdt.loadSarif');
  assert.equal(typeof state.registered[0].handler, 'function');
  assert.equal(context.subscriptions.length, 2);
  assert.equal(context.subscriptions[0], collection);
  assert.ok(require('../package.json').activationEvents.includes('onCommand:gdt.loadSarif'));
});

test('imports the real Godot SARIF exporter output when supplied', { skip: !process.env.GDT_SARIF_REPORT }, t => {
  const dir = tempDir(t);
  const { vscode } = mockVscode([dir]);
  const root = Uri.file(dir);
  const data = JSON.parse(fs.readFileSync(process.env.GDT_SARIF_REPORT, 'utf8'));
  const converted = convertSarif(vscode, data, root);
  assert.equal(converted.findings, 4);
  assert.equal(converted.skipped, 0);
  const player = diagnosticsAt(converted, Uri.joinPath(root, 'player.gd'));
  assert.equal(player.length, 1);
  assert.equal(player[0].range.start.line, 16);
  assert.equal(player[0].severity, vscode.DiagnosticSeverity.Warning);
  assert.equal(diagnosticsAt(converted, Uri.joinPath(root, 'locked.tscn'))[0].severity, vscode.DiagnosticSeverity.Error);
  assert.equal(diagnosticsAt(converted, Uri.joinPath(root, 'art', 'orphan.png'))[0].severity, vscode.DiagnosticSeverity.Information);
});
