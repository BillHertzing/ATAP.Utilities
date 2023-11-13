
import * as vscode from 'vscode';
import { GUID, Int, IDType } from '@IDTypes/index';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor, logExecutionTime } from '@Decorators/index';
import { Philote, IPhilote } from '@Philote/index';
import { DefaultConfiguration } from '../DefaultConfiguration';
import {
  SupportedSerializersEnum,
  SerializationStructure,
  ISerializationStructure,
  isSerializationStructure,
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
  static CreateTag(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
): Tag {
    let _obj: Tag | null;
    if (initializationStructure) {
      try {
        // ToDo: deserialize based on contents of structure
        _obj = Tag.convertFrom_yaml(initializationStructure.value);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create Tag from initializationStructure using convertFrom_xxx -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create Tag from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
          );
        }
      }
      if (_obj === null) {
        throw new Error(
          `${callingModule}: create Tag from initializationStructureusing convertFrom_xxx produced a null`,
        );
      }
      return _obj;
    } else {
      try {
        _obj = new Tag('aStaticTag');
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create new Tag error }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: new Tag threw something that was not polymorphus on error`,
          );
        }
      }
      return _obj;
    }

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
