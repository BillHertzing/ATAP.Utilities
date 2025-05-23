import * as vscode from "vscode";

import { GUID, Int, IDType, nextID } from "@IDTypes/index";
import { DetailedError } from "@ErrorClasses/index";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { logConstructor, logMethod, logAsyncFunction } from "@Decorators/index";
import {
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from "@Serializers/index";

export interface IPhilote {
  readonly ID: GUID;
  readonly others: Philote[];
  convertTo_json(): string;
  convertTo_yaml(): string;
  toString(): string;
  addOther(philote: IPhilote): void; // Method to add to the 'others' array
  removeOther(philote: IPhilote): void; // Method to remove from the 'others' array
}

@logConstructor
export class Philote implements IPhilote {
  public readonly ID: GUID;
  public readonly others: Philote[];
  constructor(
    //private readonly logger: ILogger,
    ID?: GUID,
  ) {
    //this.logger = new Logger(this.logger, "Philote");
    this.ID = ID !== undefined ? ID : nextID(); // returns a random GUID string or the next sequential Int available from the ID pool
    this.others = [];
  }
  @logMethod(LogLevel.Debug)
  addOther(philote: Philote): void {
    // Add philote to the others array if not already present
    if (!this.others.includes(philote)) {
      this.others.push(philote);
    }
  }
  @logMethod(LogLevel.Trace)
  removeOther(philote: Philote): void {
    // Remove philote from the others array
    const index = this.others.indexOf(philote);
    if (index > -1) {
      this.others.splice(index, 1);
    }
  }
  @logMethod(LogLevel.Trace)
  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json(json: string): Philote {
    return fromJson<Philote>(json);
  }
  @logMethod(LogLevel.Trace)
  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml(yaml: string): Philote {
    return fromYaml<Philote>(yaml);
  }

  @logMethod(LogLevel.Trace)
  toString(): string {
    return `Philote: ${this.ID}`;
  }
}
