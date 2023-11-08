import { GUID, Int, IDType, } from '@IDTypes/IDTypes';

import { IItem, Item, IItemCollection, ItemCollection } from './itemGeneric';

// Since Tag<T> has no additional members over Item<T>, the ITag<T> interface
// is effectively the same as IItem<T> but can be used to provide more specific typing
// where a Tag rather than any Item is required.

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
