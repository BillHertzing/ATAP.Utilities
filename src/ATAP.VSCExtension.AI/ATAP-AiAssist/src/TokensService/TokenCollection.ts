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
    ItemWithIDValueType,
    ItemWithID,
    IItemWithID,
    ItemWithIDCollection,
    IItemWithIDCollection,
    ItemWithIDsService,
    IItemWithIDsService,
} from '@ItemWithIDsService/index';


import { TokenValueType, Token, IToken } from './Token';

  export interface ITokenCollection extends IItemWithIDCollection {
    // No new members; simply a more specific type of IItemWithID with Token semantics.
}


  export class TokenCollection extends ItemWithIDCollection {
    constructor(ID?: Philote, Tokens?: IToken[]) {
      const _ID = ID !== undefined ? ID : new Philote();
      const _Tokens = Tokens !== undefined ? Tokens : [];
      super(ID, Tokens);
    }

    static convertFrom_json(json: string): TokenCollection {
      return fromJson<TokenCollection>(json);
    }

    static convertFrom_yaml(yaml: string): TokenCollection {
      return fromYaml<TokenCollection>(yaml);
    }
}
