// TDD Test File: CategoryCollection.test.ts
import * as assert from 'assert';
import { GUID, Int, IDType, } from '@IDTypes/IDTypes';
import { Philote, IPhilote } from '@Philote/Philote';

import { Category, CategoryCollection } from '@QueryContextsService/index';

suite('Category Tests', () => {
  // Define some common variables for use in tests
  const guidExample: string = '123e4567-e89b-12d3-a456-426614174000';
  const intExample: Int = 10;
  let testName: string = 'ATestName';
  test('Category instantiation and method checks', () => {
    const guidCategory = new Category(testName, new Philote<string>(guidExample));
    assert.strictEqual(guidCategory.name, testName);
    // Add more assertions as necessary to test the functionality
  });

  test('Category<Int> instantiation and method checks', () => {
    const intCategory = new Category<Int>(testName, new Philote<Int>(intExample));
    assert.strictEqual(intCategory.name, testName);
    // Add more assertions as necessary to test the functionality
  });

  test('CategoryCollection manipulation', () => {
    const categoryCollectionGUID = new CategoryCollection(new Philote<string>(guidExample));
    const guidCategory =new Category(testName, new Philote<string>(guidExample));
    categoryCollectionGUID.addItem(guidCategory);

    const found = categoryCollectionGUID.findItemByName(testName);
    assert(found !== undefined && found.name === testName);
  });

  test('CategoryCollection<Int> manipulation', () => {
    const categoryCollectionInt = new CategoryCollection<Int>(new Philote<Int>(intExample));
    const intCategory = new Category<Int>(testName, new Philote<Int>(intExample));
    categoryCollectionInt.addItem(intCategory);

    const found = categoryCollectionInt.findItemByName(testName);
    assert(found !== undefined && found.name === testName);
  });

  test('Category<Int> should serialize and deserialize correctly', () => {
    // Create an instance of Category<Int>
    const testValue =  new Category<Int>(testName, new Philote<Int>(intExample));

    // Convert the instance to JSON
    const json = testValue.convertTo_json();
    console.log(json);

    // Prepare what the expected JSON would look like
    const expectedJson = JSON.stringify({
      name: testValue.name,
      ID: testValue.ID
    });
    console.log(expectedJson);

    // Assert the JSON serialized as expected
    assert.strictEqual(json, expectedJson);

    // convert the json back to an instance
    const resultCategory = Category.convertFrom_json<Int>(json);

    // test the equality of deserialized object properties
    // Since type information is not included in JSON, we check for value equality
    //assert.strictEqual(resultCategory.ID, testValue.ID);
    assert.strictEqual(resultCategory.name, testValue.name);

  });

  test('Should serialize and deserialize CategoryCollection<Int> correctly', () => {
    // Setup - create a new CategoryCollection<Int> and add a Category to it
    const category10 = new Category<Int>('category10', new Philote<Int>(intExample));
    const category11 = new Category<Int>('category11', new Philote<Int>(intExample + 1));

    const categoryCollection = new CategoryCollection<Int>(new Philote<Int>(1));
    categoryCollection.addItem(category10);
    categoryCollection.addItem(category11);

    // Act - serialize the collection to JSON and deserialize it back
    const serialized = categoryCollection.convertTo_json();
    console.log(serialized);
    const deserializedCollection = CategoryCollection.convertFrom_json<Int>(serialized);

    // Assert - the deserialized collection should match the original collection's data
    assert.strictEqual(deserializedCollection.items.length, categoryCollection.items.length, "Deserialized collection should have the same number of items as the original.");
    //assert.strictEqual(deserializedCollection.ID.ID, categoryCollection.ID.ID, "Deserialized collection's ID should match the original's ID.");

    // Additional assertions could be done for the rest of the properties of items
    deserializedCollection.items.forEach((item, index) => {
      assert.strictEqual(item.name, categoryCollection.items[index].name, "Item names should match after deserialization.");
      //assert.strictEqual(item.ID.ID, categoryCollection.items[index].ID.ID, "Item IDs should match after deserialization.");
    });
  });

  // Additional tests can include serialization/deserialization, removal logic, etc.
});
