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

import { isDeepEqual } from '@Utilities/index';

export type ItemWithIDValueType =
  | TagValueType
  | CategoryValueType
  | AssociationValueType
  | TokenValueType
  | QueryContextValueType;

export type ItemWithIDTypes = Tag | Category | Association | Token | QueryContext;

export type MapTypeToValueType<T> = T extends Tag
  ? TagValueType
  : T extends Category
  ? CategoryValueType
  : T extends Association
  ? AssociationValueType
  : T extends Token
  ? TokenValueType
  : T extends QueryContext
  ? QueryContextValueType
  : never;

import * as yaml from 'js-yaml';
export interface YamlData<T extends ItemWithIDTypes> {
  value: MapTypeToValueType<T>;
}

export const fromYamlForItemWithID = <T extends ItemWithIDTypes>(yamlString: string): YamlData<T> => {
  return yaml.load(yamlString) as YamlData<T>;
};

// Define the IItemWithID interface with type constraints
export interface IItemWithID<T extends ItemWithIDTypes> {
  readonly value: MapTypeToValueType<T>;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}

// Define the ItemWithID generic class
export class ItemWithID<T extends ItemWithIDTypes> implements IItemWithID<T> {
  readonly value: MapTypeToValueType<T>;
  readonly ID: IPhilote;

  constructor(value: MapTypeToValueType<T>, ID?: IPhilote) {
    this.value = value;
    this.ID = ID ?? new Philote();
  }
  static CreateItemWithID(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): ItemWithIDTypes {
    let _obj: ItemWithIDTypes | null;
    if (initializationStructure) {
      try {
        // ToDo: deserialize based on contents of structure
        _obj = ItemWithID.convertFrom_json(initializationStructure.value);
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


  toString(): string {
    return `ItemWithID: ${JSON.stringify(this.value)}`;
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends ItemWithIDTypes>(json: string): ItemWithID<T> {
    const data = JSON.parse(json);
    return new ItemWithID<T>(data.value as MapTypeToValueType<T>);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  // static convertFrom_yaml<T extends ItemWithIDTypes>(yaml: string): ItemWithID<T> {
  //   const data = fromYaml(yaml); // Assuming fromYaml is a function to parse YAML string
  //   return new ItemWithID<T>(data.value as MapTypeToValueType<T>);
  // }
}

export interface ICollection<T extends ItemWithIDTypes> {
  ID: Philote;
  value: ItemWithID<T>[];
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
  findItemWithIDByValue(value: MapTypeToValueType<T>): Promise<ItemWithID<T> | undefined>;
}

export class Collection<T extends ItemWithIDTypes> implements ICollection<T> {
  ID: Philote;
  value: ItemWithID<T>[];

  constructor(value: ItemWithID<T>[], ID?: Philote) {
    this.value = value;
    this.ID = ID ?? new Philote();
  }

  convertTo_json(): string {
    return toJson(this);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  toString(): string {
    return `Collection ID ${this.ID.ToString()}: ${this.value.map((item) => item.toString()).join(', ')}`;
  }

  async findItemWithIDByValue(valueToFind: MapTypeToValueType<T>): Promise<ItemWithID<T> | undefined> {
    return new Promise((resolve) => {
      const foundItem = this.value.find((element: ItemWithID<T>) => {
        if (typeof element.value === 'object' && typeof valueToFind === 'object') {
          return isDeepEqual(element.value, valueToFind);
        }
        return element.value === valueToFind;
      });
      resolve(foundItem);
    });
  }
}

export interface IFactory<T extends ItemWithIDTypes> {
  create(...args: any[]): T;
  dispose(instance: T): void;
}

export class Factory<T extends ItemWithIDTypes> implements IFactory<T> {
  private logger: ILogger;
  private context: vscode.ExtensionContext;
  private instances: Set<T>;
  private typeConstructor: { create: (...args: any[]) => T };

  constructor(logger: ILogger, context: vscode.ExtensionContext, typeConstructor: { create: (...args: any[]) => T }) {
    this.logger = logger;
    this.context = context;
    this.instances = new Set<T>();
    this.typeConstructor = typeConstructor;
  }

  create(...args: any[]): T {
    const instance = this.typeConstructor.create(...args);
    this.instances.add(instance);
    return instance;
  }

  dispose(instance: T): void {
    if (this.instances.has(instance)) {
      // Perform any necessary cleanup for the instance
      // ...

      this.instances.delete(instance);
    }
  }
}

export interface ICollectionFactory<T extends ItemWithIDTypes> {
  createCollection(...args: any[]): Collection<T>;
  disposeCollection(collection: Collection<T>): void;
}

export class CollectionFactory<T extends ItemWithIDTypes> implements ICollectionFactory<T> {
  private logger: ILogger;
  private context: vscode.ExtensionContext;
  private collections: Set<Collection<T>>;

  constructor(logger: ILogger, context: vscode.ExtensionContext) {
    this.logger = logger;
    this.context = context;
    this.collections = new Set<Collection<T>>();
  }

  createCollection(...args: [ItemWithID<T>[], Philote?]): Collection<T> {
    const collection = new Collection<T>(...args);
    // ... other logic ...
    return collection;
  }

  disposeCollection(collection: Collection<T>): void {
    if (this.collections.has(collection)) {
      // Perform any necessary cleanup for the collection
      // ...

      this.collections.delete(collection);
    }
  }
}

export type TagValueType = string;

export interface ITag extends IItemWithID<Tag> {
  toString(): string;
}

export class Tag extends ItemWithID<Tag> implements ITag {
  constructor(value: string, ID?: IPhilote) {
    super(value, ID);
  }

  // Implement the toString method
  toString(): string {
    return `Tag ID:${this.ID.ToString()} ;Tag value:${this.value}`;
  }

  // Static method to create Tag instances
  static create(value: string): Tag {
    return new Tag(value);
  }
}

export interface ITagCollection extends ICollection<Tag> {
  // Add any additional methods specific to a collection of Tags, if necessary
  // Example:
  // findTagBySomeCriteria(criteria: any): Tag | undefined;
}

export class TagCollection extends Collection<Tag> implements ITagCollection {
  constructor(value: ItemWithID<Tag>[], ID?: Philote) {
    super(value, ID);
  }

  // Implement any additional methods specific to TagCollection
  // Example:
  // findTagBySomeCriteria(criteria: any): Tag | undefined {
  //   // Implementation specific to finding a tag based on the given criteria
  // }
}

export type CategoryValueType = string;

export interface ICategory extends IItemWithID<Category> {
  toString(): string;
}

export class Category extends ItemWithID<Category> implements ICategory {
  constructor(value: string, ID?: IPhilote) {
    super(value, ID);
  }

  // Implement the toString method
  toString(): string {
    return `Category ID:${this.ID.ToString()} ;Category value:${this.value}`;
  }

  // Static method to create Category instances
  static create(value: string): Category {
    return new Category(value);
  }
}

export interface ICategoryCollection extends ICollection<Category> {
  // Add any additional methods specific to a collection of Categorys, if necessary
  // Example:
  // findCategoryBySomeCriteria(criteria: any): Category | undefined;
}

export class CategoryCollection extends Collection<Category> implements ICategoryCollection {
  constructor(value: ItemWithID<Category>[], ID?: Philote) {
    super(value, ID);
  }

  // Implement any additional methods specific to CategoryCollection
  // Example:
  // findCategoryBySomeCriteria(criteria: any): Category | undefined {
  //   // Implementation specific to finding a tag based on the given criteria
  // }
}

export type TokenValueType = string;

export interface IToken extends IItemWithID<Token> {
  toString(): string;
}

export class Token extends ItemWithID<Token> implements IToken {
  constructor(value: string, ID?: IPhilote) {
    super(value, ID);
  }

  // Implement the toString method
  toString(): string {
    return `Token ID:${this.ID.ToString()} ;Token value:${this.value}`;
  }

  // Static method to create Token instances
  static create(value: string): Token {
    return new Token(value);
  }
}

export interface ITokenCollection extends ICollection<Token> {
  // Add any additional methods specific to a collection of Tokens, if necessary
  // Example:
  // findTokenBySomeCriteria(criteria: any): Token | undefined;
}

export class TokenCollection extends Collection<Token> implements ITokenCollection {
  constructor(value: ItemWithID<Token>[], ID?: Philote) {
    super(value, ID);
  }

  // Implement any additional methods specific to TokenCollection
  // Example:
  // findTokenBySomeCriteria(criteria: any): Token | undefined {
  //   // Implementation specific to finding a token based on the given criteria
  // }
}

export type AssociationValueType = {
  tagCollection: ITagCollection;
  categoryCollection: ICategoryCollection;
};

export interface IAssociation extends IItemWithID<Association> {
  toString(): string;
}

export class Association extends ItemWithID<Association> implements IAssociation {
  constructor(value: string, ID?: IPhilote) {
    super(value, ID);
  }

  // Implement the toString method
  toString(): string {
    return `Association ID:${this.ID.ToString()} ;Association value:${this.value}`;
  }

  // Static method to create Association instances
  static create(value: string): Association {
    return new Association(value);
  }
}

export interface IAssociationCollection extends ICollection<Association> {
  // Add any additional methods specific to a collection of Associations, if necessary
  // Example:
  // findAssociationBySomeCriteria(criteria: any): Association | undefined;
}

export class AssociationCollection extends Collection<Association> implements IAssociationCollection {
  constructor(value: ItemWithID<Association>[], ID?: Philote) {
    super(value, ID);
  }

  // Implement any additional methods specific to AssociationCollection
  // Example:
  // findAssociationBySomeCriteria(criteria: any): Association | undefined {
  //   // Implementation specific to finding a association based on the given criteria
  // }
}

export type QueryContextValueType = string;

export interface IQueryContext extends IItemWithID<QueryContext> {
  toString(): string;
}

export class QueryContext extends ItemWithID<QueryContext> implements IQueryContext {
  constructor(value: string, ID?: IPhilote) {
    super(value, ID);
  }

  // Implement the toString method
  toString(): string {
    return `QueryContext ID:${this.ID.ToString()} ;QueryContext value:${this.value}`;
  }

  // Static method to create QueryContext instances
  static create(value: string): QueryContext {
    return new QueryContext(value);
  }
}

export interface IQueryContextCollection extends ICollection<QueryContext> {
  // Add any additional methods specific to a collection of QueryContexts, if necessary
  // Example:
  // findQueryContextBySomeCriteria(criteria: any): QueryContext | undefined;
}

export class QueryContextCollection extends Collection<QueryContext> implements IQueryContextCollection {
  constructor(value: ItemWithID<QueryContext>[], ID?: Philote) {
    super(value, ID);
  }

  // Implement any additional methods specific to QueryContextCollection
  // Example:
  // findQueryContextBySomeCriteria(criteria: any): QueryContext | undefined {
  //   // Implementation specific to finding a querycontext based on the given criteria
  // }
}

class Data {
  private tagFactory: IFactory<Tag>;
  private tagCollectionFactory: ICollectionFactory<Tag>;
  private categoryFactory: IFactory<Category>;
  private categoryCollectionFactory: ICollectionFactory<Category>;
  private tokenFactory: IFactory<Token>;
  private tokenCollectionFactory: ICollectionFactory<Token>;
  private associationFactory: IFactory<Association>;
  private associationCollectionFactory: ICollectionFactory<Association>;
  private querycontextFactory: IFactory<QueryContext>;
  private querycontextCollectionFactory: ICollectionFactory<QueryContext>;

  constructor(logger: ILogger, context: vscode.ExtensionContext) {
    this.tagFactory = new Factory<Tag>(logger, context, Tag);
    this.tagCollectionFactory = new CollectionFactory<Tag>(logger, context);
    this.categoryFactory = new Factory<Category>(logger, context, Category);
    this.categoryCollectionFactory = new CollectionFactory<Category>(logger, context);
    this.tokenFactory = new Factory<Token>(logger, context, Token);
    this.tokenCollectionFactory = new CollectionFactory<Token>(logger, context);
    this.associationFactory = new Factory<Association>(logger, context, Association);
    this.associationCollectionFactory = new CollectionFactory<Association>(logger, context);
    this.querycontextFactory = new Factory<QueryContext>(logger, context, QueryContext);
    this.querycontextCollectionFactory = new CollectionFactory<QueryContext>(logger, context);
  }
}