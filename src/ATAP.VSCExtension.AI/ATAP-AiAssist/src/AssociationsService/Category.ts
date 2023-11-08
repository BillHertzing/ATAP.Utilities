import { GUID, Int, IDType, } from '@IDTypes/IDTypes';

import { IItem, Item, IItemCollection, ItemCollection } from './itemGeneric';

// Since Category<T> has no additional members over Item<T>, the ICategory<T> interface
// is effectively the same as IItem<T> but can be used to provide more specific typing
// where a Category rather than any Item is required.

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
