import {
  GUID,
  Int,
  IDType,

} from './IDTypes';
import {
  toJson,
  fromJson,
  toYaml,
  fromYaml
} from './Serilaizers';

export interface IPhilote<T extends IDType> {
  readonly ID: T; // The ID should be public and read-only

  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
  addOther(philote: IPhilote<T>): void; // Method to add to the 'others' array
  removeOther(philote: IPhilote<T>): void; // Method to remove from the 'others' array
}


export class Philote<T extends IDType>implements IPhilote<T>  {
  public readonly ID: T; // Public read-only
  private readonly others: Philote<T>[]; // Private read-only array

  constructor(ID: T) {
    this.ID = ID;
    this.others = [];
  }

  addOther(philote: Philote<T>): void {
    // Add philote to the others array if not already present
    if (!this.others.includes(philote)) {
      this.others.push(philote);
    }
  }

  removeOther(philote: Philote<T>): void {
    // Remove philote from the others array
    const index = this.others.indexOf(philote);
    if (index > -1) {
      this.others.splice(index, 1);
    }
  }
  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Philote<T> {
    return fromJson<Philote<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Philote<T> {
    return fromYaml<Philote<T>>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.ID}`;
  }
}
