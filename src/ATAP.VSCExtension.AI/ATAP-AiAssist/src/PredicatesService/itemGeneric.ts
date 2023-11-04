import { GUID, Int, IDType } from './IDTypes';

import { toJson, fromJson, toYaml, fromYaml } from './Serilaizers';

import { Philote } from './Philote';

export interface IItem<T extends IDType> {
  readonly name: string;
  readonly ID: Philote<T>;
  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
}

export class Item<T extends IDType> implements IItem<T> {
  public readonly name: string;
  public readonly ID: Philote<T>;

  constructor(name: string, ID: Philote<T>) {
    // Accepts Philote as the ID
    this.name = name;
    this.ID = ID;
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Item<T> {
    return fromJson<Item<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Item<T> {
    return fromYaml<Item<T>>(yaml);
  }

  ToString(): string {
    return `name: ${this.ID} ID: ${this.ID}`;
  }
}

// Interface encapsulating the return structure of findByName
export interface IFindItemByNameResult<T extends IDType> {
  readonly success: boolean;
  readonly pick: Item<T> | null;
  readonly errorMessage: string | null;
}

// Class implementing the IFindByNameResult interface
export class FindItemByNameResult<T extends IDType> implements IFindItemByNameResult<T> {
  public readonly success: boolean;
  public readonly pick: Item<T> | null;
  public readonly errorMessage: string | null;

  constructor(success: boolean, pick: Item<T> | null, errorMessage: string | null) {
    this.success = success;
    this.pick = pick;
    this.errorMessage = errorMessage;
  }

  static convertFrom_json<T extends IDType>(json: string): FindItemByNameResult<T> {
    return fromJson<FindItemByNameResult<T>>(json);
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_yaml<T extends IDType>(yamlString: string): FindItemByNameResult<T> {
    return fromYaml<FindItemByNameResult<T>>(yamlString);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IItemCollection<T extends IDType> {
  readonly items: IItem<T>[];
  readonly ID: Philote<T>;
  addItem(item: IItem<T>): void;
  findItemByName(name: string): IItem<T> | undefined;
  convertTo_json(): string;
  convertTo_yaml(): string;
  ToString(): string;
}

export class ItemCollection<T extends IDType> implements IItemCollection<T> {
  public readonly items: Item<T>[];
  public readonly ID: Philote<T>; // Now of type Philote

  constructor(ID: Philote<T>, items?: Item<T>[]) {
    // Accepts Philote as the collection ID
    this.ID = ID;
    this.items = items || [];
  }

  public addItem(item: Item<T>): void {
    this.items.push(item);
  }

  public findItemByName(name: string): Item<T> | undefined {
    return this.items.find((item) => item.name === name);
  }

  // async findByName<T extends IDType>(nameToFind: string): Promise<IFindByNameResult<T>> {
  //   let foundCategory: Category<T> | undefined = this.categories.find((obj) => obj.name === nameToFind);
  //   if (!foundCategory || !foundCategory.name || foundCategory.name.length === 0) {
  //     const message = `Category with name ${nameToFind} not found.`;
  //     return new FindByNameResult<T>(false, null, `Category with name ${nameToFind} not found.`);
  //   } else {
  //     return new FindByNameResult<T>(true, foundCategory, null);
  //   }
  // }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): ItemCollection<T> {
    return fromJson<ItemCollection<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): ItemCollection<T> {
    return fromYaml<ItemCollection<T>>(yaml);
  }

  ToString(): string {
    return `numElements: ${this.items.length} ID: ${this.ID}`;
  }
}

// Usage example
//  let philoteID = new Philote<GUID>("guid-1");
//  let item1 = new Item<GUID>("item1", philoteID);
//  let itemCollection = new ItemCollection<GUID>(philoteID, [item1]);
