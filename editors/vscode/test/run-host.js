'use strict';

// Integration smoke: downloads a pinned editor for the extension host.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { runTests } = require('@vscode/test-electron');

async function main() {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'gdt-vscode-host-'));
  try {
    await runTests({
      version: '1.80.2',
      timeout: 60000,
      extensionDevelopmentPath: path.resolve(__dirname, '..'),
      extensionTestsPath: path.resolve(__dirname, 'host.js'),
      launchArgs: [scratch, '--disable-extensions', '--disable-gpu'],
      extensionTestsEnv: { GDT_SARIF_REPORT: process.env.GDT_SARIF_REPORT || '' },
    });
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}

main().catch(error => {
  console.error('VS Code extension host smoke failed:', error);
  process.exitCode = 1;
});
