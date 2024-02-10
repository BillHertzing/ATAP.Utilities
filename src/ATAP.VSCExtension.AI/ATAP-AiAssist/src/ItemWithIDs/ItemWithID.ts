import * as vscode from 'vscode';
import {
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/index';

import * as yaml from 'js-yaml';

import { DetailedError } from '@ErrorClasses/index';
import { ILogger, Logger } from '@Logger/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import { GUID, Int, IDType, nextID } from '@IDTypes/index';
import { Philote, IPhilote } from '@Philote/index';

import { QueryFragmentEnum } from '@BaseEnumerations/index';

export type TagValueType = string;
export type CategoryValueType = string;
export type QueryRequestValueType = string;
export type QueryResponseValueType = string;

export type AiAssistCancellationTokenSourceValueType = vscode.CancellationTokenSource;

export interface IAssociationValueType {
  tagCollection: ITagCollection;
  categoryCollection: ICategoryCollection;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class AssociationValueType {
  constructor(
    readonly tagCollection: ITagCollection,
    readonly categoryCollection: ICategoryCollection,
  ) {}
  toString(): string {
    return `AssociationValueType tagCollection:${this.tagCollection.toString()}; categoryCollection:${this.categoryCollection.toString()}`;
  }
  convertTo_json(): string {
    return toJson(this);
  }
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryFragmentValueType {
  readonly kindOfFragment: QueryFragmentEnum;
  value: string; // ToDo: Type to ValueTypeMapping string, pathlike or a collectionID of a queryFragmentCollection;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class QueryFragmentValueType implements IQueryFragmentValueType {
  constructor(
    readonly kindOfFragment: QueryFragmentEnum,
    readonly value: string, // ToDo: Type to ValueTypeMapping string, pathlike or a collectionID of a queryFragmentCollection;
  ) {}
  toString(): string {
    return `QueryFragmentValueType kindOfFragment:${this.kindOfFragment.toString()}; value:${toJson(this.value)}`;
  }
  convertTo_json(): string {
    return toJson(this);
  }
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryPairValueType {
  queryRequest: IQueryRequest;
  queryResponse: IQueryResponse;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class QueryPairValueType {
  constructor(
    readonly queryRequest: IQueryRequest,
    readonly queryResponse: IQueryResponse,
  ) {}
  toString(): string {
    return `QueryPairValueType queryRequest:${this.queryRequest.toString()}; queryResponse:${this.queryResponse.toString()}`;
  }
  convertTo_json(): string {
    return toJson(this);
  }
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryPairCollectionValueType {
  queryPairCollection: IQueryPair[];
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class QueryPairCollectionValueType {
  constructor(readonly queryPairCollection: IQueryPair[]) {}
  toString(): string {
    return `QueryPairCollectionValueType queryPairCollection:${this.queryPairCollection.toString()}}`;
  }
  convertTo_json(): string {
    return toJson(this);
  }
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export type CancellationTokenSourceValueType = vscode.CancellationTokenSource;

export type ItemWithIDValueType =
  | string
  | IAssociationValueType
  | IQueryFragmentValueType
  | IQueryPairValueType
  | IQueryPairCollectionValueType
  | AiAssistCancellationTokenSourceValueType;

// export type MapTypeToValueType<T> = T extends Tag
//   ? TagValueType
//   : T extends Category
//     ? CategoryValueType
//     : T extends Association
//       ? AssociationValueType
//       : never;

// export interface YamlData<T extends ItemWithIDTypes, V extends ItemWithIDValueType> {
//   value: MapTypeToValueType<T>;
// }

// export const fromYamlForItemWithID = <T extends ItemWithIDTypes, V extends ItemWithIDValueType>(
//   yamlString: string,
// ): YamlData<T, V> => {
//   return yaml.load(yamlString) as YamlData<T, V>;
// };

export type ItemWithIDTypes =
  | Tag
  | Category
  | Association
  | QueryFragment
  | QueryRequest
  | QueryResponse
  | QueryPair
  | QueryPairCollection
  | AiAssistCancellationTokenSource
  | AiAssistCancellationTokenSourceCollection;

export interface IItemWithID<T extends ItemWithIDTypes, V extends ItemWithIDValueType> {
  readonly value: V;
  readonly ID: Philote;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class ItemWithID<T extends ItemWithIDTypes, V extends ItemWithIDValueType> {
  constructor(
    readonly value: V,
    readonly ID: IPhilote = new Philote(),
  ) {}
  static create<T extends ItemWithIDTypes, V extends ItemWithIDValueType>(value: V): ItemWithID<T, V> {
    return new ItemWithID<T, V>(value);
  }
  @logFunction
  toString(): string {
    return `ItemWithID ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }

  // static convertFrom_json<T extends ItemWithIDTypes, V extends ItemWithIDValueType>(json: string): ItemWithID<T,V> {
  //   const data = JSON.parse(json);
  //   return new ItemWithID<T,V>(data.value as MapTypeToValueType<T>);
  // }

  // static convertFrom_yaml<T extends ItemWithIDTypes, V extends ItemWithIDValueType>(
  //   yamlString: string,
  // ): ItemWithID<T, V> {
  //   const data = fromYamlForItemWithID<T, V>(yamlString);
  //   return new ItemWithID<T, V>(data.value);
  // }
}

export interface ICollection<T extends ItemWithIDTypes, V extends ItemWithIDValueType> {
  readonly value: ItemWithID<T, V>[];
  readonly ID: Philote;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
  findById<T>(criteria: GUID): T | undefined;
}
@logConstructor
export class Collection<T extends ItemWithIDTypes, V extends ItemWithIDValueType> implements ICollection<T, V> {
  constructor(
    readonly value: ItemWithID<T, V>[],
    readonly ID: IPhilote = new Philote(),
  ) {}
  static create<T extends ItemWithIDTypes, V extends ItemWithIDValueType>(value: ItemWithID<T, V>[]): Collection<T, V> {
    return new Collection<T, V>(value);
  }
  @logFunction
  toString(): string {
    return `Collection ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
  // find within this value an instance of type T based on it's Philote's GUID
  findById<T>(criteria: GUID): T | undefined {
    return this.value.find((item) => item.ID.toString() === criteria.toString()) as T;
  }
}

export interface ITag extends IItemWithID<Tag, string> {
  readonly value: string;
  readonly ID: Philote;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class Tag extends ItemWithID<Tag, string> implements ITag {
  constructor(
    readonly value: string,
    readonly ID: IPhilote = new Philote(),
  ) {
    super(value, ID);
  }
  // static create(value: string): Tag {
  //   return new Tag(value);
  // }
  @logFunction
  toString(): string {
    return `Tag ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface ITagCollection extends ICollection<Tag, TagValueType> {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class TagCollection extends Collection<Tag, TagValueType> implements ITagCollection {
  constructor(value: ItemWithID<Tag, TagValueType>[], ID?: Philote) {
    super(value, ID);
  }
  create(value: ItemWithID<Tag, TagValueType>[]): TagCollection {
    return new TagCollection(value);
  }
  @logFunction
  toString(): string {
    return `TagCollection ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface ICategory {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class Category extends ItemWithID<Category, string> implements ICategory {
  constructor(
    value: string,
    readonly ID: IPhilote = new Philote(),
  ) {
    super(value, ID);
  }
  // static create(value: string): Category {
  //   return new Category(value);
  // }
  @logFunction
  toString(): string {
    return `Category ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface ICategoryCollection extends ICollection<Category, CategoryValueType> {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}

@logConstructor
export class CategoryCollection extends Collection<Category, CategoryValueType> implements ICategoryCollection {
  constructor(value: ItemWithID<Category, CategoryValueType>[], ID?: Philote) {
    super(value, ID);
  }
  @logFunction
  toString(): string {
    return `CategoryCollection ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IAiAssistCancellationTokenSource
  extends IItemWithID<AiAssistCancellationTokenSource, AiAssistCancellationTokenSourceValueType> {
  readonly value: AiAssistCancellationTokenSourceValueType;
  readonly ID: Philote;
  toString(): string;
}
@logConstructor
export class AiAssistCancellationTokenSource
  extends ItemWithID<AiAssistCancellationTokenSource, AiAssistCancellationTokenSourceValueType>
  implements IAiAssistCancellationTokenSource
{
  constructor(
    readonly value: AiAssistCancellationTokenSourceValueType,
    readonly ID: IPhilote = new Philote(),
  ) {
    super(value, ID);
  }
  // static create(value: AiAssistCancellationTokenSourceValueType): Tag {
  //   return new AiAssistCancellationTokenSource(value);
  // }
  @logFunction
  toString(): string {
    return `AiAssistCancellationTokenSource ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IAiAssistCancellationTokenSourceCollection
  extends ICollection<AiAssistCancellationTokenSource, AiAssistCancellationTokenSourceValueType> {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class AiAssistCancellationTokenSourceCollection
  extends Collection<AiAssistCancellationTokenSource, AiAssistCancellationTokenSourceValueType>
  implements IAiAssistCancellationTokenSourceCollection
{
  constructor(
    value: ItemWithID<AiAssistCancellationTokenSource, AiAssistCancellationTokenSourceValueType>[],
    ID?: Philote,
  ) {
    super(value, ID);
  }
  create(
    value: ItemWithID<AiAssistCancellationTokenSource, AiAssistCancellationTokenSourceValueType>[],
  ): AiAssistCancellationTokenSourceCollection {
    return new AiAssistCancellationTokenSourceCollection(value);
  }
  @logFunction
  toString(): string {
    return `AiAssistCancellationTokenSourceCollection ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IAssociation {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class Association extends ItemWithID<Association, IAssociationValueType> implements IAssociation {
  constructor(value: IAssociationValueType, ID?: IPhilote) {
    super(value, ID);
  }
  // static create(value: IAssociationValueType): Association {
  //   return new Association(value);
  // }
  @logFunction
  toString(): string {
    return `Association ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IAssociationCollection extends ICollection<Association, AssociationValueType> {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}

@logConstructor
export class AssociationCollection
  extends Collection<Association, AssociationValueType>
  implements IAssociationCollection
{
  constructor(value: ItemWithID<Association, AssociationValueType>[], ID?: Philote) {
    super(value, ID);
  }
  @logFunction
  toString(): string {
    return `AssociationCollection ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryFragment extends IItemWithID<QueryFragment, QueryFragmentValueType> {
  readonly value: QueryFragmentValueType;
  readonly ID: Philote;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class QueryFragment extends ItemWithID<QueryFragment, QueryFragmentValueType> implements IQueryFragment {
  constructor(
    readonly value: QueryFragmentValueType,
    readonly ID: IPhilote = new Philote(),
  ) {
    super(value, ID);
  }
  // static create(value: QueryFragmentValueType): QueryFragment {
  //   return new QueryFragment(value);
  // }
  @logFunction
  toString(): string {
    return `QueryFragment ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryFragmentCollection extends ICollection<QueryFragment, QueryFragmentValueType> {
  findByID<QueryFragment>(criteria: GUID): QueryFragment;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}

@logConstructor
export class QueryFragmentCollection
  extends Collection<QueryFragment, QueryFragmentValueType>
  implements IQueryFragmentCollection
{
  constructor(value: ItemWithID<QueryFragment, QueryFragmentValueType>[], ID?: Philote) {
    super(value, ID);
  }

  @logFunction
  findByID<QueryFragment>(criteria: GUID): QueryFragment {
    return super.findById<QueryFragment>(criteria) as QueryFragment;
  }

  @logFunction
  toString(): string {
    return `QueryFragmentCollection ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryRequest extends IItemWithID<QueryRequest, string> {
  readonly value: string;
  readonly ID: Philote;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class QueryRequest extends ItemWithID<QueryRequest, string> implements IQueryRequest {
  constructor(
    readonly value: string,
    readonly ID: IPhilote = new Philote(),
  ) {
    super(value, ID);
  }
  // static create(value: string): QueryRequest {
  //   return new QueryRequest(value);
  // }
  @logFunction
  toString(): string {
    return `QueryRequest ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryResponse extends IItemWithID<QueryResponse, string> {
  readonly value: string;
  readonly ID: Philote;
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class QueryResponse extends ItemWithID<QueryResponse, string> implements IQueryResponse {
  constructor(
    readonly value: string,
    readonly ID: IPhilote = new Philote(),
  ) {
    super(value, ID);
  }
  // static create(value: string): QueryResponse {
  //   return new QueryResponse(value);
  // }
  @logFunction
  toString(): string {
    return `QueryResponse ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryPair {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}
@logConstructor
export class QueryPair extends ItemWithID<QueryPair, IQueryPairValueType> implements IQueryPair {
  constructor(value: IQueryPairValueType, ID?: IPhilote) {
    super(value, ID);
  }
  // static create(value: IQueryPairValueType): QueryPair {
  //   return new QueryPair(value);
  // }
  @logFunction
  toString(): string {
    return `QueryPair ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IQueryPairCollection extends ICollection<QueryPair, QueryPairValueType> {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}

@logConstructor
export class QueryPairCollection extends Collection<QueryPair, QueryPairValueType> implements IQueryPairCollection {
  constructor(value: ItemWithID<QueryPair, QueryPairValueType>[], ID?: Philote) {
    super(value, ID);
  }
  @logFunction
  toString(): string {
    return `QueryPairCollection ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}

export interface IConversationCollection extends ICollection<QueryPairCollection, QueryPairCollectionValueType> {
  toString(): string;
  convertTo_json(): string;
  convertTo_yaml(): string;
}

@logConstructor
export class ConversationCollection
  extends Collection<QueryPairCollection, QueryPairCollectionValueType>
  implements IConversationCollection
{
  constructor(value: ItemWithID<QueryPairCollection, QueryPairCollectionValueType>[], ID?: Philote) {
    super(value, ID);
  }
  @logFunction
  toString(): string {
    return `ConversationCollection ID:${this.ID.toString()}; value:${this.value.toString()}`;
  }
  @logFunction
  convertTo_json(): string {
    return toJson(this);
  }
  @logFunction
  convertTo_yaml(): string {
    return toYaml(this);
  }
}
