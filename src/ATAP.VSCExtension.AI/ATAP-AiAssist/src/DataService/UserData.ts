import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import * as vscode from 'vscode';

import { GlobalStateCache } from './GlobalStateCache';
import { GUID, Int, IDType } from '@IDTypes/IDTypes';
import {
  Predicate,
  IPredicate,
  Category,
  ICategory,
  Tag,
  ITag,
  PredicateCollection,
  IPredicateCollection,
  CategoryCollection,
  ICategoryCollection,
  TagCollection,
  ITagCollection,
} from '@PredicatesService/index';

import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/Serializers';

// This defines what a UserData instance looks like
export interface IUserData<T extends IDType> {
  readonly categoryCollection: ICategoryCollection<T>;
  readonly predicateCollection: IPredicateCollection<T>;
  readonly tagCollection: ITagCollection<T>;
}

export class UserData<T extends IDType> implements IUserData<T> {
  readonly categoryCollection: ICategoryCollection<T>;
  readonly predicateCollection: IPredicateCollection<T>;
  readonly tagCollection: ITagCollection<T>;

  constructor(logger: ILogger, context: vscode.ExtensionContext);
  constructor(logger: ILogger, context: vscode.ExtensionContext, categoryCollection: ICategoryCollection<T>);
  constructor(logger: ILogger, context: vscode.ExtensionContext, predicateCollection: IPredicateCollection<T>);
  constructor(logger: ILogger, context: vscode.ExtensionContext, tagCollection: ITagCollection<T>);
  constructor(logger: ILogger, context: vscode.ExtensionContext, initializationStructure: ISerializationStructure);

  constructor(
    private logger: ILogger,
    private context: vscode.ExtensionContext,
    categoryCollection?: ICategoryCollection<T>,
    predicateCollection?: IPredicateCollection<T>,
    tagCollection?: ITagCollection<T>,
    initializationStructure?: ISerializationStructure
  ) {

    // Initialize the global cache so we can populate it as we create the data structure
    const globalStateCache = new GlobalStateCache(context);

    if (categoryCollection !== undefined) {
      this.categoryCollection = categoryCollection;
    } else {
      this.categoryCollection = new CategoryCollection<T>();
    }
    if (predicateCollection !== undefined) {
      this.predicateCollection = predicateCollection;
    } else {
      this.predicateCollection = new PredicateCollection<T>();
    }
    if (tagCollection !== undefined) {
      this.tagCollection = tagCollection;
    } else {
      this.tagCollection = new TagCollection<T>();
    }

  }
}
