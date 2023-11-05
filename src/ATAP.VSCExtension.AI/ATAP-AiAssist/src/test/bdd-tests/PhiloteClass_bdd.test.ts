import 'mocha'; // Mocha types
import * as chai from 'chai';
import { GUID, Int, IDType, } from '@IDTypes/IDTypes';

import { Philote, IPhilote } from '@Philote/Philote';


const expect = chai.expect;
console.log("Philote Class Tests BDD");


describe('Philote Class Tests', () => {
    let testGuid: GUID = '1234-5678-91011';
    let testInt: Int = 42;

    describe('Constructor and basic methods', () => {
        it('Should correctly construct with GUID', () => {
            const philote = new Philote<GUID>(testGuid);
            expect(philote.ID).to.equal(testGuid);
            expect(philote.others).to.deep.equal([]);
        });

        it('Should correctly construct with Int', () => {
            const philote = new Philote<Int>(testInt);
            expect(philote.ID).to.equal(testInt);
            expect(philote.others).to.deep.equal([]);
        });

        it('Should return correct string representation', () => {
            const philote = new Philote<GUID>(testGuid);
            expect(philote.ToString()).to.equal(`Philote: ${testGuid}`);
        });
    });

    describe('JSON conversion methods', () => {
        it('Should correctly convert to JSON and back (GUID)', () => {
            const original = new Philote<GUID>(testGuid);
            const json = original.convertTo_json();
            const restored = Philote.convertFrom_json<GUID>(json);
            expect(restored).to.deep.equal(original);
        });

        it('Should correctly convert to JSON and back (Int)', () => {
            const original = new Philote<Int>(testInt);
            const json = original.convertTo_json();
            const restored = Philote.convertFrom_json<Int>(json);
            expect(restored).to.deep.equal(original);
        });
    });

    describe('YAML conversion methods', () => {
        it('Should correctly convert to YAML and back (GUID)', () => {
            const original = new Philote<GUID>(testGuid);
            const yaml = original.convertTo_yaml();
            const restored = Philote.convertFrom_yaml<GUID>(yaml);
            expect(restored).to.deep.equal(original);
        });

        it('Should correctly convert to YAML and back (Int)', () => {
            const original = new Philote<Int>(testInt);
            const yaml = original.convertTo_yaml();
            const restored = Philote.convertFrom_yaml<Int>(yaml);
            expect(restored).to.deep.equal(original);
        });
    });
});
