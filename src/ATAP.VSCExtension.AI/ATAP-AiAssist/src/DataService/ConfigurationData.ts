import * as vscode from 'vscode';

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

export interface IConfigurationData {
  getPromptExpertise(): string;
  getKeePassKDBXPath(): string;
  // getEndpointConfigs(): Record<LLModels, EndpointConfig>;
}

@logConstructor
export class ConfigurationData implements IConfigurationData {
  // ToDo: constructor overloads to initialize with various combinations of empty fields and fields initialized with one or more SerializationStructures
  constructor(
    private logger: ILogger,
    private extensionContext: vscode.ExtensionContext, // private configurationDataInitializationStructure?: ISerializationStructure,
  ) {}

  private getSerializedString(key: string): AllowedTypesInValue {
    const extensionID = 'ataputilities.atap-aiassist';
    // const cLIIdentifier = extensionID + '.' + key
    // is there a CLI argument?
    // const eNVIdentifier = toupper(extensionID + '.' + key)
    // is there an environment variable?
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
      `ConfigurationData.getSerializedString: ${key} not found in argv, env, settings or DefaultConfiguration`,
    );
  }

  getPromptExpertise(): string {
    return this.getSerializedString('YourExpertise') as string;
  }

  getKeePassKDBXPath(): string {
    return this.getSerializedString('KeePassKDBXPath') as string;
  }

  // getEndpointConfigs(): Record<LLModels, EndpointConfig> {
  //   // Initialize with undefined for each key
  //   const enumConfig: Record<LLModels, EndpointConfig> = {
  //     [LLModels.ChatGPT]: undefined,
  //     //[LLModels.Grok]: undefined,
  //     //[LLModels.Copilot]: undefined,
  //     // Initialize other LLModels as needed
  //   };
  //   const configJson = this.getSerializedString('EndpointConfigurationsAsJSON') as string;
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
}
