

import { GUID, Int, IDType, } from '@IDTypes/IDTypes';

import { Philote, IPhilote } from '@Philote/Philote';

import { IItem, Item, IItemCollection, ItemCollection } from './itemGeneric';

import { ICategory, Category, ICategoryCollection,CategoryCollection } from './Category';

import { ITag, Tag, ITagCollection,TagCollection } from './Tag';

export interface IPredicate<T extends IDType> extends IItem<T> {
  readonly TagCollection: TagCollection<T>;
  readonly CategoryCollection: CategoryCollection<T>;
}

export class Predicate<T extends IDType> extends Item<T> implements IPredicate<T> {
  public readonly TagCollection: TagCollection<T>;
  public readonly CategoryCollection: CategoryCollection<T>;

  constructor(
    name: string,
    ID: Philote<T>,
    TagCollection: TagCollection<T>,
    CategoryCollection: CategoryCollection<T>,
  ) {
    super(name, ID); // Call to the super class constructor
    this.TagCollection = TagCollection;
    this.CategoryCollection = CategoryCollection;
  }
}


export interface IPredicateCollection<T extends IDType> extends IItemCollection<T> {
  // No new members; simply a more specific type of IItem<T> with Predicate semantics.
}

export class PredicateCollection<T extends IDType> extends ItemCollection<T> {
  // No new members added, but the type is distinct from Item
}
