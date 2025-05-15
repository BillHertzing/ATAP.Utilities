import 'mocha'; // Mocha types
import * as chai from 'chai';
import { Philote, IPhilote } from '@Philote/index';
const expect = chai.expect;
console.log("Philote Class Tests TDD");


describe('Philote', function() {
  describe('constructor', function() {
    it('should create a Philote with a default ID if none is provided', function() {
      const philote = new Philote();
      expect(philote.ID).to.be.a('string');
    });

    it('should create a Philote with the given ID', function() {
      const testID = 'test-id';
      const philote = new Philote(testID);
      expect(philote.ID).to.equal(testID);
    });
  });

  describe('addOther', function() {
    it('should add a new Philote to the others array', function() {
      const philote1 = new Philote();
      const philote2 = new Philote();
      philote1.addOther(philote2);
      expect(philote1.others).to.include(philote2);
    });

    it('should not add the same Philote twice', function() {
      const philote1 = new Philote();
      const philote2 = new Philote();
      philote1.addOther(philote2);
      philote1.addOther(philote2);
      expect(philote1.others).to.have.lengthOf(1);
    });
  });

  describe('removeOther', function() {
    it('should remove a Philote from the others array', function() {
      const philote1 = new Philote();
      const philote2 = new Philote();
      philote1.addOther(philote2);
      philote1.removeOther(philote2);
      expect(philote1.others).to.not.include(philote2);
    });
  });

  describe('convertTo_json', function() {
    it('should convert Philote instance to JSON string', function() {
      const philote = new Philote();
      const json = philote.convertTo_json();
      expect(json).to.be.a('string');
      expect(json).to.contain(philote.ID);
    });
  });

  describe('convertFrom_json', function() {
    it('should convert JSON string to Philote instance', function() {
      const philote = new Philote();
      const json = philote.convertTo_json();
      const newPhilote = Philote.convertFrom_json(json);
      expect(newPhilote).to.be.instanceOf(Philote);
      expect(newPhilote.ID).to.equal(philote.ID);
    });
  });

  describe('convertTo_yaml', function() {
    it('should convert Philote instance to YAML string', function() {
      const philote = new Philote();
      const yaml = philote.convertTo_yaml();
      expect(yaml).to.be.a('string');
      expect(yaml).to.contain(philote.ID);
    });
  });

  describe('convertFrom_yaml', function() {
    it('should convert YAML string to Philote instance', function() {
      const philote = new Philote();
      const yaml = philote.convertTo_yaml();
      const newPhilote = Philote.convertFrom_yaml(yaml);
      expect(newPhilote).to.be.instanceOf(Philote);
      expect(newPhilote.ID).to.equal(philote.ID);
    });
  });

  describe('toString', function() {
    it('should return a string containing the ID of the Philote', function() {
      const philote = new Philote();
      const stringRepresentation = philote.toString();
      expect(stringRepresentation).to.be.a('string');
      expect(stringRepresentation).to.contain(philote.ID);
    });
  });
});
