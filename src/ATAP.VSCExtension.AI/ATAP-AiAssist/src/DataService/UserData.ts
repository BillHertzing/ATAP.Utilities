import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import * as vscode from 'vscode';

import { GUID, Int, IDType } from '@IDTypes/IDTypes';
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
  ItemWithIDValueType,
  ItemWithID,
  IItemWithID,
  ItemWithIDCollection,
  IItemWithIDCollection,
  ItemWithIDsService,
  IItemWithIDsService,
} from '@ItemWithIDsService/index';

import {
  TagValueType,
  Tag,
  ITag,
  TagCollection,
  ITagCollection,
  TagsService,
  ITagsService,
} from '@AssociationsService/index';

import {
  CategoryValueType,
  Category,
  ICategory,
  CategoryCollection,
  ICategoryCollection,
  CategorysService,
  ICategorysService,
} from '@AssociationsService/index';

import {
  AssociationValueType,
  Association,
  IAssociation,
  AssociationCollection,
  IAssociationCollection,
  AssociationsService,
  IAssociationsService,
} from '@AssociationsService/index';

import {
  QueryContextValueType,
  QueryContext,
  IQueryContext,
  QueryContextCollection,
  IQueryContextCollection,
  QueryContextsService,
  IQueryContextsService,
} from '@QueryContextsService/index';

import { GlobalStateCache } from './GlobalStateCache';


// This defines what a UserData instance looks like
export interface IUserData {
  readonly categoryCollection: ICategoryCollection;
  readonly queryContextCollection: IQueryContextCollection;
  readonly tagCollection: ITagCollection;
}

export class UserData implements IUserData {
  readonly categoryCollection: ICategoryCollection;
  readonly queryContextCollection: IQueryContextCollection;
  readonly tagCollection: ITagCollection;

  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, categoryCollection: ICategoryCollection);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, queryContextCollection: IQueryContextCollection);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, tagCollection: ITagCollection);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, initializationStructure: ISerializationStructure);

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
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
