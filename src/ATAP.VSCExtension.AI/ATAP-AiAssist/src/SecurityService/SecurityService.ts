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

import { ExternalDataVetting } from './ExternalDataVetting';

export interface ISecurityService {
  //version: string;
}
@logConstructor
export class SecurityService implements ISecurityService {
  private message: string;
  private externalDataVetting: ExternalDataVetting;

  constructor(private logger: ILogger, private extensionContext: vscode.ExtensionContext) {
    this.message = 'starting SecurityService constructor';
    this.logger.log(this.message, LogLevel.Debug);

    this.externalDataVetting = new ExternalDataVetting(this.logger);

    this.message = 'leaving SecurityService constructor';
    this.logger.log(this.message, LogLevel.Debug);
  }
  @logFunction
  static CreateSecurityService(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): SecurityService {
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
          throw new Error(`${callingModule}: new SecurityService threw something that was not polymorphus on error`);
        }
      }
      return _obj;
    }
  }
  @logFunction
  static convertFrom_json(json: string): SecurityService {
    return fromJson<SecurityService>(json);
  }
  @logFunction
  static convertFrom_yaml(yaml: string): SecurityService {
    return fromYaml<SecurityService>(yaml);
  }
}
