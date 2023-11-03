import * as path from 'path';
import * as Mocha from 'mocha';
import * as glob from 'glob';

function sleep(milliseconds: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
}

console.log("Index (TDD)");
sleep(5000);

export function run(): Promise<void> {
	// Create the mocha test
	const mocha = new Mocha({
		ui: 'tdd',
		color: true
	});
	const testsRoot = path.resolve(__dirname, '..');
  console.log(`testsRoot is ${testsRoot}`);

	return new Promise((c, e) => {
		const testFiles = new glob.Glob("tdd-tests/**/**.test.js", { cwd: testsRoot });
    console.log(`TDD testFiles is ${testFiles}`);
		const testFileStream = testFiles.stream();

		testFileStream.on("data", (file) => {
			mocha.addFile(path.resolve(testsRoot, file));
		});
		testFileStream.on("error", (err) => {
			e(err);
		});
		testFileStream.on("end", () => {
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
