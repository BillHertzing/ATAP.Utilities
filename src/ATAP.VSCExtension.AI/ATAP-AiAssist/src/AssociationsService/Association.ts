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
import {
  TagValueType,
  Tag,
  ITag,
  TagCollection,
  ITagCollection,
  TagsService,
  ITagsService,
} from '@AssociationsService/index';
import {
  CategoryValueType,
  Category,
  ICategory,
  CategoryCollection,
  ICategoryCollection,
  CategorysService,
  ICategorysService,
} from '@AssociationsService/index';

export type AssociationValueType = {
  tagCollection: ITagCollection;
  categoryCollection: ICategoryCollection;
};

// Define an interface for association that extends IItemWithID
export interface IAssociation extends IItemWithID {

}

// Association class extending ItemWithID
export class Association extends ItemWithID implements IAssociation {
  constructor(value: AssociationValueType, ID?: Philote) {
    super(value, ID);
  }

  static convertFrom_json(json: string): Association {
    return fromJson<Association>(json);
  }

  static convertFrom_yaml(yaml: string): Association {
    return fromYaml<Association>(yaml);
  }

  dispose(): void {
    // Call dispose for base ItemWithID
    super.dispose();
    // ToDo: How to get a logger without having to pass it in every function call?
    //console.log(`Association (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }
}

export interface IAssociationCollection extends IItemWithIDCollection {
  // No new members; simply a more specific type of IItemWithID with Association semantics.
}

export class AssociationCollection extends ItemWithIDCollection {
  constructor(ID?: Philote, associations?: IAssociation[]) {
    const _ID = ID !== undefined ? ID : new Philote();
    const _associations = associations !== undefined ? associations : [];
    super(ID, associations);
  }

  static convertFrom_json(json: string): AssociationCollection {
    return fromJson<AssociationCollection>(json);
  }

  static convertFrom_yaml(yaml: string): AssociationCollection {
    return fromYaml<AssociationCollection>(yaml);
  }
}

export interface IAssociationsService extends IItemWithIDsService {
  createAssociation(value: AssociationValueType, ID?: Philote): Association;
  dispose(): void;
}

// AssociationService is a factory for Association instances
export class AssociationsService extends ItemWithIDsService implements IAssociationsService {
  private associationWithIDs: Association[] = [];

  public createAssociation(value: AssociationValueType, ID?: Philote): Association {
    const association = new Association(value, ID);
    this.associationWithIDs.push(association);
    return association;
  }
  static convertFrom_json(json: string): AssociationsService {
    return fromJson<AssociationsService>(json);
  }

  static convertFrom_yaml(yaml: string): AssociationsService {
    return fromYaml<AssociationsService>(yaml);
  }


  dispose(): void {
    this.associationWithIDs.forEach((associationWithID) => {
      associationWithID.dispose();
    });
    this.associationWithIDs = [];
  }
}