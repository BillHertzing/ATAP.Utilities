import 'mocha'; // Mocha types
import * as chai from 'chai';
import { Philote, IPhilote } from '@Philote/index';
const expect = chai.expect;
console.log("Philote Class Tests BDD");


describe('Philote Class', function() {
  describe('Creating instances', function() {
    it('Given no ID, when constructing a Philote, then it should have a random GUID as ID', function() {
      const philote = new Philote();
      expect(philote.ID).to.be.a('string');
    });

    it('Given an ID, when constructing a Philote, then it should use the provided ID', function() {
      const testID = 'test-id';
      const philote = new Philote(testID);
      expect(philote.ID).to.equal(testID);
    });
  });

  describe('Managing relationships', function() {
    context('Adding an association', function() {
      it('When adding another Philote, then it should appear in the others array', function() {
        const philote1 = new Philote();
        const philote2 = new Philote();
        philote1.addOther(philote2);
        expect(philote1.others).to.include(philote2);
      });

      it('When adding the same Philote again, then it should not duplicate in the others array', function() {
        const philote1 = new Philote();
        const philote2 = new Philote();
        philote1.addOther(philote2);
        philote1.addOther(philote2);
        expect(philote1.others).to.have.lengthOf(1);
      });
    });

    context('Removing an association', function() {
      it('When removing an associated Philote, then it should no longer be in the others array', function() {
        const philote1 = new Philote();
        const philote2 = new Philote();
        philote1.addOther(philote2);
        philote1.removeOther(philote2);
        expect(philote1.others).to.not.include(philote2);
      });
    });
  });

  describe('Serialization', function() {
    context('To JSON', function() {
      it('When converting to JSON, then the resulting string should represent the Philote', function() {
        const philote = new Philote();
        const json = philote.convertTo_json();
        expect(json).to.be.a('string');
        expect(json).to.contain(philote.ID);
      });
    });

    context('From JSON', function() {
      it('Given a JSON representation, when converting from JSON, then it should return a Philote instance with corresponding ID', function() {
        const philote = new Philote();
        const json = philote.convertTo_json();
        const newPhilote = Philote.convertFrom_json(json);
        expect(newPhilote).to.be.instanceOf(Philote);
        expect(newPhilote.ID).to.equal(philote.ID);
      });
    });

    context('To YAML', function() {
      it('When converting to YAML, then the resulting string should represent the Philote', function() {
        const philote = new Philote();
        const yaml = philote.convertTo_yaml();
        expect(yaml).to.be.a('string');
        expect(yaml).to.contain(philote.ID);
      });
    });

    context('From YAML', function() {
      it('Given a YAML representation, when converting from YAML, then it should return a Philote instance with corresponding ID', function() {
        const philote = new Philote();
        const yaml = philote.convertTo_yaml();
        const newPhilote = Philote.convertFrom_yaml(yaml);
        expect(newPhilote).to.be.instanceOf(Philote);
        expect(newPhilote.ID).to.equal(philote.ID);
      });
    });
  });

  describe('String Representation', function() {
    it('When calling toString, then it should return a string containing the ID of the Philote', function() {
      const philote = new Philote();
      const stringRepresentation = philote.toString();
      expect(stringRepresentation).to.be.a('string');
      expect(stringRepresentation).to.contain(philote.ID);
    });
  });
});
