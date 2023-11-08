import { GUID, Int, IDType, nextID } from '@IDTypes/IDTypes';
import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/Serializers';

export interface IPhilote {
  readonly ID: GUID;
  readonly others: Philote[];
  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
  addOther(philote: IPhilote): void; // Method to add to the 'others' array
  removeOther(philote: IPhilote): void; // Method to remove from the 'others' array
}

export class Philote implements IPhilote {
  public readonly ID: GUID;
  public readonly others: Philote[];
  constructor(ID?: GUID) {
    this.ID = ID !== undefined ? ID : nextID(); // returns a random GUID string or the next sequential Int available from the ID pool
    this.others = [];
  }

  addOther(philote: Philote): void {
    // Add philote to the others array if not already present
    if (!this.others.includes(philote)) {
      this.others.push(philote);
    }
  }

  removeOther(philote: Philote): void {
    // Remove philote from the others array
    const index = this.others.indexOf(philote);
    if (index > -1) {
      this.others.splice(index, 1);
    }
  }
  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json(json: string): Philote {
    return fromJson<Philote>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml(yaml: string): Philote {
    return fromYaml<Philote>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.ID}`;
  }
}
