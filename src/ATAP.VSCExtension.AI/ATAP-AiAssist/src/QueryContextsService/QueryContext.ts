import { DetailedError } from '@ErrorClasses/index';
import { GUID, Int, IDType } from '@IDTypes/index';

import { Philote, IPhilote } from '@Philote/index';
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
}

export interface IQueryContextCollection extends IItemWithIDCollection {
  // No new members; simply a more specific type of IItemWithID with QueryContext semantics.
}

export class QueryContextCollection extends ItemWithIDCollection {
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
  private QueryContextWithIDs: QueryContext[] = [];

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

