import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import * as vscode from 'vscode';

import { DefaultConfiguration } from '../DefaultConfiguration';
import { GlobalStateCache } from './GlobalStateCache';
import { GUID, Int, IDType } from '@IDTypes/IDTypes';
import {
  QueryContext,
  IQueryContext,
  Category,
  ICategory,
  Tag,
  ITag,
  QueryContextCollection,
  IQueryContextCollection,
  CategoryCollection,
  ICategoryCollection,
  TagCollection,
  ITagCollection,
} from '@QueryContextsService/index';

import { SupportedSerializersEnum, SerializationStructure, ISerializationStructure, toJson, fromJson, toYaml, fromYaml } from '@Serializers/Serializers';

import { UserData, IUserData } from './UserData';


export interface IConfigurationData<T extends IDType> {}

export class ConfigurationData<T extends IDType> implements IConfigurationData<T> {}

export interface IData<T extends IDType> {
  readonly userData: IUserData<T>;
  readonly configurationData: IConfigurationData<T>;
}

export class Data<T extends IDType> {
  private message: string;

  // constructor overload signatures
  constructor(logger: ILogger, context: vscode.ExtensionContext);
  constructor(logger: ILogger, context: vscode.ExtensionContext, userData: IUserData<T>);
  constructor(logger: ILogger, context: vscode.ExtensionContext, configurationData: IConfigurationData<T>);
  constructor(
    logger: ILogger,
    context: vscode.ExtensionContext,
    userData: UserData<T>,
    configurationData: ConfigurationData<T>,
  );
  constructor(logger: ILogger, context: vscode.ExtensionContext, initializationStructure: ISerializationStructure);
  constructor(logger: ILogger, context: vscode.ExtensionContext, userData: IUserData<T>, initializationStructure: ISerializationStructure);
  constructor(logger: ILogger, context: vscode.ExtensionContext, configurationData: IConfigurationData<T>, initializationStructure: ISerializationStructure);
  constructor(
    logger: ILogger,
    context: vscode.ExtensionContext,
    userData: IUserData<T>,
    configurationData: IConfigurationData<T>,
    initializationStructure: ISerializationStructure
  );

  constructor(
    private logger: ILogger,
    private context: vscode.ExtensionContext,
    readonly userData?: IUserData<T>,
    readonly configurationData?: IConfigurationData<T>,
    private initializationStructure?: ISerializationStructure,
  ) {
    this.message = 'starting Data constructor';
    this.logger.log(this.message, LogLevel.Debug);

    // ToDo : error hanling around invalid datastructure
    // Throw on error, add text to any inner exception
    // if (!this.initializationStructure || this.initializationStructure.value.length === 0) {
    //   // No initialization string provided
    //   this.message = `initialization string MOT provided = ${this.initializationStructure}`;
    // } else {
    //   // Is there a parameter to override the default serializerName
    //   this.message = `initialization string provided. serializerName =  ${this.serializerName},  initializationStructure = ${this.initializationStructure}`;
    // }
    // this.logger.log(this.message, LogLevel.Debug);

    // ToDo: version-aware configuration data loading
    // ToDo: wrap in a try catch
    this.userData = new UserData<T>(this.logger, this.context, this.userData, this.initializationStructure.UserData);

    // ToDo: wrap in a try catch
    this.configurationData = new ConfigurationData<T>(this.logger, this.context, this.configurationData, this.initializationStructure.ConfigurationData);


  }
}

export interface IDataService<T extends IDType> {
  data:Data<T>
}

export class DataService<T extends IDType> implements IDataService<T> {
  public readonly data: Data<T>;
  private message: string;

  // constructor overload signatures
  //   use DefaultConfiguration for both UserData and ConfigurationData
  constructor(logger: ILogger, context: vscode.ExtensionContext);
  constructor(logger: ILogger, context: vscode.ExtensionContext, userData: IUserData<T>);
  constructor(logger: ILogger, context: vscode.ExtensionContext, configurationData: IConfigurationData<T>);
  constructor(
    logger: ILogger,
    context: vscode.ExtensionContext,
    userData: UserData<T>,
    configurationData: ConfigurationData<T>,
  );
  constructor(logger: ILogger, context: vscode.ExtensionContext, initializationStructure: ISerializationStructure);
  constructor(logger: ILogger, context: vscode.ExtensionContext, userData: IUserData<T>, initializationStructure: ISerializationStructure);
  constructor(logger: ILogger, context: vscode.ExtensionContext, configurationData: IConfigurationData<T>, initializationStructure: ISerializationStructure);
  constructor(
    logger: ILogger,
    context: vscode.ExtensionContext,
    userData: IUserData<T>,
    configurationData: IConfigurationData<T>,
    initializationStructure: ISerializationStructure
  );

  constructor(
    private logger: ILogger,
    private context: vscode.ExtensionContext,
    readonly userData?: IUserData<T>,
    readonly configurationData?: IConfigurationData<T>,
    private initializationStructure?: ISerializationStructure,
  ) {
    this.message = 'starting DataService constructor';
    this.logger.log(this.message, LogLevel.Debug);
    // ToDo: version-aware configuration data loading
    // ToDo: add a parameter to support creation of a Data instance from an initializationStructure that uses a different serializerName
    // ToDo: error handling around initializationStructure parameter
    // Throw if an error is found in the initializationStructure or if using it produces an error when instantiaing the internal objects

    this.data = new Data(this.logger, this.context, this.userData, this.configurationData, this.initializationStructure);
    // Split the initializationStructure.value into user
    if (!initializationStructure || initializationStructure.value.length === 0) {
      // No initialization string provided
      this.message = `initialization structure MOT provided or the  of the value is 0`;
    } else {
      this.message = `initialization string provided = ${this.initializationStructure}`;
    }
    this.logger.log(this.message, LogLevel.Debug);

    if (DefaultConfiguration.serializerName === 'YAML') {
        this.configurationData = fromYaml<T>;
    } else if (DefaultConfiguration.serializerName === 'JSON') {
        this.configurationData = fromJson<T>;
    }
    this.message = 'leaving DataService constructor';
    this.logger.log(this.message, LogLevel.Debug);
  }
}
