import {
  LogLevel,
  ChannelInfo,
  ILogger,
  Logger,
  getLoggerLogLevelFromSettings,
  setLoggerLogLevelFromSettings,
  getDevelopmentLoggerLogLevelFromSettings,
  setDevelopmentLoggerLogLevelFromSettings,
} from '../Logger';
import * as vscode from 'vscode';
import * as yaml from 'js-yaml';


export class PredicatesService {
  private message: string;

  constructor(private logger: ILogger) {
    this.message = 'starting PredicatesService constructor';
    this.logger.log(this.message, LogLevel.Trace);
    this.loadTagsFromSettings();
    this.loaCategorysFromSettings();
    this.loadPredicatesFromSettings();
    this.message = 'leaving PredicatesService constructor';
    this.logger.log(this.message, LogLevel.Trace);
  }

  private loadTagsFromSettings(): void {
    this.message = 'starting loadTagsFromSettings';
    this.logger.log(this.message, LogLevel.Trace);
  }
  private loaCategorysFromSettings(): void {
    this.message = 'starting loadTagsFromSettings';
    this.logger.log(this.message, LogLevel.Trace);
  }
  private loadPredicatesFromSettings(): void {
    this.message = 'starting loadTagsFromSettings';
    this.logger.log(this.message, LogLevel.Trace);
  }
}

export type GUID = string;
export type Int = number;
export type IDType = GUID | Int;

// Utility methods for JSON and YAML conversion. YAML conversion is done with js-yaml
const toJson = (obj: any): string => JSON.stringify(obj);
const fromJson = <T>(json: string): T => JSON.parse(json);
const toYaml = (obj: any): string => yaml.dump(obj);
const fromYaml = <T>(yamlString: string): T => yaml.load(yamlString) as T;

export class Philote<T extends IDType> {
  readonly ID: T;
  others: Philote<T>[];

  constructor(ID: T) {
    this.ID = ID;
    this.others = [];
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Philote<T> {
    return fromJson<Philote<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Philote<T> {
    return fromYaml<Philote<T>>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.ID}`;
  }
}

export class Category<T extends IDType> {
  readonly philote: Philote<T>;
  readonly name: string;

  constructor(philote: Philote<T>, name: string) {
    this.philote = philote;
    this.name = name;
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Category<T> {
    return fromJson<Category<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Category<T> {
    return fromYaml<Category<T>>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.philote.ID}`;
  }
}

export class Categorys<T extends IDType> {
  readonly philote: Philote<T>;
  categories: Category<T>[];

  constructor(philote: Philote<T>) {
    this.philote = philote;
    this.categories = [];
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Categorys<T> {
    return fromJson<Categorys<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Categorys<T> {
    return fromYaml<Categorys<T>>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.philote.ID}`;
  }
}

export class Tag<T extends IDType> {
  readonly philote: Philote<T>;
  tag: string;

  constructor(philote: Philote<T>, tag: string) {
    this.philote = philote;
    this.tag = tag;
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Tag<T> {
    return fromJson<Tag<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Tag<T> {
    return fromYaml<Tag<T>>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.philote.ID}`;
  }
}

export class Tags<T extends IDType> {
  readonly philote: Philote<T>;
  tags: Tag<T>[];

  constructor(philote: Philote<T>) {
    this.philote = philote;
    this.tags = [];
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Tags<T> {
    return fromJson<Tags<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Tags<T> {
    return fromYaml<Tags<T>>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.philote.ID}`;
  }
}

export class Predicate<T extends IDType> {
  readonly philote: Philote<T>;
  readonly predicate: string;
  readonly categories: Categorys<T>;
  readonly tags: Tags<T>;

  constructor(philote: Philote<T>, predicate: string, categories: Categorys<T>, tags: Tags<T>) {
    this.philote = philote;
    this.predicate = predicate;
    this.categories = categories;
    this.tags = tags;
  }

  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Predicate<T> {
    return fromJson<Predicate<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Predicate<T> {
    return fromYaml<Predicate<T>>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.philote.ID}`;
  }
}

export class Predicates<T extends IDType> {
  readonly philote: Philote<T>;
  predicates: Predicate<T>[];

  constructor(philote: Philote<T>) {
    this.philote = philote;
    this.predicates = [];
  }
  convertTo_json(): string {
    return toJson(this);
  }

  static convertFrom_json<T extends IDType>(json: string): Predicates<T> {
    return fromJson<Predicates<T>>(json);
  }

  convertTo_yaml(): string {
    return toYaml(this);
  }

  static convertFrom_yaml<T extends IDType>(yaml: string): Predicates<T> {
    return fromYaml<Predicates<T>>(yaml);
  }

  ToString(): string {
    return `Philote: ${this.philote.ID}`;
  }

}
