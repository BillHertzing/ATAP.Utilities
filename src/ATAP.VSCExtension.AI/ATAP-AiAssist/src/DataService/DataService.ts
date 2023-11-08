import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import * as vscode from 'vscode';

import { DefaultConfiguration } from '../DefaultConfiguration';
import { GlobalStateCache } from './GlobalStateCache';
import { GUID, Int, IDType } from '@IDTypes/IDTypes';


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


import {
  QueryContext,
  IQueryContext,
  QueryContextCollection,
  IQueryContextCollection,
} from '@QueryContextsService/index';

import { SupportedSerializersEnum, SerializationStructure, ISerializationStructure, toJson, fromJson, toYaml, fromYaml } from '@Serializers/Serializers';

import { UserData, IUserData } from './UserData';


export interface IConfigurationData {}

export class ConfigurationData implements IConfigurationData {}

export interface IData {
  readonly userData: IUserData;
  readonly configurationData: IConfigurationData;
}

export class Data {
  private message: string;

  // constructor overload signatures
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, userData: IUserData);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, configurationData: IConfigurationData);
  constructor(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    userData: UserData,
    configurationData: ConfigurationData,
  );
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, initializationStructure: ISerializationStructure);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, userData: IUserData, initializationStructure: ISerializationStructure);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, configurationData: IConfigurationData, initializationStructure: ISerializationStructure);
  constructor(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    userData: IUserData,
    configurationData: IConfigurationData,
    initializationStructure: ISerializationStructure
  );

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    readonly userData?: IUserData,
    readonly configurationData?: IConfigurationData,
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
    this.userData = new UserData(this.logger, this.extensionContext, this.userData, this.initializationStructure.UserData);

    // ToDo: wrap in a try catch
    this.configurationData = new ConfigurationData(this.logger, this.extensionContext, this.configurationData, this.initializationStructure.ConfigurationData);


  }
}

export interface IDataService {
  data:Data
}

export class DataService implements IDataService {
  public readonly data: Data;
  private message: string;

  // constructor overload signatures
  //   use DefaultConfiguration for both UserData and ConfigurationData
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, userData: IUserData);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, configurationData: IConfigurationData);
  constructor(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    userData: UserData,
    configurationData: ConfigurationData,
  );
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, initializationStructure: ISerializationStructure);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, userData: IUserData, initializationStructure: ISerializationStructure);
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext, configurationData: IConfigurationData, initializationStructure: ISerializationStructure);
  constructor(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    userData: IUserData,
    configurationData: IConfigurationData,
    initializationStructure: ISerializationStructure
  );

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    readonly userData?: IUserData,
    readonly configurationData?: IConfigurationData,
    private initializationStructure?: ISerializationStructure,
  ) {
    this.message = 'starting DataService constructor';
    this.logger.log(this.message, LogLevel.Debug);
    // ToDo: version-aware configuration data loading
    // ToDo: add a parameter to support creation of a Data instance from an initializationStructure that uses a different serializerName
    // ToDo: error handling around initializationStructure parameter
    // Throw if an error is found in the initializationStructure or if using it produces an error when instantiaing the internal objects

    this.data = new Data(this.logger, this.extensionContext, this.userData, this.configurationData, this.initializationStructure);
    // Split the initializationStructure.value into user
    if (!initializationStructure || initializationStructure.value.length === 0) {
      // No initialization string provided
      this.message = `initialization structure MOT provided or the  of the value is 0`;
    } else {
      this.message = `initialization string provided = ${this.initializationStructure}`;
    }
    this.logger.log(this.message, LogLevel.Debug);

    if (DefaultConfiguration.serializerName === 'YAML') {
        this.configurationData = fromYaml;
    } else if (DefaultConfiguration.serializerName === 'JSON') {
        this.configurationData = fromJson;
    }
    this.message = 'leaving DataService constructor';
    this.logger.log(this.message, LogLevel.Debug);
  }
}
