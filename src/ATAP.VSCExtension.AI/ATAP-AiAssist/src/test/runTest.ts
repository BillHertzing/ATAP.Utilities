import * as path from 'path';

import { runTests } from '@vscode/test-electron';

export async function main() {
  try {
    // The folder containing the Extension Manifest package.json
    // Passed to `--extensionDevelopmentPath`
    const extensionDevelopmentPath = path.resolve(__dirname, '../../../');
    console.log(`runTest.js (from runTest.ts) extensionDevelopmentPath : ${extensionDevelopmentPath}`);

    // The paths to the test subdirectories, which now include two patterns
    // to match test files in both subdirectories.
    const extensionTestsPaths = [
      path.resolve(__dirname, './tdd-tests'),
      path.resolve(__dirname, './bdd-tests'),
    ];

    // Loop through all test paths and run tests for each path
    for (const extensionTestsPath of extensionTestsPaths) {
      console.log(`runTest.js (from runTest.ts) extensionTestsPath :${extensionTestsPath}`);
      // Download VS Code, unzip it, and run the integration test
      await runTests({
        version: 'stable',
        extensionDevelopmentPath,
        extensionTestsPath,
        launchArgs: [
          // This disables all installed extensions except the one being tested
          '--disable-extensions'
          // Add other launch arguments if needed
        ],
      });
    }
  } catch (err) {
    console.error('Failed to run tests', err);
    process.exit(1);
  }
}

main();
