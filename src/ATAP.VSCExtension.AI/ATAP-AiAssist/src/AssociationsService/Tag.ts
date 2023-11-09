import { GUID, Int, IDType } from '@IDTypes/index';
import { Philote, IPhilote } from '@Philote/index';
import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  toJson,
  fromJson,
  toYaml,
  fromYaml,
} from '@Serializers/index';
import {
  ItemWithID,
  IItemWithID,
  ItemWithIDsService,
  IItemWithIDsService,
  ItemWithIDCollection,
  IItemWithIDCollection,
} from '@ItemWithIDsService/index';

export type TagValueType = string;

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

  static convertFrom_json(json: string): Tag {
    return fromJson<Tag>(json);
  }

  static convertFrom_yaml(yaml: string): Tag {
    return fromYaml<Tag>(yaml);
  }

  ToString(): string {
    return `value: ${this.ID} ID: ${this.ID}`;
  }
}

export interface ITagCollection extends IItemWithIDCollection {
  // No new members; simply a more specific type of IItemWithID with Tag semantics.
}

export class TagCollection extends ItemWithIDCollection {
  constructor(ID?: Philote, tags?: ITag[]) {
    const _ID = ID !== undefined ? ID : new Philote();
    const _tags = tags !== undefined ? tags : [];
    super(ID, tags);
  }

  static convertFrom_json(json: string): TagCollection {
    return fromJson<TagCollection>(json);
  }

  static convertFrom_yaml(yaml: string): TagCollection {
    return fromYaml<TagCollection>(yaml);
  }
}

export interface ITagsService extends IItemWithIDsService {
  createTag(value: TagValueType, ID?: Philote): Tag;
  dispose(): void;
}

// TagsService is a factory for Tag instances
export class TagsService extends ItemWithIDsService implements ITagsService {
  private TagWithIDs: Tag[] = [];

  public createTag(value: TagValueType, ID?: Philote): Tag {
    const tag = new Tag(value, ID);
    this.TagWithIDs.push(tag);
    return tag;
  }
  static convertFrom_json(json: string): TagsService {
    return fromJson<TagsService>(json);
  }

  static convertFrom_yaml(yaml: string): TagsService {
    return fromYaml<TagsService>(yaml);
  }

  dispose(): void {
    this.TagWithIDs.forEach((TagWithID) => {
      TagWithID.dispose();
    });
    this.TagWithIDs = [];
  }
}
