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

export interface IQueryContext extends IItemWithID {
  readonly TagCollection: TagCollection;
  readonly CategoryCollection: CategoryCollection;
}

export class QueryContext extends ItemWithID implements IQueryContext {
  public readonly TagCollection: TagCollection;
  public readonly CategoryCollection: CategoryCollection;

  constructor(value: string, TagCollection: TagCollection, CategoryCollection: CategoryCollection, ID?: Philote) {
    super(value, ID); // Call to the super class constructor
    this.TagCollection = TagCollection;
    this.CategoryCollection = CategoryCollection;
  }
}

export interface IQueryContextCollection extends IItemWithIDCollection {
  // No new members; simply a more specific type of IItemWithID with QueryContext semantics.
}

export class QueryContextCollection extends ItemWithIDCollection {
  // No new members added, but the type is distinct from Item
}
