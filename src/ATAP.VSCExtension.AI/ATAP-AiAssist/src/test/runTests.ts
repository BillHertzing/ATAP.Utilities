//import { glob, globSync, globStream, globStreamSync, Glob } from "glob";
import { glob, globSync, globStream } from "fast-glob";
import { dirname, resolve, join } from "path";
import { fileURLToPath } from "url";
// import * as Mocha from "mocha";
const Mocha = require("mocha");

async function runTests(
  testsRoot: string,
  pattern: string,
  mochaOpts: Mocha.MochaOptions,
): Promise<number> {
  console.log(
    `runTests.ts: runTests: testsRoot is ${testsRoot}; pattern is ${pattern}; mochaOpts is ${JSON.stringify(mochaOpts)} `,
  );

  const mocha = new Mocha(mochaOpts);

  // error occurs here at runtime, glob is not defined
  const testFiles = await glob(pattern, {
    cwd: testsRoot.replaceAll("/\\/", "/"),
    onlyFiles: true,
  });
  // // Use glob to return an array of file paths that match the pattern
  //  //  The following glob signature came from somewhere, the npm package glob does not have this signature
  //const testFiles = await glob(pattern, { cwd: testsRoot, nodir: true }, (err: Error, testfiles: string[]) => {
  // const testFiles = await glob(
  //   pattern,
  //   { cwd: testsRoot, nodir: true },
  //   (err: Error, testfiles: string[]) => {
  //     if (err) {
  //       console.error(`runTests.ts: runTests: glob error: ${err}`);
  //       throw err;
  //     }
  //   });
  console.log(
    `runTests.ts: runTests: testFiles is ${JSON.stringify(testFiles)}`,
  );
  // Add collected files to Mocha
  testFiles.forEach((file) => {
    console.log(`runTests.ts: runTests: file is ${file}`);
    mocha.addFile(file); // path.resolve(testsRoot, file)
  });
  // Run the tests
  return new Promise<number>((resolve, reject) => {
    console.log(
      `runTests.ts: runTests: mocha.files is ${mocha.files.toString()}`,
    );
    mocha.run((failures: number) => {
      if (failures > 0) {
        reject(new Error(`${failures} tests failed.`));
      } else {
        resolve(failures);
      }
    });
  });

  // glob(pattern, { cwd: testsRoot }, (err: Error, files: string[]) => {
  //   if (err) {
  //     return reject(err);
  //   }

  //   files.forEach((f) => mocha.addFile(path.resolve(testsRoot, f)));

  //   try {
  //     mocha.run((failures) => resolve(failures));
  //   } catch (err) {
  //     reject(err);
  //   }
  // });
}

export async function run(): Promise<void> {
  const testsRoot = __dirname; // resolve(dirname(fileURLToPath(import.meta.url)), '.');
  console.log(`runTests.ts: run: testsRoot is ${testsRoot}`);
  const tddFailures = await runTests(
    join(testsRoot, "tdd-tests\\"),
    "./**/*.test.js",
    { ui: "tdd" },
  );
  console.log(`runTests.ts: run: tddFailures is ${tddFailures}`);
  const bddFailures = await runTests(
    join(testsRoot, "bdd-tests\\"),
    "./**/*.test.js",
    { ui: "bdd" },
  );
  console.log(`runTests.ts: run: bddFailures is ${bddFailures}`);
  if (bddFailures + tddFailures > 0) {
    throw new Error("Tests failed");
  }
}

// import * as path from 'path';

// import { runTests } from '@vscode/test-electron';

// export async function main() {
//   try {
//     console.log(`_generated/out/test/runTest.ts main function starting. cwd is ${process.cwd()}`);

//     // The folder containing the Extension Manifest package.json
//     // Passed to `--extensionDevelopmentPath`
//     const extensionDevelopmentPath = path.resolve(__dirname, '../../../');
//     console.log(`runTest.js (from runTest.ts) extensionDevelopmentPath : ${extensionDevelopmentPath}`);

//     // The paths to the test subdirectories, which now include two patterns
//     // to match test files in both subdirectories.
//     const extensionTestsPaths = [path.resolve(__dirname, './tdd-tests'), path.resolve(__dirname, './bdd-tests')];

//     // extensionTestsPath is an array holding paths to one or more test directory
//     console.log(
//       `_generated/out/test/runTest.ts main function: extensionTestsPaths : ${extensionTestsPaths.toString()}`,
//     );

//     // Loop through all test paths and run tests for each path
//     for (const extensionTestsPath of extensionTestsPaths) {
//       console.log(
//         `_generated/out/test/runTest.ts main function: extensionTestsPath : ${extensionTestsPath.toString()}`,
//       ); // Download VS Code, unzip it, and run the integration test
//       await runTests({
//         version: 'stable',
//         extensionDevelopmentPath,
//         extensionTestsPath,
//         launchArgs: [
//           // This disables all installed extensions except the one being tested
//           '--disable-extensions',
//           // Add other launch arguments if needed
//         ],
//       });
//     }
//   } catch (err) {
//     console.error(`_generated/out/test/runTest.ts main function: failed, err -> ${err}`);
//     process.exit(1);
//   }
// }

// main();
