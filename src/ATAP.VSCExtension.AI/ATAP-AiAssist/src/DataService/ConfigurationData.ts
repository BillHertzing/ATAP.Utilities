import * as vscode from 'vscode';
import * as path from 'path';

import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import {
  logConstructor,
  logFunction,
  logAsyncFunction,
  logExecutionTime,
} from '@Decorators/index';
import { DefaultConfiguration, AllowedTypesInValue } from './DefaultConfiguration';
import { isRunningInDevelopmentEnvironment, isRunningInTestingEnvironment } from '@Utilities/index';
import {
  LLModels,
  HttpVerb,
  EndpointManager,
  EndpointConfig,
  ChatGptEndpointConfig,
  GrokEndpointConfig,
  CopilotEndpointConfig,
} from '@EndpointManager/index';
import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  QueryEngineFlagsEnum,
  VCSCommandMenuItemEnum,
  SupportedSerializersEnum,
} from '@BaseEnumerations/index';

export interface IConfigurationData  {
  readonly currentEnvironment: string;
  readonly tagsFilePath: string;
  readonly categorysFilePath: string;
  readonly associationsFilePath: string;
  readonly queryFragmentsFilePath: string;
  readonly conversationsFilePath: string;
  readonly debuggerLogLevel: LogLevel;
  readonly extensionID: string;
  readonly promptExpertise: string;
  readonly serializerName: string;
  readonly currentMode: ModeMenuItemEnum;
  readonly currentQueryAgentCommand: QueryAgentCommandMenuItemEnum;
  readonly currentQueryEngines: QueryEngineFlagsEnum;
  readonly currentSources: string[];
  readonly priorMode: ModeMenuItemEnum;
  readonly priorQueryAgentCommand: QueryAgentCommandMenuItemEnum;
  getTempDirectoryBasePath(): string;
  getDevelopmentWorkspacePath(): string | undefined;
  getKeePassKDBXPath(): string;
  // getEndpointConfigs(): Record<LLModels, EndpointConfig>;
  disposeAsync(): void;
}

@logConstructor
export class ConfigurationData implements IConfigurationData {
  private disposed = false;
  // ToDo: constructor overloads to initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
  constructor(
    public readonly logger: ILogger,
    private extensionContext: vscode.ExtensionContext, // private configurationDataInitializationStructure?: ISerializationStructure,
    // ToDo: make the envKeyMap a static property of the class, so it can be used during extension activation

    private envKeyMap: Record<string, string[]> = {
      //toUpper(DefaultConfiguration.Production.extensionID + '.' + key)
      TempDirectoryBasePath: ['TEMP'],
      CloudBasePath: ['CLOUD_BASE_PATH'],
    },
  ) {
    this.logger = new Logger(this.logger, this.constructor.name);
  }

  //@logFunction
  private getNonNull(key: string): AllowedTypesInValue {
    const extensionID = this.extensionID;

    // const cLIIdentifier = extensionID + '.' + key
    // is there a CLI argument?
    // is there an environment variable?
    if (this.envKeyMap[key]) {
      for (const envKey of this.envKeyMap[key]) {
        if (process.env[envKey]) {
          return process.env[envKey] as string;
        }
      }
    }
    // is there a setting?
    // ToDo: upgrade to using a type map if in fact settings can be enumerations, or if we want to support serialized objects in settings
    if (vscode.workspace.getConfiguration(extensionID).has(key)) {
      return vscode.workspace.getConfiguration(extensionID).get(key) as string;
    }
    // is there a static development default?
    if (isRunningInDevelopmentEnvironment() && key in DefaultConfiguration.Development) {
      return DefaultConfiguration.Development[key];
    }
    // is there a static testing default?
    // if (isRunningInTestingEnvironment() && key in DefaultConfiguration.Testing) {
    //   return DefaultConfiguration.Testing[key];
    // }
    // is there a static production default?
    if (DefaultConfiguration.Production[key]) {
      return DefaultConfiguration.Production[key];
    }
    // ToDo: add a function that will prompt the user to set a Setting (User or workspace)
    // If there is no value anywhere in the configRoot structure
    // add function to prompt user to enter the value string in the settings for key
    throw new DetailedError(
      `ConfigurationData.getNonNull: ${key} not found in argv, env, settings or DefaultConfiguration`,
    );
  }

  @logFunction
  private getPossiblyUndefined(key: string): AllowedTypesInValue | undefined {
    const extensionID = 'ataputilities.atap-aiassist';
    // const cLIIdentifier = extensionID + '.' + key
    // is there a CLI argument?
    // const eNVIdentifier = toUpper(extensionID + '.' + key)
    // is there an environment variable?
    if (this.envKeyMap[key]) {
      for (const envKey of this.envKeyMap[key]) {
        if (process.env[envKey]) {
          return process.env[envKey] as string;
        }
      }
    }
    // is there a setting?
    if (vscode.workspace.getConfiguration(extensionID).has(key)) {
      return vscode.workspace.getConfiguration(extensionID).get(key) as string;
    }
    // is there a static development default?
    if (isRunningInDevelopmentEnvironment() && key in DefaultConfiguration.Development) {
      return DefaultConfiguration.Development[key];
    }
    // is there a static testing default?
    // if (isRunningInTestingEnvironment() && key in DefaultConfiguration.Testing) {
    //   return DefaultConfiguration.Testing[key];
    // }

    // is there a static production default?
    if (DefaultConfiguration.Production[key]) {
      return DefaultConfiguration.Production[key];
    }
    return undefined;
  }
  get currentEnvironment(): string {
    if (isRunningInDevelopmentEnvironment()) {
      return 'Development';
    } else if (isRunningInTestingEnvironment()) {
      return 'Testing';
    } else {
      return 'Production';
    }
  }

  get tagsFilePath(): string {
    return path.join(
      this.getNonNull('cloudBasePath') as string,
      this.getNonNull('extensionID') as string,
      this.getNonNull('tagsFileName') as string,
    ) as string;
  }
  get categorysFilePath(): string {
    return path.join(
      this.getNonNull('cloudBasePath') as string,
      this.getNonNull('extensionID') as string,
      this.getNonNull('categorysFileName') as string,
    ) as string;
  }
  get associationsFilePath(): string {
    return path.join(
      this.getNonNull('cloudBasePath') as string,
      this.getNonNull('extensionID') as string,
      this.getNonNull('associationsFileName') as string,
    ) as string;
  }
  get queryFragmentsFilePath(): string {
    return path.join(
      this.getNonNull('cloudBasePath') as string,
      this.getNonNull('extensionID') as string,
      this.getNonNull('queryFragmentsFileName') as string,
    ) as string;
  }
  get conversationsFilePath(): string {
    return path.join(
      this.getNonNull('cloudBasePath') as string,
      this.getNonNull('extensionID') as string,
      this.getNonNull('conversationsFileName') as string,
    ) as string;
  }

  get currentMode(): ModeMenuItemEnum {
    return this.getNonNull('currentMode') as ModeMenuItemEnum;
  }
  get currentQueryAgentCommand(): QueryAgentCommandMenuItemEnum {
    return this.getNonNull('currentQueryAgentCommand') as QueryAgentCommandMenuItemEnum;
  }
  get currentQueryEngines(): QueryEngineFlagsEnum {
    return this.getNonNull('currentQueryEngines') as QueryEngineFlagsEnum;
  }
  get currentSources(): string[] {
    return this.getNonNull('currentSources') as string[];
  }

  get debuggerLogLevel(): LogLevel {
    return this.getNonNull('debuggerLogLevel') as LogLevel;
  }
  get extensionID(): string {
    if (!DefaultConfiguration.Production['extensionID']) {
      throw new DetailedError('extensionID not found in DefaultConfiguration.Production');
    } else {
      return DefaultConfiguration.Production['extensionID'] as string;
    }
  }
  get priorMode(): ModeMenuItemEnum {
    return this.getNonNull('priorMode') as ModeMenuItemEnum;
  }
  get priorQueryAgentCommand(): QueryAgentCommandMenuItemEnum {
    return this.getNonNull('priorQueryAgentCommand') as QueryAgentCommandMenuItemEnum;
  }

  get promptExpertise(): string {
    return this.getNonNull('YourExpertise') as string;
  }

  get serializerName(): string {
    return this.getNonNull('serializerName') as string;
  }

  getTempDirectoryBasePath(): string {
    // ToDo: allow for multiple temp to be set with differnet strings in different places
    return this.getNonNull('TempDirectoryBasePath') as string;
  }

  getDevelopmentWorkspacePath(): string | undefined {
    return this.getPossiblyUndefined('DevelopmentWorkspacePath') as string;
  }

  getKeePassKDBXPath(): string {
    return this.getNonNull('KeePassKDBXPath') as string;
  }

  // getEndpointConfigs(): Record<LLModels, EndpointConfig> {
  //   // Initialize with undefined for each key
  //   const enumConfig: Record<LLModels, EndpointConfig> = {
  //     [LLModels.ChatGPT]: undefined,
  //     //[LLModels.Grok]: undefined,
  //     //[LLModels.Copilot]: undefined,
  //     // Initialize other LLModels as needed
  //   };
  //   const configJson = this.getNonNull('EndpointConfigurationsAsJSON') as string;
  //   if (configJson) {
  //     const parsedConfig: Record<string, EndpointConfig> = JSON.parse(configJson);
  //     // Iterate over the enum keys and populate enumConfig
  //     for (const model of Object.values(LLModels)) {
  //       if (parsedConfig[model]) {
  //         enumConfig[model as LLModels] = parsedConfig[model];
  //       }
  //     }
  //   }
  //   return enumConfig;
  // }

  // All setxxx functions are async, because they need to write to the settings
  //  TooDo: accept a workspace or user setting
  private async putSetting(key: string, value: AllowedTypesInValue): Promise<void> {
    const extensionID = 'ataputilities.atap-aiassist';
    try {
      //  TooDo: update a workspace or user setting
      // Update the user setting
      await vscode.workspace
        .getConfiguration(extensionID)
        .update('promptExpertise', value, vscode.ConfigurationTarget.Global);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`ConfigurationData.putSetting: failed to set ${extensionID}.${key} -> `, e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `An unknown error occurred during ConfigurationData.putSetting call, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }

  async setPromptExpertise(value: string): Promise<void> {
    try {
      // Update the setting
      await this.putSetting('promptExpertise', value);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`ConfigurationData.setPromptExpertise failed -> `, e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `An unknown error occurred in the ConfigurationData.setPromptExpertise method, and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }

  async setEndpointConfig(configs: Record<string, EndpointConfig>) {
    const configJson = JSON.stringify(configs, (key, value) => {
      // Custom replacer function to handle special types, if necessary
      return value;
    });
    vscode.workspace
      .getConfiguration('ataputilities.atap-aiassist')
      .update('EndpointConfigurations', configJson, vscode.ConfigurationTarget.Global);
  }

  @logAsyncFunction
  async disposeAsync() {
    if (!this.disposed) {
      // release any resources
      this.disposed = true;
    }
  }
}
