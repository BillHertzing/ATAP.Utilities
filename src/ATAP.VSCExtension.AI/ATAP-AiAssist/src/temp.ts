export type GUID = string;
export type Int = number;
export type IDType = GUID | Int;

export interface IItem<T extends IDType> {
  readonly name: string;
}

export class Item<T extends IDType> implements IItem<T>{
  public readonly name: string;
  constructor(name: string) {
    this.name = name;
  }

}
export interface IItemCollection<T extends IDType> {
  readonly items: IItem<T>[];
}

export class ItemCollection<T extends IDType> implements IItemCollection<T> {
  public readonly items: Item<T>[];
  constructor( items?: Item<T>[]) {
    // Accepts Philote as the collection ID
    this.items = items || [];
  }
}

export interface ITag<T extends IDType> extends IItem<T> {
  // No new members; simply a more specific type of IItem<T> with Tag semantics.
}
export class Tag<T extends IDType> extends Item<T> {
  // No new members added, but the type is distinct from Item
}

export interface ITagCollection<T extends IDType> extends IItemCollection<T> {
  // No new members; simply a more specific type of IItem<T> with Tag semantics.
}

export class TagCollection<T extends IDType> extends ItemCollection<T> {
  // No new members added, but the type is distinct from Item
}

export interface ICategory<T extends IDType> extends IItem<T> {
  // No new members; simply a more specific type of IItem<T> with Category semantics.
}

export class Category<T extends IDType> extends Item<T> {
  // No new members added, but the type is distinct from Item
}

export interface ICategoryCollection<T extends IDType> extends IItemCollection<T> {
  // No new members; simply a more specific type of IItem<T> with Category semantics.
}

export class CategoryCollection<T extends IDType> extends ItemCollection<T> {
  // No new members added, but the type is distinct from Item
}

export interface IPredicate<T extends IDType> extends IItem<T> {
  readonly TagCollection: TagCollection<T>;
  readonly CategoryCollection: CategoryCollection<T>;
}

export class Predicate<T extends IDType> extends Item<T> implements IPredicate<T> {
  public readonly TagCollection: TagCollection<T>;
  public readonly CategoryCollection: CategoryCollection<T>;

  constructor(
    name: string,
    TagCollection: TagCollection<T>,
    CategoryCollection: CategoryCollection<T>,
  ) {
    super(name); // Call to the super class constructor
    this.TagCollection = TagCollection;
    this.CategoryCollection = CategoryCollection;
  }
}

export interface IPredicateCollection<T extends IDType> extends IItemCollection<T> {
  // No new members; simply a more specific type of IItem<T> with Predicate semantics.
}

export class PredicateCollection<T extends IDType> extends ItemCollection<T> {
  // No new members added, but the type is distinct from ItemCollection
}


interface ITypeConstructors<T extends IDType> {
  [key: string]: new <T extends IDType>(name: string) => Item<T>;
}


interface ITypeCollectionConstructors<T extends IDType>  {
  [key: string]: new <T extends IDType>(items: Item<T>[]) => ItemCollection<T>;
}

// Define the TypeMap with all the possible derivatives
type TypeMap<T extends IDType> = {
  [key: string]: ITypeConstructors<T> | ITypeCollectionConstructors<T>;
};


// Here is our type map with the constructors of our known types.
const typeMap: TypeMap<T> = {
  "Tag": Tag,
  "TagCollection": TagCollection,
  "Category": Category,
  "CategoryCollection": CategoryCollection,
  "Predicate": Predicate,
  "PredicateCollection": PredicateCollection
};

// A function to create a type instance based on the string identifier
export function createInstance<T extends IDType>(typeName: string, name: string): Item<T> {
  const TypeConstructor = typeMap[typeName];

  if (!TypeConstructor) {
    throw new Error(`Constructor for ${typeName} not found`);
  }

  return new TypeConstructor<T>(...args);
}