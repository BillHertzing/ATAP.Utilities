import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { GUID, Int, IDType } from '@IDTypes/index';
import { Philote, IPhilote } from '@Philote/index';
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

import { IExternalDataVetting, ExternalDataVetting } from './ExternalDataVetting';

export interface ISecurityService {
  readonly externalDataVetting: IExternalDataVetting;

  //version: string;
}
@logConstructor
export class SecurityService implements ISecurityService {
  readonly _externalDataVetting: IExternalDataVetting;
  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
  ) {
    this._externalDataVetting = new ExternalDataVetting(logger);
  }

  static create(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): SecurityService {
    Logger.staticLog(`SecurityService.create called`, LogLevel.Debug);

    let _obj: SecurityService | null;
    if (initializationStructure) {
      try {
        // ToDo: deserialize based on contents of structure
        _obj = SecurityService.convertFrom_yaml(initializationStructure.value);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create SecurityService from DefaultConfiguration.Development["SecurityServiceAsSerializationStructure"] using convertFrom_xxx -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create SecurityService from DefaultConfiguration.Development["SecurityServiceAsSerializationStructure"] using convertFrom_xxx threw something other than a polymorphous Error`,
          );
        }
      }
      if (_obj === null) {
        throw new Error(
          `${callingModule}: create SecurityService from DefaultConfiguration.Development["SecurityServiceAsSerializationStructure"] using convertFrom_xxx produced a null`,
        );
      }
      return _obj;
    } else {
      try {
        _obj = new SecurityService(logger, extensionContext);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(`${callingModule}: create new SecurityService error }`, e);
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `CreateSecurityServicecaught an unknown object from SecurityService.ctor, and the instance of (e) returned is of type ${typeof e}`,
          );
        }
      }
      return _obj;
    }
  }

  get externalDataVetting(): IExternalDataVetting {
    return this._externalDataVetting;
  }

  static convertFrom_json(json: string): SecurityService {
    return fromJson<SecurityService>(json);
  }
  static convertFrom_yaml(yaml: string): SecurityService {
    return fromYaml<SecurityService>(yaml);
  }
}
