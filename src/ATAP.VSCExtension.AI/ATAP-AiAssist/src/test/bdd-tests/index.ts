import * as path from 'path';
import * as Mocha from 'mocha';
import * as glob from 'glob';

console.log('Index (BDD)');

export function run(): Promise<void> {
  // Create the mocha test
  const mocha = new Mocha({
    ui: 'bdd',
    color: true,
  });
  const testsRoot = path.resolve(__dirname, '..');
  console.log(`BDD testsRoot is ${testsRoot}`);

  return new Promise((c, e) => {
    let filePaths: string[] = []; // Initialize an array to hold the file paths
    const testFiles = new glob.Glob('bdd-tests/**/**.test.js', { cwd: testsRoot });
    const testFileStream = testFiles.stream();

    testFileStream.on('data', (file) => {
      // Resolve and add file path to the array
      filePaths.push(path.resolve(testsRoot, file));
      mocha.addFile(path.resolve(testsRoot, file));
    });
    testFileStream.on('error', (err) => {
      e(err);
    });
    testFileStream.on('end', () => {
      let str: string = JSON.stringify(filePaths);
      console.log(`BDD testFiles is ${str}`);
      try {
        // Run the mocha test
        mocha.run(failures => {
          if (failures > 0) {
            e(new Error(`${failures} tests failed.`));
          } else {
            c();
          }
        });
      } catch (err) {
        console.error(err);
        e(err);
      }
    });
  });
}
