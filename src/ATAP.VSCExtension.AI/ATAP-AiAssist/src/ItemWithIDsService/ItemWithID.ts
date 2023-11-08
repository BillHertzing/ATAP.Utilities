import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import { GUID, Int, IDType } from '@IDTypes/IDTypes';
import { Philote, IPhilote } from '@Philote/Philote';
import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/Serializers';

import { TagValueType } from '@AssociationsService/index';
import { CategoryValueType } from '@AssociationsService/index';
import { AssociationValueType } from '@AssociationsService/index';
export type ItemWithIDValueType = TagValueType | CategoryValueType | AssociationValueType;

// Define an  interface for itemWithIDs
export interface IItemWithID {
  ID?: Philote;
  value: ItemWithIDValueType;
  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
  dispose(): void;
}

// base itemWithID implementation
export class ItemWithID implements IItemWithID {
  constructor(public value: ItemWithIDValueType, public ID?: Philote) {}
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
    //console.log(`Tag (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }
}

// Interface encapsulating the return structure of findByValue
export interface IFindItemByValueResult {
  readonly success: boolean;
  readonly pick: IItemWithID | null;
  readonly errorMessage: string | null;
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

  constructor(ID: Philote, itemWithIDs?: ItemWithID[]) {
    // Accepts Philote as the collection ID
    this.ID = ID;
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
    return `numElements: ${this.itemWithIDs.length} ID: ${this.ID}`;
  }

  dispose(): void {
    // placeholder:Implement disposal logic for ItemWithID if necessary
    // ToDo: How to get a logger without having to pass it in every function call?
  }
}

export interface IItemWithIDsService {
  createItemWithID(value: ItemWithIDValueType, ID?: Philote): ItemWithID;
  dispose(): void;
}

// ItemWithID Service to keep track of created instances of the base item
export class ItemWithIDsService {
  private itemWithIDs: ItemWithID[] = [];

  public createItemWithID(value: ItemWithIDValueType, ID?: Philote): ItemWithID {
    const itemwithid = new ItemWithID(value, ID);
    this.itemWithIDs.push(itemwithid);
    return itemwithid;
  }

  dispose(): void {
    this.itemWithIDs.forEach((itemWithID) => {
      itemWithID.dispose();
    });
    this.itemWithIDs = [];
  }
}
