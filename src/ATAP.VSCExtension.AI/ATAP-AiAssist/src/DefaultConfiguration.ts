// DefaultConfiguration.ts

import { GUID, Int, IDType } from '@IDTypes/IDTypes';
import { SupportedSerializersEnum } from '@Serializers/Serializers';

// everything here will be initialized before the entry point of the extension
export class DefaultConfiguration {
  // This is the default configuration for the extension, per the version number above
  static version: string = 'v0.0.1'; // manipulated by the CI/CD tools
  // The default serializer used throughout
  static serializerName: SupportedSerializersEnum = SupportedSerializersEnum.Yaml;
  // This JSON or YAML serialization of the data the extension starts with when initialized with no VSC global extension state data, when run for the first time, or when factory reset
  static production: { [key: string]: object } = {
    DataService: {
      UserData: '{a:b}',
      ConfigurationData: '{a:b}',
      // Add more key-value pairs as needed
    },
  };
}
