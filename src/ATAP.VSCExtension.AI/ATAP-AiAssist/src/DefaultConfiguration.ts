// DefaultConfiguration.ts

import { GUID, Int, IDType } from '@IDTypes/index';
import { SupportedSerializersEnum, SerializationStructure, ISerializationStructure } from '@Serializers/index';
import { IDataService, IData, IUserData } from '@DataService/index';

// everything here will be initialized before the entry point of the extension
// These are the Interfaces for objects that are allowed to be stored in the DefaultConfiguration
type AllowedTypesInValue = string | number | ISerializationStructure | IDataService | IData | IUserData;

export class DefaultConfiguration {
  // This is the default configuration for the extension, per the version number above
  static version: string = 'v0.0.1'; // manipulated by the CI/CD tools
  // The default serializer used throughout the default configuration
  static serializerName: SupportedSerializersEnum = SupportedSerializersEnum.Yaml;
  // This JSON or YAML serialization of the data the extension starts with when initialized with no VSC global extension state data, when run for the first time, or when factory reset
  static Production: Record<string, AllowedTypesInValue> = {
    "DataServiceAsSerializationStructure": new SerializationStructure(SupportedSerializersEnum.Yaml,
      "{}")

      // "ID":{}
      // "UserData: '{a:b}',
      // ConfigurationData: '{a:b}',
      // Add more key-value pairs as needed
      };
  static Development: Record<string, AllowedTypesInValue> = {
    "DataServiceAsSerializationStructure": {
      "serializerEnum": SupportedSerializersEnum.Yaml,
      "value":"{}"
    },

      // "ID":{}
      // "UserData: '{a:b}',
      // ConfigurationData: '{a:b}',
      // Add more key-value pairs as needed
  };
}
