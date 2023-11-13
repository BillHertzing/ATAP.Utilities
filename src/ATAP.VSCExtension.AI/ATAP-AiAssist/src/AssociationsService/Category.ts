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

import {
  ItemWithID,
  IItemWithID,
  ItemWithIDsService,
  IItemWithIDsService,
  ItemWithIDCollection,
  IItemWithIDCollection,
} from '@ItemWithIDsService/index';

export type CategoryValueType = string;

// Define an interface for category that extends IItemWithID
export interface ICategory extends IItemWithID {}

// Category class extending ItemWithID
export class Category extends ItemWithID implements ICategory {
  constructor(value: CategoryValueType, ID?: Philote) {
    super(value, ID);
  }

  static CreateCategory(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
): Category {
    let _obj: Category | null;
    if (initializationStructure) {
      try {
        // ToDo: deserialize based on contents of structure
        _obj = Category.convertFrom_yaml(initializationStructure.value);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create Category from initializationStructure using convertFrom_xxx -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create Category from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
          );
        }
      }
      if (_obj === null) {
        throw new Error(
          `${callingModule}: create Category from initializationStructureusing convertFrom_xxx produced a null`,
        );
      }
      return _obj;
    } else {
      try {
        _obj = new Category('aStaticCategory');
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create new Category error }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: new Category threw something that was not polymorphus on error`,
          );
        }
      }
      return _obj;
    }

}


  static convertFrom_json(json: string): Category {
    return fromJson<Category>(json);
  }

  static convertFrom_yaml(yaml: string): Category {
    return fromYaml<Category>(yaml);
  }

  dispose(): void {
    // Call dispose for base ItemWithID
    super.dispose();
    // ToDo: How to get a logger without having to pass it in every function call?
    //console.log(`Category (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }

  // placedholder
  placeholder(): void {
    //console.log(`Placeholder method called for Category (ID: ${this.ID.id}, Value: ${this.value})`);
  }
}

export interface ICategoryCollection extends IItemWithIDCollection {
  // No new members; simply a more specific type of IItemWithID with Category semantics.
}

export class CategoryCollection extends ItemWithIDCollection {
  constructor(ID?: Philote, categorys?: ICategory[]) {
    const _ID = ID !== undefined ? ID : new Philote();
    const _categorys = categorys !== undefined ? categorys : [];
    super(ID, categorys);
  }

  static convertFrom_json(json: string): CategoryCollection {
    return fromJson<CategoryCollection>(json);
  }

  static convertFrom_yaml(yaml: string): CategoryCollection {
    return fromYaml<CategoryCollection>(yaml);
  }
}

export interface ICategorysService extends IItemWithIDsService {
  createCategory(value: CategoryValueType, ID?: Philote): Category;
  dispose(): void;
}

// CategoryService is a factory for Category instances
export class CategorysService extends ItemWithIDsService implements ICategorysService {
  private categoryWithIDs: Category[] = [];

  public createCategory(value: CategoryValueType, ID?: Philote): Category {
    const category = new Category(value, ID);
    this.categoryWithIDs.push(category);
    return category;
  }

  static convertFrom_json(json: string): CategorysService {
    return fromJson<CategorysService>(json);
  }

  static convertFrom_yaml(yaml: string): CategorysService {
    return fromYaml<CategorysService>(yaml);
  }

  dispose(): void {
    this.categoryWithIDs.forEach((categoryWithID) => {
      categoryWithID.dispose();
    });
    this.categoryWithIDs = [];
  }
}
