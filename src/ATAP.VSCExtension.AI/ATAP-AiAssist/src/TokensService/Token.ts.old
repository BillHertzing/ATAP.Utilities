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

export type TokenValueType = string;

export interface IToken extends IItemWithID {}

// Token class extending ItemWithID
export class Token extends ItemWithID implements IToken {

  constructor(value: TokenValueType, ID?: Philote) {
    super(value, ID);
  }

    static CreateToken(
        logger: ILogger,
        extensionContext: vscode.ExtensionContext,
        callingModule: string,
        initializationStructure?: ISerializationStructure,
    ): Token {
        let _obj: Token | null;
        if (initializationStructure) {
          try {
            // ToDo: deserialize based on contents of structure
            _obj = Token.convertFrom_yaml(initializationStructure.value);
          } catch (e) {
            if (e instanceof Error) {
              throw new DetailedError(
                `${callingModule}: create Token from initializationStructure using convertFrom_xxx -> }`,
                e,
              );
            } else {
              // ToDo:  investigation to determine what else might happen
              throw new Error(
                `${callingModule}: create Token from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
              );
            }
          }
          if (_obj === null) {
            throw new Error(
              `${callingModule}: create Token from initializationStructureusing convertFrom_xxx produced a null`,
            );
          }
          return _obj;
        } else {
          try {
            _obj = new Token('aStaticToken');
          } catch (e) {
            if (e instanceof Error) {
              throw new DetailedError(
                `${callingModule}: create new Token error }`,
                e,
              );
            } else {
              // ToDo:  investigation to determine what else might happen
              throw new Error(
                `${callingModule}: new Token threw something that was not polymorphus on error`,
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
    //console.log(`Token (ID: ${this.ID.id}, Value: ${this.value}) is disposed.`);
  }

  static convertFrom_json(json: string): Token {
    return fromJson<Token>(json);
  }

  static convertFrom_yaml(yaml: string): Token {
    return fromYaml<Token>(yaml);
  }

  ToString(): string {
    return `value: ${this.ID} ID: ${this.ID}`;
  }
}

export function isToken(obj: any): obj is IToken {
    return obj && typeof obj === 'object' && 'value' in obj;
  }
