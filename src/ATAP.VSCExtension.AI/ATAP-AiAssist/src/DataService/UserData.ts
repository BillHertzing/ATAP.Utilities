import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import * as vscode from 'vscode';

import { GlobalStateCache } from './GlobalStateCache';
import { GUID, Int, IDType } from '@IDTypes/IDTypes';
import {
  QueryContext,
  IQueryContext,
  Category,
  ICategory,
  Tag,
  ITag,
  QueryContextCollection,
  IQueryContextCollection,
  CategoryCollection,
  ICategoryCollection,
  TagCollection,
  ITagCollection,
} from '@QueryContextsService/index';

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
  readonly categoryCollection: ICategoryCollection;
  readonly queryContextCollection: IQueryContextCollection;
  readonly tagCollection: ITagCollection;
}

export class UserData<T extends IDType> implements IUserData {
  readonly categoryCollection: ICategoryCollection;
  readonly queryContextCollection: IQueryContextCollection;
  readonly tagCollection: ITagCollection;

  constructor(logger: ILogger, context: vscode.ExtensionContext);
  constructor(logger: ILogger, context: vscode.ExtensionContext, categoryCollection: ICategoryCollection);
  constructor(logger: ILogger, context: vscode.ExtensionContext, queryContextCollection: IQueryContextCollection);
  constructor(logger: ILogger, context: vscode.ExtensionContext, tagCollection: ITagCollection);
  constructor(logger: ILogger, context: vscode.ExtensionContext, initializationStructure: ISerializationStructure);

  constructor(
    private logger: ILogger,
    private context: vscode.ExtensionContext,
    categoryCollection?: ICategoryCollection,
    queryContextCollection?: IQueryContextCollection,
    tagCollection?: ITagCollection,
    initializationStructure?: ISerializationStructure
  ) {

    // Initialize the global cache so we can populate it as we create the data structure
    const globalStateCache = new GlobalStateCache(context);

    if (categoryCollection !== undefined) {
      this.categoryCollection = categoryCollection;
    } else {
      this.categoryCollection = new CategoryCollection();
    }
    if (queryContextCollection !== undefined) {
      this.queryContextCollection = queryContextCollection;
    } else {
      this.queryContextCollection = new QueryContextCollection();
    }
    if (tagCollection !== undefined) {
      this.tagCollection = tagCollection;
    } else {
      this.tagCollection = new TagCollection();
    }

  }
}
