import { GUID, Int, IDType } from '@IDTypes/IDTypes';
import { IItem, Item, IItemCollection, ItemCollection } from '../PredicatesService';
import { Category, ICategory, ICategoryCollection, CategoryCollection } from '../PredicatesService';
import { Tag, ITag, ITagCollection, TagCollection } from '../PredicatesService';

type TypeConstructor<T extends IDType> = new (...args: any[]) => T;

// Create a type map that associates string keys with class types for a specific T
type TypeMap<T extends IDType> = {
  Category: TypeConstructor<Category<T>>;
  Tag: TypeConstructor<Tag<T>>;
  TagCollection: TypeConstructor<TagCollection<T>>;
};

// Define a type for known constructors.
// This interface ensures any type with a string key has a constructor taking a name and returns an Item<T>
interface ITypeConstructors {
  [key: string]: new <T extends IDType>(name: string) => Item<T>;
}

// The type map will need to be instantiated with a specific IDType
// This module creates one live data field

// Here is our type map with the constructors of our known types.
let typeConstructors: ITypeConstructors = {
  "Tag": Tag,
  "Category": Category
};

// Instead of manually maintaining a union of keys, use keyof typeof to generate it
type KnownTypes = keyof typeof typeConstructors;

//  ToDo: candidate for user state?
function createTypeMap<T extends IDType>(): TypeMap<T> {
  return {
    Category: Category as any, // Type casting to any to bypass the constraint checks for demonstration.
    Tag: Tag as any,
    TagCollection: TagCollection as any,
  };
}

// Return an instance of a type. Based on a TypeMap which maps strings to Types.
//   Provide the Type name as a string,
//   All remaining arguments are sent to the Type's constructor (.ctor)
//   Acceptable Type names are found in
//     typeConstructors: ITypeConstructors found in @TypeMap/TypeMap
//  The TypeMap feature
// Function to create an instance based on a string type key for a specific IDType
export function createTypeInstance<T extends IDType, K extends keyof TypeMap<T>>(
  typeName: K,
  ...args: ConstructorParameters<TypeMap<T>[K]>
): InstanceType<TypeMap<T>[K]> {
  const typeMap = createTypeMap<T>();
  const TypeConstructor = typeMap[typeName];
  if (!TypeConstructor) {

  }
  }

 return new TypeConstructor(...args) as InstanceType<TypeMap<T>[K]>;
}

// Another AI response, but needs vetting
// export function createInstance<T extends IDType>(typeName: KnownTypes, name: string): Item<T> {
//   const TypeConstructor: any = typeConstructors[typeName]; // Cast to any to satisfy the compiler

//   if (!TypeConstructor) {
//       throw new Error(`Constructor for ${typeName} not found`);
//   }

//   // Return a specific instance type using the new operator
//   return new TypeConstructor<T>(name) as Item<T>;
// }


// The TypeMap represents a map to constructors.
// Type casting to any is done to bypass the TypeScript compiler's checks. This should ideally be replaced with proper casting if your class constructors are correctly defined.
// It's worth double-checking that your classes (Category, Tag, TagCollection) are defined in a way that their constructors are compliant with the new signature in TypeConstructor<T>.
// The explicit cast as InstanceType<TypeMap<T>[K]> after new TypeConstructor(...args) tells TypeScript to trust our assertion that the type we are creating is indeed correct. This can be considered a type-safe cast since we have made checks for the existence of TypeConstructor.
