import { GUID, Int, IDType } from '@IDTypes/index';
import { Philote, IPhilote } from '@Philote/index';
import {
  TagValueType,
  CategoryValueType,
  IAssociationValueType,
  AssociationValueType,
  QueryRequestValueType,
  QueryResponseValueType,
  IQueryPairValueType,
  QueryPairValueType,
  ItemWithIDValueType,
  ItemWithIDTypes,
  //  MapTypeToValueType,
  //  YamlData,
  //  fromYamlForItemWithID,
  IItemWithID,
  ItemWithID,
  ICollection,
  Collection,
  ITag,
  Tag,
  ITagCollection,
  TagCollection,
  ICategory,
  Category,
  ICategoryCollection,
  CategoryCollection,
  IAssociation,
  Association,
  IAssociationCollection,
  AssociationCollection,
  IQueryRequest,
  QueryRequest,
  IQueryResponse,
  QueryResponse,
  IQueryPair,
  QueryPair,
  IQueryPairCollection,
  QueryPairCollection,
  //IConversationCollection,
  //ConversationCollection,
} from '@ItemWithIDs/index';

// Define a type for known singular type constructors.
// This interface ensures any type with a string key has a constructor taking a value and an ID and returns an ItemWithID
// interface ITypeSingularConstructors {
//   [key: string]: new (value: string, ID: Philote) => ItemWithID;
// }

// Here is our type map with the constructors of our known singular types.
// let typeSingularConstructorsGUID: ITypeSingularConstructors = {
//   Tag: Tag,
//   Category: Category,
// };

// Define a type for known collection type constructors.
// This interface ensures any type with a string key has a constructor taking a name and an ID and returns an ItemWithIDCollection
// interface ITypeCollectionConstructors {
//   [key: string]: new (ID: Philote, items: ItemWithID[]) => ItemWithIDCollection;
// }

// Here is our type map with the constructors of our known Collection types.
// let typeCollectionConstructorsGUID: ITypeCollectionConstructors = {
//   TagCollection: TagCollection,
//   CategoryCollection: CategoryCollection,
// };

// Define the TypeMap with all the possible derivatives
// interface ITypeMap {
//   [key: string]: ITypeSingularConstructors | ITypeCollectionConstructors;
// }

// Create a type map instance that associates string keys with class types for a specific T
// let typeMapGUID: ITypeMap = {
//   Category: ITypeSingularConstructors<Category>,
//   Tag: ITypeSingularConstructors<Tag>,
//   TagCollection: ITypeCollectionConstructors<TagCollection>,
//   CategoryCollection: ITypeCollectionConstructors<CategoryCollection>,
// };

// The type map will need to be instantiated with a specific IDType
// This module creates one live data field

// Instead of manually maintaining a union of keys, use keyof typeof to generate it
// type KnownTypes = keyof typeof typeMapGUID;

// //  ToDo: candidate for user state?
// function createTypeMap(): TypeMap {
//   return {
//     Category: Category as any, // Type casting to any to bypass the constraint checks for demonstration.
//     Tag: Tag as any,
//     TagCollection: TagCollection as any,
//   };
// }

// Return an instance of a type. Based on a TypeMap which maps strings to Types.
//   Provide the Type name as a string,
//   All remaining arguments are sent to the Type's constructor (.ctor)
//   Acceptable Type names are found in
//     typeConstructors: ITypeConstructors found in @TypeMap/index
//  The TypeMap feature
// Function to create an instance based on a string type key for a specific IDType
// export function createTypeInstance<T extends IDType, K extends keyof ITypeMap>(
//   typeName: K,
//   ...args: ConstructorParameters<ITypeMap[K]>
// ): InstanceType<ITypeMap[K]> {
//   const typeMap = createTypeMap();
//   const TypeConstructor = typeMap[typeName];
//   if (!TypeConstructor) {
//   } else {
//     return new TypeConstructor(...args) as InstanceType<TypeMap[K]>;
//   }
// }

// Another AI response, but needs vetting
// export function createInstance(typeName: KnownTypes, name: string): ItemWithID {
//   const TypeConstructor: any = typeConstructors[typeName]; // Cast to any to satisfy the compiler

//   if (!TypeConstructor) {
//       throw new Error(`Constructor for ${typeName} not found`);
//   }

//   // Return a specific instance type using the new operator
//   return new TypeConstructor(name) as ItemWithID;
// }
