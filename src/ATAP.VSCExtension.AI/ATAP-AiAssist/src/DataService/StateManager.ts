import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logAsyncFunction } from '@Decorators/index';

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

import { ModeMenuItemEnum, CommandMenuItemEnum } from '@StateMachineService/index';

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

  currentMode: ModeMenuItemEnum;
  currentCommand: CommandMenuItemEnum;
  currentSources: string[];
  disposeAsync(): void;
}

export class StateManager implements IStateManager {
  private readonly cache: GlobalStateCache;
  private disposed = false;
  constructor(
    private logger: ILogger,
    readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly configurationData: IConfigurationData
  ) {
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
      // ToDo: possibly add validationthat the new collection was created
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
      // ToDo: possibly add validationthat the new collection was created
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
    // ToDo: possibly add validationthat the new collection was created
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
    //   // ToDo: possibly add validationthat the new collection was created
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
    //   // ToDo: possibly add validationthat the new collection was created
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
      this.currentCommand = this.cache.getValue<CommandMenuItemEnum>('currentMode') as CommandMenuItemEnum;
    }
    // ToDo: possibly add validationthat the CurrentMode was correctly created and initialized
    logger.log(`currentMode = ${this.currentMode}`, LogLevel.Debug);

    let _currentCommand = this.cache.getValue<ModeMenuItemEnum>('currentMode');
    if (!_currentCommand || (_currentCommand && _currentCommand === undefined)) {
      logger.log(`StateManager.constructor: currentCommand exists as undefined`, LogLevel.Debug);
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache.setValue<CommandMenuItemEnum>('currentCommand', this.configurationData.currentCommand).catch((e) => {
          if (e instanceof Error) {
            throw new DetailedError(`StateManager.constructor: failed to set currentCommand -> `, e);
          } else {
            throw new Error(
              `StateManager .ctor: failed to set currentCommand and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        });
      })();
      // At this point the cache will no longer be undefined
      this.currentCommand = this.cache.getValue<CommandMenuItemEnum>('currentCommand') as CommandMenuItemEnum;
    }
    // ToDo: possibly add validationthat the CurrentCommand was correctly created and initialized
    logger.log(`currentCommand = ${this.currentCommand}`, LogLevel.Debug);

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

    // ToDo: possibly add validationthat the CurrentMode was correctly created and initialized
    logger.log(`CurrentSources = ${this.cache.getValue<string>('CurrentSources')}`, LogLevel.Debug);
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
  async handleCurrentCommandChangedAsync(value: CommandMenuItemEnum): Promise<void> {
    await this.cache.setValue<CommandMenuItemEnum>('currentCommand', value);
  }

  async handleCurrentSourcesChangedAsync(value: string[]): Promise<void> {
    await this.cache.setValue<string[]>('currentSources', value);
  }

  get currentMode(): ModeMenuItemEnum {
    return this.cache.getValue<ModeMenuItemEnum>('currentMode') as ModeMenuItemEnum;
  }

  set currentMode(value: ModeMenuItemEnum) {
    this.handleCurrentModeChangedAsync(value);
  }

  get currentCommand(): CommandMenuItemEnum {
    return this.cache.getValue<CommandMenuItemEnum>('currentCommand') as CommandMenuItemEnum;
  }

  set currentCommand(value: CommandMenuItemEnum) {
    this.handleCurrentCommandChangedAsync(value);
  }

  get currentSources(): string[] {
    return this.cache.getValue<string[]>('currentSources') as string[];
  }

  set currentSources(value: string[]) {
    this.currentSources = value;
    this.handleCurrentSourcesChangedAsync(value);
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
