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

  dispose(): void {
    this.categoryWithIDs.forEach((categoryWithID) => {
      categoryWithID.dispose();
    });
    this.categoryWithIDs = [];
  }
}
