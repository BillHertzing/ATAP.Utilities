import * as vscode from 'vscode';
import { GUID, Int, IDType } from '@IDTypes/index';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor, logExecutionTime } from '@Decorators/index';
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
  ItemWithIDValueType,
  ItemWithIDTypes,
  MapTypeToValueType,
  YamlData,
  fromYamlForItemWithID,
  IItemWithID,
  ItemWithID,
  ICollection,
  Collection,
  IFactory,
  Factory,
  ICollectionFactory,
  CollectionFactory,
  TagValueType,
  ITag,
  Tag,
  ITagCollection,
  TagCollection,
  CategoryValueType,
  ICategory,
  Category,
  ICategoryCollection,
  CategoryCollection,
  TokenValueType,
  IToken,
  Token,
  ITokenCollection,
  TokenCollection,
  AssociationValueType,
  IAssociation,
  Association,
  IAssociationCollection,
  AssociationCollection,
  QueryContextValueType,
  IQueryContext,
  QueryContext,
  IQueryContextCollection,
  QueryContextCollection,
} from '@ItemWithIDs/index';

import { GlobalStateCache } from './GlobalStateCache';

// This defines what a UserData instance looks like
export interface IUserData {
  //readonly associationCollection: IAssociationCollection;
  //readonly categoryCollection: ICategoryCollection;
  //readonly queryContextCollection: IQueryContextCollection;
  readonly tagCollection: ITagCollection;
}


export class UserData implements IUserData {
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

   readonly tagCollection: ITagCollection;
  // readonly categoryCollection: ICategoryCollection;
  // readonly associationCollection: IAssociationCollection;
  // readonly tokenCollection: ITokenCollection;
  // readonly querycontextCollection: IQueryContextCollection;

  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);
  // constructor(
  //   logger: ILogger,
  //   extensionContext: vscode.ExtensionContext,
  //   initializationStructure: ISerializationStructure,
  // );

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    tagCollection?: ITagCollection,
    categoryCollection?: ICategoryCollection,
    associationCollection?: ICategoryCollection,
    tokenCollection?: ITokenCollection,
    queryContextCollection?: IQueryContextCollection,
    initializationStructure?: ISerializationStructure,
  ) {
    // Initialize the global cache so we can populate it as we create the data structure
    const globalStateCache = new GlobalStateCache(extensionContext);
    this.tagFactory = new Factory<Tag>(logger, extensionContext, Tag);
    this.tagCollectionFactory = new CollectionFactory<Tag>(logger, extensionContext);
    this.categoryFactory = new Factory<Category>(logger, extensionContext, Category);
    this.categoryCollectionFactory = new CollectionFactory<Category>(logger, extensionContext);
    this.tokenFactory = new Factory<Token>(logger, extensionContext, Token);
    this.tokenCollectionFactory = new CollectionFactory<Token>(logger, extensionContext);
    this.associationFactory = new Factory<Association>(logger, extensionContext, Association);
    this.associationCollectionFactory = new CollectionFactory<Association>(logger, extensionContext);
    this.querycontextFactory = new Factory<QueryContext>(logger, extensionContext, QueryContext);
    this.querycontextCollectionFactory = new CollectionFactory<QueryContext>(logger, extensionContext);

    // if (initializationStructure !== undefined) {
    // } else {
    //   //this.associationCollection = new AssociationCollection();
    //   //this.categoryCollection = new CategoryCollection();
    //   //this.queryContextCollection = new QueryContextCollection();
    this.tagCollection = this.tagCollectionFactory.createCollection();
    // this.categoryCollection = this.categoryCollectionFactory.createCollection();
    // this.associationCollection = this.asociationCollectionFactory.createCollection();
    // this.tokenCollection = this.tokenCollectionFactory.createCollection();
    // this.querycontextCollection = this.querycontextCollectionFactory.createCollection();
    // }
  }
}
