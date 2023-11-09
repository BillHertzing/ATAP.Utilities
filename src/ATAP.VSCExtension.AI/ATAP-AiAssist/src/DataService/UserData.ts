import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';

import { GUID, Int, IDType } from '@IDTypes/index';
import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/index';

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
  //readonly associationCollection: IAssociationCollection;
  //readonly categoryCollection: ICategoryCollection;
  //readonly queryContextCollection: IQueryContextCollection;
  readonly tagCollection: ITagCollection;
}

export class UserData implements IUserData {
  //readonly associationCollection: IAssociationCollection;
  //readonly categoryCollection: ICategoryCollection;
  //readonly queryContextCollection: IQueryContextCollection;
  readonly tagCollection: ITagCollection;

  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);
  // constructor(
  //   logger: ILogger,
  //   extensionContext: vscode.ExtensionContext,
  //   initializationStructure: ISerializationStructure,
  // );

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    associationCollection?: ICategoryCollection,
    categoryCollection?: ICategoryCollection,
    queryContextCollection?: IQueryContextCollection,
    tagCollection?: ITagCollection,
    initializationStructure?: ISerializationStructure,
  ) {
    // Initialize the global cache so we can populate it as we create the data structure
    const globalStateCache = new GlobalStateCache(extensionContext);

    // if (initializationStructure !== undefined) {
    // } else {
    //   //this.associationCollection = new AssociationCollection();
    //   //this.categoryCollection = new CategoryCollection();
    //   //this.queryContextCollection = new QueryContextCollection();
      this.tagCollection = new TagCollection();
    // }
  }
}
