import * as vscode from 'vscode';
import 'mocha'; // Mocha types
import * as chai from 'chai';

const expect = chai.expect;
import * as assert from 'assert';
console.log("Extension Tests TDD");
suite('AiAAssist VSC Extension Test Suite', () => {
	// vscode.window.showInformationMessage('Start all tests.');

	test('Sample test', () => {
		assert.strictEqual(-1, [1, 2, 3].indexOf(5));
		assert.strictEqual(-1, [1, 2, 3].indexOf(0));
  });


  // describe('Philote Class Tests', () => {
  //   let testGuid: GUID = '1234-5678-91011';
  //   let testInt: Int = 42;
  // });

});
