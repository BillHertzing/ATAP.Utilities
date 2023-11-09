import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';

import { DefaultConfiguration } from '../DefaultConfiguration';
import { GlobalStateCache } from './GlobalStateCache';
import { GUID, Int, IDType } from '@IDTypes/index';

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

import { UserData, IUserData } from './UserData';

export interface IConfigurationData {}

export class ConfigurationData implements IConfigurationData {
  private message: string;

  // ToDo: constructor overloads to initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    private configurationDataInitializationStructure?: ISerializationStructure,
  ) {
    this.message = 'starting ConfigurationData constructor';
    this.logger.log(this.message, LogLevel.Debug);
    this.message = 'leaving ConfigurationData constructor';
    this.logger.log(this.message, LogLevel.Trace);
  }
}

export interface IData {
  readonly userData: IUserData;
  readonly configurationData: IConfigurationData;
}

export class Data {
  private message: string;
  public readonly userData: IUserData;
  public readonly configurationData: IConfigurationData;

  // constructor overload signatures to initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);
  constructor(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    userDataInitializationStructure: ISerializationStructure,
  );

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    private userDataInitializationStructure?: ISerializationStructure,
    private configurationDataInitializationStructure?: ISerializationStructure,
  ) {
    this.message = 'starting Data constructor';
    this.logger.log(this.message, LogLevel.Debug);

    //ToDo: initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
    // ToDo: can do this with a terneray operator, except for executing code to select which deserializer to use

    try {
      this.userData =
        userDataInitializationStructure !== undefined && userDataInitializationStructure.value.length !== 0
          ? new UserData(this.logger, this.extensionContext)
          : new UserData(this.logger, this.extensionContext);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('Data.ctor. create userData -> }', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(`Data.ctor. create userData thew an object that was not of type Error ->`);
      }
    }
    try {
      this.configurationData =
        configurationDataInitializationStructure !== undefined &&
        configurationDataInitializationStructure.value.length !== 0
          ? new ConfigurationData(this.logger, this.extensionContext)
          : new ConfigurationData(this.logger, this.extensionContext);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('Data.ctor. create configurationData -> }', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(`Data.ctor. create configurationData thew an object that was not of type Error ->`);
      }
    }
    this.message = 'leaving Data constructor';
    this.logger.log(this.message, LogLevel.Debug);
  }
}

export interface IDataService {
  version: string;
  data: Data;
}

export class DataService implements IDataService {
  public readonly version: string;
  public readonly data: Data;
  private message: string;

  // constructor overload signatures to initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext,
    dataInitializationStructure?: ISerializationStructure,
  ) {
    this.message = 'starting DataService constructor';
    this.logger.log(this.message, LogLevel.Debug);
    // capture any errors and report them upward
    try {
      this.data =
        dataInitializationStructure !== undefined && dataInitializationStructure.value.length !== 0
          ? new Data(this.logger, this.extensionContext)
          : new Data(this.logger, this.extensionContext);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('DataService.ctor. create data -> }', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(`DataService.ctor. create data thew an object that was not of type Error ->`);
      }
    }

    // ToDo: version-aware configuration data loading
    this.version = DefaultConfiguration.version;
    this.data = new Data(this.logger, this.extensionContext);

    this.message = 'leaving DataService constructor';
    this.logger.log(this.message, LogLevel.Debug);
  }

  // ToDo: make data derive from ItemWithID, and keep track of multiple instances of data (to support profiles?)
  // ToDo: ensure compatability  between the dataService rehydrated from the Default Configuration with  actual version number of the extension

  static CreateDataService(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): DataService {
    let _obj: DataService | null;
    if (initializationStructure) {
      try {
        // ToDo: deserialize based on contents of structure
        _obj = DataService.convertFrom_yaml(initializationStructure.value);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create dataService from DefaultConfiguration.Development["DataServiceAsSerializationStructure"] using convertFrom_xxx -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create dataService from DefaultConfiguration.Development["DataServiceAsSerializationStructure"] using convertFrom_xxx threw something other than a polymorphous Error`,
          );
        }
      }
      if (_obj === null) {
        throw new Error(
          `${callingModule}: create dataService from DefaultConfiguration.Development["DataServiceAsSerializationStructure"] using convertFrom_xxx produced a null`,
        );
      }
      return _obj;
    } else {
      try {
        _obj = new DataService(logger, extensionContext);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create dataService from DefaultConfiguration.Development["DataServiceAsSerializationStructure"] -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create dataService from DefaultConfiguration.Development["DataServiceAsSerializationStructure"]`,
          );
        }
      }
      return _obj;
    }
  }

  static convertFrom_json(json: string): DataService {
    return fromJson<DataService>(json);
  }

  static convertFrom_yaml(yaml: string): DataService {
    return fromYaml<DataService>(yaml);
  }
}
