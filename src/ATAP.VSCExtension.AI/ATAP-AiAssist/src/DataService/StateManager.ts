import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import {
  TagValueType,
  CategoryValueType,
  IAssociationValueType,
  AssociationValueType,
  QueryRequestValueType,
  QueryResponseValueType,
  IQueryPairValueType,
  QueryPairValueType,
  ItemWithIDValueType,
  ItemWithIDTypes,
  //  MapTypeToValueType,
  //  YamlData,
  //  fromYamlForItemWithID,
  IItemWithID,
  ItemWithID,
  ICollection,
  Collection,
  ITag,
  Tag,
  ITagCollection,
  TagCollection,
  ICategory,
  Category,
  ICategoryCollection,
  CategoryCollection,
  IAssociation,
  Association,
  IAssociationCollection,
  AssociationCollection,
  IQueryRequest,
  QueryRequest,
  IQueryResponse,
  QueryResponse,
  IQueryPair,
  QueryPair,
  IQueryPairCollection,
  QueryPairCollection,
  IConversationCollection,
  ConversationCollection,
} from '@ItemWithIDs/index';

import { ModeMenuItemEnum, QueryAgentCommandMenuItemEnum, QueryEngineFlagsEnum } from '@BaseEnumerations/index';

import { IConfigurationData } from './ConfigurationData';

export interface IStateManager {
  getsavedPromptDocumentData(): string | undefined;
  setSavedPromptDocumentData(value: string): Promise<void>;
  getWorkspacePath(): string | undefined;
  setWorkspacePath(value: string): Promise<void>;
  getWorkspaceName(): string | undefined;
  setWorkspaceName(value: string): Promise<void>;
  getWorkspaceRootFolderPath(): string | undefined;
  setWorkspaceRootFolderPath(value: string): Promise<void>;
  getCurrentTag(): ITag | undefined;
  setCurrentTag(value: ITag): Promise<void>;
  getCurrentCategory(): ICategory | undefined;
  setCurrentCategory(value: ICategory): Promise<void>;
  getCurrentAssociation(): IAssociation | undefined;
  setCurrentAssociation(value: IAssociation): Promise<void>;

  currentQueryEngines: QueryEngineFlagsEnum;

  currentMode: ModeMenuItemEnum;
  currentQueryAgentCommand: QueryAgentCommandMenuItemEnum;
  currentSources: string[];
  priorMode: ModeMenuItemEnum;
  priorQueryAgentCommand: QueryAgentCommandMenuItemEnum;
  disposeAsync(): void;
}

export class StateManager implements IStateManager {
  private readonly cache: GlobalStateCache;
  private disposed = false;
  constructor(
    private logger: ILogger,
    readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly configurationData: IConfigurationData,
  ) {
    this.logger = new Logger(`${logger.scope}.${this.constructor.name}`);
    this.cache = new GlobalStateCache(extensionContext);
    // create new collections if there is no collection in GlobalState
    if (!this.cache.getValue<TagCollection>('TagCollection')) {
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache.setValue<TagCollection>('TagCollection', new TagCollection([])).catch((e) => {
          if (e instanceof Error) {
            throw new DetailedError(`StateManager.constructor: failed to set TagCollection -> `, e);
          } else {
            throw new Error(
              `StateManager .ctor: failed to set TagCollection and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        });
      })();
      // ToDo: possibly add validation that the new collection was created
    }
    if (!this.cache.getValue<CategoryCollection>('CategoryCollection')) {
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache.setValue<CategoryCollection>('CategoryCollection', new CategoryCollection([])).catch((e) => {
          if (e instanceof Error) {
            throw new DetailedError(`StateManager.constructor: failed to set CategoryCollection -> `, e);
          } else {
            throw new Error(
              `StateManager .ctor: failed to set CategoryCollection and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        });
      })();
      // ToDo: possibly add validation that the new collection was created
    }
    if (!this.cache.getValue<AssociationCollection>('AssociationCollection')) {
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache
          .setValue<AssociationCollection>('AssociationCollection', new AssociationCollection([]))
          .catch((e) => {
            if (e instanceof Error) {
              throw new DetailedError(`StateManager.constructor: failed to set AssociationCollection -> `, e);
            } else {
              throw new Error(
                `StateManager .ctor: failed to set AssociationCollection and the instance of (e) returned is of type ${typeof e}`,
              );
            }
          });
      })();
    }
    // ToDo: possibly add validation that the new collection was created
    // if (!this.cache.getValue<QueryContextCollection>('QueryContextCollection')) {
    //   // Immediately Invoked Async Function Expression (IIFE)
    //   (() => {
    //     this.cache
    //       .setValue<QueryContextCollection>('QueryContextCollection', new QueryContextCollection([]))
    //       .catch((e) => {
    //         if (e instanceof Error) {
    //           throw new DetailedError(`StateManager.constructor: failed to set QueryContextCollection -> `, e);
    //         } else {
    //           throw new Error(
    //             `StateManager .ctor: failed to set QueryContextCollection and the instance of (e) returned is of type ${typeof e}`,
    //           );
    //         }
    //       });
    //   })();
    //   // ToDo: possibly add validation that the new collection was created
    // }
    // if (!this.cache.getValue<ConversationCollection>('ConversationCollection')) {
    //   // Immediately Invoked Async Function Expression (IIFE)
    //   (() => {
    //     this.cache
    //       .setValue<ConversationCollection>('ConversationCollection', new ConversationCollection([]))
    //       .catch((e) => {
    //         if (e instanceof Error) {
    //           throw new DetailedError(`StateManager.constructor: failed to set ConversationCollection -> `, e);
    //         } else {
    //           throw new Error(
    //             `StateManager .ctor: failed to set ConversationCollection and the instance of (e) returned is of type ${typeof e}`,
    //           );
    //         }
    //       });
    //   })();
    //   // ToDo: possibly add validation that the new collection was created
    // }

    let _currentMode = this.cache.getValue<ModeMenuItemEnum>('currentMode');
    if (!_currentMode || (_currentMode && _currentMode === undefined)) {
      logger.log(`StateManager.constructor: currentMode exists as undefined`, LogLevel.Debug);
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache.setValue<ModeMenuItemEnum>('currentMode', this.configurationData.currentMode).catch((e) => {
          if (e instanceof Error) {
            throw new DetailedError(`StateManager.constructor: failed to set currentMode -> `, e);
          } else {
            throw new Error(
              `StateManager .ctor: failed to set currentMode and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        });
      })();
      // At this point the cache will no longer be undefined
      this.currentMode = this.cache.getValue<ModeMenuItemEnum>('currentMode') as ModeMenuItemEnum;
    }
    // ToDo: possibly add validation that the CurrentMode was correctly created and initialized
    // logger.log(`currentMode = ${this.currentMode}`, LogLevel.Debug);

    let _currentQueryAgentCommand = this.cache.getValue<ModeMenuItemEnum>('currentQueryAgentCommand');
    if (!_currentQueryAgentCommand || (_currentQueryAgentCommand && _currentQueryAgentCommand === undefined)) {
      logger.log(`StateManager.constructor: currentQueryAgentCommand exists as undefined`, LogLevel.Debug);
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache
          .setValue<QueryAgentCommandMenuItemEnum>(
            'currentQueryAgentCommand',
            this.configurationData.currentQueryAgentCommand,
          )
          .catch((e) => {
            if (e instanceof Error) {
              throw new DetailedError(`StateManager.constructor: failed to set currentQueryAgentCommand -> `, e);
            } else {
              throw new Error(
                `StateManager .ctor: failed to set currentQueryAgentCommand and the instance of (e) returned is of type ${typeof e}`,
              );
            }
          });
      })();
      // At this point the cache will no longer be undefined
      this.currentQueryAgentCommand = this.cache.getValue<QueryAgentCommandMenuItemEnum>(
        'currentQueryAgentCommand',
      ) as QueryAgentCommandMenuItemEnum;
    }
    // ToDo: possibly add validation that the CurrentCommand was correctly created and initialized
    //  logger.log(`currentQueryAgentCommand = ${this.currentQueryAgentCommand}`, LogLevel.Debug);

    let _currentQueryEngines = this.cache.getValue<QueryEngineFlagsEnum>('currentQueryEngines');
    if (!_currentQueryEngines || (_currentQueryEngines && _currentQueryEngines === undefined)) {
      logger.log(`StateManager.constructor: currentQueryEngines exists as undefined`, LogLevel.Debug);
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache
          .setValue<QueryEngineFlagsEnum>('currentQueryAgentCommand', this.configurationData.currentQueryEngines)
          .catch((e) => {
            if (e instanceof Error) {
              throw new DetailedError(`StateManager.constructor: failed to set currentQueryEngines -> `, e);
            } else {
              throw new Error(
                `StateManager .ctor: failed to set currentQueryEngines and the instance of (e) returned is of type ${typeof e}`,
              );
            }
          });
      })();
      // At this point the cache will no longer be undefined
      this.currentQueryEngines = this.cache.getValue<QueryEngineFlagsEnum>(
        'currentQueryEngines',
      ) as QueryEngineFlagsEnum;
    }
    // ToDo: possibly add validation that the currentQueryEngines was correctly created and initialized
    //logger.log(`currentQueryEngines = ${this.currentQueryEngines}`, LogLevel.Debug);

    if (!this.cache.getValue<string>('CurrentSources')) {
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache.setValue<string>('CurrentSources', 'all').catch((e) => {
          if (e instanceof Error) {
            throw new DetailedError(`StateManager.constructor: failed to set CurrentSources -> `, e);
          } else {
            throw new Error(
              `StateManager .ctor: failed to set CurrentSources and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        });
      })();
    }

    // ToDo: possibly add validation that the CurrentMode was correctly created and initialized
    // logger.log(`CurrentSources = ${this.cache.getValue<string>('CurrentSources')}`, LogLevel.Debug);

    let _priorMode = this.cache.getValue<ModeMenuItemEnum>('priorMode');
    if (!_priorMode || (_priorMode && _priorMode === undefined)) {
      logger.log(`StateManager.constructor: priorMode exists as undefined`, LogLevel.Debug);
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache.setValue<ModeMenuItemEnum>('priorMode', this.configurationData.priorMode).catch((e) => {
          if (e instanceof Error) {
            throw new DetailedError(`StateManager.constructor: failed to set priorMode -> `, e);
          } else {
            throw new Error(
              `StateManager .ctor: failed to set priorMode and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        });
      })();
      // At this point the cache will no longer be undefined
      this.priorQueryAgentCommand = this.cache.getValue<QueryAgentCommandMenuItemEnum>(
        'priorMode',
      ) as QueryAgentCommandMenuItemEnum;
    }
    // ToDo: possibly add validation that the PriorMode was correctly created and initialized
    // logger.log(`priorMode = ${this.priorMode}`, LogLevel.Debug);

    let _priorQueryAgentCommand = this.cache.getValue<ModeMenuItemEnum>('priorMode');
    if (!_priorQueryAgentCommand || (_priorQueryAgentCommand && _priorQueryAgentCommand === undefined)) {
      logger.log(`StateManager.constructor: priorQueryAgentCommand exists as undefined`, LogLevel.Debug);
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache
          .setValue<QueryAgentCommandMenuItemEnum>(
            'priorQueryAgentCommand',
            this.configurationData.priorQueryAgentCommand,
          )
          .catch((e) => {
            if (e instanceof Error) {
              throw new DetailedError(`StateManager.constructor: failed to set priorQueryAgentCommand -> `, e);
            } else {
              throw new Error(
                `StateManager .ctor: failed to set priorQueryAgentCommand and the instance of (e) returned is of type ${typeof e}`,
              );
            }
          });
      })();
      // At this point the cache will no longer be undefined
      this.priorQueryAgentCommand = this.cache.getValue<QueryAgentCommandMenuItemEnum>(
        'priorQueryAgentCommand',
      ) as QueryAgentCommandMenuItemEnum;
    }
    // ToDo: possibly add validation that the PriorCommand was correctly created and initialized
    // logger.log(`priorQueryAgentCommand = ${this.priorQueryAgentCommand}`, LogLevel.Debug);
  }

  getsavedPromptDocumentData(): string | undefined {
    return this.cache.getValue('savedPromptDocumentData');
  }

  async setSavedPromptDocumentData(value: string): Promise<void> {
    await this.cache.setValue<string>('savedPromptDocumentData', value);
  }

  getWorkspacePath(): string | undefined {
    return this.cache.getValue('WorkspacePath');
  }

  async setWorkspacePath(value: string): Promise<void> {
    await this.cache.setValue<string>('WorkspacePath', value);
  }

  getWorkspaceName(): string | undefined {
    return this.cache.getValue('WorkspaceName');
  }

  async setWorkspaceName(value: string): Promise<void> {
    await this.cache.setValue<string>('WorkspaceName', value);
  }

  getWorkspaceRootFolderPath(): string | undefined {
    return this.cache.getValue('WorkspaceRootFolderPath');
  }

  async setWorkspaceRootFolderPath(value: string): Promise<void> {
    await this.cache.setValue<string>('WorkspaceRootFolderPath', value);
  }

  getCurrentTag(): ITag | undefined {
    return this.cache.getValue<ITag>('Tag');
  }

  async setCurrentTag(value: ITag): Promise<void> {
    await this.cache.setValue<ITag>('Tag', value);
  }

  getTagCollection(): ITagCollection | undefined {
    return this.cache.getValue<ITagCollection>('TagCollection');
  }

  async setTagCollection(value: ITagCollection): Promise<void> {
    await this.cache.setValue<ITagCollection>('TagCollection', value);
  }

  getCurrentCategory(): ICategory | undefined {
    return this.cache.getValue<ICategory>('Category');
  }

  async setCurrentCategory(value: ICategory): Promise<void> {
    await this.cache.setValue<ICategory>('Category', value);
  }

  getCategoryCollection(): ICategoryCollection | undefined {
    return this.cache.getValue<ICategoryCollection>('CategoryCollection');
  }

  async setCategoryCollection(value: ICategoryCollection): Promise<void> {
    await this.cache.setValue<ICategoryCollection>('CategoryCollection', value);
  }

  getCurrentAssociation(): IAssociation | undefined {
    return this.cache.getValue<IAssociation>('Association');
  }

  async setCurrentAssociation(value: IAssociation): Promise<void> {
    await this.cache.setValue<IAssociation>('Association', value);
  }

  getAssociationCollection(): IAssociationCollection | undefined {
    return this.cache.getValue<IAssociationCollection>('AssociationCollection');
  }

  async setAssociationCollection(value: IAssociationCollection): Promise<void> {
    await this.cache.setValue<IAssociationCollection>('AssociationCollection', value);
  }

  // getCurrentQueryContext(): IQueryContext | undefined {
  //   return this.cache.getValue<IQueryContext>('QueryContext');
  // }

  // async setCurrentQueryContext(value: IQueryContext): Promise<void> {
  //   await this.cache.setValue<IQueryContext>('QueryContext', value);
  // }

  // getQueryContextCollection(): IQueryContextCollection | undefined {
  //   return this.cache.getValue<IQueryContextCollection>('QueryContextCollection');
  // }

  // async setQueryContextCollection(value: IQueryContextCollection): Promise<void> {
  //   await this.cache.setValue<IQueryContextCollection>('QueryContextCollection', value);
  // }

  async handleCurrentModeChangedAsync(value: ModeMenuItemEnum): Promise<void> {
    await this.cache.setValue<ModeMenuItemEnum>('currentMode', value);
  }
  async handleCurrentQueryAgentCommandChangedAsync(value: QueryAgentCommandMenuItemEnum): Promise<void> {
    await this.cache.setValue<QueryAgentCommandMenuItemEnum>('currentQueryAgentCommand', value);
  }

  async handleCurrentQueryEnginesChangedAsync(value: QueryEngineFlagsEnum): Promise<void> {
    await this.cache.setValue<QueryEngineFlagsEnum>('currentQueryEngines', value);
  }

  async handleCurrentSourcesChangedAsync(value: string[]): Promise<void> {
    await this.cache.setValue<string[]>('currentSources', value);
  }

  async handlePriorModeChangedAsync(value: ModeMenuItemEnum): Promise<void> {
    await this.cache.setValue<ModeMenuItemEnum>('priorMode', value);
  }
  async handlePriorQueryAgentCommandChangedAsync(value: QueryAgentCommandMenuItemEnum): Promise<void> {
    await this.cache.setValue<QueryAgentCommandMenuItemEnum>('priorQueryAgentCommand', value);
  }

  get currentMode(): ModeMenuItemEnum {
    return this.cache.getValue<ModeMenuItemEnum>('currentMode') as ModeMenuItemEnum;
  }

  set currentMode(value: ModeMenuItemEnum) {
    this.handleCurrentModeChangedAsync(value);
  }

  get currentQueryAgentCommand(): QueryAgentCommandMenuItemEnum {
    return this.cache.getValue<QueryAgentCommandMenuItemEnum>(
      'currentQueryAgentCommand',
    ) as QueryAgentCommandMenuItemEnum;
  }

  set currentQueryAgentCommand(value: QueryAgentCommandMenuItemEnum) {
    this.handleCurrentQueryAgentCommandChangedAsync(value);
  }

  get currentQueryEngines(): QueryEngineFlagsEnum {
    return this.cache.getValue<QueryEngineFlagsEnum>('currentQueryEngines') as QueryEngineFlagsEnum;
  }

  set currentQueryEngines(value: QueryEngineFlagsEnum) {
    this.handleCurrentQueryEnginesChangedAsync(value);
  }

  get currentSources(): string[] {
    return this.cache.getValue<string[]>('currentSources') as string[];
  }

  set currentSources(value: string[]) {
    this.currentSources = value;
    this.handleCurrentSourcesChangedAsync(value);
  }

  get priorMode(): ModeMenuItemEnum {
    return this.cache.getValue<ModeMenuItemEnum>('priorMode') as ModeMenuItemEnum;
  }

  set priorMode(value: ModeMenuItemEnum) {
    this.handlePriorModeChangedAsync(value);
  }

  get priorQueryAgentCommand(): QueryAgentCommandMenuItemEnum {
    return this.cache.getValue<QueryAgentCommandMenuItemEnum>(
      'priorQueryAgentCommand',
    ) as QueryAgentCommandMenuItemEnum;
  }

  set priorQueryAgentCommand(value: QueryAgentCommandMenuItemEnum) {
    this.handlePriorQueryAgentCommandChangedAsync(value);
  }

  @logAsyncFunction
  async disposeAsync() {
    if (!this.disposed) {
      // release the GlobalStateCache
      this.disposed = true;
    }
  }
}

class GlobalStateCache {
  private readonly cache: { [key: string]: any } = {};
  private readonly extensionContext: vscode.ExtensionContext;
  private disposed = false;
  constructor(extensionContext: vscode.ExtensionContext) {
    this.extensionContext = extensionContext;
  }

  getValue<T>(key: string): T | undefined {
    // First, try to get the value from the in-memory cache
    if (this.cache.hasOwnProperty(key)) {
      return this.cache[key] as T;
    }
    // If not available, read from globalState and update the cache
    const value = this.extensionContext.globalState.get<T>(key);
    if (value !== undefined) {
      this.cache[key] = value;
    }
    return value;
  }

  async setValue<T>(key: string, value: T): Promise<void> {
    // Update the cache first
    this.cache[key] = value;

    // Persist the value to globalState
    try {
      await this.extensionContext.globalState.update(key, value);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`GlobalStateCache: failed to set ${key} -> `, e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `GlobalStateCache: failed to set ${key} and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }

  async clearValue(key: string): Promise<void> {
    // Clear the cache
    delete this.cache[key];
    // Remove the value from globalState
    try {
      this.extensionContext.globalState.update(key, undefined);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`GlobalStateCache: failed to clear ${key} -> `, e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `GlobalStateCache: failed to clear ${key} and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }

  dispose() {
    if (!this.disposed) {
      // release any resources
      this.disposed = true;
    }
  }
}
