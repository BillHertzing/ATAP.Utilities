import * as vscode from 'vscode';
import { GUID, Int, IDType } from '@IDTypes/index';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { DefaultConfiguration } from './DefaultConfiguration';
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
  ItemWithIDTypes,
  MapTypeToValueType,
  YamlData,
  fromYamlForItemWithID,
  IItemWithID,
  ItemWithID,
  ICollection,
  Collection,
  IFactory,
  Factory,
  ICollectionFactory,
  CollectionFactory,
  TagValueType,
  ITag,
  Tag,
  ITagCollection,
  TagCollection,
  CategoryValueType,
  ICategory,
  Category,
  ICategoryCollection,
  CategoryCollection,
  TokenValueType,
  IToken,
  Token,
  ITokenCollection,
  TokenCollection,
  AssociationValueType,
  IAssociation,
  Association,
  IAssociationCollection,
  AssociationCollection,
  QueryContextValueType,
  IQueryContext,
  QueryContext,
  IQueryContextCollection,
  QueryContextCollection,
} from '@ItemWithIDs/index';

import { IStateManager, StateManager } from './StateManager';
import { IConfigurationData, ConfigurationData } from './ConfigurationData';

export interface IData {
  getMasterPassword(): string | undefined;
  readonly configurationData: IConfigurationData;
  readonly stateManager: IStateManager;
}

@logConstructor
export class Data {
  public readonly stateManager: IStateManager;
  public readonly configurationData: IConfigurationData;

  // Data that does NOT get put into globalState
  private masterPassword: Buffer | null = null;
  private masterPasswordTimer: NodeJS.Timeout | null = null;

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
    // instantiate the configurationData

    try {
      this.configurationData = new ConfigurationData(this.logger, this.extensionContext);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('Data.ctor. create configurationData -> ', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `Data constructor instantiating a new StateManager threw something other than a polymorphous Error`,
        );
      }
    }

    // instantiate the stateManager
    // ToDo: figure out what StateManager is using folder for, and how to pass it in
    try {
      this.stateManager = new StateManager(this.logger, this.extensionContext); //, need a workspace folder passed into the constructor, see https://github.com/microsoft/vscode-cmake-tools/blob/main/src/state.ts
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('Data.ctor. create stateManager -> ', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(`Data.ctor. create stateManager thew an object that was not of type Error -> `);
      }
    }

    // When the extension starts and instantiates the Data structure, ask the user for the master password to the Keepass vault
    // masterPassword is a secure buffer in the Data class that holds the master password to a Keepass vault
    // it is NOT stored in the cache
    // it is cleared after 3 hours
    this.askForMasterPassword();
  }
  private askForMasterPassword(): Promise<void> {
    return new Promise((resolve) => {
      vscode.window
        .showInputBox({ prompt: 'Enter the master password to the Keepass vault at TBD', password: true })
        .then((password) => {
          if (password) {
            this.masterPassword = Buffer.from(password);

            // Set a timer to clear the secure buffer after 3 hours
            if (this.masterPasswordTimer) {
              clearTimeout(this.masterPasswordTimer);
            }
            this.masterPasswordTimer = setTimeout(() => {
              this.masterPassword = null;
            }, 3 * 60 * 60 * 1000);
          }
          resolve();
        });
    });
  }

  public getMasterPassword(): string | undefined {
    if (!this.masterPassword) {
      this.askForMasterPassword();
    }
    return this.masterPassword ? this.masterPassword.toString() : undefined;
  }
}

export interface IDataService {
  version: string;
  data: IData;
}

@logConstructor
export class DataService implements IDataService {
  public readonly version: string;
  public readonly data: Data;

  // constructor overload signatures to initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext, //dataInitializationStructure?: ISerializationStructure,
  ) {
    // capture any errors and report them upward
    try {
      this.data = new Data(this.logger, this.extensionContext);
      // dataInitializationStructure !== undefined && dataInitializationStructure.value.length !== 0
      //   ? new Data(this.logger, this.extensionContext)
      //   : new Data(this.logger, this.extensionContext);
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
  }

  // ToDo: make data derive from ItemWithID, and keep track of multiple instances of data (to support profiles?)
  // ToDo: ensure compatability  between the dataService rehydrated from the Default Configuration with  actual version number of the extension
  @logExecutionTime
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
            `${callingModule}: create dataService from initializationStructure using convertFrom_xxx -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create dataService from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
          );
        }
      }
      if (_obj === null) {
        throw new Error(
          `${callingModule}: create dataService from initializationStructure using convertFrom_xxx produced a null`,
        );
      }
      return _obj;
    } else {
      try {
        _obj = new DataService(logger, extensionContext);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(`${callingModule}: create dataService from initializationStructure -> }`, e);
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(`${callingModule}: create dataService from initializationStructure`);
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
