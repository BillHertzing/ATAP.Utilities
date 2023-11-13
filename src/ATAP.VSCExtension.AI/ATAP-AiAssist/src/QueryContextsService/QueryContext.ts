import * as vscode from 'vscode';
import { GUID, Int, IDType } from '@IDTypes/index';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor, logExecutionTime } from '@Decorators/index';
import { Philote, IPhilote } from '@Philote/index';
import { DefaultConfiguration } from '../DefaultConfiguration';
import { UserData, IUserData } from '@DataService/index';
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

export type QueryContextValueType = string;

export interface IQueryContext extends IItemWithID {}

export class QueryContext extends ItemWithID implements IQueryContext {

  constructor(value: string,  ID?: Philote) {
    super(value, ID); // Call to the super class constructor
  }

  static convertFrom_json(json: string): QueryContext {
    return fromJson<QueryContext>(json);
  }

  static convertFrom_yaml(yaml: string): QueryContext {
    return fromYaml<QueryContext>(yaml);
  }

}

export interface IQueryContextCollection extends IItemWithIDCollection {
  // No new members; simply a more specific type of IItemWithID with QueryContext semantics.
}

export class QueryContextCollection extends ItemWithIDCollection {

  constructor(ID?: Philote, queryContexts?: QueryContext[]) {

    super(ID, queryContexts); // Call to the super class constructor
  }


  static convertFrom_json(json: string): QueryContextCollection {
    return fromJson<QueryContextCollection>(json);
  }

  static convertFrom_yaml(yaml: string): QueryContextCollection {
    return fromYaml<QueryContextCollection>(yaml);
  }
}

export interface IQueryContextsService extends IItemWithIDsService {
  createQueryContext(value: QueryContextValueType, ID?: Philote): QueryContext;
  dispose(): void;
}

// QueryContextsService is a factory for QueryContext instances
export class QueryContextsService extends ItemWithIDsService implements IQueryContextsService {
  private message: string;

  private QueryContextWithIDs: QueryContext[] = [];

  constructor(private logger: ILogger, private extensionContext: vscode.ExtensionContext) {
    super();
    this.message = 'starting QueryContextsService constructor';
    this.logger.log(this.message, LogLevel.Debug);


    this.message = 'leaving QueryContextsService constructor';
    this.logger.log(this.message, LogLevel.Debug);
  }

  public createQueryContext(value: QueryContextValueType, ID?: Philote): QueryContext {
    const queryContextWithID = new QueryContext(value, ID);
    this.QueryContextWithIDs.push(queryContextWithID);
    return queryContextWithID;
  }

  dispose(): void {
    this.QueryContextWithIDs.forEach((QueryContextWithID) => {
      QueryContextWithID.dispose();
    });
    this.QueryContextWithIDs = [];
  }
}

