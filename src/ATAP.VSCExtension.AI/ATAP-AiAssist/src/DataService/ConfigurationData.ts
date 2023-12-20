import * as vscode from 'vscode';
import * as path from 'path';

import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { DefaultConfiguration, AllowedTypesInValue } from './DefaultConfiguration';
import { isRunningInDevHost } from '@Utilities/index';
import {
  LLModels,
  HttpVerb,
  EndpointManager,
  EndpointConfig,
  ChatGptEndpointConfig,
  GrokEndpointConfig,
  CopilotEndpointConfig,
} from '@EndpointManager/index';

import { ModeMenuItemEnum, CommandMenuItemEnum } from '@StateMachineService/index';

export interface IConfigurationData {
  readonly conversationFilePath: string;
  readonly debuggerLogLevel: LogLevel;
  readonly extensionID: string;
  readonly promptExpertise: string;
  readonly serializerName: string;
  getTempDirectoryBasePath(): string;
  getDevelopmentWorkspacePath(): string | undefined;
  getKeePassKDBXPath(): string;
  getDefaultCurrentMode(): ModeMenuItemEnum;
  getDefaultCurrentCommand(): CommandMenuItemEnum;
  // getEndpointConfigs(): Record<LLModels, EndpointConfig>;
  dispose(): void;
}

@logConstructor
export class ConfigurationData implements IConfigurationData {
  private disposed = false;
  // ToDo: constructor overloads to initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext, // private configurationDataInitializationStructure?: ISerializationStructure,
    private envKeyMap: Record<string, string[]> = {
      //toUpper(DefaultConfiguration.Production.extensionID + '.' + key)
      TempDirectoryBasePath: ['TEMP'],
      CloudBasePath: ['CLOUD_BASE_PATH'],
    },
  ) {}

  @logFunction
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
    if (vscode.workspace.getConfiguration(extensionID).has(key)) {
      return vscode.workspace.getConfiguration(extensionID).get(key) as string;
    }
    // is there a static development default?
    if (isRunningInDevHost() && DefaultConfiguration.Development[key]) {
      return DefaultConfiguration.Development[key];
    }
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
    if (isRunningInDevHost() && DefaultConfiguration.Development[key]) {
      return DefaultConfiguration.Development[key];
    }
    // is there a static production default?
    if (DefaultConfiguration.Production[key]) {
      return DefaultConfiguration.Production[key];
    }
    return undefined;
  }
  get conversationFilePath(): string {
    console.log(`CloudBasePath ${this.getNonNull('CloudBasePath')}`, LogLevel.Debug);
    console.log(`extensionID ${this.getNonNull('extensionID')}`, LogLevel.Debug);
    console.log(`ConversationFileName ${this.getNonNull('ConversationFileName')}`, LogLevel.Debug);

    return path.join(
      this.getNonNull('CloudBasePath') as string,
      this.getNonNull('extensionID') as string,
      this.getNonNull('ConversationFileName') as string,
    ) as string;
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

  getDefaultCurrentMode(): ModeMenuItemEnum {
    return this.getNonNull('DefaultCurrentMode') as ModeMenuItemEnum;
  }
  getDefaultCurrentCommand(): CommandMenuItemEnum {
    return this.getNonNull('DefaultCurrentCommand') as CommandMenuItemEnum;
  }
  dispose() {
    if (!this.disposed) {
      // release any resources
      this.disposed = true;
    }
  }
}
