'use strict';

// The exporter writes PROJECTROOT-relative paths as raw Godot resource paths,
// not percent-encoded URLs. Resolve them against a selected workspace folder;
// do not use its placeholder originalUriBaseIds.PROJECTROOT = file:///.
function projectFile(vscode, projectRoot, artifact) {
  if (!isObject(artifact) || typeof artifact.uri !== 'string' || !artifact.uri) return null;
  if (artifact.uriBaseId !== undefined && artifact.uriBaseId !== 'PROJECTROOT') return null;
  const file = artifact.uri;
  if (file.startsWith('/') || /^[a-z][a-z0-9+.-]*:/i.test(file) || /[\\\x00-\x1f\x7f]/.test(file)) return null;
  const parts = file.split('/');
  if (parts.includes('..') || parts.every(part => !part || part === '.')) return null;
  return vscode.Uri.joinPath(projectRoot, ...parts);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function position(value, fallback) {
  return Number.isInteger(value) && value >= 1 && value <= 0x7fffffff ? value - 1 : fallback;
}

function diagnosticRange(vscode, region) {
  region = isObject(region) ? region : {};
  const startLine = position(region.startLine, 0);
  const startColumn = position(region.startColumn, 0);
  let endLine = position(region.endLine, startLine);
  let endColumn = position(region.endColumn, endLine > startLine ? 0 : startColumn + 1);
  if (endLine < startLine || (endLine === startLine && endColumn <= startColumn)) {
    endLine = startLine;
    endColumn = startColumn + 1;
  }
  return new vscode.Range(startLine, startColumn, endLine, endColumn);
}

function severity(vscode, level) {
  if (level === 'error') return vscode.DiagnosticSeverity.Error;
  if (level === 'note') return vscode.DiagnosticSeverity.Information;
  if (level === 'none') return vscode.DiagnosticSeverity.Hint;
  return vscode.DiagnosticSeverity.Warning;
}

// Convert the complete report before replacing any existing diagnostics.
function convertSarif(vscode, report, projectRoot) {
  if (!isObject(report) || report.version !== '2.1.0' || !Array.isArray(report.runs)) {
    throw new Error('Expected a SARIF 2.1.0 log with a runs array');
  }
  const files = new Map();
  let findings = 0;
  let skipped = 0;
  for (const run of report.runs) {
    if (!isObject(run) || (run.results !== undefined && !Array.isArray(run.results))) {
      throw new Error('A SARIF run has an invalid results array');
    }
    for (const result of run.results || []) {
      const first = isObject(result) && Array.isArray(result.locations) ? result.locations[0] : null;
      const physical = isObject(first) && isObject(first.physicalLocation) ? first.physicalLocation : null;
      const uri = physical && projectFile(vscode, projectRoot, physical.artifactLocation);
      if (!uri) {
        skipped += 1;
        continue;
      }
      const text = isObject(result.message) && typeof result.message.text === 'string' && result.message.text
        ? result.message.text : (typeof result.ruleId === 'string' && result.ruleId || 'GodotDevTools finding');
      const diagnostic = new vscode.Diagnostic(diagnosticRange(vscode, physical.region), text, severity(vscode, result.level));
      if (typeof result.ruleId === 'string' && result.ruleId) diagnostic.code = result.ruleId;
      diagnostic.source = 'godot-dev-tools';
      const key = uri.toString();
      if (!files.has(key)) files.set(key, [uri, []]);
      files.get(key)[1].push(diagnostic);
      findings += 1;
    }
  }
  return { entries: Array.from(files.values()), findings, skipped };
}

async function readSarif(vscode, reportUri, projectRoot) {
  const bytes = await vscode.workspace.fs.readFile(reportUri);
  const report = JSON.parse(Buffer.from(bytes).toString('utf8'));
  return convertSarif(vscode, report, projectRoot);
}

function replaceDiagnostics(collection, converted) {
  collection.clear();
  collection.set(converted.entries);
}

async function loadSarif(vscode, collection, reportUri, projectRoot) {
  const converted = await readSarif(vscode, reportUri, projectRoot);
  replaceDiagnostics(collection, converted);
  return converted;
}

async function projectRootFor(vscode) {
  const folders = vscode.workspace.workspaceFolders || [];
  if (!folders.length) {
    vscode.window.showErrorMessage('GodotDevTools: open a Godot project folder in VS Code before loading SARIF.');
    return null;
  }
  if (folders.length === 1) return folders[0].uri;
  const choice = await vscode.window.showQuickPick(
    folders.map(folder => ({ label: folder.name, description: folder.uri.toString(), folder })),
    { placeHolder: 'Choose the Godot project root for this SARIF report' }
  );
  return choice ? choice.folder.uri : null;
}

function createLoadCommand(vscode, collection) {
  let latestRequest = 0;
  return async () => {
    let request = 0;
    try {
      const uris = await vscode.window.showOpenDialog({ canSelectMany: false, filters: { SARIF: ['sarif'] } });
      if (!uris || !uris.length) return;
      const projectRoot = await projectRootFor(vscode);
      if (!projectRoot) return;
      request = ++latestRequest;
      const converted = await readSarif(vscode, uris[0], projectRoot);
      if (request !== latestRequest) return;
      replaceDiagnostics(collection, converted);
      const skipped = converted.skipped ? `; skipped ${converted.skipped} result(s) without a supported location` : '';
      vscode.window.showInformationMessage(
        `GodotDevTools: loaded ${converted.findings} diagnostic(s) in ${converted.entries.length} file(s)${skipped}.`
      );
    } catch (error) {
      if (request && request !== latestRequest) return;
      const message = error && error.message ? error.message : String(error);
      vscode.window.showErrorMessage(`GodotDevTools: could not load SARIF: ${message}`);
    }
  };
}

module.exports = { convertSarif, loadSarif, createLoadCommand };
