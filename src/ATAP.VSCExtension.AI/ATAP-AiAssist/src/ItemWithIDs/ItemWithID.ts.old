import * as vscode from 'vscode';
import { GUID, Int, IDType } from '@IDTypes/index';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor, logExecutionTime } from '@Decorators/index';
import { Philote, IPhilote } from '@Philote/index';
import { DefaultConfiguration } from '../DefaultConfiguration';
import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/index';

import { TagValueType, Tag, ITag } from '@AssociationsService/index';
import { CategoryValueType, Category, ICategory } from '@AssociationsService/index';
import { AssociationValueType, Association, IAssociation } from '@AssociationsService/index';
//import { TokenValueType , Token, IToken} from '@TokensService/index';
import { QueryContextValueType, QueryContext, IQueryContext } from '@QueryContextsService/index';

export type ItemWithIDValueType =
  | string
  | number
  | TagValueType
  | CategoryValueType
  | AssociationValueType
  | QueryContextValueType;
export type ItemWithIDType = Tag | Category | Association | QueryContext; //| Token | QueryContextValueType;

// Define an  interface for itemWithIDs
export interface IItemWithID {
  ID?: Philote;
  value: ItemWithIDValueType;
  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
  dispose(): void;
}

// base ItemWithID implementation
export class ItemWithID implements IItemWithID {
  private message: string = '';
  constructor(public value: ItemWithIDValueType, public ID?: Philote) {
    this.ID = ID !== undefined ? ID : new Philote();
  }

  static CreateItemWithID(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): ItemWithID {
    let _obj: ItemWithID | null;
    if (initializationStructure) {
      try {
        // ToDo: deserialize based on contents of structure
        _obj = ItemWithID.convertFrom_yaml(initializationStructure.value);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create ItemWithID from initializationStructure using convertFrom_xxx -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create ItemWithID from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
          );
        }
      }
      if (_obj === null) {
        throw new Error(
          `${callingModule}: create ItemWithID from initializationStructureusing convertFrom_xxx produced a null`,
        );
      }
      return _obj;
    } else {
      try {
        _obj = new ItemWithID('aStaticItemWithID');
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(`${callingModule}: create new ItemWithID error }`, e);
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(`${callingModule}: new ItemWithID threw something that was not polymorphus on error`);
        }
      }
      return _obj;
    }
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json(json: string): ItemWithID {
    return fromJson<ItemWithID>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml(yaml: string): ItemWithID {
    return fromYaml<ItemWithID>(yaml);
  }

  ToString(): string {
    return `value: ${this.ID} ID: ${this.ID}`;
  }

  dispose(): void {
    // placeholder:Implement disposal logic for ItemWithID if necessary
    // ToDo: How to get a logger without having to pass it in every function call?
    //console.log(`ItemWithID (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }
}

// Interface encapsulating the return structure of findByValue
export interface IFindItemByValueResult {
  readonly success: boolean;
  readonly pick: IItemWithID | null;
  readonly errorMessage: string | null;
  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
}

// Class implementing the IFindByValueResult interface
export class FindItemByValueResult implements IFindItemByValueResult {
  public readonly success: boolean;
  public readonly pick: IItemWithID | null;
  public readonly errorMessage: string | null;

  constructor(success: boolean, pick: IItemWithID | null, errorMessage: string | null) {
    this.success = success;
    this.pick = pick;
    this.errorMessage = errorMessage;
  }

  static convertFrom_json(json: string): FindItemByValueResult {
    return fromJson<FindItemByValueResult>(json);
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_yaml(yamlString: string): FindItemByValueResult {
    return fromYaml<FindItemByValueResult>(yamlString);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }
  ToString(): string {
    return `success: ${this.success} pick: ${this.pick?.ToString()} errormessage: ${this.errorMessage?.toString()}`;
  }

}

export interface IItemWithIDCollection {
  readonly itemWithIDs: IItemWithID[];
  readonly ID: Philote;
  addItemWithID(itemWithID: IItemWithID): void;
  findItemWithIDByValue(value: string): IItemWithID | undefined;
  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
  dispose(): void;
}

export class ItemWithIDCollection implements IItemWithIDCollection {
  public readonly itemWithIDs: ItemWithID[];
  public readonly ID: Philote; // Now of type Philote

  constructor(ID?: Philote, itemWithIDs?: ItemWithID[]) {
    this.ID = ID !== undefined ? ID : new Philote(); // returns a Philote with a random GUID string or the next sequential Int available from the ID pool
    this.itemWithIDs = itemWithIDs || [];
  }

  public addItemWithID(itemWithID: ItemWithID): void {
    this.itemWithIDs.push(itemWithID);
  }

  public findItemWithIDByValue(value: string): ItemWithID | undefined {
    return this.itemWithIDs.find((itemWithID) => itemWithID.value === value);
  }

  // async findByValue(valueToFind: string): Promise<IFindByValueResult> {
  //   let foundCategory: Category | undefined = this.categories.find((obj) => obj.value === valueToFind);
  //   if (!foundCategory || !foundCategory.value || foundCategory.value.length === 0) {
  //     const message = `Category with value ${valueToFind} not found.`;
  //     return new FindByValueResult(false, null, `Category with value ${valueToFind} not found.`);
  //   } else {
  //     return new FindByValueResult(true, foundCategory, null);
  //   }
  // }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json(json: string): ItemWithIDCollection {
    return fromJson<ItemWithIDCollection>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml(yaml: string): ItemWithIDCollection {
    return fromYaml<ItemWithIDCollection>(yaml);
  }

  ToString(): string {
    return `ItemWithIDCollection: ${this.ID}; numElements: ${this.itemWithIDs.length} `;
  }

  dispose(): void {
    // placeholder:Implement disposal logic for ItemWithID if necessary
    // ToDo: How to get a logger without having to pass it in every function call?
  }
}

export interface IItemWithIDsService {
  createItemWithID(value: ItemWithIDValueType, ID?: Philote): ItemWithID;
  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
  dispose(): void;
}


// ItemWithID Service to keep track of created instances of the base item
export class ItemWithIDsService {
  private message: string = '';
  private itemWithIDsCollection: ItemWithIDCollection;

  constructor(private logger: ILogger, private extensionContext: vscode.ExtensionContext) {
    this.message = 'starting ItemWithIDsService constructor';
    this.logger.log(this.message, LogLevel.Debug);

    this.itemWithIDsCollection = new ItemWithIDCollection();
    this.message = 'leaving ItemWithIDsService constructor';
    this.logger.log(this.message, LogLevel.Debug);
  }

  public createItemWithIDService(value: ItemWithIDValueType, ID?: Philote): ItemWithID {
    const itemWithID = new ItemWithID(value, ID);
    this.itemWithIDsCollection.itemWithIDs.push(itemWithID);
    return itemWithID;
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json(json: string): ItemWithIDsService {
    return fromJson<ItemWithIDsService>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml(yaml: string): ItemWithIDsService {
    return fromYaml<ItemWithIDsService>(yaml);
  }

  ToString(): string {
    return `ItemWithIDsService has one itemWithIDsCollection: ${this.itemWithIDsCollection.ToString()} }`;
  }
  dispose(): void {
    this.itemWithIDsCollection.itemWithIDs.forEach((itemWithID) => {
      itemWithID.dispose();
    });
    this.itemWithIDsCollection = new ItemWithIDCollection();
  }
}
