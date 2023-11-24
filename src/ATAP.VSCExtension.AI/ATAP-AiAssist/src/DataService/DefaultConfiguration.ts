import { SupportedSerializersEnum, SerializationStructure, ISerializationStructure } from '@Serializers/index';
import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

// everything here will be initialized before the entry point of the extension
// These are the Interfaces for objects that are allowed to be stored in the DefaultConfiguration
export type AllowedTypesInValue =
  | undefined
  | string
  | number
  | ISerializationStructure
  | IDataService
  | IStateManager
  | IConfigurationData;

export class DefaultConfiguration {
  // This is the default configuration for the extension, per the version number above
  static version: string = 'v0.0.1'; // manipulated by the CI/CD tools
  // The default serializer used throughout the default configuration
  static serializerName: SupportedSerializersEnum = SupportedSerializersEnum.Yaml;
  // This JSON or YAML serialization of the data the extension starts with when initialized with no VSC global extension state data, when run for the first time, or when factory reset
  static Production: Record<string, AllowedTypesInValue> = {
    ExtensionFullName: 'ataputilities.atap-aiassist',
    YourExpertise:
      'You are an expert in Visual Studio Code (VSC), VSC extension development, VSC testing and TypeScript',
    KeePassKDBXPath: 'C:\\Dropbox\\whertzing\\GitHub\\ATAP.IAC\\Security\\.PSVaultATAP_secrets.kdbx',
    DataServiceAsSerializationStructure: new SerializationStructure(SupportedSerializersEnum.Yaml, '{}'),
  };
  static Development: Record<string, AllowedTypesInValue> = {
    DataServiceAsSerializationStructure: {
      serializerEnum: SupportedSerializersEnum.Yaml,
      value: '{}',
    },
  };
}
