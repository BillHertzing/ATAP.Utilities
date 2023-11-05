
import * as yaml from 'js-yaml';

// Utility methods for JSON and YAML conversion. YAML conversion is done with js-yaml
export const toJson = (obj: any): string => JSON.stringify(obj);
export const fromJson = <T>(json: string): T => JSON.parse(json);
export const toYaml = (obj: any): string => yaml.dump(obj);
export const fromYaml = <T>(yamlString: string): T => yaml.load(yamlString) as T;

