import * as assert from 'assert';
import { Philote, IPhilote } from '@Philote/Philote';

import { Item, ItemCollection } from '@QueryContextsService/QueryContextsService';

// Typically you would mock VS Code extension import if required for your tests
// import * as vscode from 'vscode'; // Uncomment if you need to use VS Code API

suite('Extension Tests', function () {
  // Define some common variables for use in tests
  const guidExample: string = "123e4567-e89b-12d3-a456-426614174000";
  let philoteGUID: Philote<string>;
  let item1: Item<string>;
  let itemCollection: ItemCollection<string>;

  setup(() => {
    // Initialize objects before each test
    philoteGUID = new Philote<string>(guidExample);
    item1 = new Item<string>("item1", philoteGUID);
    itemCollection = new ItemCollection<string>(philoteGUID, [item1]);
  });

  test('Philote should initialize correctly', () => {
    assert.strictEqual(philoteGUID.ID, guidExample);
  });

  test('Item should initialize correctly', () => {
    assert.strictEqual(item1.name, "item1");
    assert.strictEqual(item1.ID, philoteGUID);
  });

  test('ItemCollection should initialize correctly and find items', () => {
    assert.strictEqual(itemCollection.ID, philoteGUID);
    assert.strictEqual(itemCollection.items.length, 1);
    assert.strictEqual(itemCollection.findItemByName("item1"), item1);
  });

  test('Philote should convert to JSON and back', () => {
    const json = philoteGUID.convertTo_json();
    const parsedPhilote = Philote.convertFrom_json<string>(json);
    assert.strictEqual(parsedPhilote.ID, philoteGUID.ID);
  });

  test('Philote should convert to YAML and back', () => {
    const yaml = philoteGUID.convertTo_yaml();
    const parsedPhilote = Philote.convertFrom_yaml<string>(yaml);
    assert.strictEqual(parsedPhilote.ID, philoteGUID.ID);
  });

  test('ItemCollection should add items correctly', () => {
    const newItem = new Item<string>("item2", philoteGUID);
    itemCollection.addItem(newItem);
    assert.strictEqual(itemCollection.items.length, 2);
    assert.strictEqual(itemCollection.findItemByName("item2"), newItem);
  });

  test('toJson and fromJson utility for ItemCollection', () => {
    const json = itemCollection.convertTo_json();
    const newItemCollection = ItemCollection.convertFrom_json<string>(json);
    assert.strictEqual(newItemCollection.ID.ID, itemCollection.ID.ID);
    assert.strictEqual(newItemCollection.items.length, itemCollection.items.length);
  });

  test('toYaml and fromYaml utility for ItemCollection', () => {
    const yamlString = itemCollection.convertTo_yaml();
    const newYamlCollection = ItemCollection.convertFrom_yaml<string>(yamlString);
    assert.strictEqual(newYamlCollection.ID.ID, itemCollection.ID.ID);
    assert.strictEqual(newYamlCollection.items.length, itemCollection.items.length);
  });

  // Add more tests as needed
});
