import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import { GUID, Int, IDType, } from '@IDTypes/IDTypes';
import { Philote, IPhilote } from '@Philote/Philote';

export type ItemWithIDValueType<T extends IDType> = ITag<T> | ICategory<T>;  //| IPredicate<T>;
export type TagValueType = string;
export type CategoryValueType = string;
export type ItemValueType = TagValueType | CategoryValueType;


// Define an  interface for items
 interface IItemWithID<T extends IDType> {
   ID: Philote<T>;
   value: ItemValueType;
   dispose(): void;
}

// base item implementation
 class ItemWithID<T extends IDType> implements IItemWithID<T> {
  constructor(public ID: Philote<T>, public value: ItemValueType) {
    }
    dispose(): void {
      // placeholder:Implement disposal logic for ItemWithID if necessary
      // ToDo: How to get a logger without having to pass it in every function call?
      //console.log(`Tag (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }
}

// Define an interface for tag that extends IItemWithID
interface ITag<T extends IDType> extends IItemWithID<T> {
}

// Define an interface for category that extends IItemWithID
interface ICategory<T extends IDType> extends IItemWithID<T> {
}

// Concrete Tag class extending ItemWithID
class Tag<T extends IDType> extends ItemWithID<T> implements ITag<T> {
  constructor(ID: Philote<T>, value: TagValueType) {
    super(ID, value);
  }

  dispose(): void {
    // Call dispose for base ItemWithID
    super.dispose();
    // ToDo: How to get a logger without having to pass it in every function call?
    //console.log(`Tag (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }

  // placedholder
  placeholder (): void {
    //console.log(`Placeholder method called for Tag (ID: ${this.ID.id}, Value: ${this.value})`);
  }
}

// Concrete Category class extending ItemWithID
class Category<T extends IDType> extends ItemWithID<T> implements ITag<T> {
  constructor(ID: Philote<T>, value:CategoryValueType) {
    super(ID, value);
  }

  dispose(): void {
    // Call dispose for base ItemWithID
    super.dispose();
    // ToDo: How to get a logger without having to pass it in every function call?
    //console.log(`Tag (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }

  // placedholder
  placeholder (): void {
    //console.log(`Placeholder method called for Category (ID: ${this.ID.id}, Value: ${this.value})`);
  }
}

export interface IItemService<T extends IDType> {

}

 // Item Service to keep track of created instances of the base item
 class ItemService<T extends IDType> {
  // private items: IItemWithID<IDType>[] = [];

  // createItem(ID: Philote<IDType>, value: ItemWithIDValueType<T>): IItemWithID<IDType> {
  //   const item = this.createTag(ID, value);
  //   this.items.push(item);
  //   return item;
  // }

  // disposeAllItems(): void {
  //   this.items.forEach((item) => {
  //     item.dispose();
  //   });
  //   this.items = [];
  // }

 }


// TagyService is a factory for TAag instances
class TagService<T extends IDType> extends ItemService<T> implements IItemService<T> {
  private items: Tag<IDType>[] = [];

  public createTag(ID: Philote<IDType>, value: TagValueType): Tag<IDType> {
    const tag = new Tag(ID, value);
    return new Tag(ID, value);
  }

  disposeAllTags(): void {
    this.items.forEach((item) => {
      item.dispose();
    });
    this.items = [];
  }

}

// CategoryService is a factory for Category instances
class CategoryService<T extends IDType> extends ItemService<IDType> {
  public createCategory(ID: Philote<IDType>, value: CategoryValueType): Category<IDType> {
    return new Tag(ID, value);
  }
}

// Examples
const tagService = new TagService<GUID>();
const tag001 = tagService.createTag(new Philote<GUID>("GUID"), "Tag001");
tagService.disposeAllTags();

