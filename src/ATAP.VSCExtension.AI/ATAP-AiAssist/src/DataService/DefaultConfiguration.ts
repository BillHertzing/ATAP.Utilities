import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';
import { SerializationStructure, ISerializationStructure } from '@Serializers/index';
import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  QueryEngineFlagsEnum,
  SupportedSerializersEnum,
} from '@BaseEnumerations/index';

// everything here will be initialized before the entry point of the extension
// These are the Interfaces for objects that are allowed to be stored in the DefaultConfiguration
export type AllowedTypesInValue =
  // | undefined
  | string
  | number
  | ISerializationStructure
  | IDataService
  | IStateManager
  | IConfigurationData
  | ModeMenuItemEnum
  | QueryAgentCommandMenuItemEnum
  | QueryEngineFlagsEnum
  | string[]
  | SupportedSerializersEnum
  | LogLevel;

export class DefaultConfiguration {
  // This is the default configuration for the extension, per the version number above
  static version: string = 'v0.0.1'; // manipulated by the CI/CD tools

  // The bottom of the configuration root, the values used if there is no corresponding CLI argument, no corresponding environment variable, no test environment default, or no development environment default
  static Production: Record<string, AllowedTypesInValue> = {
    currentMode: ModeMenuItemEnum.Workspace,
    priorMode: ModeMenuItemEnum.Workspace,
    currentQueryAgentCommand: QueryAgentCommandMenuItemEnum.Chat,
    priorQueryAgentCommand: QueryAgentCommandMenuItemEnum.Chat,
    currentQueryEngines: QueryEngineFlagsEnum.ChatGPT,
    currentSources: ['workspace'],
    TagsFileName: 'Tags.json',
    CategorysFileName: 'Categorys.json',
    AssociationsFileName: 'Associations.json',
    ConversationsFileName: 'Conversations.json',
    CloudBasePath: 'C:\\Dropbox',
    DataServiceAsSerializationStructure: new SerializationStructure(SupportedSerializersEnum.Yaml, '{}'),
    extensionID: 'ataputilities.atap-aiassist',
    KeePassKDBXPath: 'C:\\Dropbox\\whertzing\\GitHub\\ATAP.IAC\\Security\\.PSVaultATAP_secrets.kdbx',
    // The default serializer
    serializerName: SupportedSerializersEnum.Yaml,
    YourExpertise: `you are an expert system meant to help domain-specific experts, with focus on Typescript, Visual Studio Code,
VSC extension development, bdd and tdd testing, (node js installation usage, and maintenance).
Use a professional tone. Expository statements, especially explanations of code should be terse.
Descriptive object names are preferred, including the use of full english words in class and instance naming.
Use best security practices at all times. Ensure no Personal Identifying Information (PII) or Personal Confidential Information (PCI) data is exposed unless encrypted in transit and at rest.
Code should prioritize execution speed as top priority.
Memory utilization and network utilization should share second priority.
Maintainability and observability should share third priority.
Ensure sufficient comments to explain the code, but keep them terse. Provide just enough comments so that asking a Large Language Model (LLM) to 'explain this code' produces the correct answer.
 `,
  };

  // The development environment default values, used if there is no corresponding CLI argument, no corresponding environment variable, and no test environment default
  static Development: Record<string, AllowedTypesInValue> = {
    //KeePassKDBXPath: '"C:/Dropbox/whertzing/GitHub/ATAP.IAC/Security/ATAP_KeePassDatabase.kdbx"',
    // DataServiceAsSerializationStructure: {
    //   serializerEnum: SupportedSerializersEnum.Yaml,
    //   value: '{}',
    // },
    ConversationsFileName: 'devConversations.json',
  };

  // The Testing environment default values, used if there is no corresponding CLI argument, no corresponding environment variable, and no test environment default
  static Testing: Record<string, AllowedTypesInValue> = {
    //KeePassKDBXPath: '"C:/Dropbox/whertzing/GitHub/ATAP.IAC/Security/ATAP_KeePassDatabase.kdbx"',
    ConversationsFileName: 'testingConversations.json',
    debuggerLogLevel: LogLevel.Debug,
  };
}
