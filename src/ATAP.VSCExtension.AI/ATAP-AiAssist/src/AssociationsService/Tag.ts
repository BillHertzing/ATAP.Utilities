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

export type TagValueType = string;

// Define an interface for tag that extends IItemWithID
export interface ITag extends IItemWithID {}

// Tag class extending ItemWithID
export class Tag extends ItemWithID implements ITag {
  constructor(value: TagValueType, ID?: Philote) {
    super(value, ID);
  }

  dispose(): void {
    // Call dispose for base ItemWithID
    super.dispose();
    // ToDo: How to get a logger without having to pass it in every function call?
    //console.log(`Tag (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }

  // placedholder
  placeholder(): void {
    //console.log(`Placeholder method called for Tag (ID: ${this.ID.id}, Value: ${this.value})`);
  }
}

export interface ITagCollection extends IItemWithIDCollection {
  // No new members; simply a more specific type of IItemWithID with Tag semantics.
}

export class TagCollection extends ItemWithIDCollection {
}

export interface ITagsService extends IItemWithIDsService {
  createTag(value: TagValueType, ID?: Philote): Tag;
  dispose(): void
}

// TagService is a factory for Tag instances
export class TagsService extends ItemWithIDsService implements ITagsService {
  private TagWithIDs: Tag[] = [];

  public createTag(value: TagValueType, ID?: Philote): Tag {
    const tag = new Tag(value, ID);
    this.TagWithIDs.push(tag);
    return tag;
  }

  dispose(): void {
    this.TagWithIDs.forEach((TagWithID) => {
      TagWithID.dispose();
    });
    this.TagWithIDs = [];
  }
}
