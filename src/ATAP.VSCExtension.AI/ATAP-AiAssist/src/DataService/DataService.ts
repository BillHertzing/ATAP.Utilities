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

import { IStateManager, StateManager } from './StateManager';
import { SupportedSecretsVaultEnum, ISecretsManager, SecretsManager } from './SecretsManager';
import { IConfigurationData, ConfigurationData } from './ConfigurationData';
import { IEventManager, EventManager } from './EventManager';
import { IFileManager, FileManager } from './FileManager';

import { PathLike } from 'fs';

export interface IData {
  getTemporaryPromptDocumentPath(): string | undefined;
  setTemporaryPromptDocumentPath(value: string): void;
  getTemporaryPromptDocument(): vscode.TextDocument | undefined;
  setTemporaryPromptDocument(value: vscode.TextDocument): void;

  readonly configurationData: IConfigurationData;
  readonly stateManager: IStateManager;
  readonly secretsManager: ISecretsManager;
  readonly eventManager: IEventManager;
  readonly fileManager: IFileManager;
  disposeAsync(): void;
}

@logConstructor
export class Data {
  public readonly stateManager: IStateManager;
  public readonly configurationData: IConfigurationData;
  public readonly secretsManager: ISecretsManager;
  public readonly eventManager: IEventManager;
  public readonly fileManager: IFileManager;

  // Data that does NOT get put into globalState
  private temporaryPromptDocumentPath: string | undefined = undefined;
  private temporaryPromptDocument: vscode.TextDocument | undefined = undefined;

  private disposed = false;

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
          `Data constructor instantiating a new ConfigurationData threw something other than a polymorphous Error`,
        );
      }
    }

    // instantiate the stateManager
    // ToDo: figure out what StateManager is using folder for, and how to pass it in
    try {
      this.stateManager = new StateManager(this.logger, this.extensionContext, this.configurationData); //, need a workspace folder passed into the constructor, see https://github.com/microsoft/vscode-cmake-tools/blob/main/src/state.ts
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('Data.ctor. create stateManager -> ', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(`Data.ctor. create stateManager thew an object that was not of type Error -> `);
      }
    }

    // instantiate the secretsManager
    try {
      this.secretsManager = new SecretsManager(
        SupportedSecretsVaultEnum.KeePass,
        this.logger,
        this.extensionContext,
        this.configurationData,
      ); //, need a workspace folder passed into the constructor?
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('Data.ctor. create secretsManager -> ', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(`Data.ctor. create secretsManager thew an object that was not of type Error -> `);
      }
    }

    // instantiate the eventManager
    try {
      this.eventManager = new EventManager(this.logger, this.extensionContext, this.configurationData); //, need a workspace folder passed into the constructor?
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('Data.ctor. create eventManager -> ', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(`Data.ctor. create eventManager thew an object that was not of type Error -> `);
      }
    }

    // instantiate the fileManager
    try {
      this.fileManager = new FileManager(this.logger, this.configurationData); //, need a workspace folder passed into the constructor?
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError('Data.ctor. create fileManager -> ', e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(`Data.ctor. create fileManager thew an object that was not of type Error -> `);
      }
    }
  }

  async initializeAsync() {
    //await this.stateManager.in;
  }
  public getTemporaryPromptDocumentPath(): string | undefined {
    return this.temporaryPromptDocumentPath ? this.temporaryPromptDocumentPath : undefined;
  }
  public setTemporaryPromptDocumentPath(value: string) {
    this.temporaryPromptDocumentPath = value;
  }
  public getTemporaryPromptDocument(): vscode.TextDocument | undefined {
    return this.temporaryPromptDocument ? this.temporaryPromptDocument : undefined;
  }
  public setTemporaryPromptDocument(value: vscode.TextDocument) {
    this.temporaryPromptDocument = value;
  }
  @logAsyncFunction
  async disposeAsync() {
    if (!this.disposed) {
      // release resources
      await this.fileManager.disposeAsync();
      this.eventManager.dispose();
      this.secretsManager.dispose();
      this.stateManager.dispose();
      this.configurationData.dispose();
      this.disposed = true;
    }
  }
}

export interface IDataService {
  version: string;
  data: IData;
  disposeAsync(): void;
}

@logConstructor
export class DataService implements IDataService {
  public readonly version: string;
  public readonly data: Data;
  private disposed = false;
  // constructor overload signatures to initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
  constructor(logger: ILogger, extensionContext: vscode.ExtensionContext);

  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext, //dataInitializationStructure?: ISerializationStructure,
  ) {
    // ToDo: version-aware configuration data loading; multiroot-workspace-aware
    this.version = DefaultConfiguration.version;
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
  }

  // ToDo: make data derive from ItemWithID, and keep track of multiple instances of data (to support profiles?)
  // ToDo: ensure compatability  between the dataService rehydrated from the Default Configuration with  actual version number of the extension
  static create(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): DataService {
    Logger.staticLog(`DataService.create called`, LogLevel.Debug);

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
  @logAsyncFunction
  async disposeAsync() {
    if (!this.disposed) {
      // release any resources
      await this.data.disposeAsync();
      this.disposed = true;
    }
  }
}
