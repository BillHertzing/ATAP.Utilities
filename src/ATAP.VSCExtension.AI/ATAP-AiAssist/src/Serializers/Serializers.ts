import * as yaml from 'js-yaml';

import { SupportedSerializersEnum } from '@BaseEnumerations/index';

// Utility methods for JSON and YAML conversion. YAML conversion is done with js-yaml
export const toJson = (obj: any): string => JSON.stringify(obj);
export const fromJson = <T>(json: string): T => JSON.parse(json);
export const toYaml = (obj: any): string => yaml.dump(obj);
export const fromYaml = <T>(yamlString: string): T => yaml.load(yamlString) as T;

export interface ISerializationStructure {
  readonly value: string;
  readonly serializerEnum: SupportedSerializersEnum;
}
export class SerializationStructure implements ISerializationStructure {
  constructor(
    readonly serializerEnum: SupportedSerializersEnum,
    readonly value: string,
  ) {}

  //  getConversionFunction() {
  //   switch (this.serializerEnum) {
  //     case SupportedSerializersEnum.Yaml:
  //       return convertFrom_yaml;
  //     case SupportedSerializersEnum.Json:
  //       return convertFrom_json;
  //     default:
  //       throw new Error('Unsupported serializer');
  //   }
  // }
}

export function isSerializationStructure(obj: any): obj is ISerializationStructure {
  return obj && typeof obj === 'object' && 'value' in obj;
}

export function stringifyWithCircularReference(obj: any): string {
  const seen = new WeakSet();
  return JSON.stringify(obj, (key, value) => {
    if (typeof value === 'object' && value !== null) {
      if (seen.has(value)) {
        // Circular reference found, discard key
        return;
      }
      seen.add(value);
    }
    return value;
  });
}
