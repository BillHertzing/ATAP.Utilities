import { GUID, Int, IDType, } from '@IDTypes/IDTypes';
import { Category, ICategory, ICategoryCollection,CategoryCollection } from '@PredicatesService/PredicatesService';
import { Tag, ITag, ITagCollection,TagCollection } from '@PredicatesService/PredicatesService';



type TypeConstructor<T extends IDType> = new (...args: any[]) => T;

// Create a type map that associates string keys with class types for a specific T
type TypeMap<T extends IDType> = {
  'Category': TypeConstructor<Category<T>>,
  'Tag': TypeConstructor<Tag<T>>,
  'TagCollection': TypeConstructor<TagCollection<T>>,
};

// The type map will need to be instantiated with a specific IDType
function createTypeMap<T extends IDType>(): TypeMap<T> {
  return {
    'Category': Category as TypeConstructor<Category<T>>,
    'Tag': Tag as TypeConstructor<Tag<T>>,
    'TagCollection': TagCollection as TypeConstructor<TagCollection<T>>,
  };
}

// Function to create an instance based on a string type key for a specific IDType
function createTypeInstance<T extends IDType, K extends keyof TypeMap<T>>(typeName: K, ...args: ConstructorParameters<TypeMap<T>[K]>): InstanceType<TypeMap<T>[K]> {
  const typeMap = createTypeMap<T>();
  const TypeConstructor = typeMap[typeName];
  return new TypeConstructor(...args);
}

